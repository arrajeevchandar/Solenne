# SDLC Stage 1 — Plan

**Input:** Module assignment or feature request  
**Output:** Written scope + acceptance criteria  
**Duration:** 1–4 hours per feature; 1 day per module kickoff

---

## Activities

1. Read current module doc in `modules/M{N}-*.md`
2. Read relevant product phase in `product/Phase-*.md`
3. Identify dependencies (prior module exit gates)
4. List files to create/modify (from Module Implementation Guide)
5. Define acceptance criteria (from Test Catalog P0 items)
6. Confirm out-of-scope items (post-MVP list)

---

## Checklist

- [ ] Feature/module scope is one paragraph or less
- [ ] Owner assigned (Rajeev / Shambhavi / Yanish)
- [ ] Dependencies identified and unblocked
- [ ] Acceptance criteria copied from Test Catalog
- [ ] No scope creep (AWS, paid LLM, Apple Sign-In unless explicitly in scope)

---

## Artifacts

| Artifact | Location |
|----------|----------|
| Module scope | `modules/M{N}-*.md` (already exists) |
| Task list | GitHub Issues / Linear / standup notes |
| AI prompt | Playbook §12 template |

---

## Gate to Stage 2

Team agrees: "We know exactly what we're building this week."

→ [Stage 2 — Design](./Stage-02-Design.md)
