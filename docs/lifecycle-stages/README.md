# SOLENNE — Lifecycle Stages

**Version:** 1.0.0  
**Date:** June 17, 2026  
**Build path:** Flutter + Firebase Spark + Python ML worker

This folder contains **every lifecycle** for the SOLENNE college MVP — broken into individual stage documents for planning, implementation, and AI-assisted coding.

---

## Folder Structure

```
lifecycle-stages/
├── 00-Master-Lifecycle-Overview.md     ← Start here: how all lifecycles connect
├── product/                            ← 24-week product phases (0–8)
├── modules/                            ← 5 major dev modules (M1–M5)
├── sdlc/                               ← Software development stages (Plan → Maintain)
├── entity/                             ← Runtime lifecycles (user, journal, job, etc.)
└── release/                            ← Demo, integration, post-MVP
```

---

## Lifecycle Types

| # | Lifecycle | Folder | Stages | Duration |
|---|-----------|--------|--------|----------|
| 1 | **Product Development** | `product/` | Phase 0 → Phase 8 | 24 weeks |
| 2 | **Module Development** | `modules/` | M1 → M5 + Integration | ~24 weeks |
| 3 | **Software Development (SDLC)** | `sdlc/` | Plan → Maintain (7 stages) | Per feature |
| 4 | **User Journey** | `entity/User-Journey-Lifecycle.md` | 8 stages | Ongoing per user |
| 5 | **Journal Entry** | `entity/Journal-Entry-Lifecycle.md` | 7 states | Per recording |
| 6 | **Analysis Job** | `entity/Analysis-Job-Lifecycle.md` | 4 states | Per upload |
| 7 | **Analysis Pipeline** | `entity/Analysis-Pipeline-Lifecycle.md` | 9 steps | Per job |
| 8 | **Personal Baseline** | `entity/Baseline-Lifecycle.md` | 4 phases | 7–21 days |
| 9 | **Insight** | `entity/Insight-Lifecycle.md` | 6 stages | Per trigger |
| 10 | **Consent & Data** | `entity/Consent-Data-Lifecycle.md` | 5 stages | Account lifetime |
| 11 | **Release & Demo** | `release/` | 5 stages | Final 2–3 weeks |

---

## Quick Navigation

### Product Phases (Week-by-Week Roadmap)

| Phase | Document | Weeks | Milestone |
|-------|----------|-------|-----------|
| 0 | [Phase-00-Firebase-Flutter](./product/Phase-00-Firebase-Flutter.md) | 1–2 | M0 Dev Environment |
| 1 | [Phase-01-Consent-Profile](./product/Phase-01-Consent-Profile.md) | 3 | — |
| 2 | [Phase-02-Record-Upload](./product/Phase-02-Record-Upload.md) | 4–6 | M1 First Upload |
| 3 | [Phase-03-Worker-Transcript](./product/Phase-03-Worker-Transcript.md) | 7–9 | M2 partial |
| 4 | [Phase-04-Full-Analysis](./product/Phase-04-Full-Analysis.md) | 10–12 | M2 First Analysis |
| 5 | [Phase-05-Baseline-Trends](./product/Phase-05-Baseline-Trends.md) | 13–15 | M3 First Trend |
| 6 | [Phase-06-Insights-Dashboard](./product/Phase-06-Insights-Dashboard.md) | 16–18 | M4 First Insight |
| 7 | [Phase-07-FCM-Polish](./product/Phase-07-FCM-Polish.md) | 19–21 | — |
| 8 | [Phase-08-Demo-Launch](./product/Phase-08-Demo-Launch.md) | 22–24 | M5/M6 Beta Ready |

### Module Stages (Ownership Rotation)

| Module | Document | Owner | Duration |
|--------|----------|-------|----------|
| M1 | [M1-Identity-First-Run](./modules/M1-Identity-First-Run.md) | Rajeev | 4–5 wks |
| M2 | [M2-Video-Journal](./modules/M2-Video-Journal.md) | Shambhavi | 5–6 wks |
| M3 | [M3-AI-Analysis-Engine](./modules/M3-AI-Analysis-Engine.md) | Yanish | 6–7 wks |
| M4 | [M4-Dashboard-Insights](./modules/M4-Dashboard-Insights.md) | Rajeev | 4–5 wks |
| M5 | [M5-Trust-Launch](./modules/M5-Trust-Launch.md) | Shambhavi | 3–4 wks |

### SDLC Stages (Per Feature / PR)

| Stage | Document |
|-------|----------|
| 1 Plan | [Stage-01-Plan](./sdlc/Stage-01-Plan.md) |
| 2 Design | [Stage-02-Design](./sdlc/Stage-02-Design.md) |
| 3 Implement | [Stage-03-Implement](./sdlc/Stage-03-Implement.md) |
| 4 Test | [Stage-04-Test](./sdlc/Stage-04-Test.md) |
| 5 Deploy | [Stage-05-Deploy](./sdlc/Stage-05-Deploy.md) |
| 6 Handoff | [Stage-06-Handoff](./sdlc/Stage-06-Handoff.md) |
| 7 Maintain | [Stage-07-Maintain](./sdlc/Stage-07-Maintain.md) |

---

## Related Docs

| Path | Role |
|------|------|
| `docs/implementation-readiness/` | Tech stack, tests, edge cases |
| `docs/SOLENNE-Team-Work-Plan.md` | Module ownership & exit gates |
| `docs/SOLENNE-Weekly-Tracker.md` | Week-by-week status tracking |

---

*One lifecycle type per folder. One stage per file. Pick the doc that matches your current work.*
