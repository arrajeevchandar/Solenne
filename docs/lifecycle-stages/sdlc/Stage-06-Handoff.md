# SDLC Stage 6 — Handoff

**Input:** Module exit gate passed  
**Output:** `docs/handoffs/M{N}.md` + 15-min demo  
**Duration:** 0.5–1 day at module end

---

## When Required

- End of each module M1–M5
- Optional: major schema changes mid-module

---

## Handoff Document Template

Create `docs/handoffs/M{N}.md`:

```markdown
# Handoff — Module M{N}: {Name}

**Owner:** {name}  
**Date:** YYYY-MM-DD  
**Next owner:** {name}

## What Shipped
- Bullet list of features

## How to Run
- Commands, env vars, Firebase project

## Firestore Schema Changes
- Collections/fields added or changed

## Known Bugs (P1/P2)
- Issue + workaround

## Demo Script (2 min)
- Steps to verify core flow

## Questions for Next Owner
- Open decisions
```

---

## Handoff Meeting (15 min)

1. Demo exit gate checklist live (5 min)
2. Walk through handoff doc (5 min)
3. Q&A; next owner confirms unblocked (5 min)

---

## Team Handoff Checklist

- [ ] All exit gate items checked
- [ ] PR merged to shared branch
- [ ] `docs/handoffs/M{N}.md` written
- [ ] README updated if setup changed
- [ ] 15-min demo completed
- [ ] Next owner runs app independently within 24h

---

## Gate to Stage 7 / Next Module

Next owner confirms: "I can start M{N+1} without asking you."

→ [Stage 7 — Maintain](./Stage-07-Maintain.md) (previous module)  
→ [Stage 1 — Plan](./Stage-01-Plan.md) (next module owner)
