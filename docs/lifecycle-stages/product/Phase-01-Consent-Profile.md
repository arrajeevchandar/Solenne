# Phase 1 — Consent & Profile

**Weeks:** 3  
**Sprints:** 2 (partial)  
**Module overlap:** M1 (Rajeev)  
**Milestone:** —

---

## Objective

Complete onboarding flow with granular modality consent, user profile in Firestore, returning-user skip logic.

---

## Entry Criteria

- [ ] Phase 0 exit gate passed
- [ ] Auth working on device

---

## Deliverables

| # | Deliverable |
|---|-------------|
| 1 | Multi-step onboarding wizard |
| 2 | Terms + Privacy + 18+ acceptance (versioned) |
| 3 | Face / voice / text consent toggles |
| 4 | Wellness goal + timezone capture |
| 5 | Recording tutorial + medical disclaimer |
| 6 | `users/{uid}` + `consents/{id}` Firestore docs |
| 7 | Profile view/edit screen |
| 8 | Settings shell (stub for M5) |
| 9 | Skip onboarding if `onboardingComplete: true` |

---

## Exit Criteria

- [ ] New user completes onboarding in < 5 minutes
- [ ] Consent records visible in Firestore Console
- [ ] Returning user lands on home without onboarding
- [ ] Profile edits persist to Firestore
- [ ] Medical disclaimer shown during onboarding

---

## Next Phase

→ [Phase 2 — Record + Upload](./Phase-02-Record-Upload.md)

---

## References

- `entity/Consent-Data-Lifecycle.md` — consent stages
- `modules/M1-Identity-First-Run.md` — full M1 exit gate
