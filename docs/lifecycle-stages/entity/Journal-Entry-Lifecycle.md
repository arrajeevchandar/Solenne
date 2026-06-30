# Journal Entry Lifecycle

**Owner module:** M2 (create) · M3 (analysis fields)  
**Collection:** `users/{uid}/journals/{journalId}`

---

## State Diagram

```
┌─────────────┐
│  recording  │  Local camera active (not yet in Firestore)
└──────┬──────┘
       │ user confirms upload
       ▼
┌─────────────┐
│  uploading  │  analysisStatus: uploading
└──────┬──────┘
       │ Storage putFile complete
       ▼
┌─────────────┐
│   queued    │  analysisStatus: queued · analysis_jobs created
└──────┬──────┘
       │ worker claims
       ▼
┌─────────────┐
│ processing  │  analysisStatus: processing · processingStep updates
└──────┬──────┘
       │
   ┌───┴───┐
   ▼       ▼
┌────────┐ ┌────────┐
│complete│ │ failed │
└────────┘ └────────┘
```

---

## State Table

| State | Set by | Fields | User sees |
|-------|--------|--------|-----------|
| `recording` | — (local only) | — | Camera UI |
| `uploading` | Flutter | `analysisStatus: uploading` | Progress bar |
| `queued` | Flutter | `analysisStatus: queued` | "Waiting for analysis" badge |
| `processing` | Worker | `analysisStatus: processing`, `processingStep` | Step indicator |
| `complete` | Worker | metrics nested on doc | Full results |
| `failed` | Worker / client timeout | `errorMessage` optional | Error state |

---

## Transitions

| From | To | Action |
|------|-----|--------|
| recording | uploading | User taps Upload; create journal doc |
| uploading | queued | Storage upload success; create job |
| uploading | (retry) | Network error; retry up to 3× |
| queued | processing | Worker updates job + journal |
| processing | complete | Pipeline success |
| processing | failed | Exception or timeout |
| any | deleted | User deletes; remove Storage + doc |

---

## Side Effects per Transition

| Transition | Side effects |
|------------|--------------|
| → queued | Create `analysis_jobs/{id}`; update streak |
| → complete | Worker may create insight; update baselines |
| → deleted | Remove Storage file; decrement streak if needed |

---

## Timeouts

| State | Client timeout | Action |
|-------|----------------|--------|
| uploading | 10 min | Show failed; offer retry |
| processing | 15 min | Show " taking longer than usual" |
| queued (no worker) | ∞ | Show "Start worker" hint in dev |

---

## References

- `entity/Analysis-Job-Lifecycle.md`
- `implementation-readiness/04-Edge-Cases-And-Failure-Modes.md` §3–4
