from __future__ import annotations

import logging
import random
import time

from .cloudinary_admin import CloudinaryAdminClient
from .config import WorkerConfig
from .firebase_gateway import FirebaseGateway
from .privacy_jobs import DeletionWorker, ExportWorker
from .queue_wakeup import FirestoreQueueWakeup
from .supervisor import AnalysisSupervisor


LOGGER = logging.getLogger("solenne.dispatcher")


class QueueWorker:
    def __init__(
        self,
        config: WorkerConfig | None = None,
        gateway: FirebaseGateway | None = None,
    ) -> None:
        self.config = config or WorkerConfig.from_env()
        self.gateway = gateway or FirebaseGateway(self.config)
        self.analysis = AnalysisSupervisor(self.config, self.gateway)
        self.deletion: DeletionWorker | None = None
        self.export: ExportWorker | None = None
        if self.config.has_cloudinary_admin_credentials:
            cloudinary_client = CloudinaryAdminClient(self.config)
            self.deletion = DeletionWorker(
                self.config,
                self.gateway,
                cloudinary_client,
                cancel_analysis=self.analysis.cancel,
            )
            self.export = ExportWorker(self.config, self.gateway, cloudinary_client)
        else:
            LOGGER.warning(
                "Cloudinary Admin credentials are absent; deletion and export "
                "queues are disabled."
            )

    def process_next(
        self, *, wait_for_analysis: bool = True, recover: bool = True
    ) -> bool:
        if recover:
            recovered = self.gateway.recover_stale_jobs()
            if recovered:
                LOGGER.info("Recovered %s stale or legacy queue job(s).", recovered)
        self.analysis.poll()
        if self.deletion is not None and self.deletion.cleanup_next():
            return True
        if self.deletion is not None and self.deletion.process_next():
            return True
        if self.analysis.active:
            return False
        if self.export is not None and self.export.expire_next():
            return True
        if self.export is not None and self.export.process_next():
            return True
        started = self.analysis.start_next()
        if started and wait_for_analysis:
            self.analysis.wait()
        return started

    def process_analysis_job(self, job_id: str) -> bool:
        self.gateway.recover_stale_jobs()
        started = self.analysis.start_next(job_id)
        if started:
            self.analysis.wait()
        return started

    def watch(self) -> None:
        wakeup = FirestoreQueueWakeup(self.gateway.db)
        quota_failures = 0
        next_maintenance = time.monotonic()
        LOGGER.info("Worker ready; waiting for queued jobs.")
        try:
            wakeup.start()
            recovered = self.gateway.recover_stale_jobs(include_legacy=True)
            if recovered:
                LOGGER.info("Recovered %s stale or legacy queue job(s).", recovered)
            next_maintenance = (
                time.monotonic() + self.config.maintenance_interval_seconds
            )
            while True:
                now = time.monotonic()
                maintenance_due = now >= next_maintenance
                if self.analysis.active:
                    self.analysis.poll()
                if not wakeup.event.is_set() and not maintenance_due:
                    timeout = min(
                        1.0 if self.analysis.active else 60.0,
                        max(0.0, next_maintenance - now),
                    )
                    wakeup.wait(timeout)
                    continue
                wakeup.clear()
                try:
                    if maintenance_due:
                        recovered = self.gateway.recover_stale_jobs(
                            include_legacy=False
                        )
                        if recovered:
                            LOGGER.info(
                                "Recovered %s stale or legacy queue job(s).",
                                recovered,
                            )
                        next_maintenance = (
                            time.monotonic()
                            + self.config.maintenance_interval_seconds
                        )
                    self.process_next(wait_for_analysis=False, recover=False)
                    quota_failures = 0
                except Exception as error:
                    if _is_quota_error(error):
                        quota_failures += 1
                        base = min(
                            self.config.quota_backoff_max_seconds,
                            self.config.quota_backoff_initial_seconds
                            * (2 ** (quota_failures - 1)),
                        )
                        delay = min(
                            self.config.quota_backoff_max_seconds,
                            base * random.uniform(0.8, 1.2),
                        )
                        LOGGER.error(
                            "Firestore quota is exhausted; queue access will "
                            "resume in %.0f seconds.",
                            delay,
                        )
                        wakeup.wait(delay)
                        wakeup.wake()
                    else:
                        LOGGER.exception("Worker queue cycle failed.")
                        wakeup.wait(min(30.0, self.config.poll_interval_seconds))
                        wakeup.wake()
        except KeyboardInterrupt:
            LOGGER.info("Worker shutdown requested.")
        finally:
            wakeup.close()
            self.analysis.shutdown()


def _is_quota_error(error: Exception) -> bool:
    code = getattr(error, "code", None)
    if callable(code):
        code = code()
    normalized = str(code or "").lower().replace("_", "-")
    text = str(error).lower()
    return (
        "resource-exhausted" in normalized
        or "resource exhausted" in normalized
        or "quota exceeded" in text
        or "429" in text
    )
