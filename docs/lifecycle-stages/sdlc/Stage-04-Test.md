# SDLC Stage 4 — Test

**Input:** Implemented PR  
**Output:** All P0 tests pass  
**Duration:** 0.5–2 days per feature

---

## Test Layers

| Layer | Command / Action | When |
|-------|------------------|------|
| **Unit** | `flutter test` / `pytest` | Every PR |
| **Integration** | Device/emulator flows | Before module exit |
| **Manual QA** | Test Catalog § manual | Before module exit |
| **Security** | Cross-user access attempt | M1, M5 |

---

## Process

1. Run automated tests from `implementation-readiness/03-Test-Catalog.md` for current module
2. Execute manual QA checklist on physical device
3. Log failures as issues; fix before merge
4. Re-test edge cases from `04-Edge-Cases-And-Failure-Modes.md`

---

## P0 Gate (Must Pass)

- All Test Catalog items marked P0 for current module
- No regression on prior module exit gates (smoke test prior flows)
- Worker pipeline tested with real video (M3+)

---

## Gate to Stage 5

All P0 tests pass; PR approved.

→ [Stage 5 — Deploy](./Stage-05-Deploy.md)
