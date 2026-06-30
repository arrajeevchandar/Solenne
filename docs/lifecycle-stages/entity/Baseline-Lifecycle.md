# Personal Baseline Lifecycle

**Owner module:** M3 writes · M4 displays  
**Collection:** `users/{uid}/baselines/{metricName}`

---

## Phases

```
Phase 1          Phase 2           Phase 3            Phase 4
Init         →  Building       →  Approaching     →  Mature
(entry 1)        (2–6 entries)     (5 in 7 days)      (14–21 days)
```

---

## Phase Details

| Phase | Entries | Confidence range | Insight behavior | UI |
|-------|---------|------------------|------------------|-----|
| **Init** | 1 | 0.0 – 0.15 | No insights | "Building your baseline" |
| **Building** | 2–4 | 0.15 – 0.4 | Suppressed | "X/7 entries" |
| **Approaching** | 5+ in 7 days | 0.4 – 0.6 | Limited templates | Progress bar ~70% |
| **Mature** | 14–21 days consistent | 0.6 – 1.0 | Full insights | Band on chart |

---

## Confidence Formula

```
confidence = min(1.0, (n / 21) * consistency_factor * quality_factor)

consistency_factor = entries_last_14_days / 14  (cap 1.0)
quality_factor = mean(recording_quality_scores)
```

Display: *"Baseline 67% established (10 of 14 days)"*

---

## EWMA Parameters

| Parameter | Days 1–21 | After day 21 |
|-----------|-----------|--------------|
| α (alpha) | 0.10 | 0.05 |

```
μ_t = α * x_t + (1 - α) * μ_{t-1}
σ_t = sqrt(α * (x_t - μ_t)² + (1 - α) * σ_{t-1}²)
```

---

## Metrics Tracked

| metricName | Source |
|------------|--------|
| `overall_valence` | fused.overallValence |
| `overall_arousal` | fused.overallArousal |
| `voice_energy` | voice.energyMean |
| `speaking_rate` | voice.speakingRate |
| `sentiment` | nlp.sentimentValence |
| `engagement` | fused.engagement |
| `volatility` | fused.volatility |

---

## Drift Detection (MVP: Z-score only)

| Signal | Threshold | Template |
|--------|-----------|----------|
| Valence drop | z < -2 for 3+ days | T1 |
| Energy drop | z < -1.5 | T2 |
| High volatility | z > 2 | T5 |

---

## Lifecycle Events

| Event | Action |
|-------|--------|
| First analysis complete | Create baseline docs (n=1) |
| Each subsequent journal | EWMA update |
| User deletes all journals | Delete baseline docs (M5) |
| User deletes account | Cascade delete baselines |

---

## References

- SAD-PRD §7 Personal Baseline Engine
- `entity/Insight-Lifecycle.md`
