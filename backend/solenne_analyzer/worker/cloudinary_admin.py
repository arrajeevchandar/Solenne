from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import time

from .config import WorkerConfig


class CloudinaryAdminError(RuntimeError):
    """Raised when a privileged Cloudinary operation cannot be completed."""


@dataclass(frozen=True)
class PrivateArchive:
    public_id: str
    bytes: int
    format: str = "zip"


class CloudinaryAdminClient:
    def __init__(self, config: WorkerConfig) -> None:
        config.validate_cloudinary_admin()
        try:
            import cloudinary
        except ImportError as error:
            raise CloudinaryAdminError(
                "The cloudinary package is required for media cleanup and exports."
            ) from error
        cloudinary.config(
            cloud_name=config.cloudinary_cloud_name,
            api_key=config.cloudinary_api_key,
            api_secret=config.cloudinary_api_secret,
            secure=True,
        )

    def destroy_video(self, public_id: str) -> None:
        from cloudinary import uploader

        try:
            result = uploader.destroy(
                public_id,
                resource_type="video",
                type="upload",
                invalidate=True,
            )
        except Exception as error:
            raise CloudinaryAdminError("Cloudinary video deletion failed.") from error
        outcome = str((result or {}).get("result", "")).lower()
        if outcome not in {"ok", "not found"}:
            raise CloudinaryAdminError(
                f"Cloudinary video deletion returned {outcome or 'no result'}."
            )

    def upload_private_zip(
        self,
        archive_path: Path,
        *,
        public_id: str,
    ) -> PrivateArchive:
        from cloudinary import uploader

        try:
            result = uploader.upload(
                str(archive_path),
                resource_type="raw",
                type="private",
                public_id=public_id,
                overwrite=True,
            )
        except Exception as error:
            raise CloudinaryAdminError("Private ZIP upload failed.") from error
        saved_public_id = str((result or {}).get("public_id", "")).strip()
        if not saved_public_id:
            raise CloudinaryAdminError("Private ZIP upload returned no public ID.")
        return PrivateArchive(
            public_id=saved_public_id,
            bytes=int((result or {}).get("bytes", archive_path.stat().st_size)),
            format=str((result or {}).get("format", "zip") or "zip"),
        )

    def private_download_url(
        self,
        public_id: str,
        *,
        file_format: str = "zip",
        expires_at: int | None = None,
    ) -> str:
        from cloudinary import utils

        expiry = expires_at or int(time.time()) + 300
        try:
            return str(
                utils.private_download_url(
                    public_id,
                    file_format,
                    resource_type="raw",
                    type="private",
                    expires_at=expiry,
                    attachment=True,
                )
            )
        except Exception as error:
            raise CloudinaryAdminError(
                "Could not create a private ZIP download URL."
            ) from error

    def destroy_private_zip(self, public_id: str) -> None:
        from cloudinary import uploader

        try:
            result = uploader.destroy(
                public_id,
                resource_type="raw",
                type="private",
                invalidate=True,
            )
        except Exception as error:
            raise CloudinaryAdminError("Private ZIP deletion failed.") from error
        outcome = str((result or {}).get("result", "")).lower()
        if outcome not in {"ok", "not found"}:
            raise CloudinaryAdminError(
                f"Private ZIP deletion returned {outcome or 'no result'}."
            )
