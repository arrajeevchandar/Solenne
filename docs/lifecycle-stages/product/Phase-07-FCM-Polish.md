# Phase 7 — FCM + Polish

**Weeks:** 19–21  
**Sprints:** 11–12 (partial)  
**Module overlap:** M5 (Shambhavi)  
**Milestone:** **M5 — Beta Ready** (partial)

---

## Objective

Push notifications on analysis complete, privacy controls, account deletion, complete settings, bug bash.

---

## Entry Criteria

- [ ] Phase 6 exit gate passed (M4 handoff from Rajeev)
- [ ] APNs key uploaded (iOS push) if demoing on iPhone

---

## Deliverables

| # | Deliverable |
|---|-------------|
| 1 | FCM token saved to user doc |
| 2 | iOS/Android notification permission flow |
| 3 | Worker sends FCM on analysis complete |
| 4 | In-app notification center + deep links |
| 5 | Privacy dashboard (what's stored) |
| 6 | Consent revoke toggles (face/voice/text) |
| 7 | Delete all data + delete account |
| 8 | Settings complete: password, about, disclaimer |
| 9 | Firebase rules final audit |
| 10 | P0/P1 bug bash |

---

## Exit Criteria

- [ ] Push received on physical device when analysis completes
- [ ] Revoking face consent stops face on **next** journal
- [ ] Delete account removes Auth + Firestore + Storage
- [ ] Medical disclaimer on settings and insights
- [ ] No P0 bugs open

---

## User-Facing Outcome

> "I'm notified when my analysis is ready, and I trust the app with my data."

---

## Next Phase

→ [Phase 8 — Demo Launch](./Phase-08-Demo-Launch.md)

---

## References

- `entity/Consent-Data-Lifecycle.md`
- `modules/M5-Trust-Launch.md`
