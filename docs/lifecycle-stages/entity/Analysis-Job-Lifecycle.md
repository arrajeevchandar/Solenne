# Analysis Job Lifecycle

**Owner module:** M2 creates · M3 processes  
**Collection:** `analysis_jobs/{jobId}`

---

## State Diagram

```
         Flutter creates
              │
              ▼
        ┌──────────┐
        │  queued  │
        └────┬─────┘
             │ worker claim (transaction or status check)
             ▼
        ┌──────────┐
        │processing│
        └────┬─────┘
             │
      ┌──────┴──────┐
      ▼             ▼
┌──────────┐  ┌──────────┐
│ complete │  │  failed  │
└──────────┘  └────┬─────┘
                   │ retryCount < 3
                   └──► queued (optional requeue)
```

---

## State Table

| State | Set by | Writable by |
|-------|--------|-------------|
| `queued` | Flutter (on upload complete) | Client create only |
| `processing` | Worker | Admin SDK only |
| `complete` | Worker | Admin SDK only |
| `failed` | Worker | Admin SDK only |

**Security:** Clients cannot update job status (Firestore rules).

---

## Job Document Fields

```javascript
{
  userId: string,
  journalId: string,
  status: "queued" | "processing" | "complete" | "failed",
  processingStep: string | null,  // mirror for UI
  createdAt: timestamp,
  startedAt: timestamp | null,
  completedAt: timestamp | null,
  errorMessage: string | null,
  retryCount: number  // default 0
}
```

---

## Worker Claim Logic

```python
# Pseudocode — prevent double processing in MVP (single worker)
job_ref.update({"status": "processing", "startedAt": SERVER_TIMESTAMP})
```

For multi-worker future: use Firestore transaction compare-and-set on `status == queued`.

---

## Failure & Retry

| Condition | Action |
|-----------|--------|
| Download fail | failed; retryCount++ |
| ffmpeg fail | failed |
| Whisper OOM | failed; log suggest int8 |
| Partial pipeline | failed; do not write partial metrics (atomic batch) |
| retryCount >= 3 | failed permanent; user sees failed in app |

---

## Stale Job Recovery

If `processing` for > 30 minutes:

1. Manual: set `status: queued` via Admin script, OR
2. Worker reaper (optional): auto-fail with message "Worker interrupted"

---

## References

- `entity/Analysis-Pipeline-Lifecycle.md`
- `modules/M3-AI-Analysis-Engine.md`
