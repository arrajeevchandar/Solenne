# SDLC Stage 3 — Implement

**Input:** Design approved  
**Output:** Code + unit tests  
**Duration:** Majority of module time

---

## Activities

1. Create files in order from Module Implementation Guide
2. Match conventions in Playbook §5 (repo structure)
3. Use pinned dependencies Playbook §2
4. Write unit tests alongside code (not after)
5. Open PR with focused diff — one feature per PR when possible
6. Other teammates review PRs (rotation rule: non-owner reviews)

---

## Implementation Rules

| Rule | Detail |
|------|--------|
| Minimal scope | Only files needed for this feature |
| No drive-by refactors | Don't reformat unrelated code |
| Consent-aware | Worker checks consent before face/NLP |
| Aggregates only | No per-frame arrays in Firestore |
| Error messages | User-friendly; see Edge Cases doc |

---

## Code Review Checklist

- [ ] Matches Firestore schema
- [ ] Security rules cover new paths
- [ ] No secrets committed
- [ ] Medical disclaimer preserved where required
- [ ] Analyzer clean (`flutter analyze`)

---

## Gate to Stage 4

PR ready; unit tests written; CI green on branch.

→ [Stage 4 — Test](./Stage-04-Test.md)
