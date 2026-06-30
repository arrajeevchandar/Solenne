# Analysis Pipeline Lifecycle

**Owner module:** M3  
**Runs inside:** `processing` job state  
**Location:** `worker/pipeline/`

---

## Pipeline Steps (Sequential)

```
Step 1        Step 2         Step 3          Step 4
Download  →  Transcode   →  Transcribe   →  Face (optional)

Step 5        Step 6         Step 7          Step 8         Step 9
Voice     →  NLP         →  Fusion       →  Baseline     →  Insights
```

---

## Step Details

| Step | `processingStep` | Input | Output | Skip if |
|------|------------------|-------|--------|---------|
| **1 Download** | `downloading` | Storage path | Local video file | — |
| **2 Transcode** | `transcoding` | Video | WAV 16kHz mono | — |
| **3 Transcribe** | `transcribing` | WAV | `transcript` on journal | — |
| **4 Face** | `face` | Video frames | `facial` block | consent.face = false |
| **5 Voice** | `voice` | WAV | `voice` block | — |
| **6 NLP** | `nlp` | transcript.text | `nlp` block | empty transcript |
| **7 Fusion** | `fusion` | modality blocks | `fused` block | ≥1 modality |
| **8 Baseline** | `baseline` | fused metrics | `baselines/{metric}` | always after fusion |
| **9 Insights** | `insights` | baseline + drift | `insights/{id}` | confidence < 0.6 |

---

## Consent Snapshot

At **Step 1 start**, worker reads latest consents:

```python
consents = get_consents(user_id)  # frozen for this job
```

Revoke during processing does not affect current job.

---

## Timing Budget (3-min video, laptop CPU)

| Step | Typical duration |
|------|------------------|
| Download | 10–30 s |
| Transcode | 5–15 s |
| Transcribe | 2–4 min |
| Face | 30–60 s |
| Voice | 10–20 s |
| NLP | < 5 s |
| Fusion + baseline + insights | < 10 s |
| **Total** | **4–8 min** |

---

## Atomic Write

All journal metric fields written in **one Firestore batch** at pipeline end (or fail entirely).

---

## Modality Weights (Fusion)

```python
MODALITY_WEIGHTS = {'face': 0.35, 'voice': 0.35, 'text': 0.30}
CONFIDENCE_THRESHOLD = 0.5
```

---

## Post-Pipeline

1. Update job → `complete`
2. Update journal → `analysisStatus: complete`
3. Send FCM (M5)
4. Log total duration

---

## References

- Playbook §8 Analysis Pipeline Specification
- `entity/Baseline-Lifecycle.md`
- `entity/Insight-Lifecycle.md`
