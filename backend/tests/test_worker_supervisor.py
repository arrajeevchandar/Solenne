from __future__ import annotations

import unittest
from unittest.mock import patch

from solenne_analyzer.worker.config import WorkerConfig
from solenne_analyzer.worker.firebase_gateway import ClaimedJob
from solenne_analyzer.worker.supervisor import AnalysisSupervisor


def _config() -> WorkerConfig:
    return WorkerConfig(
        firebase_project_id="solenne-9324d",
        firebase_service_account=None,
        poll_interval_seconds=0.01,
        cloudinary_cloud_name="dqjd3lszl",
        cloudinary_folder="solenne/journals",
        whisper_model="base",
        max_video_seconds=180,
        max_download_bytes=1024,
        download_timeout_seconds=1,
        transient_retries=1,
        analysis_heartbeat_seconds=5,
        analysis_lease_seconds=30,
    )


class AnalysisSupervisorTests(unittest.TestCase):
    def test_child_crash_requeues_owned_analysis(self) -> None:
        gateway = _Gateway()
        process = _Process(alive_after_start=False, exit_code=7)
        supervisor = AnalysisSupervisor(_config(), gateway)

        with patch(
            "solenne_analyzer.worker.supervisor.multiprocessing.get_context",
            return_value=_Context(process),
        ):
            self.assertTrue(supervisor.start_next())
            self.assertTrue(supervisor.poll())

        self.assertEqual(gateway.interrupted, ["job-1"])
        self.assertIsNone(supervisor.job_id)

    def test_lease_loss_stops_child_and_acknowledges_cancellation(self) -> None:
        gateway = _Gateway(renewed=False)
        process = _Process(alive_after_start=True)
        supervisor = AnalysisSupervisor(_config(), gateway)

        with patch(
            "solenne_analyzer.worker.supervisor.multiprocessing.get_context",
            return_value=_Context(process),
        ), patch(
            "solenne_analyzer.worker.supervisor.time.monotonic",
            side_effect=[0.0, 6.0],
        ):
            self.assertTrue(supervisor.start_next())
            supervisor.poll()

        self.assertTrue(process.terminated)
        self.assertEqual(gateway.acknowledged, ["journal-1"])

    def test_deletion_cancels_matching_child(self) -> None:
        gateway = _Gateway()
        process = _Process(alive_after_start=True)
        supervisor = AnalysisSupervisor(_config(), gateway)

        with patch(
            "solenne_analyzer.worker.supervisor.multiprocessing.get_context",
            return_value=_Context(process),
        ), patch(
            "solenne_analyzer.worker.supervisor.time.monotonic",
            return_value=0.0,
        ):
            self.assertTrue(supervisor.start_next())
            self.assertTrue(supervisor.cancel("journal-1"))

        self.assertTrue(process.terminated)
        self.assertEqual(gateway.acknowledged, ["journal-1"])
        self.assertIsNone(supervisor.job_id)


class _Gateway:
    def __init__(self, *, renewed: bool = True) -> None:
        self.job = ClaimedJob(
            "job-1",
            "user-1",
            "journal-1",
            0,
            "worker-1",
            "token-1",
            0,
        )
        self.renewed = renewed
        self.interrupted: list[str] = []
        self.acknowledged: list[str] = []

    def claim_next_job(self):
        return self.job

    def claim_job(self, job_id):
        return self.job if job_id == self.job.id else None

    def interrupt_analysis(self, job):
        self.interrupted.append(job.id)

    def renew_analysis_lease(self, _job):
        return self.renewed

    def acknowledge_analysis_cancellation(self, journal_id):
        self.acknowledged.append(journal_id)


class _Context:
    def __init__(self, process) -> None:
        self.process = process

    def Process(self, **_kwargs):
        return self.process


class _Process:
    def __init__(
        self,
        *,
        alive_after_start: bool,
        exit_code: int = 0,
    ) -> None:
        self._alive = False
        self.alive_after_start = alive_after_start
        self.exitcode = exit_code
        self.terminated = False

    def start(self):
        self._alive = self.alive_after_start

    def is_alive(self):
        return self._alive

    def join(self, timeout=None):
        return None

    def terminate(self):
        self.terminated = True
        self._alive = False

    def kill(self):
        self.terminated = True
        self._alive = False


if __name__ == "__main__":
    unittest.main()
