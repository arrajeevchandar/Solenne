# Phase 2 — Record + Upload

**Weeks:** 4–6  
**Sprints:** 3–5  
**Module overlap:** M2 start (Shambhavi)  
**Milestone:** **M1 — First Upload**

---

## Objective

Core product loop: record video journal, upload to Firebase Storage, list and play back entries, streak tracking, analysis job creation.

---

## Entry Criteria

- [ ] Phase 1 exit gate passed (M1 handoff from Rajeev)
- [ ] Storage rules deployed with 100 MB limit

---

## Deliverables

| # | Deliverable |
|---|-------------|
| 1 | Camera/mic permission flow |
| 2 | Record screen: countdown, timer, 3-min auto-stop |
| 3 | Preview + re-record before upload |
| 4 | Storage upload with progress + retry |
| 5 | Journal list with thumbnails + status badges |
| 6 | Video playback from Storage |
| 7 | Delete journal (Firestore + Storage) |
| 8 | Streak counter on user doc |
| 9 | Create `analysis_jobs` doc on upload complete |
| 10 | Home stub with Record FAB |

---

## Exit Criteria

- [ ] Record → upload → journal in list with thumbnail
- [ ] Video plays back reliably
- [ ] `analysisStatus: queued` on journal doc
- [ ] `analysis_jobs` doc exists with correct `userId`
- [ ] Streak increments on consecutive calendar days (user timezone)
- [ ] Delete removes all traces

---

## User-Facing Outcome

> "I recorded my first journal and can watch it back."

---

## Next Phase

→ [Phase 3 — Worker + Transcript](./Phase-03-Worker-Transcript.md)

---

## References

- `entity/Journal-Entry-Lifecycle.md`
- `modules/M2-Video-Journal.md`
