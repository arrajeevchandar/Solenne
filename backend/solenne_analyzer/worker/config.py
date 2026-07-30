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
    cloudinary_api_key: str = ""
    cloudinary_api_secret: str = ""
    export_zip_max_bytes: int = 100 * 1024 * 1024
    export_expiry_hours: int = 24
    export_allowed_origins: tuple[str, ...] = ("*",)
    analysis_lease_seconds: int = 90
    analysis_heartbeat_seconds: int = 15
    analysis_max_attempts: int = 3
    deletion_lease_seconds: int = 60
    deletion_cancel_grace_seconds: int = 15

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
            cloudinary_api_key=os.environ.get("CLOUDINARY_API_KEY", "").strip(),
            cloudinary_api_secret=os.environ.get(
                "CLOUDINARY_API_SECRET", ""
            ).strip(),
            export_zip_max_bytes=int(
                os.environ.get(
                    "MAX_EXPORT_ZIP_BYTES", str(100 * 1024 * 1024)
                )
            ),
            export_expiry_hours=max(
                1, int(os.environ.get("EXPORT_EXPIRY_HOURS", "24"))
            ),
            export_allowed_origins=tuple(
                origin.strip()
                for origin in os.environ.get(
                    "EXPORT_ALLOWED_ORIGINS", "*"
                ).split(",")
                if origin.strip()
            )
            or ("*",),
            analysis_lease_seconds=max(
                30, int(os.environ.get("ANALYSIS_LEASE_SECONDS", "90"))
            ),
            analysis_heartbeat_seconds=max(
                5, int(os.environ.get("ANALYSIS_HEARTBEAT_SECONDS", "15"))
            ),
            analysis_max_attempts=max(
                1, int(os.environ.get("ANALYSIS_MAX_ATTEMPTS", "3"))
            ),
            deletion_lease_seconds=max(
                30, int(os.environ.get("DELETION_LEASE_SECONDS", "60"))
            ),
            deletion_cancel_grace_seconds=max(
                0, int(os.environ.get("DELETION_CANCEL_GRACE_SECONDS", "15"))
            ),
        )

    def validate(self) -> None:
        if self.analysis_heartbeat_seconds >= self.analysis_lease_seconds:
            raise ValueError(
                "ANALYSIS_HEARTBEAT_SECONDS must be lower than "
                "ANALYSIS_LEASE_SECONDS."
            )
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

    @property
    def has_cloudinary_admin_credentials(self) -> bool:
        return bool(self.cloudinary_api_key and self.cloudinary_api_secret)

    def validate_cloudinary_admin(self) -> None:
        if not self.has_cloudinary_admin_credentials:
            raise ValueError(
                "CLOUDINARY_API_KEY and CLOUDINARY_API_SECRET are required "
                "for deletion and export jobs."
            )
