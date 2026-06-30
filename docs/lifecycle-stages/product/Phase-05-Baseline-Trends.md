# Phase 5 — Baseline + Trends

**Weeks:** 13–15  
**Sprints:** 10  
**Module overlap:** M3 finish + M4 start (Yanish → Rajeev)  
**Milestone:** **M3 — First Trend**

---

## Objective

EWMA personal baselines updated after each analysis; 7-day trend chart with baseline confidence band on dashboard.

---

## Entry Criteria

- [ ] Phase 4 exit gate passed (fusion metrics on journal docs)
- [ ] At least 2 test journals with complete analysis

---

## Deliverables

| # | Deliverable | Owner |
|---|-------------|-------|
| 1 | EWMA baseline engine in worker | Yanish |
| 2 | `users/{uid}/baselines/{metric}` collection | Yanish |
| 3 | Z-score computation per metric | Yanish |
| 4 | Baseline confidence formula | Yanish |
| 5 | Dashboard home (Rajeev begins M4) | Rajeev |
| 6 | 7-day valence/arousal chart (`fl_chart`) | Rajeev |
| 7 | Baseline band overlay on chart | Rajeev |
| 8 | Baseline progress widget ("X/7 entries") | Rajeev |

---

## Exit Criteria

- [ ] Second journal updates baseline docs
- [ ] 7 seeded entries render chart correctly
- [ ] Baseline band visible when confidence > 0.3
- [ ] Empty chart state when < 2 complete journals

---

## User-Facing Outcome

> "I see how my mood has trended over the past week compared to my norm."

---

## Next Phase

→ [Phase 6 — Insights + Dashboard](./Phase-06-Insights-Dashboard.md)

---

## References

- `entity/Baseline-Lifecycle.md`
