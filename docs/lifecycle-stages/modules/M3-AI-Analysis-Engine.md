# Module M3 — AI Analysis Engine

**Owner:** Yanish (Turn 3)  
**Duration:** 6–7 weeks  
**Product phases:** 3, 4, 5 (baseline portion)  
**Depends on:** M2 exit gate

---

## One-Line Summary

Python worker that processes videos plus all Flutter UI showing analysis progress and results. **Largest module.**

---

## Module Lifecycle Stages

| Stage | Activities | Gate |
|-------|------------|------|
| **1. Plan** | Read M2 handoff; set up worker venv + service account | Worker connects |
| **2. Pre-dev** | Download Whisper model once; ffmpeg verified | Pre-flight OK |
| **3. Implement** | Module Guide § M3 Steps 1–5 | PRs merged |
| **4. Test** | Test Catalog § M3 (pytest + Flutter + manual) | All P0 pass |
| **5. Exit Gate** | Checklist below | All boxes ✓ |
| **6. Handoff** | `docs/handoffs/M3.md` + worker README | Rajeev unblocked for M4 |
| **7. Demo** | Upload → worker → full results in app | — |

---

## Scope

| Area | Features |
|------|----------|
| Worker | Poll jobs, state machine, download, pipeline orchestration |
| Media | ffmpeg audio extract |
| Transcription | faster-whisper small (CPU) |
| Face | MediaPipe (consent-aware skip) |
| Voice | librosa prosody |
| NLP | VADER sentiment |
| Fusion | Late fusion, wellness metrics on journal |
| Baseline | EWMA in `baselines/` collection |
| Insights | Template generation (≥1 after enough entries) |
| Flutter UI | Status listener, results cards, congruence, quality warning |

---

## Code Paths

- `worker/` — entire Python pipeline
- `mobile/lib/features/analysis/` — results + status widgets
- Updates to journal detail from M2

---

## Exit Gate

- [ ] Worker on laptop: upload → full analysis in Firestore within ~8 min
- [ ] App auto-updates when worker writes (no manual refresh)
- [ ] Face analysis skipped when user opted out in M1
- [ ] 2nd journal entry updates baselines
- [ ] At least 1 template insight generated after sufficient entries
- [ ] README documents how to run the worker
- [ ] pytest passes

---

## Handoff to M4 (Rajeev)

Must document:
- Worker run command
- Firestore fields written per journal
- Baseline + insight query patterns
- How to requeue failed jobs

---

## References

- `entity/Analysis-Job-Lifecycle.md`
- `entity/Analysis-Pipeline-Lifecycle.md`
- `entity/Baseline-Lifecycle.md`
- `product/Phase-03` through `Phase-05`
