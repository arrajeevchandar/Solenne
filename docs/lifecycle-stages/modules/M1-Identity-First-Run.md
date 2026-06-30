# Module M1 — Identity & First Run

**Owner:** Rajeev (Turn 1)  
**Duration:** 4–5 weeks  
**Product phases:** 0, 1  
**Depends on:** —

---

## One-Line Summary

Everything from app install until a logged-in user with completed profile is ready to record their first journal.

---

## Module Lifecycle Stages

| Stage | Activities | Gate |
|-------|------------|------|
| **1. Plan** | Review Team Work Plan + Module Guide § M1; confirm scope | Team agrees |
| **2. Pre-dev** | Complete Environment Setup checklist; Firebase project live | 100% checklist |
| **3. Implement** | Steps 1–5 in Module Implementation Guide | PRs merged |
| **4. Test** | Test Catalog § M1 (unit + integration + manual) | All P0 pass |
| **5. Exit Gate** | Checklist below | All boxes ✓ |
| **6. Handoff** | Write `docs/handoffs/M1.md`; 15-min demo | Next owner unblocked |
| **7. Demo** | Show register → onboard → empty home to team | — |

---

## Scope (What's Inside)

| Area | Features |
|------|----------|
| Platform | Firebase Spark, Flutter scaffold, `flutterfire configure`, repo structure |
| App shell | Theme, go_router, bottom nav skeleton, Riverpod |
| Security | Firestore + Storage rules (user-scoped) |
| Auth | Email, Google Sign-In, password reset, logout, auth guard |
| Onboarding | Welcome, Terms/Privacy, 18+, consent, wellness goal, timezone, tutorial, disclaimer |
| Profile | View/edit display name, timezone, wellness goal |
| First-run | Skip onboarding if complete |

---

## Screens Delivered

Login · Register · Forgot Password · Onboarding wizard · Profile · Settings (shell) · Home (empty stub)

---

## Exit Gate

- [ ] New user: install → register → onboard → land on empty home
- [ ] Returning user: login → skip onboarding → home
- [ ] Consent + profile data visible in Firestore
- [ ] Other team members can clone repo and run the app
- [ ] `flutter analyze` clean

---

## Handoff to M2 (Shambhavi)

Must document:
- Firebase project ID, package name, bundle ID
- Firestore paths for user + consent
- How auth guard works in router
- Known issues

---

## References

- `docs/implementation-readiness/02-Module-Implementation-Guide.md` § M1
- `product/Phase-00-Firebase-Flutter.md` + `Phase-01-Consent-Profile.md`
