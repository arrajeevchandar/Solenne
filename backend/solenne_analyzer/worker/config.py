from __future__ import annotations

from dataclasses import dataclass
import os
from pathlib import Path

from ..config import BACKEND_ROOT, load_dotenv


@dataclass(frozen=True)
class WorkerConfig:
    firebase_project_id: str
    firebase_service_account: Path | None
    poll_interval_seconds: float
    cloudinary_cloud_name: str
    cloudinary_folder: str
    whisper_model: str
    max_video_seconds: int
    max_download_bytes: int
    download_timeout_seconds: float
    transient_retries: int

    @classmethod
    def from_env(cls) -> "WorkerConfig":
        load_dotenv(BACKEND_ROOT / ".env")
        account_value = os.environ.get("FIREBASE_SERVICE_ACCOUNT")
        default_account = BACKEND_ROOT / "serviceAccountKey.json"
        account_path: Path | None = None
        if account_value:
            account_path = Path(account_value)
            if not account_path.is_absolute():
                account_path = BACKEND_ROOT / account_path
            account_path = account_path.resolve()
        elif default_account.is_file():
            account_path = default_account.resolve()
        return cls(
            firebase_project_id=os.environ.get(
                "FIREBASE_PROJECT_ID", "solenne-9324d"
            ),
            firebase_service_account=account_path,
            poll_interval_seconds=float(
                os.environ.get("POLL_INTERVAL_SECONDS", "5")
            ),
            cloudinary_cloud_name=os.environ.get(
                "CLOUDINARY_CLOUD_NAME", "dqjd3lszl"
            ),
            cloudinary_folder=os.environ.get(
                "CLOUDINARY_UPLOAD_FOLDER", "solenne/journals"
            ).strip("/"),
            whisper_model=os.environ.get("WHISPER_MODEL", "base"),
            max_video_seconds=int(os.environ.get("MAX_VIDEO_SECONDS", "180")),
            max_download_bytes=int(
                os.environ.get("MAX_VIDEO_BYTES", str(500 * 1024 * 1024))
            ),
            download_timeout_seconds=float(
                os.environ.get("DOWNLOAD_TIMEOUT_SECONDS", "90")
            ),
            transient_retries=max(
                1, int(os.environ.get("TRANSIENT_RETRIES", "3"))
            ),
        )

    def validate(self) -> None:
        if (
            self.firebase_service_account is not None
            and not self.firebase_service_account.is_file()
        ):
            raise FileNotFoundError(
                "Firebase Admin credentials were not found at "
                f"{self.firebase_service_account}. Generate a private key in "
                "Firebase Console > Project settings > Service accounts and set "
                "FIREBASE_SERVICE_ACCOUNT in backend/.env."
            )
