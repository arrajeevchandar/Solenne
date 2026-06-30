# Phase 0 — Firebase + Flutter Foundations

**Weeks:** 1–2  
**Sprints:** 1 (partial)  
**Module overlap:** M1 start (Rajeev)  
**Milestone:** **M0 — Dev Environment**

---

## Objective

Firebase project live, Flutter app scaffolded, authentication working on device, team can clone and run.

---

## Entry Criteria

- [ ] All dev tools installed (`docs/implementation-readiness/01-Environment-Setup.md`)
- [ ] Team roster and Firebase Console access agreed
- [ ] Git repo created with `.gitignore` for secrets

---

## Deliverables

| # | Deliverable | Owner |
|---|-------------|-------|
| 1 | Firebase project (Spark plan) | Rajeev |
| 2 | Firestore + Storage rules files in repo | Rajeev |
| 3 | Flutter app `mobile/` with `flutterfire configure` | Rajeev |
| 4 | Email login + register screens | Rajeev |
| 5 | `go_router` + Riverpod scaffold | Rajeev |
| 6 | GitHub Actions `flutter analyze` + `flutter test` | Rajeev |
| 7 | README: clone → run instructions | Rajeev |

---

## Key Activities

### Week 1
- Create Firebase project; enable Auth (Email + Google)
- `flutter create mobile`; register Android/iOS apps
- Deploy initial Firestore + Storage rules
- App shell: theme, router, empty home

### Week 2
- Login / register / forgot password UI
- Auth state provider + route guards
- First PR merged; CI green
- Teammate verification: clone + run on device

---

## Exit Criteria (Phase Gate)

- [ ] `flutter run` works on emulator or physical device
- [ ] User can register and login with email
- [ ] Firebase Console shows new Auth user
- [ ] Firestore rules deployed (default deny + user paths)
- [ ] CI passes on `main`/`develop`
- [ ] Second team member runs app without help

---

## Risks

| Risk | Mitigation |
|------|------------|
| Google Sign-In config delay | Ship email auth first; Google in Phase 1 |
| iOS signing issues | Android-first for Week 2 gate |
| Firebase rules too permissive | Review rules before any real data |

---

## Next Phase

→ [Phase 1 — Consent & Profile](./Phase-01-Consent-Profile.md)

---

## References

- `docs/implementation-readiness/02-Module-Implementation-Guide.md` § M1 Steps 1–3
- `docs/SOLENNE-Weekly-Tracker.md` — Week 1–2
