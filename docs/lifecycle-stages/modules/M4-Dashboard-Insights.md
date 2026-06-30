# Module M4 — Dashboard & Insights

**Owner:** Rajeev (Turn 4)  
**Duration:** 4–5 weeks  
**Product phases:** 5 (charts), 6  
**Depends on:** M3 exit gate

---

## One-Line Summary

Everything the user sees to understand emotional patterns — home dashboard, trend charts, insight center. **Read-only on worker output — do not rebuild the worker.**

---

## Module Lifecycle Stages

| Stage | Activities | Gate |
|-------|------------|------|
| **1. Plan** | Read M3 handoff; seed 7+ journals for chart testing | Seed data ready |
| **2. Pre-dev** | Verify Firestore queries for trends + insights | Queries return data |
| **3. Implement** | Module Guide § M4 | PRs merged |
| **4. Test** | Test Catalog § M4 | All P0 pass |
| **5. Exit Gate** | Checklist below | All boxes ✓ |
| **6. Handoff** | `docs/handoffs/M4.md` | Shambhavi unblocked |
| **7. Demo** | Dashboard → trends → insight → source journal | — |

---

## Scope

| Area | Features |
|------|----------|
| Dashboard | Streak, latest journal, record CTA, insight preview, baseline progress |
| Trends | 7-day valence/arousal chart, baseline band, metric selector |
| Timeline | Full trends screen, empty states |
| Insights | List, unread badge, detail, evidence drawer |
| Feedback | Helpful / not helpful, dismiss |
| Suppression | Hide when baseline confidence < 0.6 |
| Navigation | Replace M2 home stub; wire bottom nav |

---

## Exit Gate

- [ ] Dashboard populated with 7 seeded journal entries
- [ ] 7-day chart renders with baseline band
- [ ] ≥1 insight visible with evidence drawer
- [ ] Unread badge clears when insight opened
- [ ] Full flow: login → dashboard → trends → insight → source journal

---

## Handoff to M5 (Shambhavi)

Must document:
- Demo seed account credentials (test only)
- Chart metric definitions
- Insight list query

---

## References

- `entity/Insight-Lifecycle.md`
- `product/Phase-06-Insights-Dashboard.md`
