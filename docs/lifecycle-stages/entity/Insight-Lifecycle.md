# Insight Lifecycle

**Owner module:** M3 generates · M4 displays  
**Collection:** `users/{uid}/insights/{insightId}`

---

## Stages

```
Stage 1         Stage 2          Stage 3         Stage 4
Trigger    →   Generate     →   Deliver      →   Read
(drift)        (template)       (Firestore)      (user opens)

Stage 5         Stage 6
Feedback   →   Archive/Dismiss
(optional)     (optional)
```

---

## Stage Details

| Stage | Actor | Action | Fields |
|-------|-------|--------|--------|
| **1 Trigger** | Worker | Z-score / template rules fire | — |
| **2 Generate** | Worker | Select template T1–T5; apply blocklist | `text`, `templateId`, `confidence`, `evidence` |
| **3 Deliver** | Worker | Write insight doc; optional FCM | `createdAt`, `isRead: false` |
| **4 Read** | Flutter | User opens insight | `isRead: true` |
| **5 Feedback** | Flutter | Helpful / not helpful | `helpful: bool` |
| **6 Dismiss** | Flutter | User dismisses | `dismissed: true` (optional P1) |

---

## Generation Gates

Insight **not** generated if:

- Baseline confidence < **0.6**
- Fewer than **5 entries in 7 days**
- Blocklist triggers on generated text
- Same template already sent in last **7 days** (dedupe)

---

## Template Catalog

| ID | Trigger | Example |
|----|---------|---------|
| T1 | z(valence) < -2, 3+ days | Emotional tone lower than baseline |
| T2 | z(energy) < -1.5 | Voice energy quieter than norm |
| T3 | congruence < 0.4 | Words and tone misaligned |
| T4 | z(valence) > +1.5, 5 days | Positive trend vs baseline |
| T5 | z(volatility) > 2 | More variable expression |

---

## Evidence Object

```javascript
evidence: {
  journalIds: ["id1", "id2"],
  metrics: {
    valence_z: -2.3,
    period_days: 7
  },
  templateId: "T1_valence_drop"
}
```

Flutter evidence drawer links to `journalIds`.

---

## Insight Document

```javascript
{
  text: string,
  confidence: number,      // 0-1
  evidence: object,
  templateId: string,
  isRead: boolean,
  helpful: boolean | null,
  createdAt: timestamp,
  suppressedReason: string | null
}
```

---

## Language Guardrails

- Observations, not diagnoses
- Blocklist: clinical terms (see Playbook §10.3)
- Append wellness disclaimer on display

---

## References

- `entity/Baseline-Lifecycle.md`
- `modules/M4-Dashboard-Insights.md`
