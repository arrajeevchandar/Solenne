# SOLENNE — Implementation Readiness

**Purpose:** Zero-friction starting point for AI-assisted implementation. Read this folder before writing any code.

| Document | Use When |
|----------|----------|
| **[SOLENNE-Implementation-Playbook.md](./SOLENNE-Implementation-Playbook.md)** | Primary reference — tech stack, requirements, lifecycle, edge cases, tests, versions, module prompts |
| **[01-Environment-Setup.md](./01-Environment-Setup.md)** | Day 0 — install tools, Firebase project, clone/run checklist |
| **[02-Module-Implementation-Guide.md](./02-Module-Implementation-Guide.md)** | Module-by-module build order (M1→M5), files to create, exit gates |
| **[03-Test-Catalog.md](./03-Test-Catalog.md)** | All test cases — unit, integration, E2E, manual QA |
| **[04-Edge-Cases-And-Failure-Modes.md](./04-Edge-Cases-And-Failure-Modes.md)** | Edge cases, error handling, recovery patterns |

## Source Documents (parent `docs/` folder)

| Document | Role |
|----------|------|
| `lifecycle-stages/` | **All lifecycle stages** — product phases, modules, SDLC, entity states, release |
| `SOLENNE-SAD-PRD.md` | Product + architecture source of truth (production target) |
| `SOLENNE-Zero-Budget-Build-Plan.md` | **Active build path** — Flutter + Firebase + Python worker |
| `SOLENNE-Team-Work-Plan.md` | 3-person rotation, 5 major modules |
| `SOLENNE-Engineering-Execution-Plan.md` | Detailed sub-modules, epics, paid AWS path |
| `SOLENNE-Weekly-Tracker.md` | Week-by-week status tracking |

## Build Path (Locked for MVP)

**College / $0 path:** Flutter mobile + Firebase Spark + local Python ML worker.

Do **not** mix AWS microservices items into MVP sprints unless migrating later.

## Quick Start for AI Sessions

1. Read **Playbook §1–3** (stack + requirements + repo structure).
2. Confirm current module from `SOLENNE-Team-Work-Plan.md` (M1→M5).
3. Open **02-Module-Implementation-Guide.md** for that module only.
4. Run **01-Environment-Setup.md** checklist if env is not verified.
5. Implement; validate against **03-Test-Catalog.md** for the module.
6. Check **04-Edge-Cases-And-Failure-Modes.md** before marking done.

---

*Version 1.0.0 · June 17, 2026*
