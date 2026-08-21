from __future__ import annotations

from dataclasses import dataclass
import re

from firebase_admin import firestore


@dataclass(frozen=True)
class UsernameMigration:
    user_id: str
    old_username: str
    new_username: str


def canonical_username(value: str) -> str:
    return value.strip().lower().lstrip("@")


def migration_username(data: dict, user_id: str, occupied: set[str]) -> str:
    raw = str(data.get("usernameNormalized") or data.get("username") or "")
    canonical = canonical_username(raw)
    if re.fullmatch(r"[a-z0-9_]{3,20}", canonical) and canonical not in occupied:
        return canonical

    display_name = str(data.get("displayName") or "solenne")
    base = re.sub(r"[^a-z0-9_]", "", display_name.lower().replace(" ", "_"))
    base = (base or "solenne")[:12]
    if len(base) < 3:
        base = "solenne"
    suffix = user_id[:6].lower()
    for attempt in range(100):
        tail = f"_{suffix}{attempt if attempt else ''}"
        candidate = f"{base[:20 - len(tail)]}{tail}"
        if candidate not in occupied:
            return candidate
    raise RuntimeError(f"Could not allocate a username for user {user_id}.")


def migrate_usernames(db, *, apply: bool) -> list[UsernameMigration]:
    reservations = {
        snapshot.id: str((snapshot.to_dict() or {}).get("uid", ""))
        for snapshot in db.collection("usernames").stream()
    }
    occupied: set[str] = set()
    migrations: list[UsernameMigration] = []
    users = sorted(db.collection("users").stream(), key=lambda item: item.id)
    for snapshot in users:
        data = snapshot.to_dict() or {}
        raw = str(data.get("usernameNormalized") or data.get("username") or "").strip()
        canonical = canonical_username(raw)
        current_is_valid = (
            bool(re.fullmatch(r"[a-z0-9_]{3,20}", canonical))
            and raw == canonical
            and reservations.get(canonical) == snapshot.id
            and canonical not in occupied
        )
        if current_is_valid:
            occupied.add(canonical)
            continue

        unavailable = occupied | {
            name for name, owner in reservations.items() if owner != snapshot.id
        }
        candidate = migration_username(data, snapshot.id, unavailable)
        occupied.add(candidate)
        migration = UsernameMigration(snapshot.id, raw, candidate)
        migrations.append(migration)
        if apply:
            _apply_migration(db, snapshot.id, raw, candidate)
    return migrations


def _apply_migration(db, user_id: str, old_username: str, new_username: str) -> None:
    user_ref = db.collection("users").document(user_id)
    new_ref = db.collection("usernames").document(new_username)
    old_ref = (
        db.collection("usernames").document(old_username)
        if old_username and old_username != new_username
        else None
    )
    transaction = db.transaction()

    @firestore.transactional
    def update(transaction):
        user_snapshot = user_ref.get(transaction=transaction)
        new_snapshot = new_ref.get(transaction=transaction)
        old_snapshot = (
            old_ref.get(transaction=transaction) if old_ref is not None else None
        )
        if not user_snapshot.exists:
            return
        if new_snapshot.exists and (new_snapshot.to_dict() or {}).get("uid") != user_id:
            raise RuntimeError(f"Username {new_username} was reserved concurrently.")
        data = user_snapshot.to_dict() or {}
        display_name = str(data.get("displayName") or "Friend")
        photo_url = str(data.get("photoUrl") or "")
        transaction.set(
            new_ref,
            {
                "uid": user_id,
                "username": new_username,
                "usernameNormalized": new_username,
                "displayName": display_name,
                "photoUrl": photo_url,
                "updatedAt": firestore.SERVER_TIMESTAMP,
            },
        )
        transaction.update(
            user_ref,
            {
                "username": new_username,
                "usernameNormalized": new_username,
                "updatedAt": firestore.SERVER_TIMESTAMP,
            },
        )
        if (
            old_ref is not None
            and old_snapshot is not None
            and old_snapshot.exists
            and (old_snapshot.to_dict() or {}).get("uid") == user_id
        ):
            transaction.delete(old_ref)

    update(transaction)
