# Module M5 — Trust, Notifications & Launch

**Owner:** Shambhavi (Turn 5)  
**Duration:** 3–4 weeks  
**Product phases:** 7, 8  
**Depends on:** M4 exit gate

---

## One-Line Summary

Push notifications, privacy controls, full settings, account deletion, demo-ready polish.

---

## Module Lifecycle Stages

| Stage | Activities | Gate |
|-------|------------|------|
| **1. Plan** | Read M4 handoff; plan demo script + APK target | Demo plan written |
| **2. Pre-dev** | FCM/APNs configured; physical device for push test | Token saves to Firestore |
| **3. Implement** | Module Guide § M5 | PRs merged |
| **4. Test** | Test Catalog § M5 + E2E demo script | All P0 pass |
| **5. Exit Gate** | Checklist below | All boxes ✓ |
| **6. Handoff** | `docs/handoffs/M5.md` + demo script | Integration week starts |
| **7. Demo** | Full E2E with push + delete test on throwaway account | — |

---

## Scope

| Area | Features |
|------|----------|
| FCM | Permission, token save, worker push on complete, deep links |
| Notifications | In-app list, deep links to journal/insight |
| Privacy | What's stored, consent revoke toggles |
| Data rights | Delete all data, delete account (cascade) |
| Settings | Password, notification prefs stub, about, disclaimer |
| Demo | Seed 2 accounts, APK, backup recording, README polish |
| Hardening | Bug bash, rules audit |

---

## Exit Gate

- [ ] Push received when analysis completes
- [ ] Revoking face consent stops face analysis on next entry
- [ ] Delete account removes all user data
- [ ] End-to-end demo works without manual Firestore edits
- [ ] Second team member can run full demo from README alone

---

## Post-Module: Integration Week

Yanish leads all three · See `../release/Release-Demo-Lifecycle.md`

---

## References

- `entity/Consent-Data-Lifecycle.md`
- `product/Phase-07-FCM-Polish.md` + `Phase-08-Demo-Launch.md`
