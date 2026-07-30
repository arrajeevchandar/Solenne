from __future__ import annotations

import logging
import time

from .cloudinary_admin import CloudinaryAdminClient
from .config import WorkerConfig
from .firebase_gateway import FirebaseGateway
from .privacy_jobs import DeletionWorker, ExportWorker
from .runner import AnalysisWorker


LOGGER = logging.getLogger("solenne.dispatcher")


class QueueWorker:
    def __init__(
        self,
        config: WorkerConfig | None = None,
        gateway: FirebaseGateway | None = None,
    ) -> None:
        self.config = config or WorkerConfig.from_env()
        self.gateway = gateway or FirebaseGateway(self.config)
        self.analysis = AnalysisWorker(self.config, gateway=self.gateway)
        self.deletion: DeletionWorker | None = None
        self.export: ExportWorker | None = None
        if self.config.has_cloudinary_admin_credentials:
            cloudinary_client = CloudinaryAdminClient(self.config)
            self.deletion = DeletionWorker(
                self.config, self.gateway, cloudinary_client
            )
            self.export = ExportWorker(self.config, self.gateway, cloudinary_client)
        else:
            LOGGER.warning(
                "Cloudinary Admin credentials are absent; deletion and export "
                "queues are disabled."
            )

    def process_next(self) -> bool:
        if self.deletion is not None and self.deletion.cleanup_next():
            return True
        if self.deletion is not None and self.deletion.process_next():
            return True
        if self.export is not None and self.export.expire_next():
            return True
        if self.export is not None and self.export.process_next():
            return True
        return self.analysis.process_next()

    def process_analysis_job(self, job_id: str) -> bool:
        return self.analysis.process_job(job_id)

    def watch(self) -> None:
        LOGGER.info("Worker ready; waiting for queued jobs.")
        while True:
            try:
                processed = self.process_next()
            except Exception as error:
                LOGGER.error("Worker poll failed: %s", error)
                processed = False
            time.sleep(self.config.poll_interval_seconds)
