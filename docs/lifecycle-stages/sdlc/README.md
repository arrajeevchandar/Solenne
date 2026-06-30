# Software Development Lifecycle (SDLC)

**Applies to:** Every feature, every PR, every module subsection  
**Stages:** 7 sequential stages

| Stage | Document | Output |
|-------|----------|--------|
| **1** | [Stage-01-Plan](./Stage-01-Plan.md) | Scope + acceptance criteria |
| **2** | [Stage-02-Design](./Stage-02-Design.md) | Schema, API, UI wireflow |
| **3** | [Stage-03-Implement](./Stage-03-Implement.md) | Code + unit tests |
| **4** | [Stage-04-Test](./Stage-04-Test.md) | P0 tests pass |
| **5** | [Stage-05-Deploy](./Stage-05-Deploy.md) | Merged + Firebase rules live |
| **6** | [Stage-06-Handoff](./Stage-06-Handoff.md) | Docs updated for next owner |
| **7** | [Stage-07-Maintain](./Stage-07-Maintain.md) | Bugs tracked during next module |

## Flow

```
Plan → Design → Implement → Test → Deploy → Handoff → Maintain
         ↑__________________________|
              (iterate if test fails)
```

## Module Mapping

When building a full module (M1–M5), the module lifecycle **is** SDLC × module scope:

| Module stage | SDLC stage |
|--------------|------------|
| Plan | Stage 1 |
| Pre-dev | Stage 2 |
| Implement | Stage 3 |
| Test | Stage 4 |
| Exit gate | Stage 4 + 5 |
| Handoff | Stage 6 |
| Demo | Stage 5 verification |

## AI Session Rule

One AI session = **one SDLC cycle** for **one feature** (not an entire module unless explicitly scoped).
