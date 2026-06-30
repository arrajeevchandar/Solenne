# Consent & Data Lifecycle

**Owner module:** M1 creates · M5 manages  
**Collections:** `users/{uid}/consents/*` · all user data

---

## Stages

```
Stage 1         Stage 2          Stage 3          Stage 4         Stage 5
Collect    →   Active Use   →   Revoke       →   Export*     →   Erasure
(onboard)      (analysis)       (M5 settings)    (manual)        (delete)

* Automated GDPR export = post-MVP
```

---

## Stage 1 — Collect (Onboarding)

| Consent type | Required | Stored as |
|--------------|----------|-----------|
| Terms of Service | Yes | `consents/terms` + version |
| Privacy Policy | Yes | `consents/privacy` + version |
| Age 18+ | Yes | `consents/age` |
| Face analysis | Opt-in | `consents/face` |
| Voice analysis | Opt-in (default on) | `consents/voice` |
| Text/NLP analysis | Opt-in (default on) | `consents/text` |

Each record:

```javascript
{ type, granted: boolean, version: string, createdAt: timestamp }
```

---

## Stage 2 — Active Use

| Consent | Pipeline behavior |
|---------|-------------------|
| face = true | MediaPipe runs |
| face = false | Skip face; re-normalize fusion weights |
| voice = false | Skip voice (unusual; warn user) |
| text = false | Skip NLP; transcript still stored for user view only |

Worker snapshots consent at job start.

---

## Stage 3 — Revoke (M5)

| Action | Effect |
|--------|--------|
| Revoke face | Next job skips face; old journals unchanged |
| Revoke text | Next job skips NLP |
| Re-enable | Next job includes modality |

**Not in MVP:** Re-process historical entries after consent change.

---

## Stage 4 — Export (MVP: Manual)

College MVP: Firebase Console export or manual JSON dump.

Post-MVP: In-app ZIP with journals, transcripts, metrics, insights.

---

## Stage 5 — Erasure

### Delete all data
- Delete all `journals`, `insights`, `baselines`, `consents`
- Delete Storage prefix `users/{uid}/`
- Keep Auth user + minimal profile OR full account delete

### Delete account (M5)
1. Delete Storage files
2. Delete Firestore user doc + subcollections
3. Delete `analysis_jobs` for userId
4. Delete Firebase Auth user
5. Redirect to login

Order matters: Storage first (largest), Auth last.

---

## Data Inventory (Privacy Dashboard)

Show user:
- Video count + total storage
- Journal count
- Insight count
- Consent status per modality
- Account created date

---

## References

- `entity/User-Journey-Lifecycle.md` Stage 3
- `modules/M5-Trust-Launch.md`
- SAD-PRD Privacy user stories 96–110
