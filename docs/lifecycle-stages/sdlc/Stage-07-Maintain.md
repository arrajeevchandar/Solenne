# SDLC Stage 7 — Maintain

**Input:** Shipped module; new module active  
**Output:** Bug fixes without blocking next owner  
**Duration:** Ongoing during next module (passive ownership)

---

## Responsibilities

| Role | During next module |
|------|-------------------|
| **Previous module owner** | Answer questions ≤ 24h; fix P0 bugs in your module |
| **Current module owner** | Full focus on new module; no split ownership |
| **Other teammate** | PR review + device testing |

---

## Bug Triage

| Priority | Response | Example |
|----------|----------|---------|
| **P0** | Fix within 24h | Auth broken, upload fails for all users |
| **P1** | Fix within current sprint | Streak wrong on DST boundary |
| **P2** | Backlog / post-MVP | UI polish, nice-to-have |

---

## Rules

1. **Do not** start new features in a shipped module during MVP crunch
2. **Do** fix regressions you caused
3. **Do** update handoff doc if workaround added
4. P0 fixes go through same SDLC Stages 3–5 (abbreviated test OK)

---

## End of Maintain Stage

Maintain ends when:
- Next module ships its exit gate, OR
- Project reaches Phase 8 demo, OR
- Module owner explicitly transfers maintain to team

---

## Post-MVP

After demo, all modules enter shared maintenance until migration to production stack.

→ Back to [Stage 1 — Plan](./Stage-01-Plan.md) for post-MVP features
