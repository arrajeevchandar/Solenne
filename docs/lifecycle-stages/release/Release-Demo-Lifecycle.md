# Release & Demo Lifecycle

**Duration:** 1–3 weeks (overlaps Phase 8)  
**Lead:** Yanish (integration) · All hands  
**Prerequisite:** M5 exit gate passed

---

## Stages

```
Stage 1           Stage 2            Stage 3           Stage 4          Stage 5
Integration  →   Seed & Build   →   Rehearsal    →   Demo Day    →   Retrospective
(all test)       (APK, accounts)    (live + backup)   (present)       (backlog)
```

---

## Stage 1 — Integration (3–5 days)

**Goal:** All modules work together without manual Firestore edits.

| Task | Owner | Done when |
|------|-------|-----------|
| Pull latest `develop` | All | Clean build |
| Full E2E on Android device | Shambhavi | Record → analysis → insight |
| Full E2E on iOS (if demoing) | Rajeev | Same flow |
| Worker stability: 3 videos back-to-back | Yanish | All complete |
| Cross-user isolation test | Rajeev | User A cannot see User B |
| Firestore rules pen-test | Rajeev | Rules hold |
| Fix P0 integration bugs | Whoever owns module | Zero P0 open |

---

## Stage 2 — Seed & Build (2–3 days)

| Task | Detail |
|------|--------|
| Demo account 1 | 7+ days seeded journals, insights visible |
| Demo account 2 | Fresh user path for onboarding demo |
| APK build | `flutter build apk --release` or debug for sideload |
| Backup recording | Full 10-min screen recording of happy path |
| Worker hotspot doc | Campus WiFi + laptop worker instructions |
| Slide deck | Flutter+Firebase prototype → AWS at scale |

---

## Stage 3 — Rehearsal (1–2 days)

Run demo script twice:

| Run | Mode | Success criteria |
|-----|------|------------------|
| Run A | Live (worker on laptop) | Completes in ≤ 15 min |
| Run B | Backup video only | Plays if Run A fails |

**Demo script (10 min):**

1. Worker running (show terminal briefly)
2. Login demo account 1 → dashboard with trends
3. Open insight → evidence → source journal
4. Logout → register demo account 2 OR show onboarding recording
5. Record 30–60s journal → wait for analysis OR cut to pre-seeded complete entry
6. State medical disclaimer + "not a medical device"
7. Q&A backup: architecture slide

---

## Stage 4 — Demo Day

| Checklist | |
|-----------|---|
| [ ] Laptop charged; worker tested 1 hour before |
| [ ] Phone charged; APK installed |
| [ ] Backup video on phone + laptop |
| [ ] Hotspot tested if venue WiFi unreliable |
| [ ] Disclaimer stated verbally |

**If live demo fails:** Switch to backup video within 30 seconds; continue narrating architecture.

---

## Stage 5 — Retrospective (1 day)

| Output | Location |
|--------|----------|
| What went well / poorly | Team notes |
| Post-MVP backlog | GitHub Issues / doc |
| Handoff to future work | Playbook §14 Migration Map |

### Post-MVP Backlog (Starter)

- Apple Sign-In
- Offline upload queue
- Calendar heatmap
- GDPR export ZIP
- Cloud Run worker
- AWS migration path

---

## Release Artifacts Checklist

- [ ] Final README
- [ ] APK or install instructions
- [ ] Demo script (this doc § Stage 3)
- [ ] Backup screen recording
- [ ] Architecture slide
- [ ] `docs/handoffs/M1.md` through `M5.md` complete

---

## References

- `product/Phase-08-Demo-Launch.md`
- `docs/SOLENNE-Zero-Budget-Build-Plan.md` — Demo Day Checklist
- `implementation-readiness/03-Test-Catalog.md` §7
