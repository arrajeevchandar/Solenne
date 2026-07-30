from __future__ import annotations

from datetime import datetime, timezone
import logging
from pathlib import Path
import re
import subprocess
import tempfile
import time
from urllib.parse import urlparse
import zipfile

from ..config import DependencyMissingError, MediaValidationError
from ..pipeline.media import _ffmpeg_executable
from .cloudinary_admin import CloudinaryAdminClient
from .config import WorkerConfig
from .firebase_gateway import (
    ClaimedDeletionJob,
    ClaimedExportJob,
    FirebaseGateway,
)
from .media_source import (
    download_cloudinary_video,
    validate_cloudinary_video_url,
)


LOGGER = logging.getLogger("solenne.privacy")
_SAFE_NAME = re.compile(r"[^A-Za-z0-9_-]+")


class ExportBuildError(RuntimeError):
    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


class DeletionWorker:
    def __init__(
        self,
        config: WorkerConfig,
        gateway: FirebaseGateway,
        cloudinary_client: CloudinaryAdminClient,
    ) -> None:
        self.config = config
        self.gateway = gateway
        self.cloudinary = cloudinary_client

    def process_next(self) -> bool:
        job = self.gateway.claim_next_deletion()
        if job is None:
            return False
        return self._process(job)

    def cleanup_next(self) -> bool:
        return self.gateway.cleanup_expired_deletion()

    def _process(self, job: ClaimedDeletionJob) -> bool:
        LOGGER.info("Processing deletion job %s", job.id)
        try:
            prepared = self.gateway.prepare_deletion(job)
            if prepared.wait_for_analysis:
                LOGGER.info("Deletion job %s is waiting for analysis.", job.id)
                return False
            journal = prepared.journal
            if journal is not None:
                public_id = validate_cloudinary_public_id(
                    str(journal.get("cloudinaryPublicId", "")),
                    folder=self.config.cloudinary_folder,
                )
                if public_id:
                    self._destroy_video_with_retry(public_id)
            self.gateway.complete_deletion(job)
            LOGGER.info("Completed deletion job %s", job.id)
            return True
        except Exception as error:
            LOGGER.error("Deletion job %s failed: %s", job.id, _safe_error(error))
            self.gateway.fail_deletion(
                job,
                code="media_delete_failed",
                message=_safe_error(error),
            )
            return True

    def _destroy_video_with_retry(self, public_id: str) -> None:
        last_error: Exception | None = None
        for attempt in range(1, self.config.transient_retries + 1):
            try:
                self.cloudinary.destroy_video(public_id)
                return
            except Exception as error:
                last_error = error
                if attempt < self.config.transient_retries:
                    time.sleep(2 ** (attempt - 1))
        assert last_error is not None
        raise last_error


class ExportWorker:
    def __init__(
        self,
        config: WorkerConfig,
        gateway: FirebaseGateway,
        cloudinary_client: CloudinaryAdminClient,
    ) -> None:
        self.config = config
        self.gateway = gateway
        self.cloudinary = cloudinary_client

    def expire_next(self) -> bool:
        pending = self.gateway.claim_pending_artifact_cleanup()
        if pending is not None:
            try:
                self.cloudinary.destroy_private_zip(pending.public_id)
                self.gateway.complete_artifact_cleanup(pending.job_id)
            except Exception as error:
                LOGGER.warning(
                    "Export %s cleanup retry failed: %s",
                    pending.job_id,
                    _safe_error(error),
                )
                return False
            return True
        expired = self.gateway.claim_expired_export()
        if expired is None:
            return False
        try:
            self.cloudinary.destroy_private_zip(expired.public_id)
        except Exception as error:
            LOGGER.warning(
                "Expired export %s cleanup failed: %s",
                expired.job_id,
                _safe_error(error),
            )
            self.gateway.mark_artifact_cleanup_pending(expired.job_id)
            return False
        else:
            self.gateway.complete_artifact_cleanup(expired.job_id)
        return True

    def process_next(self) -> bool:
        job = self.gateway.claim_next_export()
        if job is None:
            return False
        self._process(job)
        return True

    def _process(self, job: ClaimedExportJob) -> None:
        LOGGER.info("Processing export job %s", job.id)
        uploaded_public_id: str | None = None
        try:
            journals = self.gateway.get_export_journals(job)
            with tempfile.TemporaryDirectory(prefix="solenne-export-") as value:
                temp_dir = Path(value)
                archive_path, included_count, skipped = build_export_archive(
                    job,
                    journals,
                    temp_dir=temp_dir,
                    config=self.config,
                    on_progress=lambda step, count: self.gateway.update_export_progress(
                        job, step=step, completed_items=count
                    ),
                )
                archive = self.cloudinary.upload_private_zip(
                    archive_path,
                    public_id=(
                        f"solenne/exports/{_safe_component(job.user_id)}/"
                        f"{_safe_component(job.id)}.zip"
                    ),
                )
                uploaded_public_id = archive.public_id
                filename = export_filename(job.export_kind, job.id)
                self.gateway.complete_export(
                    job,
                    public_id=archive.public_id,
                    file_format=archive.format,
                    filename=filename,
                    size_bytes=archive.bytes,
                    included_count=included_count,
                    skipped=skipped,
                    expiry_hours=self.config.export_expiry_hours,
                )
            LOGGER.info("Completed export job %s", job.id)
        except ExportBuildError as error:
            LOGGER.error("Export job %s failed: %s", job.id, _safe_error(error))
            self.gateway.fail_export(
                job,
                code=error.code,
                message=_safe_error(error),
            )
        except Exception as error:
            if uploaded_public_id:
                try:
                    self.cloudinary.destroy_private_zip(uploaded_public_id)
                except Exception as cleanup_error:
                    LOGGER.error(
                        "Could not roll back export %s after failure: %s",
                        job.id,
                        _safe_error(cleanup_error),
                    )
            LOGGER.error("Export job %s failed: %s", job.id, _safe_error(error))
            self.gateway.fail_export(
                job,
                code="export_failed",
                message=_safe_error(error),
            )


def build_export_archive(
    job: ClaimedExportJob,
    journals: list[tuple[str, dict]],
    *,
    temp_dir: Path,
    config: WorkerConfig,
    on_progress=None,
) -> tuple[Path, int, list[dict[str, str]]]:
    temp_dir.mkdir(parents=True, exist_ok=True)
    archive_path = temp_dir / "solenne-export.zip"
    skipped: list[dict[str, str]] = []
    included_count = 0
    selected_by_id = {journal_id: data for journal_id, data in journals}
    total_processed = 0

    with zipfile.ZipFile(
        archive_path,
        mode="w",
        compression=zipfile.ZIP_DEFLATED,
        compresslevel=6,
    ) as archive:
        for journal_id in job.journal_ids:
            journal = selected_by_id.get(journal_id)
            if journal is None:
                skipped.append(
                    {"journalId": journal_id, "reason": "session unavailable"}
                )
                continue
            stem = journal_archive_stem(journal_id, journal)
            if job.export_kind in {"transcript", "both"}:
                transcript = journal.get("transcript") or {}
                text = str(transcript.get("text", "")).strip()
                if text:
                    archive.writestr(
                        f"transcripts/{stem}.txt",
                        transcript_document(journal, transcript, text),
                    )
                    included_count += 1
                else:
                    skipped.append(
                        {"journalId": journal_id, "reason": "transcript unavailable"}
                    )

            if job.export_kind in {"audio", "both"}:
                try:
                    mp3_path = _journal_mp3(
                        journal_id,
                        journal,
                        temp_dir=temp_dir,
                        config=config,
                    )
                    archive.write(mp3_path, f"audio/{stem}.mp3")
                    included_count += 1
                    mp3_path.unlink(missing_ok=True)
                except Exception as error:
                    LOGGER.warning(
                        "Skipping audio for %s: %s",
                        journal_id,
                        _safe_error(error),
                    )
                    skipped.append(
                        {"journalId": journal_id, "reason": "audio unavailable"}
                    )
            total_processed += 1
            if on_progress:
                on_progress("building_archive", total_processed)

        archive.writestr(
            "export-summary.txt",
            export_summary(job, included_count=included_count, skipped=skipped),
        )

    if included_count == 0:
        raise ExportBuildError(
            "nothing_exportable",
            "None of the selected sessions had files available to export.",
        )
    size = archive_path.stat().st_size
    if size > config.export_zip_max_bytes:
        raise ExportBuildError(
            "archive_too_large",
            "The ZIP is larger than 100 MB. Select fewer sessions and try again.",
        )
    return archive_path, included_count, skipped


def validate_cloudinary_public_id(public_id: str, *, folder: str) -> str:
    value = public_id.strip().strip("/")
    if not value:
        return ""
    expected = f"{folder.strip('/')}/"
    if not value.startswith(expected):
        raise ValueError("Journal media is outside the Solenne journals folder.")
    if ".." in value.split("/"):
        raise ValueError("Journal media public ID is invalid.")
    return value


def journal_archive_stem(journal_id: str, journal: dict) -> str:
    recorded_at = journal.get("recordedAt")
    if isinstance(recorded_at, datetime):
        local = recorded_at.astimezone(timezone.utc)
        prefix = local.strftime("%Y-%m-%d_%H-%M")
    else:
        prefix = "undated"
    return f"{prefix}_{_safe_component(journal_id)[-24:]}"


def transcript_document(journal: dict, transcript: dict, text: str) -> str:
    recorded_at = journal.get("recordedAt")
    recorded = (
        recorded_at.astimezone(timezone.utc).isoformat()
        if isinstance(recorded_at, datetime)
        else "Unknown"
    )
    title = str(journal.get("title") or journal.get("prompt") or "Reflection").strip()
    language = str(transcript.get("language") or "Unknown").strip()
    return (
        f"Title: {title}\n"
        f"Recorded: {recorded}\n"
        f"Language: {language}\n\n"
        f"{text}\n"
    )


def export_summary(
    job: ClaimedExportJob,
    *,
    included_count: int,
    skipped: list[dict[str, str]],
) -> str:
    lines = [
        "Solenne journal export",
        f"Export type: {job.export_kind}",
        f"Selected sessions: {len(job.journal_ids)}",
        f"Included files: {included_count}",
        f"Skipped items: {len(skipped)}",
    ]
    if skipped:
        lines.extend(["", "Skipped:"])
        lines.extend(
            f"- {item['journalId']}: {item['reason']}" for item in skipped
        )
    return "\n".join(lines) + "\n"


def export_filename(export_kind: str, job_id: str) -> str:
    day = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    kind = {
        "audio": "audio",
        "transcript": "transcripts",
        "both": "archive",
    }.get(export_kind, "archive")
    return f"solenne-{kind}-{day}-{_safe_component(job_id)[-8:]}.zip"


def _journal_mp3(
    journal_id: str,
    journal: dict,
    *,
    temp_dir: Path,
    config: WorkerConfig,
) -> Path:
    video_url = str(journal.get("videoUrl", "")).strip()
    validate_cloudinary_video_url(
        video_url,
        cloud_name=config.cloudinary_cloud_name,
        folder=config.cloudinary_folder,
    )
    suffix = Path(urlparse(video_url).path).suffix.lower()
    if suffix not in {".mp4", ".mov", ".webm", ".mkv", ".avi"}:
        suffix = ".mp4"
    safe_id = _safe_component(journal_id)
    video_path = temp_dir / f"{safe_id}{suffix}"
    mp3_path = temp_dir / f"{safe_id}.mp3"
    try:
        download_cloudinary_video(
            video_url,
            video_path,
            timeout_seconds=config.download_timeout_seconds,
            max_bytes=config.max_download_bytes,
        )
        transcode_voice_mp3(video_path, mp3_path)
        return mp3_path
    finally:
        video_path.unlink(missing_ok=True)


def transcode_voice_mp3(video_path: Path, output_path: Path) -> Path:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    command = [
        _ffmpeg_executable(),
        "-y",
        "-i",
        str(video_path),
        "-vn",
        "-ac",
        "1",
        "-ar",
        "44100",
        "-b:a",
        "64k",
        str(output_path),
    ]
    try:
        subprocess.run(command, check=True, capture_output=True, text=True)
    except FileNotFoundError as error:
        raise DependencyMissingError("ffmpeg is required for audio exports.") from error
    except subprocess.CalledProcessError as error:
        raise MediaValidationError(
            f"ffmpeg could not create the MP3: {error.stderr[-500:]}"
        ) from error
    if not output_path.is_file() or output_path.stat().st_size == 0:
        raise MediaValidationError("ffmpeg produced an empty MP3.")
    return output_path


def _safe_component(value: str) -> str:
    cleaned = _SAFE_NAME.sub("-", value.strip()).strip("-_")
    return cleaned[:80] or "entry"


def _safe_error(error: Exception) -> str:
    message = " ".join(str(error).split())
    return (message or error.__class__.__name__)[:500]
