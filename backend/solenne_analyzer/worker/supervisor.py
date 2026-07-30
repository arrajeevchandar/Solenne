from __future__ import annotations

import logging
import multiprocessing
import time

from .config import WorkerConfig
from .firebase_gateway import ClaimedJob, FirebaseGateway
from .runner import AnalysisWorker


LOGGER = logging.getLogger("solenne.supervisor")


def _run_claimed_process(config: WorkerConfig, job: ClaimedJob) -> None:
    gateway = FirebaseGateway(config)
    AnalysisWorker(config, gateway=gateway).process_claimed(job)


class AnalysisSupervisor:
    """Runs one analysis child while the dispatcher keeps servicing queues."""

    def __init__(self, config: WorkerConfig, gateway: FirebaseGateway) -> None:
        self.config = config
        self.gateway = gateway
        self._process: multiprocessing.Process | None = None
        self._job: ClaimedJob | None = None
        self._next_heartbeat = 0.0

    @property
    def active(self) -> bool:
        return self._process is not None and self._process.is_alive()

    @property
    def job_id(self) -> str | None:
        return self._job.id if self._job is not None else None

    def start_next(self, job_id: str | None = None) -> bool:
        self.poll()
        if self._process is not None:
            return False
        job = (
            self.gateway.claim_job(job_id)
            if job_id is not None
            else self.gateway.claim_next_job()
        )
        if job is None:
            return False
        context = multiprocessing.get_context("spawn")
        process = context.Process(
            target=_run_claimed_process,
            args=(self.config, job),
            name=f"solenne-analysis-{job.id}",
        )
        process.start()
        self._process = process
        self._job = job
        self._next_heartbeat = (
            time.monotonic() + self.config.analysis_heartbeat_seconds
        )
        LOGGER.info("Started supervised analysis job %s.", job.id)
        return True

    def poll(self) -> bool:
        process = self._process
        job = self._job
        if process is None or job is None:
            return False
        if not process.is_alive():
            process.join(timeout=1)
            exit_code = process.exitcode
            self.gateway.interrupt_analysis(job)
            LOGGER.info(
                "Analysis child for %s exited with code %s.",
                job.id,
                exit_code,
            )
            self._clear()
            return True
        if time.monotonic() >= self._next_heartbeat:
            if not self.gateway.renew_analysis_lease(job):
                LOGGER.info(
                    "Stopping analysis job %s after lease loss or cancellation.",
                    job.id,
                )
                self._terminate()
                self.gateway.acknowledge_analysis_cancellation(job.journal_id)
                self._clear()
                return True
            self._next_heartbeat = (
                time.monotonic() + self.config.analysis_heartbeat_seconds
            )
        return False

    def wait(self) -> None:
        while self._process is not None:
            self.poll()
            if self._process is not None:
                time.sleep(
                    min(1.0, self.config.analysis_heartbeat_seconds / 2)
                )

    def cancel(self, journal_id: str) -> bool:
        if self._job is None or self._job.journal_id != journal_id:
            return False
        self._terminate()
        self.gateway.acknowledge_analysis_cancellation(journal_id)
        self._clear()
        LOGGER.info("Cancelled supervised analysis job %s.", journal_id)
        return True

    def shutdown(self) -> None:
        job = self._job
        if job is None:
            return
        self._terminate()
        self.gateway.interrupt_analysis(job)
        self._clear()
        LOGGER.info("Requeued interrupted analysis job %s.", job.id)

    def _terminate(self) -> None:
        process = self._process
        if process is None:
            return
        if process.is_alive():
            process.terminate()
        process.join(timeout=5)
        if process.is_alive() and hasattr(process, "kill"):
            process.kill()
            process.join(timeout=2)

    def _clear(self) -> None:
        self._process = None
        self._job = None
        self._next_heartbeat = 0.0
