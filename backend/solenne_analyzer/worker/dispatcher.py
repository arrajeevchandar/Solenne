from __future__ import annotations

import logging
import time

from .cloudinary_admin import CloudinaryAdminClient
from .config import WorkerConfig
from .firebase_gateway import FirebaseGateway
from .privacy_jobs import DeletionWorker, ExportWorker
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

    def process_next(self, *, wait_for_analysis: bool = True) -> bool:
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
        LOGGER.info("Worker ready; waiting for queued jobs.")
        try:
            while True:
                try:
                    self.process_next(wait_for_analysis=False)
                except Exception as error:
                    LOGGER.error("Worker poll failed: %s", error)
                delay = (
                    min(1.0, self.config.poll_interval_seconds)
                    if self.analysis.active
                    else self.config.poll_interval_seconds
                )
                time.sleep(delay)
        except KeyboardInterrupt:
            LOGGER.info("Worker shutdown requested.")
        finally:
            self.analysis.shutdown()
