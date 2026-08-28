from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

from firebase_admin import firestore
from google.cloud.firestore_v1.base_query import FieldFilter

from .firebase_gateway import FirebaseGateway
from .username_migration import migrate_usernames


@dataclass(frozen=True)
class MaintenanceFinding:
    category: str
    document_id: str


def run_maintenance(
    gateway: FirebaseGateway, *, apply: bool
) -> list[MaintenanceFinding]:
    db = gateway.db
    findings: list[MaintenanceFinding] = []

    stale = _stale_job_findings(db)
    findings.extend(stale)
    if apply and stale:
        gateway.recover_stale_jobs(limit=max(25, len(stale)), include_legacy=True)

    migrations = migrate_usernames(db, apply=apply)
    findings.extend(
        MaintenanceFinding("username_reservation", item.user_id)
        for item in migrations
    )

    friendship_cache: dict[str, dict[str, Any] | None] = {}
    for share in (
        db.collection("journal_shares")
        .where(filter=FieldFilter("status", "==", "active"))
        .stream()
    ):
        data = share.to_dict() or {}
        friendship_id = str(data.get("friendshipId", ""))
        friendship = _friendship(db, friendship_id, friendship_cache)
        if friendship is not None and friendship.get("status") == "accepted":
            continue
        findings.append(MaintenanceFinding("orphan_share", share.id))
        if apply:
            share.reference.delete()

    required_defaults = {
        "active": True,
        "schemaVersion": 1,
        "lastMessageId": "",
        "deliveredThrough": {},
        "readThrough": {},
        "typing": {},
        "unreadCounts": {},
    }
    for conversation in db.collection("conversations").stream():
        data = conversation.to_dict() or {}
        friendship = _friendship(db, conversation.id, friendship_cache)
        accepted = friendship is not None and friendship.get("status") == "accepted"
        updates = {
            key: value for key, value in required_defaults.items() if key not in data
        }
        if not accepted and data.get("active", True):
            updates["active"] = False
            updates["typing"] = {}
        if not updates:
            continue
        category = "inactive_conversation" if not accepted else "conversation_schema"
        findings.append(MaintenanceFinding(category, conversation.id))
        if apply:
            updates["updatedAt"] = firestore.SERVER_TIMESTAMP
            conversation.reference.update(updates)

    for journal in db.collection_group("journals").stream():
        data = journal.to_dict() or {}
        status = str(data.get("analysisStatus", ""))
        job_ref = db.collection("analysis_jobs").document(journal.id)
        job = job_ref.get()
        job_data = job.to_dict() or {}
        if status in {"queued", "processing"} and not job.exists:
            findings.append(MaintenanceFinding("journal_missing_job", journal.id))
            if apply:
                journal.reference.update(
                    {
                        "analysisStatus": "failed",
                        "analysisStep": "failed",
                        "analysisErrorCode": "analysis_job_missing",
                        "analysisError": "Analysis could not start. Retry this reflection.",
                        "updatedAt": firestore.SERVER_TIMESTAMP,
                    }
                )
        elif status == "not_requested" and job.exists:
            findings.append(MaintenanceFinding("consent_job_conflict", journal.id))
            if apply:
                if job_data.get("status") == "processing":
                    job_ref.update(
                        {
                            "status": "cancel_requested",
                            "cancelRequestedAt": firestore.SERVER_TIMESTAMP,
                        }
                    )
                else:
                    job_ref.delete()
        elif status == "complete" and job.exists and job_data.get("status") != "complete":
            findings.append(MaintenanceFinding("completed_job_mismatch", journal.id))
            if apply:
                job_ref.update(
                    {
                        "status": "complete",
                        "processingStep": "complete",
                        "completedAt": firestore.SERVER_TIMESTAMP,
                        "leaseOwner": None,
                        "leaseToken": None,
                        "leaseExpiresAt": None,
                    }
                )
    return findings


def _friendship(db, friendship_id: str, cache: dict[str, Any]):
    if not friendship_id:
        return None
    if friendship_id not in cache:
        snapshot = db.collection("friendships").document(friendship_id).get()
        cache[friendship_id] = snapshot.to_dict() if snapshot.exists else None
    return cache[friendship_id]


def _stale_job_findings(db) -> list[MaintenanceFinding]:
    now = datetime.now(timezone.utc)
    findings: list[MaintenanceFinding] = []
    for collection, statuses in (
        ("analysis_jobs", {"processing", "cancel_requested"}),
        ("deletion_jobs", {"waiting", "processing"}),
    ):
        for snapshot in db.collection(collection).stream():
            data = snapshot.to_dict() or {}
            status = data.get("status")
            if status not in statuses:
                continue
            expiry = data.get("leaseExpiresAt")
            if status in {"waiting", "cancel_requested"} or not isinstance(
                expiry, datetime
            ) or expiry <= now:
                findings.append(MaintenanceFinding("stale_lease", snapshot.id))
    return findings
