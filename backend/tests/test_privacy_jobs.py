from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

from fastapi.testclient import TestClient
import httpx

from solenne_analyzer.export_api import create_app
from solenne_analyzer.worker.config import WorkerConfig
from solenne_analyzer.worker.cloudinary_admin import CloudinaryAdminClient
from solenne_analyzer.worker.firebase_gateway import (
    ClaimedDeletionJob,
    ClaimedExportJob,
    ExportDownload,
    PreparedDeletion,
)
from solenne_analyzer.worker.privacy_jobs import (
    DeletionWorker,
    ExportBuildError,
    build_export_archive,
    journal_archive_stem,
    transcode_voice_mp3,
    validate_cloudinary_public_id,
)


def _config(**changes) -> WorkerConfig:
    values = {
        "firebase_project_id": "solenne-9324d",
        "firebase_service_account": None,
        "poll_interval_seconds": 0.01,
        "cloudinary_cloud_name": "dqjd3lszl",
        "cloudinary_folder": "solenne/journals",
        "whisper_model": "base",
        "max_video_seconds": 180,
        "max_download_bytes": 1024,
        "download_timeout_seconds": 1,
        "transient_retries": 1,
        "cloudinary_api_key": "key",
        "cloudinary_api_secret": "secret",
    }
    values.update(changes)
    return WorkerConfig(**values)


class ExportArchiveTests(unittest.TestCase):
    def test_builds_transcripts_and_documents_missing_items(self) -> None:
        job = ClaimedExportJob(
            id="export-1",
            user_id="user-1",
            journal_ids=("journal-1", "journal-2"),
            export_kind="transcript",
            retry_count=0,
        )
        journals = [
            (
                "journal-1",
                {
                    "title": "Morning reset",
                    "recordedAt": datetime(2026, 7, 30, 8, 15, tzinfo=timezone.utc),
                    "transcript": {
                        "text": "I want to begin more gently.",
                        "language": "en",
                    },
                },
            ),
            (
                "journal-2",
                {
                    "recordedAt": datetime(2026, 7, 30, 9, 0, tzinfo=timezone.utc),
                    "transcript": {"text": ""},
                },
            ),
        ]
        with tempfile.TemporaryDirectory() as value:
            archive_path, included, skipped = build_export_archive(
                job,
                journals,
                temp_dir=Path(value),
                config=_config(),
            )
            with zipfile.ZipFile(archive_path) as archive:
                names = archive.namelist()
                transcript_name = next(
                    name for name in names if name.startswith("transcripts/")
                )
                transcript = archive.read(transcript_name).decode()
                summary = archive.read("export-summary.txt").decode()

        self.assertEqual(included, 1)
        self.assertEqual(
            skipped,
            [{"journalId": "journal-2", "reason": "transcript unavailable"}],
        )
        self.assertIn("Title: Morning reset", transcript)
        self.assertIn("I want to begin more gently.", transcript)
        self.assertIn("journal-2: transcript unavailable", summary)

    def test_rejects_an_archive_above_the_configured_limit(self) -> None:
        job = ClaimedExportJob(
            id="export-1",
            user_id="user-1",
            journal_ids=("journal-1",),
            export_kind="transcript",
            retry_count=0,
        )
        journals = [
            (
                "journal-1",
                {
                    "recordedAt": datetime.now(timezone.utc),
                    "transcript": {"text": "A transcript that cannot fit."},
                },
            )
        ]
        with tempfile.TemporaryDirectory() as value:
            with self.assertRaisesRegex(ExportBuildError, "larger than 100 MB"):
                build_export_archive(
                    job,
                    journals,
                    temp_dir=Path(value),
                    config=_config(export_zip_max_bytes=1),
                )

    def test_sanitizes_names_and_restricts_public_ids(self) -> None:
        stem = journal_archive_stem(
            "journal / unsafe",
            {"recordedAt": datetime(2026, 7, 30, tzinfo=timezone.utc)},
        )
        self.assertEqual(stem, "2026-07-30_00-00_journal-unsafe")
        self.assertEqual(
            validate_cloudinary_public_id(
                "solenne/journals/video-1",
                folder="solenne/journals",
            ),
            "solenne/journals/video-1",
        )
        with self.assertRaisesRegex(ValueError, "outside"):
            validate_cloudinary_public_id(
                "another-folder/video-1",
                folder="solenne/journals",
            )

    def test_mp3_transcode_uses_mono_voice_settings(self) -> None:
        with tempfile.TemporaryDirectory() as value:
            video = Path(value) / "video.mp4"
            output = Path(value) / "voice.mp3"
            video.write_bytes(b"video")

            def fake_run(command, **_kwargs):
                self.assertIn("-ac", command)
                self.assertEqual(command[command.index("-ac") + 1], "1")
                self.assertEqual(command[command.index("-b:a") + 1], "64k")
                output.write_bytes(b"mp3")

            with patch(
                "solenne_analyzer.worker.privacy_jobs._ffmpeg_executable",
                return_value="ffmpeg",
            ), patch(
                "solenne_analyzer.worker.privacy_jobs.subprocess.run",
                side_effect=fake_run,
            ):
                self.assertEqual(transcode_voice_mp3(video, output), output)


class CloudinaryAdminTests(unittest.TestCase):
    def test_video_delete_uses_video_type_and_cache_invalidation(self) -> None:
        client = CloudinaryAdminClient(_config())
        with patch(
            "cloudinary.uploader.destroy",
            return_value={"result": "ok"},
        ) as destroy:
            client.destroy_video("solenne/journals/video-1")

        destroy.assert_called_once_with(
            "solenne/journals/video-1",
            resource_type="video",
            type="upload",
            invalidate=True,
        )


class DeletionWorkerTests(unittest.TestCase):
    def test_deletes_cloudinary_before_completing_firestore(self) -> None:
        events: list[str] = []

        class Gateway:
            def claim_next_deletion(self):
                return ClaimedDeletionJob("journal-1", "user-1", "journal-1", 0)

            def prepare_deletion(self, _job):
                return PreparedDeletion(
                    journal={"cloudinaryPublicId": "solenne/journals/video-1"},
                    wait_for_analysis=False,
                )

            def complete_deletion(self, _job):
                events.append("firestore")

            def fail_deletion(self, *_args, **_kwargs):
                raise AssertionError("Deletion should not fail.")

        class Cloudinary:
            def destroy_video(self, public_id):
                if public_id != "solenne/journals/video-1":
                    raise AssertionError(f"Unexpected public ID: {public_id}")
                events.append("cloudinary")

        worker = DeletionWorker(_config(), Gateway(), Cloudinary())
        self.assertTrue(worker.process_next())
        self.assertEqual(events, ["cloudinary", "firestore"])

    def test_waiting_deletion_yields_to_other_queue_work(self) -> None:
        class Gateway:
            def claim_next_deletion(self):
                return ClaimedDeletionJob("journal-1", "user-1", "journal-1", 0)

            def prepare_deletion(self, _job):
                return PreparedDeletion(journal={}, wait_for_analysis=True)

        worker = DeletionWorker(_config(), Gateway(), object())
        self.assertFalse(worker.process_next())


class ExportApiTests(unittest.TestCase):
    def test_requires_authentication(self) -> None:
        app = create_app(
            config=_config(),
            gateway=_DownloadGateway(),
            cloudinary_client=_Cloudinary(),
            token_verifier=lambda _token: {"uid": "user-1"},
            http_client_factory=_http_client,
        )
        response = TestClient(app).get("/v1/exports/export-1/download")
        self.assertEqual(response.status_code, 401)

    def test_streams_once_and_removes_the_private_archive(self) -> None:
        gateway = _DownloadGateway()
        cloudinary = _Cloudinary()
        app = create_app(
            config=_config(),
            gateway=gateway,
            cloudinary_client=cloudinary,
            token_verifier=lambda _token: {"uid": "user-1"},
            http_client_factory=_http_client,
        )
        client = TestClient(app)

        response = client.get(
            "/v1/exports/export-1/download",
            headers={"Authorization": "Bearer valid"},
        )
        second = client.get(
            "/v1/exports/export-1/download",
            headers={"Authorization": "Bearer valid"},
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.content, b"private-zip")
        self.assertEqual(second.status_code, 410)
        self.assertEqual(cloudinary.deleted, ["private/export.zip"])
        self.assertEqual(gateway.finished, ["export-1"])

    def test_denies_a_different_authenticated_user(self) -> None:
        app = create_app(
            config=_config(),
            gateway=_DownloadGateway(),
            cloudinary_client=_Cloudinary(),
            token_verifier=lambda _token: {"uid": "another-user"},
            http_client_factory=_http_client,
        )
        response = TestClient(app).get(
            "/v1/exports/export-1/download",
            headers={"Authorization": "Bearer valid"},
        )
        self.assertEqual(response.status_code, 403)


class _DownloadGateway:
    def __init__(self) -> None:
        self.consumed = False
        self.finished: list[str] = []

    def consume_export(self, job_id, user_id):
        if self.consumed:
            raise FileExistsError("Export has already been downloaded.")
        if user_id != "user-1":
            raise PermissionError("Export belongs to another user.")
        self.consumed = True
        return ExportDownload(
            job_id=job_id,
            public_id="private/export.zip",
            file_format="zip",
            filename="solenne-export.zip",
            size_bytes=len(b"private-zip"),
        )

    def finish_export_consumption(
        self, job_id, *, error=None, cleanup_pending=False
    ):
        self.finished.append(job_id)


class _Cloudinary:
    def __init__(self) -> None:
        self.deleted: list[str] = []

    def private_download_url(self, *_args, **_kwargs):
        return "https://api.cloudinary.test/download"

    def destroy_private_zip(self, public_id):
        self.deleted.append(public_id)


def _http_client():
    return httpx.Client(
        transport=httpx.MockTransport(
            lambda request: httpx.Response(
                200,
                content=b"private-zip",
                request=request,
            )
        )
    )


if __name__ == "__main__":
    unittest.main()
