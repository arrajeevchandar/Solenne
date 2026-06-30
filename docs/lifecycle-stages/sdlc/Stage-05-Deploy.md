# SDLC Stage 5 — Deploy

**Input:** Tested, approved PR  
**Output:** Code on shared branch; Firebase rules live  
**Duration:** Same day as merge

---

## Activities

### Code merge
1. Merge PR to `develop` (or team-agreed main branch)
2. Verify CI green post-merge
3. Tag release notes in standup (informal for college MVP)

### Firebase deploy (when rules/schema change)
```bash
cd firebase
firebase deploy --only firestore:rules,storage,firestore:indexes
```

### Worker deploy (M3+)
- No cloud deploy — document worker version in handoff
- Teammate pulls latest + restarts worker

---

## Checklist

- [ ] PR merged
- [ ] CI green on target branch
- [ ] Firebase rules deployed if changed
- [ ] Indexes deployed if new queries added
- [ ] Teammates notified if setup steps changed

---

## Gate to Stage 6

Feature live for all team members who pull latest.

→ [Stage 6 — Handoff](./Stage-06-Handoff.md) (module end) or back to Stage 1 (next feature)
