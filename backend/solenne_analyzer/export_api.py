from __future__ import annotations

import logging
import re
import time
from typing import Iterator

from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from firebase_admin import auth
import httpx

from .worker.cloudinary_admin import CloudinaryAdminClient
from .worker.config import WorkerConfig
from .worker.firebase_gateway import ExportDownload, FirebaseGateway


LOGGER = logging.getLogger("solenne.export_api")
_SAFE_FILENAME = re.compile(r"[^A-Za-z0-9._-]+")


def create_app(
    *,
    config: WorkerConfig | None = None,
    gateway: FirebaseGateway | None = None,
    cloudinary_client: CloudinaryAdminClient | None = None,
    token_verifier=None,
    http_client_factory=None,
) -> FastAPI:
    runtime_config = config or WorkerConfig.from_env()
    runtime_gateway = gateway or FirebaseGateway(runtime_config)
    cloudinary = cloudinary_client or CloudinaryAdminClient(runtime_config)
    verify_token = token_verifier or auth.verify_id_token
    client_factory = http_client_factory or (
        lambda: httpx.Client(
            timeout=httpx.Timeout(300),
            follow_redirects=False,
        )
    )

    app = FastAPI(title="Solenne export download service", docs_url=None)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=list(runtime_config.export_allowed_origins),
        allow_credentials=False,
        allow_methods=["GET"],
        allow_headers=["Authorization"],
    )

    @app.get("/health")
    def health() -> dict[str, str]:
        return {"status": "ok"}

    @app.get("/v1/exports/{job_id}/download")
    def download_export(
        job_id: str,
        authorization: str | None = Header(default=None),
    ):
        user_id = _authenticated_user_id(authorization, verify_token)
        try:
            download = runtime_gateway.consume_export(job_id, user_id)
        except LookupError as error:
            raise HTTPException(status_code=404, detail=str(error)) from error
        except PermissionError as error:
            raise HTTPException(status_code=403, detail=str(error)) from error
        except (TimeoutError, FileExistsError) as error:
            raise HTTPException(status_code=410, detail=str(error)) from error
        except RuntimeError as error:
            raise HTTPException(status_code=409, detail=str(error)) from error

        signed_url = cloudinary.private_download_url(
            download.public_id,
            file_format=download.file_format,
            expires_at=int(time.time()) + 300,
        )
        client = client_factory()
        stream_context = client.stream("GET", signed_url)
        try:
            upstream = stream_context.__enter__()
            upstream.raise_for_status()
        except Exception as error:
            stream_context.__exit__(type(error), error, error.__traceback__)
            client.close()
            _consume_and_cleanup(
                runtime_gateway,
                cloudinary,
                download,
                error=f"Download source unavailable: {error}",
            )
            raise HTTPException(
                status_code=502,
                detail="The export could not be retrieved.",
            ) from error

        def body() -> Iterator[bytes]:
            stream_error: str | None = None
            try:
                yield from upstream.iter_bytes(chunk_size=64 * 1024)
            except Exception as error:
                stream_error = f"Download interrupted: {error}"
                LOGGER.warning("Export %s download interrupted.", download.job_id)
            finally:
                stream_context.__exit__(None, None, None)
                client.close()
                _consume_and_cleanup(
                    runtime_gateway,
                    cloudinary,
                    download,
                    error=stream_error,
                )

        headers = {
            "Content-Disposition": (
                f'attachment; filename="{_safe_filename(download.filename)}"'
            ),
            "Cache-Control": "no-store",
            "X-Content-Type-Options": "nosniff",
        }
        if download.size_bytes > 0:
            headers["Content-Length"] = str(download.size_bytes)
        return StreamingResponse(
            body(),
            media_type="application/zip",
            headers=headers,
        )

    return app


def _authenticated_user_id(authorization: str | None, verifier) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Authentication is required.")
    token = authorization[7:].strip()
    if not token:
        raise HTTPException(status_code=401, detail="Authentication is required.")
    try:
        decoded = verifier(token)
    except Exception as error:
        raise HTTPException(
            status_code=401, detail="Authentication token is invalid."
        ) from error
    user_id = str((decoded or {}).get("uid", "")).strip()
    if not user_id:
        raise HTTPException(
            status_code=401, detail="Authentication token has no user ID."
        )
    return user_id


def _consume_and_cleanup(
    gateway: FirebaseGateway,
    cloudinary: CloudinaryAdminClient,
    download: ExportDownload,
    *,
    error: str | None,
) -> None:
    cleanup_error = error
    cleanup_pending = False
    try:
        cloudinary.destroy_private_zip(download.public_id)
    except Exception as cloudinary_error:
        LOGGER.error(
            "Could not remove consumed export %s: %s",
            download.job_id,
            cloudinary_error,
        )
        cleanup_error = cleanup_error or "Archive cleanup requires a retry."
        cleanup_pending = True
    try:
        gateway.finish_export_consumption(
            download.job_id,
            error=cleanup_error,
            cleanup_pending=cleanup_pending,
        )
    except Exception as firestore_error:
        LOGGER.error(
            "Could not finalize consumed export %s: %s",
            download.job_id,
            firestore_error,
        )


def _safe_filename(value: str) -> str:
    cleaned = _SAFE_FILENAME.sub("-", value.strip()).strip(".-")
    return (cleaned or "solenne-export.zip")[:120]
