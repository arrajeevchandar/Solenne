from __future__ import annotations

import threading
from typing import Any, Callable

from google.cloud.firestore_v1.base_query import FieldFilter


class FirestoreQueueWakeup:
    """Turns Firestore queue snapshots into one local wake event."""

    def __init__(self, db: Any) -> None:
        self.db = db
        self.event = threading.Event()
        self._watches: list[Any] = []

    def start(self) -> None:
        if self._watches:
            return
        for collection in ("analysis_jobs", "deletion_jobs", "export_jobs"):
            query = (
                self.db.collection(collection)
                .where(filter=FieldFilter("status", "==", "queued"))
                .limit(1)
            )
            self._watches.append(query.on_snapshot(self._on_snapshot))
        self.event.set()

    def wait(self, timeout: float) -> bool:
        return self.event.wait(max(0.0, timeout))

    def clear(self) -> None:
        self.event.clear()

    def wake(self) -> None:
        self.event.set()

    def close(self) -> None:
        watches, self._watches = self._watches, []
        for watch in watches:
            unsubscribe: Callable[[], Any] | None = getattr(
                watch, "unsubscribe", None
            )
            if unsubscribe is not None:
                unsubscribe()

    def _on_snapshot(self, _documents, changes, _read_time) -> None:
        if changes:
            self.event.set()

