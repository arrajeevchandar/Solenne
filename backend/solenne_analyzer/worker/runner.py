from __future__ import annotations

import logging
from pathlib import Path
import tempfile
import time
from urllib.parse import urlparse

from ..config import AnalyzerConfig, DEFAULT_OUTPUT_DIR
from ..pipeline.orchestrator import PipelineRunner
from .config import WorkerConfig
from .firebase_gateway import (
    AnalysisCancelled,
    ClaimedJob,
    FirebaseGateway,
    JobLeaseLost,
)
from .media_source import (
    MediaSourceError,
    cloudinary_thumbnail_url,
    download_cloudinary_video,
    validate_cloudinary_media_url,
)
from .result_mapper import analysis_result_to_firestore


LOGGER = logging.getLogger("solenne.worker")


class AnalysisWorker:
    def __init__(
        self,
        config: WorkerConfig | None = None,
        gateway: FirebaseGateway | None = None,
    ) -> None:
        self.config = config or WorkerConfig.from_env()
        self.gateway = gateway or FirebaseGateway(self.config)

    def process_next(self) -> bool:
        job = self.gateway.claim_next_job()
        if job is None:
            return False
        self.process_claimed(job)
        return True

    def process_job(self, job_id: str) -> bool:
        job = self.gateway.claim_job(job_id)
        if job is None:
            return False
        self.process_claimed(job)
        return True

    def watch(self) -> None:
        LOGGER.info("Worker ready; waiting for queued analysis jobs.")
        while True:
            try:
                processed = self.process_next()
            except Exception as error:  # keep the poller alive after transport errors
                LOGGER.error("Worker poll failed: %s", _safe_error(error))
                processed = False
            if not processed:
                time.sleep(self.config.poll_interval_seconds)

    def process_claimed(self, job: ClaimedJob) -> None:
        LOGGER.info("Processing analysis job %s", job.id)
        try:
            journal = self.gateway.get_journal(job)
            entry_type = str(journal.get("entryType", "video")).strip() or "video"
            with tempfile.TemporaryDirectory(prefix="solenne-analysis-") as temp_value:
                temp_dir = Path(temp_value)
                analyzer_config = AnalyzerConfig.from_env(
                    output_dir=temp_dir / "outputs",
                    whisper_model=self.config.whisper_model,
                    max_video_seconds=self.config.max_video_seconds,
                    enable_llm_insights=True,
                )
                runner = PipelineRunner(
                    analyzer_config,
                    on_progress=lambda step: self._report_progress(job, step),
                )
                if entry_type == "written":
                    written_text = str(journal.get("writtenText", ""))
                    result = runner.analyze_written(written_text, run_id=job.id)
                    media_url = ""
                else:
                    media_url = str(
                        journal.get("audioUrl" if entry_type == "audio" else "videoUrl", "")
                    ).strip()
                    validate_cloudinary_media_url(
                        media_url,
                        cloud_name=self.config.cloudinary_cloud_name,
                        folder=self.config.cloudinary_folder,
                    )
                    suffix = Path(urlparse(media_url).path).suffix.lower()
                    if not suffix:
                        suffix = ".webm" if entry_type == "audio" else ".mp4"
                    media_path = temp_dir / f"journal-{entry_type}{suffix}"
                    self.gateway.update_progress(job, "downloading")
                    self._download_with_retry(media_url, media_path)
                    result = (
                        runner.analyze_audio(media_path, run_id=job.id)
                        if entry_type == "audio"
                        else runner.analyze(media_path, run_id=job.id)
                    )
                if result.status != "complete":
                    raise RuntimeError(result.errorMessage or "Analysis pipeline failed.")
                payload = analysis_result_to_firestore(result)
                timestamp = result.facial.bestFrameTimestampSeconds
                if entry_type == "video" and timestamp is not None:
                    try:
                        payload["thumbnailUrl"] = cloudinary_thumbnail_url(
                            media_url,
                            timestamp,
                        )
                    except (MediaSourceError, ValueError) as error:
                        LOGGER.warning(
                            "Could not derive best-frame thumbnail for %s: %s",
                            job.id,
                            _safe_error(error),
                        )
                self.gateway.complete(job, payload)
            LOGGER.info("Completed analysis job %s", job.id)
        except (AnalysisCancelled, JobLeaseLost) as error:
            LOGGER.info("Analysis job %s stopped: %s", job.id, _safe_error(error))
        except Exception as error:
            LOGGER.error("Analysis job %s failed: %s", job.id, _safe_error(error))
            try:
                self.gateway.fail(job, _safe_error(error))
            except (AnalysisCancelled, JobLeaseLost) as fence_error:
                LOGGER.info(
                    "Analysis job %s failure was discarded: %s",
                    job.id,
                    _safe_error(fence_error),
                )

    def _download_with_retry(self, video_url: str, video_path: Path) -> None:
        last_error: Exception | None = None
        for attempt in range(1, self.config.transient_retries + 1):
            try:
                download_cloudinary_video(
                    video_url,
                    video_path,
                    timeout_seconds=self.config.download_timeout_seconds,
                    max_bytes=self.config.max_download_bytes,
                )
                return
            except Exception as error:
                last_error = error
                if attempt < self.config.transient_retries:
                    time.sleep(2 ** (attempt - 1))
        assert last_error is not None
        raise last_error

    def _report_progress(self, job: ClaimedJob, step: str) -> None:
        if step in {"failed", "complete"}:
            return
        try:
            self.gateway.update_progress(job, step)
        except Exception as error:
            LOGGER.warning("Could not report progress: %s", _safe_error(error))


def _safe_error(error: Exception) -> str:
    message = " ".join(str(error).split())
    return (message or error.__class__.__name__)[:500]
