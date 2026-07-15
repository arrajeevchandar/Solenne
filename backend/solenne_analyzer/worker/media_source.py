from __future__ import annotations

from pathlib import Path
from urllib.parse import unquote, urlparse

import httpx


class MediaSourceError(RuntimeError):
    """Raised when a journal media source is unsafe or unavailable."""


def validate_cloudinary_video_url(
    url: str,
    *,
    cloud_name: str,
    folder: str,
) -> None:
    parsed = urlparse(url)
    if parsed.scheme != "https" or parsed.hostname != "res.cloudinary.com":
        raise MediaSourceError("Journal video must use the Cloudinary HTTPS host.")
    path = unquote(parsed.path)
    expected_prefix = f"/{cloud_name}/video/upload/"
    if not path.startswith(expected_prefix):
        raise MediaSourceError("Journal video belongs to an unexpected Cloudinary cloud.")
    folder_marker = f"/{folder.strip('/')}/"
    if folder_marker not in path:
        raise MediaSourceError("Journal video is outside the Solenne journals folder.")


def download_cloudinary_video(
    url: str,
    destination: Path,
    *,
    timeout_seconds: float,
    max_bytes: int,
) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    total = 0
    try:
        with httpx.Client(
            timeout=httpx.Timeout(timeout_seconds),
            follow_redirects=False,
        ) as client:
            with client.stream("GET", url) as response:
                response.raise_for_status()
                content_type = response.headers.get("content-type", "")
                if content_type and not (
                    content_type.lower().startswith("video/")
                    or content_type.lower().startswith("application/octet-stream")
                ):
                    raise MediaSourceError("Cloudinary returned a non-video response.")
                with destination.open("wb") as output:
                    for chunk in response.iter_bytes():
                        total += len(chunk)
                        if total > max_bytes:
                            raise MediaSourceError("Journal video exceeds the worker size limit.")
                        output.write(chunk)
    except httpx.HTTPError as error:
        raise MediaSourceError("Cloudinary video download failed.") from error

    if total == 0:
        raise MediaSourceError("Cloudinary returned an empty video.")
