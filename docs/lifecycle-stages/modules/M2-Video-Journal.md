# Module M2 — Video Journal

**Owner:** Shambhavi (Turn 2)  
**Duration:** 5–6 weeks  
**Product phases:** 2  
**Depends on:** M1 exit gate

---

## One-Line Summary

The core product loop — record a video journal, upload it, see it in history, play it back.

---

## Module Lifecycle Stages

| Stage | Activities | Gate |
|-------|------------|------|
| **1. Plan** | Read M1 handoff; confirm Storage paths + auth still works | Handoff reviewed |
| **2. Pre-dev** | Verify camera permissions on target devices; Storage rules tested | Device test OK |
| **3. Implement** | Module Guide § M2 Steps 1–4 | PRs merged |
| **4. Test** | Test Catalog § M2 | All P0 pass |
| **5. Exit Gate** | Checklist below | All boxes ✓ |
| **6. Handoff** | `docs/handoffs/M2.md` + demo record→upload→list | Yanish unblocked |
| **7. Demo** | Live recording on device | — |

---

## Scope

| Area | Features |
|------|----------|
| Recording | Permissions, preview, countdown, timer, 3-min auto-stop, re-record |
| Upload | Storage upload, progress, retry, journal doc creation |
| Jobs | Create `analysis_jobs` on upload complete; `analysisStatus: queued` |
| List | Paginated history, thumbnails, status badges |
| Streaks | Consecutive-day counter (user timezone) |
| Playback | video_player from Storage |
| Detail | Metadata, delete (Firestore + Storage) |
| Home | Stub dashboard with Record FAB |

---

## Exit Gate

- [ ] Record → upload → journal appears in list with thumbnail
- [ ] Video plays back from Storage
- [ ] Delete removes entry from list and Storage
- [ ] `analysis_jobs` doc created on successful upload
- [ ] Streak updates correctly

---

## Handoff to M3 (Yanish)

Must document:
- Storage path: `users/{uid}/videos/{journalId}/video.mp4`
- Journal + job field schemas
- Sample video for worker testing
- Upload retry behavior

---

## References

- `entity/Journal-Entry-Lifecycle.md`
- `product/Phase-02-Record-Upload.md`
