from __future__ import annotations

from dataclasses import dataclass
from typing import Any

import firebase_admin
from firebase_admin import credentials, firestore
from google.cloud.firestore_v1.base_query import FieldFilter

from .config import WorkerConfig


@dataclass(frozen=True)
class ClaimedJob:
    id: str
    user_id: str
    journal_id: str
    retry_count: int


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
            if data.get("status") != "queued":
                return None
            user_id = str(data.get("userId", "")).strip()
            journal_id = str(data.get("journalId", "")).strip()
            if not user_id or not journal_id:
                raise ValueError("Analysis job is missing userId or journalId.")
            transaction.update(
                job_ref,
                {
                    "status": "processing",
                    "processingStep": "starting",
                    "startedAt": firestore.SERVER_TIMESTAMP,
                    "completedAt": None,
                    "errorMessage": None,
                },
            )
            return ClaimedJob(
                id=snapshot.id,
                user_id=user_id,
                journal_id=journal_id,
                retry_count=int(data.get("retryCount", 0)),
            )

        return claim(transaction)

    def get_journal(self, job: ClaimedJob) -> dict[str, Any]:
        snapshot = self._journal_ref(job).get()
        if not snapshot.exists:
            raise ValueError("The journal referenced by this analysis job does not exist.")
        data = snapshot.to_dict() or {}
        if data.get("userId") != job.user_id:
            raise ValueError("Analysis job ownership does not match its journal.")
        return data

    def update_progress(self, job: ClaimedJob, step: str) -> None:
        batch = self.db.batch()
        batch.update(
            self._job_ref(job),
            {"status": "processing", "processingStep": step},
        )
        journal_update: dict[str, Any] = {
            "analysisStatus": "processing",
            "analysisStep": step,
        }
        if step == "downloading":
            journal_update["analysisStartedAt"] = firestore.SERVER_TIMESTAMP
        batch.update(self._journal_ref(job), journal_update)
        batch.commit()

    def complete(self, job: ClaimedJob, result: dict[str, Any]) -> None:
        batch = self.db.batch()
        journal_result = dict(result)
        if "groundingShadowInsights" not in journal_result:
            journal_result["groundingShadowInsights"] = firestore.DELETE_FIELD
        journal_result["analysisCompletedAt"] = firestore.SERVER_TIMESTAMP
        batch.update(self._journal_ref(job), journal_result)
        batch.update(
            self._job_ref(job),
            {
                "status": "complete",
                "processingStep": "complete",
                "completedAt": firestore.SERVER_TIMESTAMP,
                "errorMessage": None,
            },
        )
        batch.commit()

    def fail(self, job: ClaimedJob, message: str) -> None:
        safe_message = " ".join(message.split())[:500]
        batch = self.db.batch()
        batch.update(
            self._journal_ref(job),
            {
                "analysisStatus": "failed",
                "analysisStep": "failed",
                "analysisError": safe_message,
                "analysisCompletedAt": firestore.SERVER_TIMESTAMP,
            },
        )
        batch.update(
            self._job_ref(job),
            {
                "status": "failed",
                "processingStep": "failed",
                "completedAt": firestore.SERVER_TIMESTAMP,
                "errorMessage": safe_message,
                "retryCount": job.retry_count + 1,
            },
        )
        batch.commit()

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
                        "analysisVersion": "2026-07-v2-grounded",
                        "startedAt": None,
                        "completedAt": None,
                        "errorMessage": None,
                        "requeuedAt": firestore.SERVER_TIMESTAMP,
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
                        "analysisVersion": "2026-07-v2-grounded",
                        "createdAt": firestore.SERVER_TIMESTAMP,
                        "startedAt": None,
                        "completedAt": None,
                        "errorMessage": None,
                    },
                )
            transaction.update(
                journal_ref,
                {
                    "analysisStatus": "queued",
                    "analysisStep": "queued",
                    "analysisVersion": "2026-07-v2-grounded",
                    "analysisError": None,
                    "analysisRequestedAt": firestore.SERVER_TIMESTAMP,
                },
            )

        requeue(transaction)

    def _job_ref(self, job: ClaimedJob):
        return self.db.collection("analysis_jobs").document(job.id)

    def _journal_ref(self, job: ClaimedJob):
        return (
            self.db.collection("users")
            .document(job.user_id)
            .collection("journals")
            .document(job.journal_id)
        )


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
