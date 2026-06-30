# Phase 4 — Full Analysis

**Weeks:** 10–12  
**Sprints:** 8–9  
**Module overlap:** M3 (Yanish)  
**Milestone:** **M2 — First Analysis**

---

## Objective

Complete multimodal analysis: face (MediaPipe), voice (librosa), NLP (VADER), fusion, consent-aware skipping, results UI.

---

## Entry Criteria

- [ ] Phase 3 exit gate passed (transcript pipeline working)
- [ ] User consent docs readable from worker

---

## Deliverables

| # | Deliverable |
|---|-------------|
| 1 | Face analysis module (skip if consent off) |
| 2 | Voice prosody features |
| 3 | VADER sentiment + stress markers |
| 4 | Late fusion → `fused` block on journal |
| 5 | Quality score for low-light/no-face |
| 6 | Congruence score (cross-modal) |
| 7 | Flutter results UI: transcript + modality cards |
| 8 | Processing step indicator in UI |
| 9 | pytest for fusion + consent skip |

---

## Exit Criteria

- [ ] Full pipeline: upload → all 3 modalities in Firestore (when consented)
- [ ] Face skipped when user opted out in onboarding
- [ ] Analysis completes in ≤ 8 min (3-min video, laptop CPU)
- [ ] User sees confidence scores on journal detail
- [ ] Second journal run succeeds back-to-back

---

## User-Facing Outcome

> "I see what AI found in my video — face, voice, and words."

---

## Next Phase

→ [Phase 5 — Baseline + Trends](./Phase-05-Baseline-Trends.md)

---

## References

- `entity/Analysis-Pipeline-Lifecycle.md` (steps 4–7)
- `modules/M3-AI-Analysis-Engine.md`
