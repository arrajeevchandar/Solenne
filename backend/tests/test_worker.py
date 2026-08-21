from __future__ import annotations

from pathlib import Path
import unittest
from unittest.mock import patch

from solenne_analyzer.schemas import AiInsight, AnalysisResult, TranscriptResult
from solenne_analyzer.worker.config import WorkerConfig
from solenne_analyzer.worker.firebase_gateway import (
    ClaimedJob,
    validate_requeue_documents,
)
from solenne_analyzer.worker.media_source import (
    MediaSourceError,
    cloudinary_thumbnail_url,
    validate_cloudinary_video_url,
)
from solenne_analyzer.worker.result_mapper import analysis_result_to_firestore
from solenne_analyzer.worker.runner import AnalysisWorker


class WorkerMediaTests(unittest.TestCase):
    def test_accepts_expected_solenne_cloudinary_video(self) -> None:
        validate_cloudinary_video_url(
            "https://res.cloudinary.com/dqjd3lszl/video/upload/v1/solenne/journals/a.webm",
            cloud_name="dqjd3lszl",
            folder="solenne/journals",
        )

    def test_rejects_an_untrusted_video_host(self) -> None:
        with self.assertRaises(MediaSourceError):
            validate_cloudinary_video_url(
                "https://example.com/solenne/journals/a.mp4",
                cloud_name="dqjd3lszl",
                folder="solenne/journals",
            )


class WorkerResultTests(unittest.TestCase):
    def test_maps_firestore_payload_without_transcript_segments(self) -> None:
        result = AnalysisResult(runId="job-1", sourceVideo="private.mp4")
        result.transcript = TranscriptResult(
            text="A calm day.",
            wordCount=3,
            language="en",
            confidence=0.91,
            languageConfidence=0.83,
        )
        result.aiInsights = [
            AiInsight(
                title="A calmer pace",
                summary="Your reflection suggests a steadier rhythm.",
                moodLabel="grounded",
            )
        ]
        payload = analysis_result_to_firestore(result)

        self.assertEqual(payload["analysisStatus"], "complete")
        self.assertEqual(
            payload["analysisVersion"],
            "2026-08-v9-gpt-oss-insights",
        )
        self.assertEqual(payload["transcript"]["text"], "A calm day.")
        self.assertEqual(payload["transcript"]["languageConfidence"], 0.83)
        self.assertNotIn("segments", payload["transcript"])
        self.assertEqual(payload["aiInsights"][0]["moodLabel"], "grounded")

    def test_selected_reprocess_rejects_processing_or_mismatched_jobs(self) -> None:
        journal = {"userId": "user-1"}
        with self.assertRaisesRegex(ValueError, "cannot be requeued"):
            validate_requeue_documents(
                journal,
                {
                    "userId": "user-1",
                    "journalId": "journal-1",
                    "status": "processing",
                },
                "user-1",
                "journal-1",
            )
        with self.assertRaisesRegex(ValueError, "ownership"):
            validate_requeue_documents(
                journal,
                {
                    "userId": "another-user",
                    "journalId": "journal-1",
                    "status": "complete",
                },
                "user-1",
                "journal-1",
            )


class WorkerRunnerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.config = WorkerConfig(
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
        )

    def test_success_completes_job_and_removes_temporary_video(self) -> None:
        gateway = _FakeGateway()
        downloaded: list[Path] = []

        def fake_download(_url, destination, **_kwargs):
            destination.write_bytes(b"video")
            downloaded.append(destination)

        class FakePipelineRunner:
            def __init__(self, _config, on_progress=None):
                self.on_progress = on_progress

            def analyze(self, _path, run_id=None):
                if self.on_progress:
                    self.on_progress("transcribe")
                result = AnalysisResult(runId=run_id or "job-1", sourceVideo="local")
                result.transcript.text = "Today felt steady."
                result.transcript.wordCount = 3
                result.facial.bestFrameTimestampSeconds = 12.345
                return result

        worker = AnalysisWorker(self.config, gateway=gateway)
        with patch(
            "solenne_analyzer.worker.runner.download_cloudinary_video",
            fake_download,
        ), patch(
            "solenne_analyzer.worker.runner.PipelineRunner", FakePipelineRunner
        ):
            self.assertTrue(worker.process_next())

        self.assertIsNotNone(gateway.completed)
        self.assertIn(
            "/video/upload/so_12.345,f_jpg,q_auto/",
            gateway.completed["thumbnailUrl"],
        )
        self.assertIsNone(gateway.failed)
        self.assertTrue(downloaded)
        self.assertFalse(downloaded[0].exists())

    def test_pipeline_failure_marks_job_failed(self) -> None:
        gateway = _FakeGateway()

        def failed_download(_url, _destination, **_kwargs):
            raise MediaSourceError("download unavailable")

        worker = AnalysisWorker(self.config, gateway=gateway)
        with patch(
            "solenne_analyzer.worker.runner.download_cloudinary_video",
            failed_download,
        ):
            self.assertTrue(worker.process_next())

        self.assertIsNone(gateway.completed)
        self.assertEqual(gateway.failed, "download unavailable")

    def test_audio_job_uses_audio_pipeline_without_thumbnail(self) -> None:
        gateway = _FakeGateway(entry_type="audio")

        def fake_download(_url, destination, **_kwargs):
            destination.write_bytes(b"audio")

        class FakePipelineRunner:
            def __init__(self, _config, on_progress=None):
                self.on_progress = on_progress

            def analyze_audio(self, _path, run_id=None):
                return AnalysisResult(
                    runId=run_id or "job-1",
                    sourceVideo="local",
                    entryType="audio",
                    analysisModalities=["transcript", "voice", "text"],
                )

            def analyze(self, *_args, **_kwargs):
                raise AssertionError("Video analysis must not run for audio.")

        worker = AnalysisWorker(self.config, gateway=gateway)
        with patch(
            "solenne_analyzer.worker.runner.download_cloudinary_video",
            fake_download,
        ), patch(
            "solenne_analyzer.worker.runner.PipelineRunner", FakePipelineRunner
        ):
            self.assertTrue(worker.process_next())

        self.assertEqual(gateway.completed["entryType"], "audio")
        self.assertNotIn("thumbnailUrl", gateway.completed)

    def test_written_job_never_downloads_or_invokes_media_pipeline(self) -> None:
        gateway = _FakeGateway(entry_type="written")

        class FakePipelineRunner:
            def __init__(self, _config, on_progress=None):
                self.on_progress = on_progress

            def analyze_written(self, text, run_id=None):
                return AnalysisResult(
                    runId=run_id or "job-1",
                    sourceVideo="written-entry",
                    entryType="written",
                    analysisModalities=["text"],
                    writtenText=text,
                )

            def analyze(self, *_args, **_kwargs):
                raise AssertionError("Video analysis must not run for written entries.")

            def analyze_audio(self, *_args, **_kwargs):
                raise AssertionError("Audio analysis must not run for written entries.")

        worker = AnalysisWorker(self.config, gateway=gateway)
        with patch(
            "solenne_analyzer.worker.runner.download_cloudinary_video",
            side_effect=AssertionError("Written entries must not download media."),
        ), patch(
            "solenne_analyzer.worker.runner.PipelineRunner", FakePipelineRunner
        ):
            self.assertTrue(worker.process_next())

        self.assertEqual(gateway.completed["entryType"], "written")
        self.assertEqual(
            gateway.completed["modalityStatus"]["face"], "not_applicable"
        )

    def test_cloudinary_thumbnail_uses_selected_timestamp_and_jpg(self) -> None:
        url = cloudinary_thumbnail_url(
            "https://res.cloudinary.com/demo/video/upload/v1/"
            "solenne/journals/entry.webm?token=ignored",
            8.5,
        )

        self.assertEqual(
            url,
            "https://res.cloudinary.com/demo/video/upload/"
            "so_8.5,f_jpg,q_auto/v1/solenne/journals/entry.jpg",
        )


class _FakeGateway:
    def __init__(self, entry_type: str = "video") -> None:
        self.job = ClaimedJob("job-1", "user-1", "journal-1", 0)
        self.entry_type = entry_type
        self.completed = None
        self.failed = None
        self.progress: list[str] = []

    def claim_next_job(self):
        return self.job

    def claim_job(self, job_id):
        return self.job if job_id == self.job.id else None

    def get_journal(self, _job):
        return {
            "userId": "user-1",
            "entryType": self.entry_type,
            "videoUrl": (
                "https://res.cloudinary.com/dqjd3lszl/video/upload/"
                "v1/solenne/journals/journal-1.webm"
            ),
            "audioUrl": (
                "https://res.cloudinary.com/dqjd3lszl/video/upload/"
                "v1/solenne/journals/journal-1.m4a"
            ),
            "writtenText": "Today I made room for a difficult thought.",
        }

    def update_progress(self, _job, step):
        self.progress.append(step)

    def complete(self, _job, result):
        self.completed = result

    def fail(self, _job, message):
        self.failed = message


if __name__ == "__main__":
    unittest.main()
