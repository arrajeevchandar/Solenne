# SDLC Stage 2 — Design

**Input:** Approved plan  
**Output:** Schema, UI flow, security rules draft  
**Duration:** 0.5–2 days per feature

---

## Activities

### Flutter features
- Define screen route in `go_router`
- List Firestore fields read/written
- Sketch widget tree (screen → widgets → providers)
- Identify Riverpod providers needed

### Worker features
- Define pipeline step input/output
- List Firestore fields worker writes (client read-only?)
- Error states and retry policy

### Security
- Update `firestore.rules` / `storage.rules` if new paths
- Confirm user-scoped access

---

## Checklist

- [ ] Firestore schema documented (field names + types)
- [ ] State transitions defined (if entity lifecycle applies)
- [ ] Security rules reviewed for new collections/paths
- [ ] Edge cases identified (`implementation-readiness/04-Edge-Cases*.md`)
- [ ] Environment verified (`01-Environment-Setup.md`)

---

## Design References

| Topic | Doc |
|-------|-----|
| Firestore schema | Playbook §6 |
| Journal states | `entity/Journal-Entry-Lifecycle.md` |
| Job states | `entity/Analysis-Job-Lifecycle.md` |
| Consent enforcement | `entity/Consent-Data-Lifecycle.md` |

---

## Gate to Stage 3

Pre-dev checklist 100% for the feature area.

→ [Stage 3 — Implement](./Stage-03-Implement.md)
