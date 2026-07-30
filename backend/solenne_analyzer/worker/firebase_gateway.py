from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
import os
import socket
import time
from typing import Any
import uuid

import firebase_admin
from firebase_admin import credentials, firestore
from google.cloud.firestore_v1.base_query import FieldFilter

from .config import WorkerConfig
from .result_mapper import ANALYSIS_VERSION


@dataclass(frozen=True)
class ClaimedJob:
    id: str
    user_id: str
    journal_id: str
    retry_count: int
    lease_owner: str = ""
    lease_token: str = ""
    attempt_count: int = 0


@dataclass(frozen=True)
class ClaimedDeletionJob:
    id: str
    user_id: str
    journal_id: str
    retry_count: int
    lease_owner: str = ""
    lease_token: str = ""


@dataclass(frozen=True)
class ClaimedExportJob:
    id: str
    user_id: str
    journal_ids: tuple[str, ...]
    export_kind: str
    retry_count: int


@dataclass(frozen=True)
class PreparedDeletion:
    journal: dict[str, Any] | None
    analysis_status: str | None = None
    analysis_lease_expires_at: datetime | None = None


class JobLeaseLost(RuntimeError):
    """Raised when a stale analysis process attempts a fenced write."""


class AnalysisCancelled(RuntimeError):
    """Raised when deletion has won ownership of an analysis job."""


@dataclass(frozen=True)
class ExportDownload:
    job_id: str
    public_id: str
    file_format: str
    filename: str
    size_bytes: int


class FirebaseGateway:
    def __init__(self, config: WorkerConfig) -> None:
        config.validate()
        try:
            firebase_admin.get_app()
        except ValueError:
            credential = (
                credentials.Certificate(str(config.firebase_service_account))
                if config.firebase_service_account is not None
                else credentials.ApplicationDefault()
            )
            firebase_admin.initialize_app(
                credential, {"projectId": config.firebase_project_id}
            )
        self.db = firestore.client()
        self.config = config
        self.worker_id = (
            f"{socket.gethostname()}-{os.getpid()}-{uuid.uuid4().hex[:10]}"
        )

    def claim_next_job(self) -> ClaimedJob | None:
        query = (
            self.db.collection("analysis_jobs")
            .where(filter=FieldFilter("status", "==", "queued"))
            .order_by("createdAt")
            .limit(5)
        )
        for snapshot in query.stream():
            claimed = self._claim_snapshot(snapshot.reference)
            if claimed is not None:
                return claimed
        return None

    def claim_job(self, job_id: str) -> ClaimedJob | None:
        return self._claim_snapshot(self.db.collection("analysis_jobs").document(job_id))

    def _claim_snapshot(self, job_ref) -> ClaimedJob | None:
        transaction = self.db.transaction()

        @firestore.transactional
        def claim(transaction):
            snapshot = job_ref.get(transaction=transaction)
            if not snapshot.exists:
                return None
            data = snapshot.to_dict() or {}
            now = datetime.now(timezone.utc)
            status = data.get("status")
            lease_expires_at = data.get("leaseExpiresAt")
            lease_expired = (
                status == "processing"
                and (
                    not isinstance(lease_expires_at, datetime)
                    or lease_expires_at <= now
                )
            )
            if status != "queued" and not lease_expired:
                return None
            user_id = str(data.get("userId", "")).strip()
            journal_id = str(data.get("journalId", "")).strip()
            if not user_id or not journal_id:
                raise ValueError("Analysis job is missing userId or journalId.")
            deletion_ref = self.db.collection("deletion_jobs").document(journal_id)
            deletion_snapshot = deletion_ref.get(transaction=transaction)
            deletion = (
                deletion_snapshot.to_dict() if deletion_snapshot.exists else None
            )
            if deletion and _is_active_deletion(deletion):
                transaction.update(
                    job_ref,
                    {
                        "status": "cancelled",
                        "processingStep": "cancelled",
                        "completedAt": firestore.SERVER_TIMESTAMP,
                        "errorMessage": None,
                    },
                )
                return None
            attempt_count = int(
                data.get("attemptCount", data.get("retryCount", 0))
            )
            if lease_expired:
                attempt_count += 1
            if attempt_count >= self.config.analysis_max_attempts:
                safe_message = "Analysis stopped repeatedly and reached the retry limit."
                transaction.update(
                    job_ref,
                    {
                        "status": "failed",
                        "processingStep": "failed",
                        "completedAt": firestore.SERVER_TIMESTAMP,
                        "errorMessage": safe_message,
                        "attemptCount": attempt_count,
                        "leaseOwner": None,
                        "leaseToken": None,
                        "leaseExpiresAt": None,
                    },
                )
                transaction.update(
                    self._journal_ref_for(user_id, journal_id),
                    {
                        "analysisStatus": "failed",
                        "analysisStep": "failed",
                        "analysisError": safe_message,
                        "analysisCompletedAt": firestore.SERVER_TIMESTAMP,
                    },
                )
                return None
            lease_token = uuid.uuid4().hex
            lease_expires_at = now + timedelta(
                seconds=self.config.analysis_lease_seconds
            )
            transaction.update(
                job_ref,
                {
                    "status": "processing",
                    "processingStep": "starting",
                    "startedAt": firestore.SERVER_TIMESTAMP,
                    "completedAt": None,
                    "errorMessage": None,
                    "attemptCount": attempt_count,
                    "leaseOwner": self.worker_id,
                    "leaseToken": lease_token,
                    "leaseExpiresAt": lease_expires_at,
                    "heartbeatAt": now,
                    "cancelRequestedAt": None,
                },
            )
            return ClaimedJob(
                id=snapshot.id,
                user_id=user_id,
                journal_id=journal_id,
                retry_count=int(data.get("retryCount", 0)),
                lease_owner=self.worker_id,
                lease_token=lease_token,
                attempt_count=attempt_count,
            )

        return claim(transaction)

    def claim_next_deletion(self) -> ClaimedDeletionJob | None:
        for status in ("queued", "waiting"):
            query = (
                self.db.collection("deletion_jobs")
                .where(filter=FieldFilter("status", "==", status))
                .order_by("createdAt")
                .limit(5)
            )
            for snapshot in query.stream():
                claimed = self._claim_deletion_snapshot(snapshot.reference)
                if claimed is not None:
                    return claimed
        return None

    def _claim_deletion_snapshot(self, job_ref) -> ClaimedDeletionJob | None:
        transaction = self.db.transaction()

        @firestore.transactional
        def claim(transaction):
            snapshot = job_ref.get(transaction=transaction)
            if not snapshot.exists:
                return None
            data = snapshot.to_dict() or {}
            now = datetime.now(timezone.utc)
            status = data.get("status")
            lease_expires_at = data.get("leaseExpiresAt")
            lease_expired = (
                status == "processing"
                and (
                    not isinstance(lease_expires_at, datetime)
                    or lease_expires_at <= now
                )
            )
            if status not in {"queued", "waiting"} and not lease_expired:
                return None
            user_id = str(data.get("userId", "")).strip()
            journal_id = str(data.get("journalId", "")).strip()
            if not user_id or not journal_id or snapshot.id != journal_id:
                raise ValueError("Deletion job identity is invalid.")
            lease_token = uuid.uuid4().hex
            transaction.update(
                job_ref,
                {
                    "status": "processing",
                    "startedAt": firestore.SERVER_TIMESTAMP,
                    "completedAt": None,
                    "errorCode": None,
                    "errorMessage": None,
                    "leaseOwner": self.worker_id,
                    "leaseToken": lease_token,
                    "leaseExpiresAt": now
                    + timedelta(seconds=self.config.deletion_lease_seconds),
                    "heartbeatAt": now,
                },
            )
            return ClaimedDeletionJob(
                id=snapshot.id,
                user_id=user_id,
                journal_id=journal_id,
                retry_count=int(data.get("retryCount", 0)),
                lease_owner=self.worker_id,
                lease_token=lease_token,
            )

        return claim(transaction)

    def prepare_deletion(self, job: ClaimedDeletionJob) -> PreparedDeletion:
        journal_ref = self._journal_ref_for(job.user_id, job.journal_id)
        analysis_ref = self.db.collection("analysis_jobs").document(job.journal_id)
        deletion_ref = self.db.collection("deletion_jobs").document(job.id)
        transaction = self.db.transaction()

        @firestore.transactional
        def prepare(transaction):
            deletion_snapshot = deletion_ref.get(transaction=transaction)
            if not deletion_snapshot.exists:
                raise JobLeaseLost("Deletion job no longer exists.")
            deletion = deletion_snapshot.to_dict() or {}
            self._require_deletion_lease(job, deletion)
            journal_snapshot = journal_ref.get(transaction=transaction)
            analysis_snapshot = analysis_ref.get(transaction=transaction)
            journal = (
                journal_snapshot.to_dict() if journal_snapshot.exists else None
            )
            if journal is not None and journal.get("userId") != job.user_id:
                raise ValueError("Deletion job ownership does not match its journal.")
            if analysis_snapshot.exists:
                analysis = analysis_snapshot.to_dict() or {}
                if (
                    analysis.get("userId") != job.user_id
                    or analysis.get("journalId") != job.journal_id
                ):
                    raise ValueError(
                        "Deletion job ownership does not match its analysis job."
                    )
                analysis_status = str(analysis.get("status", ""))
                analysis_lease_expires_at = analysis.get("leaseExpiresAt")
                if analysis_status in {"processing", "cancel_requested"}:
                    transaction.update(
                        analysis_ref,
                        {
                            "status": "cancel_requested",
                            "processingStep": "cancelling",
                            "cancelRequestedAt": firestore.SERVER_TIMESTAMP,
                        },
                    )
                    return PreparedDeletion(
                        journal=journal,
                        analysis_status="cancel_requested",
                        analysis_lease_expires_at=(
                            analysis_lease_expires_at
                            if isinstance(analysis_lease_expires_at, datetime)
                            else None
                        ),
                    )
                if analysis_status == "queued":
                    transaction.update(
                        analysis_ref,
                        {
                            "status": "cancelled",
                            "processingStep": "cancelled",
                            "completedAt": firestore.SERVER_TIMESTAMP,
                            "errorMessage": None,
                        },
                    )
                    return PreparedDeletion(
                        journal=journal,
                        analysis_status="cancelled",
                    )
                return PreparedDeletion(
                    journal=journal,
                    analysis_status=analysis_status or None,
                )
            return PreparedDeletion(journal=journal)

        return prepare(transaction)

    def complete_deletion(self, job: ClaimedDeletionJob) -> None:
        deletion_ref = self.db.collection("deletion_jobs").document(job.id)
        transaction = self.db.transaction()

        @firestore.transactional
        def complete(transaction):
            snapshot = deletion_ref.get(transaction=transaction)
            if not snapshot.exists:
                raise JobLeaseLost("Deletion job no longer exists.")
            self._require_deletion_lease(job, snapshot.to_dict() or {})
            transaction.delete(
                self._journal_ref_for(job.user_id, job.journal_id)
            )
            transaction.delete(
                self.db.collection("analysis_jobs").document(job.journal_id)
            )
            transaction.update(
                deletion_ref,
                {
                    "status": "complete",
                    "completedAt": firestore.SERVER_TIMESTAMP,
                    "errorCode": None,
                    "errorMessage": None,
                    "leaseOwner": None,
                    "leaseToken": None,
                    "leaseExpiresAt": None,
                    "expiresAt": datetime.now(timezone.utc)
                    + timedelta(hours=24),
                },
            )

        complete(transaction)

    def fail_deletion(
        self,
        job: ClaimedDeletionJob,
        *,
        code: str,
        message: str,
    ) -> None:
        job_ref = self.db.collection("deletion_jobs").document(job.id)
        transaction = self.db.transaction()

        @firestore.transactional
        def fail(transaction):
            snapshot = job_ref.get(transaction=transaction)
            if not snapshot.exists:
                return
            data = snapshot.to_dict() or {}
            self._require_deletion_lease(job, data)
            transaction.update(
                job_ref,
                {
                    "status": "failed",
                    "completedAt": firestore.SERVER_TIMESTAMP,
                    "retryCount": job.retry_count + 1,
                    "errorCode": code[:80],
                    "errorMessage": " ".join(message.split())[:300],
                    "leaseOwner": None,
                    "leaseToken": None,
                    "leaseExpiresAt": None,
                },
            )

        fail(transaction)

    def renew_deletion_lease(self, job: ClaimedDeletionJob) -> bool:
        job_ref = self.db.collection("deletion_jobs").document(job.id)
        transaction = self.db.transaction()

        @firestore.transactional
        def renew(transaction):
            snapshot = job_ref.get(transaction=transaction)
            if not snapshot.exists:
                return False
            data = snapshot.to_dict() or {}
            try:
                self._require_deletion_lease(job, data)
            except JobLeaseLost:
                return False
            now = datetime.now(timezone.utc)
            transaction.update(
                job_ref,
                {
                    "heartbeatAt": now,
                    "leaseExpiresAt": now
                    + timedelta(seconds=self.config.deletion_lease_seconds),
                },
            )
            return True

        return bool(renew(transaction))

    def acknowledge_analysis_cancellation(self, journal_id: str) -> None:
        analysis_ref = self.db.collection("analysis_jobs").document(journal_id)
        transaction = self.db.transaction()

        @firestore.transactional
        def acknowledge(transaction):
            snapshot = analysis_ref.get(transaction=transaction)
            if not snapshot.exists:
                return
            data = snapshot.to_dict() or {}
            if data.get("status") != "cancel_requested":
                return
            transaction.update(
                analysis_ref,
                {
                    "status": "cancelled",
                    "processingStep": "cancelled",
                    "completedAt": firestore.SERVER_TIMESTAMP,
                    "leaseOwner": None,
                    "leaseToken": None,
                    "leaseExpiresAt": None,
                },
            )

        acknowledge(transaction)

    def wait_for_analysis_cancellation(
        self,
        journal_id: str,
        *,
        timeout_seconds: float,
    ) -> None:
        deadline = time.monotonic() + max(0.0, timeout_seconds)
        analysis_ref = self.db.collection("analysis_jobs").document(journal_id)
        while time.monotonic() < deadline:
            snapshot = analysis_ref.get()
            if not snapshot.exists:
                return
            data = snapshot.to_dict() or {}
            if data.get("status") not in {"processing", "cancel_requested"}:
                return
            lease_expires_at = data.get("leaseExpiresAt")
            if (
                not isinstance(lease_expires_at, datetime)
                or lease_expires_at <= datetime.now(timezone.utc)
            ):
                self.acknowledge_analysis_cancellation(journal_id)
                return
            time.sleep(0.25)

    def cleanup_expired_deletion(self) -> bool:
        query = (
            self.db.collection("deletion_jobs")
            .where(filter=FieldFilter("status", "==", "complete"))
            .where(
                filter=FieldFilter(
                    "expiresAt", "<=", datetime.now(timezone.utc)
                )
            )
            .order_by("expiresAt")
            .limit(1)
        )
        snapshots = list(query.stream())
        if not snapshots:
            return False
        snapshots[0].reference.delete()
        return True

    def claim_next_export(self) -> ClaimedExportJob | None:
        query = (
            self.db.collection("export_jobs")
            .where(filter=FieldFilter("status", "==", "queued"))
            .order_by("createdAt")
            .limit(5)
        )
        for snapshot in query.stream():
            claimed = self._claim_export_snapshot(snapshot.reference)
            if claimed is not None:
                return claimed
        return None

    def _claim_export_snapshot(self, job_ref) -> ClaimedExportJob | None:
        transaction = self.db.transaction()

        @firestore.transactional
        def claim(transaction):
            snapshot = job_ref.get(transaction=transaction)
            if not snapshot.exists:
                return None
            data = snapshot.to_dict() or {}
            if data.get("status") != "queued":
                return None
            user_id = str(data.get("userId", "")).strip()
            journal_ids = tuple(
                str(value).strip()
                for value in data.get("journalIds", [])
                if str(value).strip()
            )
            export_kind = str(data.get("exportKind", "")).strip()
            if (
                not user_id
                or not 1 <= len(journal_ids) <= 50
                or len(set(journal_ids)) != len(journal_ids)
                or export_kind not in {"audio", "transcript", "both"}
            ):
                raise ValueError("Export job request is invalid.")
            transaction.update(
                job_ref,
                {
                    "status": "processing",
                    "startedAt": firestore.SERVER_TIMESTAMP,
                    "completedAt": None,
                    "errorCode": None,
                    "errorMessage": None,
                },
            )
            return ClaimedExportJob(
                id=snapshot.id,
                user_id=user_id,
                journal_ids=journal_ids,
                export_kind=export_kind,
                retry_count=int(data.get("retryCount", 0)),
            )

        return claim(transaction)

    def get_export_journals(
        self, job: ClaimedExportJob
    ) -> list[tuple[str, dict[str, Any]]]:
        journals: list[tuple[str, dict[str, Any]]] = []
        for journal_id in job.journal_ids:
            snapshot = self._journal_ref_for(job.user_id, journal_id).get()
            if not snapshot.exists:
                continue
            journal = snapshot.to_dict() or {}
            if journal.get("userId") != job.user_id:
                raise ValueError("A selected journal does not belong to this user.")
            journals.append((journal_id, journal))
        return journals

    def update_export_progress(
        self, job: ClaimedExportJob, *, step: str, completed_items: int
    ) -> None:
        self.db.collection("export_jobs").document(job.id).update(
            {
                "status": "processing",
                "processingStep": step[:80],
                "completedItems": max(0, completed_items),
            }
        )

    def complete_export(
        self,
        job: ClaimedExportJob,
        *,
        public_id: str,
        file_format: str,
        filename: str,
        size_bytes: int,
        included_count: int,
        skipped: list[dict[str, str]],
        expiry_hours: int,
    ) -> None:
        self.db.collection("export_jobs").document(job.id).update(
            {
                "status": "ready",
                "processingStep": "ready",
                "completedAt": firestore.SERVER_TIMESTAMP,
                "includedCount": included_count,
                "skippedCount": len(skipped),
                "skipped": skipped,
                "artifact": {
                    "publicId": public_id,
                    "format": file_format,
                    "filename": filename,
                    "sizeBytes": size_bytes,
                },
                "expiresAt": datetime.now(timezone.utc)
                + timedelta(hours=expiry_hours),
                "errorCode": None,
                "errorMessage": None,
            }
        )

    def fail_export(
        self,
        job: ClaimedExportJob,
        *,
        code: str,
        message: str,
    ) -> None:
        self.db.collection("export_jobs").document(job.id).update(
            {
                "status": "failed",
                "processingStep": "failed",
                "completedAt": firestore.SERVER_TIMESTAMP,
                "retryCount": job.retry_count + 1,
                "errorCode": code[:80],
                "errorMessage": " ".join(message.split())[:300],
            }
        )

    def claim_expired_export(self) -> ExportDownload | None:
        for status in ("ready", "consuming"):
            query = (
                self.db.collection("export_jobs")
                .where(filter=FieldFilter("status", "==", status))
                .where(
                    filter=FieldFilter(
                        "expiresAt", "<=", datetime.now(timezone.utc)
                    )
                )
                .order_by("expiresAt")
                .limit(5)
            )
            for snapshot in query.stream():
                transaction = self.db.transaction()

                @firestore.transactional
                def claim(transaction):
                    current = snapshot.reference.get(transaction=transaction)
                    if not current.exists:
                        return None
                    data = current.to_dict() or {}
                    if data.get("status") != status:
                        return None
                    artifact = data.get("artifact") or {}
                    transaction.update(
                        snapshot.reference,
                        {
                            "status": "expired",
                            "completedAt": firestore.SERVER_TIMESTAMP,
                        },
                    )
                    return _export_download_from_data(snapshot.id, artifact)

                claimed = claim(transaction)
                if claimed is not None:
                    return claimed
        return None

    def consume_export(self, job_id: str, user_id: str) -> ExportDownload:
        job_ref = self.db.collection("export_jobs").document(job_id)
        transaction = self.db.transaction()

        @firestore.transactional
        def consume(transaction):
            snapshot = job_ref.get(transaction=transaction)
            if not snapshot.exists:
                raise LookupError("Export not found.")
            data = snapshot.to_dict() or {}
            if data.get("userId") != user_id:
                raise PermissionError("Export belongs to another user.")
            status = str(data.get("status", ""))
            if status == "expired":
                raise TimeoutError("Export has expired.")
            if status in {"consuming", "consumed"}:
                raise FileExistsError("Export has already been downloaded.")
            if status != "ready":
                raise RuntimeError("Export is not ready.")
            expires_at = data.get("expiresAt")
            if isinstance(expires_at, datetime) and expires_at <= datetime.now(
                timezone.utc
            ):
                raise TimeoutError("Export has expired.")
            artifact = data.get("artifact") or {}
            download = _export_download_from_data(job_id, artifact)
            transaction.update(
                job_ref,
                {
                    "status": "consuming",
                    "consumedAt": firestore.SERVER_TIMESTAMP,
                },
            )
            return download

        return consume(transaction)

    def finish_export_consumption(
        self,
        job_id: str,
        *,
        error: str | None = None,
        cleanup_pending: bool = False,
    ) -> None:
        payload: dict[str, Any] = {
            "status": "consumed",
            "completedAt": firestore.SERVER_TIMESTAMP,
            "cleanupPending": cleanup_pending,
        }
        if not cleanup_pending:
            payload["artifact"] = firestore.DELETE_FIELD
        if error:
            payload["errorCode"] = "download_interrupted"
            payload["errorMessage"] = " ".join(error.split())[:300]
        self.db.collection("export_jobs").document(job_id).update(payload)

    def claim_pending_artifact_cleanup(self) -> ExportDownload | None:
        query = (
            self.db.collection("export_jobs")
            .where(filter=FieldFilter("cleanupPending", "==", True))
            .limit(5)
        )
        for snapshot in query.stream():
            data = snapshot.to_dict() or {}
            artifact = data.get("artifact") or {}
            return _export_download_from_data(snapshot.id, artifact)
        return None

    def mark_artifact_cleanup_pending(self, job_id: str) -> None:
        self.db.collection("export_jobs").document(job_id).update(
            {"cleanupPending": True}
        )

    def complete_artifact_cleanup(self, job_id: str) -> None:
        self.db.collection("export_jobs").document(job_id).update(
            {
                "cleanupPending": False,
                "artifact": firestore.DELETE_FIELD,
            }
        )

    def get_journal(self, job: ClaimedJob) -> dict[str, Any]:
        snapshot = self._journal_ref(job).get()
        if not snapshot.exists:
            raise ValueError("The journal referenced by this analysis job does not exist.")
        data = snapshot.to_dict() or {}
        if data.get("userId") != job.user_id:
            raise ValueError("Analysis job ownership does not match its journal.")
        return data

    def update_progress(self, job: ClaimedJob, step: str) -> None:
        job_ref = self._job_ref(job)
        deletion_ref = self.db.collection("deletion_jobs").document(job.journal_id)
        transaction = self.db.transaction()

        @firestore.transactional
        def update(transaction):
            job_snapshot = job_ref.get(transaction=transaction)
            deletion_snapshot = deletion_ref.get(transaction=transaction)
            if not job_snapshot.exists:
                raise JobLeaseLost("Analysis job no longer exists.")
            self._require_analysis_lease(
                job,
                job_snapshot.to_dict() or {},
                deletion_snapshot.to_dict() if deletion_snapshot.exists else None,
            )
            transaction.update(
                job_ref,
                {"status": "processing", "processingStep": step},
            )
            journal_update: dict[str, Any] = {
                "analysisStatus": "processing",
                "analysisStep": step,
            }
            if step == "downloading":
                journal_update["analysisStartedAt"] = firestore.SERVER_TIMESTAMP
            transaction.update(self._journal_ref(job), journal_update)

        update(transaction)

    def complete(self, job: ClaimedJob, result: dict[str, Any]) -> None:
        job_ref = self._job_ref(job)
        deletion_ref = self.db.collection("deletion_jobs").document(job.journal_id)
        transaction = self.db.transaction()

        @firestore.transactional
        def complete(transaction):
            job_snapshot = job_ref.get(transaction=transaction)
            deletion_snapshot = deletion_ref.get(transaction=transaction)
            if not job_snapshot.exists:
                raise JobLeaseLost("Analysis job no longer exists.")
            self._require_analysis_lease(
                job,
                job_snapshot.to_dict() or {},
                deletion_snapshot.to_dict() if deletion_snapshot.exists else None,
            )
            journal_result = dict(result)
            if "groundingShadowInsights" not in journal_result:
                journal_result["groundingShadowInsights"] = firestore.DELETE_FIELD
            journal_result["analysisCompletedAt"] = firestore.SERVER_TIMESTAMP
            transaction.update(self._journal_ref(job), journal_result)
            transaction.update(
                job_ref,
                {
                    "status": "complete",
                    "processingStep": "complete",
                    "completedAt": firestore.SERVER_TIMESTAMP,
                    "errorMessage": None,
                    "leaseOwner": None,
                    "leaseToken": None,
                    "leaseExpiresAt": None,
                },
            )

        complete(transaction)

    def fail(self, job: ClaimedJob, message: str) -> None:
        safe_message = " ".join(message.split())[:500]
        job_ref = self._job_ref(job)
        deletion_ref = self.db.collection("deletion_jobs").document(job.journal_id)
        transaction = self.db.transaction()

        @firestore.transactional
        def fail(transaction):
            job_snapshot = job_ref.get(transaction=transaction)
            deletion_snapshot = deletion_ref.get(transaction=transaction)
            if not job_snapshot.exists:
                raise JobLeaseLost("Analysis job no longer exists.")
            self._require_analysis_lease(
                job,
                job_snapshot.to_dict() or {},
                deletion_snapshot.to_dict() if deletion_snapshot.exists else None,
            )
            transaction.update(
                self._journal_ref(job),
                {
                    "analysisStatus": "failed",
                    "analysisStep": "failed",
                    "analysisError": safe_message,
                    "analysisCompletedAt": firestore.SERVER_TIMESTAMP,
                },
            )
            transaction.update(
                job_ref,
                {
                    "status": "failed",
                    "processingStep": "failed",
                    "completedAt": firestore.SERVER_TIMESTAMP,
                    "errorMessage": safe_message,
                    "retryCount": job.retry_count + 1,
                    "leaseOwner": None,
                    "leaseToken": None,
                    "leaseExpiresAt": None,
                },
            )

        fail(transaction)

    def renew_analysis_lease(self, job: ClaimedJob) -> bool:
        job_ref = self._job_ref(job)
        deletion_ref = self.db.collection("deletion_jobs").document(job.journal_id)
        transaction = self.db.transaction()

        @firestore.transactional
        def renew(transaction):
            job_snapshot = job_ref.get(transaction=transaction)
            deletion_snapshot = deletion_ref.get(transaction=transaction)
            if not job_snapshot.exists:
                return False
            try:
                self._require_analysis_lease(
                    job,
                    job_snapshot.to_dict() or {},
                    (
                        deletion_snapshot.to_dict()
                        if deletion_snapshot.exists
                        else None
                    ),
                )
            except (JobLeaseLost, AnalysisCancelled):
                return False
            now = datetime.now(timezone.utc)
            transaction.update(
                job_ref,
                {
                    "heartbeatAt": now,
                    "leaseExpiresAt": now
                    + timedelta(seconds=self.config.analysis_lease_seconds),
                },
            )
            return True

        return bool(renew(transaction))

    def interrupt_analysis(self, job: ClaimedJob) -> None:
        job_ref = self._job_ref(job)
        transaction = self.db.transaction()

        @firestore.transactional
        def interrupt(transaction):
            snapshot = job_ref.get(transaction=transaction)
            if not snapshot.exists:
                return
            data = snapshot.to_dict() or {}
            if (
                data.get("status") != "processing"
                or data.get("leaseToken") != job.lease_token
            ):
                return
            self._requeue_or_fail_interrupted(
                transaction,
                job_ref,
                self._journal_ref(job),
                data,
            )

        interrupt(transaction)

    def recover_stale_jobs(self, *, limit: int = 25) -> int:
        recovered = self._recover_stale_deletions(limit=limit)
        recovered += self._recover_stale_analyses(limit=limit)
        return recovered

    def _recover_stale_deletions(self, *, limit: int) -> int:
        recovered = 0
        for status in ("waiting", "processing"):
            query = (
                self.db.collection("deletion_jobs")
                .where(filter=FieldFilter("status", "==", status))
                .limit(limit)
            )
            for snapshot in query.stream():
                data = snapshot.to_dict() or {}
                lease_expires_at = data.get("leaseExpiresAt")
                if (
                    status == "processing"
                    and isinstance(lease_expires_at, datetime)
                    and lease_expires_at > datetime.now(timezone.utc)
                ):
                    continue
                transaction = self.db.transaction()

                @firestore.transactional
                def recover(transaction):
                    current = snapshot.reference.get(transaction=transaction)
                    if not current.exists:
                        return False
                    current_data = current.to_dict() or {}
                    current_status = current_data.get("status")
                    current_expiry = current_data.get("leaseExpiresAt")
                    if current_status not in {"waiting", "processing"}:
                        return False
                    if (
                        current_status == "processing"
                        and isinstance(current_expiry, datetime)
                        and current_expiry > datetime.now(timezone.utc)
                    ):
                        return False
                    transaction.update(
                        snapshot.reference,
                        {
                            "status": "queued",
                            "lastInterruptedAt": firestore.SERVER_TIMESTAMP,
                            "leaseOwner": None,
                            "leaseToken": None,
                            "leaseExpiresAt": None,
                        },
                    )
                    return True

                if recover(transaction):
                    recovered += 1
        return recovered

    def _recover_stale_analyses(self, *, limit: int) -> int:
        recovered = 0
        for status in ("processing", "cancel_requested"):
            query = (
                self.db.collection("analysis_jobs")
                .where(filter=FieldFilter("status", "==", status))
                .limit(limit)
            )
            for snapshot in query.stream():
                data = snapshot.to_dict() or {}
                lease_expires_at = data.get("leaseExpiresAt")
                if (
                    status == "processing"
                    and isinstance(lease_expires_at, datetime)
                    and lease_expires_at > datetime.now(timezone.utc)
                ):
                    continue
                transaction = self.db.transaction()

                @firestore.transactional
                def recover(transaction):
                    current = snapshot.reference.get(transaction=transaction)
                    if not current.exists:
                        return False
                    current_data = current.to_dict() or {}
                    current_status = current_data.get("status")
                    current_expiry = current_data.get("leaseExpiresAt")
                    if current_status not in {"processing", "cancel_requested"}:
                        return False
                    if (
                        current_status == "processing"
                        and isinstance(current_expiry, datetime)
                        and current_expiry > datetime.now(timezone.utc)
                    ):
                        return False
                    user_id = str(current_data.get("userId", "")).strip()
                    journal_id = str(current_data.get("journalId", "")).strip()
                    if not user_id or not journal_id:
                        return False
                    deletion = (
                        self.db.collection("deletion_jobs")
                        .document(journal_id)
                        .get(transaction=transaction)
                    )
                    if (
                        current_status == "cancel_requested"
                        or (
                            deletion.exists
                            and _is_active_deletion(deletion.to_dict() or {})
                        )
                    ):
                        transaction.update(
                            snapshot.reference,
                            {
                                "status": "cancelled",
                                "processingStep": "cancelled",
                                "completedAt": firestore.SERVER_TIMESTAMP,
                                "leaseOwner": None,
                                "leaseToken": None,
                                "leaseExpiresAt": None,
                            },
                        )
                    else:
                        self._requeue_or_fail_interrupted(
                            transaction,
                            snapshot.reference,
                            self._journal_ref_for(user_id, journal_id),
                            current_data,
                        )
                    return True

                if recover(transaction):
                    recovered += 1
        return recovered

    def _requeue_or_fail_interrupted(
        self,
        transaction,
        job_ref,
        journal_ref,
        data: dict[str, Any],
    ) -> None:
        attempt_count = int(data.get("attemptCount", data.get("retryCount", 0))) + 1
        common = {
            "attemptCount": attempt_count,
            "lastInterruptedAt": firestore.SERVER_TIMESTAMP,
            "leaseOwner": None,
            "leaseToken": None,
            "leaseExpiresAt": None,
            "heartbeatAt": None,
        }
        if attempt_count >= self.config.analysis_max_attempts:
            message = "Analysis stopped repeatedly and reached the retry limit."
            transaction.update(
                job_ref,
                {
                    **common,
                    "status": "failed",
                    "processingStep": "failed",
                    "completedAt": firestore.SERVER_TIMESTAMP,
                    "errorMessage": message,
                },
            )
            transaction.update(
                journal_ref,
                {
                    "analysisStatus": "failed",
                    "analysisStep": "failed",
                    "analysisError": message,
                    "analysisCompletedAt": firestore.SERVER_TIMESTAMP,
                },
            )
            return
        transaction.update(
            job_ref,
            {
                **common,
                "status": "queued",
                "processingStep": "queued",
                "startedAt": None,
                "completedAt": None,
                "errorMessage": None,
            },
        )
        transaction.update(
            journal_ref,
            {
                "analysisStatus": "queued",
                "analysisStep": "retrying",
                "analysisError": None,
                "analysisCompletedAt": None,
            },
        )

    def requeue_journal(self, user_id: str, journal_id: str) -> None:
        user_id = user_id.strip()
        journal_id = journal_id.strip()
        if not user_id or not journal_id:
            raise ValueError("userId and journalId are required for reprocessing.")
        journal_ref = (
            self.db.collection("users")
            .document(user_id)
            .collection("journals")
            .document(journal_id)
        )
        job_ref = self.db.collection("analysis_jobs").document(journal_id)
        transaction = self.db.transaction()

        @firestore.transactional
        def requeue(transaction):
            journal_snapshot = journal_ref.get(transaction=transaction)
            job_snapshot = job_ref.get(transaction=transaction)
            journal = journal_snapshot.to_dict() if journal_snapshot.exists else None
            job = job_snapshot.to_dict() if job_snapshot.exists else None
            validate_requeue_documents(journal, job, user_id, journal_id)
            if job_snapshot.exists:
                transaction.update(
                    job_ref,
                    {
                        "status": "queued",
                        "processingStep": "queued",
                        "analysisVersion": ANALYSIS_VERSION,
                        "startedAt": None,
                        "completedAt": None,
                        "errorMessage": None,
                        "requeuedAt": firestore.SERVER_TIMESTAMP,
                        "attemptCount": 0,
                        "leaseOwner": None,
                        "leaseToken": None,
                        "leaseExpiresAt": None,
                        "heartbeatAt": None,
                        "cancelRequestedAt": None,
                    },
                )
            else:
                transaction.set(
                    job_ref,
                    {
                        "userId": user_id,
                        "journalId": journal_id,
                        "status": "queued",
                        "processingStep": "queued",
                        "retryCount": 0,
                        "attemptCount": 0,
                        "analysisVersion": ANALYSIS_VERSION,
                        "createdAt": firestore.SERVER_TIMESTAMP,
                        "startedAt": None,
                        "completedAt": None,
                        "errorMessage": None,
                        "leaseOwner": None,
                        "leaseToken": None,
                        "leaseExpiresAt": None,
                        "heartbeatAt": None,
                        "cancelRequestedAt": None,
                    },
                )
            transaction.update(
                journal_ref,
                {
                    "analysisStatus": "queued",
                    "analysisStep": "queued",
                    "analysisVersion": ANALYSIS_VERSION,
                    "analysisError": None,
                    "analysisRequestedAt": firestore.SERVER_TIMESTAMP,
                },
            )

        requeue(transaction)

    def _job_ref(self, job: ClaimedJob):
        return self.db.collection("analysis_jobs").document(job.id)

    def _journal_ref(self, job: ClaimedJob):
        return self._journal_ref_for(job.user_id, job.journal_id)

    def _journal_ref_for(self, user_id: str, journal_id: str):
        return (
            self.db.collection("users")
            .document(user_id)
            .collection("journals")
            .document(journal_id)
        )

    def _require_analysis_lease(
        self,
        job: ClaimedJob,
        data: dict[str, Any],
        deletion: dict[str, Any] | None,
    ) -> None:
        if deletion and _is_active_deletion(deletion):
            raise AnalysisCancelled("Journal deletion has cancelled analysis.")
        if data.get("status") == "cancel_requested":
            raise AnalysisCancelled("Analysis cancellation was requested.")
        if (
            data.get("status") != "processing"
            or not job.lease_token
            or data.get("leaseToken") != job.lease_token
            or data.get("leaseOwner") != job.lease_owner
        ):
            raise JobLeaseLost("Analysis lease is no longer owned by this worker.")
        lease_expires_at = data.get("leaseExpiresAt")
        if (
            not isinstance(lease_expires_at, datetime)
            or lease_expires_at <= datetime.now(timezone.utc)
        ):
            raise JobLeaseLost("Analysis lease has expired.")

    def _require_deletion_lease(
        self,
        job: ClaimedDeletionJob,
        data: dict[str, Any],
    ) -> None:
        if (
            data.get("status") != "processing"
            or not job.lease_token
            or data.get("leaseToken") != job.lease_token
            or data.get("leaseOwner") != job.lease_owner
        ):
            raise JobLeaseLost("Deletion lease is no longer owned by this worker.")
        lease_expires_at = data.get("leaseExpiresAt")
        if (
            not isinstance(lease_expires_at, datetime)
            or lease_expires_at <= datetime.now(timezone.utc)
        ):
            raise JobLeaseLost("Deletion lease has expired.")


def validate_requeue_documents(
    journal: dict[str, Any] | None,
    job: dict[str, Any] | None,
    user_id: str,
    journal_id: str,
) -> None:
    if journal is None:
        raise ValueError("The selected journal does not exist.")
    if journal.get("userId") != user_id:
        raise ValueError("The selected journal does not belong to this user.")
    if job is None:
        return
    if job.get("userId") != user_id or job.get("journalId") != journal_id:
        raise ValueError("The analysis job ownership does not match the journal.")
    if job.get("status") == "processing":
        raise ValueError("A processing analysis job cannot be requeued.")


def _is_active_deletion(data: dict[str, Any]) -> bool:
    return data.get("status") in {
        "queued",
        "processing",
        "waiting",
    }


def _export_download_from_data(
    job_id: str, artifact: dict[str, Any]
) -> ExportDownload:
    public_id = str(artifact.get("publicId", "")).strip()
    filename = str(artifact.get("filename", "")).strip()
    if not public_id or not filename:
        raise ValueError("Export artifact metadata is incomplete.")
    return ExportDownload(
        job_id=job_id,
        public_id=public_id,
        file_format=str(artifact.get("format", "zip") or "zip"),
        filename=filename,
        size_bytes=int(artifact.get("sizeBytes", 0)),
    )
