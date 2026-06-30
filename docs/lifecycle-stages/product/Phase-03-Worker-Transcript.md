# Phase 3 — Worker + Transcript

**Weeks:** 7–9  
**Sprints:** 6–7  
**Module overlap:** M3 start (Yanish)  
**Milestone:** **M2 partial — Transcript E2E**

---

## Objective

Python worker polls Firestore jobs, downloads video, extracts audio, transcribes with faster-whisper, writes transcript to journal doc.

---

## Entry Criteria

- [ ] Phase 2 exit gate passed (M2 handoff from Shambhavi)
- [ ] `serviceAccountKey.json` on worker machine (gitignored)
- [ ] ffmpeg installed on worker host

---

## Deliverables

| # | Deliverable |
|---|-------------|
| 1 | `worker/main.py` poll loop |
| 2 | Firebase Admin SDK client |
| 3 | Job state machine: queued → processing → complete/failed |
| 4 | Video download from Storage |
| 5 | ffmpeg audio extraction |
| 6 | faster-whisper transcription |
| 7 | Transcript written to journal doc |
| 8 | Worker README in root |
| 9 | Flutter: `analysisStatus` listener on journal detail |

---

## Exit Criteria

- [ ] Upload journal → run worker → transcript appears in app (≤ 8 min for 3-min video)
- [ ] Job status transitions visible in Firestore
- [ ] Worker logs structured output per step
- [ ] Failed jobs set `status: failed` + `errorMessage`
- [ ] App updates without manual refresh

---

## User-Facing Outcome

> "After I record, I can read what I said."

---

## Next Phase

→ [Phase 4 — Full Analysis](./Phase-04-Full-Analysis.md)

---

## References

- `entity/Analysis-Job-Lifecycle.md`
- `entity/Analysis-Pipeline-Lifecycle.md` (steps 1–3)
