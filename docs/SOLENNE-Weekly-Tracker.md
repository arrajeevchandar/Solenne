# SOLENNE — Weekly Tracker

**Version:** 1.0.0  
**Source:** `SOLENNE-Engineering-Execution-Plan.md` · `SOLENNE-Zero-Budget-Build-Plan.md`  
**Updated:** June 17, 2026

---

## How to Use

1. Set **Project Start Date** below — all week dates auto-calculate from it.
2. Each Monday: mark the active sprint, update **Status** columns, log blockers in §6.
3. Each Friday: check off **DoD** items, update milestone gates, note carry-over work.
4. Use **College path** (Flutter + Firebase) or **Paid path** (AWS microservices) — don't mix sprint rows.

**Status key:** `⬜ Not started` · `🟡 In progress` · `🟢 Done` · `🔴 Blocked` · `⏭ Skipped`

---

## Project Setup

| Field | Value |
|-------|-------|
| **Project Start Date** | _YYYY-MM-DD_ |
| **Target MVP Date** | _Start + 24 weeks_ |
| **Build Path** | ☐ College (Flutter + Firebase) · ☐ Paid (AWS) |
| **Current Week** | Week ___ of 24 |
| **Current Sprint** | Sprint ___ of 12 |
| **Team Size** | ___ FTE |

### Team Roster

| Name | Role | Primary Focus | This Week |
|------|------|---------------|-----------|
| | Flutter / FE | | |
| | Flutter / FE | | |
| | Python / ML | | |
| | UI / Design | | |
| | Firebase / FS | | |
| | PM (optional) | | |

---

## Milestone Dashboard

| ID | Milestone | Target Week | Status | Actual Date | Notes |
|----|-----------|-------------|--------|-------------|-------|
| M0 | Dev Environment (CI green, staging up) | 2 | ⬜ | | |
| M1 | First Upload (record → upload → list) | 8 | ⬜ | | |
| M2 | First Analysis (transcript + 3 modalities) | 14 | ⬜ | | |
| M3 | First Trend (7-day chart + baseline band) | 18 | ⬜ | | |
| M4 | First Insight (insight + evidence drawer) | 18 | ⬜ | | |
| M5 | Beta Ready (GDPR export/delete pass) | 22 | ⬜ | | |
| M6 | Beta Launch (100 users, SLA 95%) | 24 | ⬜ | | |

---

## 24-Week Overview

### College Path (Flutter + Firebase)

| Week | Sprint | Focus | Key Deliverable | Status |
|------|--------|-------|-----------------|--------|
| 1 | 1 | Firebase + Flutter init | Firebase project live; Flutter runs on device | ⬜ |
| 2 | 1 | Auth UI | Email login works end-to-end | ⬜ |
| 3 | 2 | Firestore models + rules | User doc schema + security rules deployed | ⬜ |
| 4 | 2 | Profile | Profile screen reads/writes Firestore | ⬜ |
| 5 | 3 | Consent onboarding | Full onboarding flow with modality consent | ⬜ |
| 6 | 3 | Onboarding polish | Baseline progress indicator stub | ⬜ |
| 7 | 4 | Camera recording | Record ≤3 min to local file | ⬜ |
| 8 | 4 | Recording UX | **M1** — record → save locally reliably | ⬜ |
| 9 | 5 | Storage upload | Upload progress UI + Firebase Storage | ⬜ |
| 10 | 5 | Journal CRUD | Journal list with thumbnails | ⬜ |
| 11 | 6 | Worker scaffold | Python worker polls jobs via Admin SDK | ⬜ |
| 12 | 6 | Job pipeline | Job created → worker logs + updates status | ⬜ |
| 13 | 7 | ffmpeg + Whisper | Transcript written to Firestore | ⬜ |
| 14 | 7 | Transcription E2E | **M2 partial** — upload → transcript in ≤5 min | ⬜ |
| 15 | 8 | Face analysis | facial_metrics on journal doc | ⬜ |
| 16 | 8 | Voice analysis | voice_metrics on journal doc | ⬜ |
| 17 | 9 | NLP + orchestration | All 3 modalities complete; **M2** | ⬜ |
| 18 | 9 | Analysis UI | User sees transcript + emotions | ⬜ |
| 19 | 10 | Fusion + baseline | baselines collection updated per user | ⬜ |
| 20 | 10 | Baseline API/UI | Baseline progress visible in app | ⬜ |
| 21 | 11 | Trends + dashboard | fl_chart 7-day view; **M3** | ⬜ |
| 22 | 11 | Insight templates | At least 1 insight with evidence; **M4** | ⬜ |
| 23 | 12 | FCM + polish | Push/in-app notifications; bug bash | ⬜ |
| 24 | 12 | Demo + launch prep | **M5/M6** — MVP demo complete | ⬜ |

### Paid Path (AWS Microservices)

| Week | Sprint | Focus | Key Deliverable | Status |
|------|--------|-------|-----------------|--------|
| 1 | 1 | Monorepo + Terraform | Repo live; staging infra scaffold | ⬜ |
| 2 | 1 | CI/CD + scaffolds | **M0** — CI green; `curl /health` → 200 | ⬜ |
| 3 | 2 | Auth service | JWT + register/login API | ⬜ |
| 4 | 2 | Auth UI + OAuth | Google OAuth; Playwright auth E2E | ⬜ |
| 5 | 3 | Journal service | Journal CRUD + streak logic | ⬜ |
| 6 | 3 | Video upload API | Presigned URL → upload → complete | ⬜ |
| 7 | 4 | Video recorder (web) | Browser recording component | ⬜ |
| 8 | 4 | Transcode pipeline | **M1** — record → upload → list + thumbnail | ⬜ |
| 9 | 5 | GPU node + Docker | GPU inference container on EKS | ⬜ |
| 10 | 5 | Whisper worker | Transcript in DB within 5 min | ⬜ |
| 11 | 6 | Face analysis | facial_metrics rows populated | ⬜ |
| 12 | 6 | Voice analysis | voice_metrics rows populated | ⬜ |
| 13 | 7 | NLP pipeline | Text analysis worker live | ⬜ |
| 14 | 7 | Orchestrator | **M2** — all 3 modalities E2E | ⬜ |
| 15 | 8 | Fusion engine | Wellness vector per entry | ⬜ |
| 16 | 8 | Baseline engine | EWMA baselines + Z-score drift | ⬜ |
| 17 | 9 | Trend API + charts | 7-day chart + baseline band; **M3** | ⬜ |
| 18 | 9 | Insight engine | Template insights + LLM guardrails; **M4** | ⬜ |
| 19 | 10 | Dashboard | Core dashboard populated | ⬜ |
| 20 | 10 | Onboarding + review | Full UX loop: onboard → record → review | ⬜ |
| 21 | 11 | Notifications | Email + in-app inbox | ⬜ |
| 22 | 11 | Privacy / GDPR | Export ZIP + delete cascade; **M5** | ⬜ |
| 23 | 12 | Hardening | Load test, WAF, observability | ⬜ |
| 24 | 12 | Beta launch | **M6** — 100 beta users invited | ⬜ |

---

## Week-by-Week Detail

Copy the active week's section into your standup notes. Check boxes as you ship.

---

### Week 1 · Sprint 1 · Foundation Start

**Dates:** _Start + 0 days → Start + 6 days_

| Owner | Task | Status |
|-------|------|--------|
| | Create Firebase project (Spark) OR Terraform staging | ⬜ |
| | Init Flutter app (`mobile/`) OR monorepo scaffold | ⬜ |
| | Configure auth (Email + Google) OR EKS + RDS | ⬜ |
| | README + onboarding doc for team | ⬜ |
| | First PR merged; CI pipeline green | ⬜ |

**DoD:** Dev environment runs locally for all team members.

**Blockers:**

---

### Week 2 · Sprint 1 · Foundation Complete

**Dates:** _Start + 7 days → Start + 13 days_

| Owner | Task | Status |
|-------|------|--------|
| | Auth UI: login + register screens | ⬜ |
| | Firestore rules draft OR service hello-world endpoints | ⬜ |
| | Deploy rules / staging URL verified | ⬜ |
| | Designer: auth screen mockups approved | ⬜ |

**DoD:** **M0** — Engineer can clone, run, and hit health/auth on device/staging.

**Blockers:**

---

### Week 3 · Sprint 2 · Data Models

**Dates:** _Start + 14 days → Start + 20 days_

| Owner | Task | Status |
|-------|------|--------|
| | User profile schema (Firestore doc OR migration 001–003) | ⬜ |
| | Consent model (modality flags, version) | ⬜ |
| | Security rules / auth middleware enforced | ⬜ |
| | Profile UI stub | ⬜ |

**DoD:** User can register and profile persists.

**Blockers:**

---

### Week 4 · Sprint 2 · Profile + Consent API

**Dates:** _Start + 21 days → Start + 27 days_

| Owner | Task | Status |
|-------|------|--------|
| | Profile edit screen | ⬜ |
| | Consent API / Firestore fields | ⬜ |
| | Timezone + wellness goals fields | ⬜ |
| | Unit tests ≥80% on auth/profile path | ⬜ |

**DoD:** Playwright/integration: register → login → update profile.

**Blockers:**

---

### Week 5 · Sprint 3 · Onboarding

**Dates:** _Start + 28 days → Start + 34 days_

| Owner | Task | Status |
|-------|------|--------|
| | Onboarding wizard (3–5 steps) | ⬜ |
| | Modality consent UI (face/voice/text) | ⬜ |
| | Skip / defer logic for optional steps | ⬜ |
| | Designer: onboarding flow signed off | ⬜ |

**DoD:** New user completes onboarding with consent recorded.

**Blockers:**

---

### Week 6 · Sprint 3 · Onboarding Polish

**Dates:** _Start + 35 days → Start + 41 days_

| Owner | Task | Status |
|-------|------|--------|
| | Baseline progress indicator (0 entries state) | ⬜ |
| | Tutorial / first-journal CTA | ⬜ |
| | Error states + empty states | ⬜ |
| | Analytics event: onboarding_complete | ⬜ |

**DoD:** Activation funnel: onboard → land on journal home.

**Blockers:**

---

### Week 7 · Sprint 4 · Recording

**Dates:** _Start + 42 days → Start + 48 days_

| Owner | Task | Status |
|-------|------|--------|
| | Camera/mic permissions flow | ⬜ |
| | Record ≤3 min (Flutter) OR MediaRecorder (web) | ⬜ |
| | Local preview before upload | ⬜ |
| | 3-min cap enforced | ⬜ |

**DoD:** Record video locally without crash on target device/browser.

**Blockers:**

---

### Week 8 · Sprint 4 · First Upload · GATE 1

**Dates:** _Start + 49 days → Start + 55 days_

| Owner | Task | Status |
|-------|------|--------|
| | Upload to Storage / S3 with progress | ⬜ |
| | Transcode OR compress before upload | ⬜ |
| | Journal list with thumbnail | ⬜ |
| | Playback works | ⬜ |

**DoD:** **M1** — Record → upload → see in list → play back.

### Gate 1 Checklist

- [ ] Upload success rate >99% in staging
- [ ] Transcode/compress completes <3 min for 3-min video
- [ ] No P0/P1 bugs in recording flow

**Blockers:**

---

### Week 9 · Sprint 5 · Upload Pipeline

**Dates:** _Start + 56 days → Start + 62 days_

| Owner | Task | Status |
|-------|------|--------|
| | Journal CRUD complete (edit, delete, soft delete) | ⬜ |
| | Streak calculation | ⬜ |
| | Upload retry + error handling | ⬜ |
| | Storage lifecycle / quota rules | ⬜ |

**DoD:** Journal list paginated; delete removes entry from UI.

**Blockers:**

---

### Week 10 · Sprint 5 · GPU / Worker Setup

**Dates:** _Start + 63 days → Start + 69 days_

| Owner | Task | Status |
|-------|------|--------|
| | Python worker scaffold + Admin SDK OR GPU node on EKS | ⬜ |
| | Job queue: journal upload triggers analysis job | ⬜ |
| | Worker health check + logging | ⬜ |
| | Analysis status field on journal doc | ⬜ |

**DoD:** Upload triggers job; worker picks up and logs.

**Blockers:**

---

### Week 11 · Sprint 6 · Worker Integration

**Dates:** _Start + 70 days → Start + 76 days_

| Owner | Task | Status |
|-------|------|--------|
| | ffmpeg audio extraction | ⬜ |
| | Job state machine (queued → processing → done/failed) | ⬜ |
| | Frontend polling / Firestore listener for status | ⬜ |
| | Failed job retry policy | ⬜ |

**DoD:** Job lifecycle visible to user (spinner → complete).

**Blockers:**

---

### Week 12 · Sprint 6 · Transcription

**Dates:** _Start + 77 days → Start + 83 days_

| Owner | Task | Status |
|-------|------|--------|
| | Whisper (faster-whisper) integrated | ⬜ |
| | Transcript stored on journal doc / DB | ⬜ |
| | Timeout handling for long videos | ⬜ |
| | Manual test with 3 sample videos | ⬜ |

**DoD:** Upload → transcript appears within 5 min.

**Blockers:**

---

### Week 13 · Sprint 7 · Face Analysis

**Dates:** _Start + 84 days → Start + 90 days_

| Owner | Task | Status |
|-------|------|--------|
| | MediaPipe / FER pipeline | ⬜ |
| | Consent opt-out skips face modality | ⬜ |
| | Confidence scores on outputs | ⬜ |
| | Quality score for poor lighting | ⬜ |

**DoD:** facial_metrics populated for test videos.

**Blockers:**

---

### Week 14 · Sprint 7 · Voice + NLP · GATE 2

**Dates:** _Start + 91 days → Start + 97 days_

| Owner | Task | Status |
|-------|------|--------|
| | Voice prosody extraction (Parselmouth / librosa) | ⬜ |
| | NLP: sentiment, stress markers, topics | ⬜ |
| | Orchestrator runs all 3 modalities in parallel | ⬜ |
| | Basic analysis results screen | ⬜ |

**DoD:** **M2** — Upload → transcript + face + voice + text complete.

### Gate 2 Checklist

- [ ] Analysis SLA <5 min for 95% of entries
- [ ] Consent opt-out verified for face modality
- [ ] Model outputs include confidence scores

**Blockers:**

---

### Week 15 · Sprint 8 · Fusion

**Dates:** _Start + 98 days → Start + 104 days_

| Owner | Task | Status |
|-------|------|--------|
| | Multimodal fusion weights implemented | ⬜ |
| | Missing modality handling | ⬜ |
| | wellness_vector schema persisted | ⬜ |
| | Unit tests on fusion fixtures | ⬜ |

**DoD:** Each journal entry has unified wellness vector.

**Blockers:**

---

### Week 16 · Sprint 8 · Baseline

**Dates:** _Start + 105 days → Start + 111 days_

| Owner | Task | Status |
|-------|------|--------|
| | EWMA baseline per metric | ⬜ |
| | Z-score drift detection | ⬜ |
| | Null baseline handling (first entry) | ⬜ |
| | Baseline confidence score | ⬜ |

**DoD:** Baseline updates on 2nd+ entry; confidence shown.

**Blockers:**

---

### Week 17 · Sprint 9 · Trends

**Dates:** _Start + 112 days → Start + 118 days_

| Owner | Task | Status |
|-------|------|--------|
| | 7-day trend API / Firestore query | ⬜ |
| | fl_chart / Recharts trend visualization | ⬜ |
| | Baseline band overlay on chart | ⬜ |
| | Seed 7 days demo data for testing | ⬜ |

**DoD:** **M3** — User with 7 entries sees trend chart.

**Blockers:**

---

### Week 18 · Sprint 9 · Insights · GATE 3

**Dates:** _Start + 119 days → Start + 125 days_

| Owner | Task | Status |
|-------|------|--------|
| | 5 insight templates implemented | ⬜ |
| | LLM phrasing + blocklist (or template-only) | ⬜ |
| | Evidence drawer links to source journals | ⬜ |
| | Suppress insights when baseline confidence <0.6 | ⬜ |

**DoD:** **M4** — At least 1 insight with evidence drawer.

### Gate 3 Checklist

- [ ] Insights suppressed when baseline confidence <0.6
- [ ] Zero clinical terms in 100-insight sample
- [ ] Evidence drawer links to source journals

**Blockers:**

---

### Week 19 · Sprint 10 · Dashboard

**Dates:** _Start + 126 days → Start + 132 days_

| Owner | Task | Status |
|-------|------|--------|
| | Dashboard home screen | ⬜ |
| | Recent journals + streak widget | ⬜ |
| | Insight center entry point | ⬜ |
| | Calendar heatmap (optional) | ⬜ |

**DoD:** Dashboard shows last journal, streak, and top insight.

**Blockers:**

---

### Week 20 · Sprint 10 · Video Review + Settings

**Dates:** _Start + 133 days → Start + 139 days_

| Owner | Task | Status |
|-------|------|--------|
| | Video review with emotion overlay | ⬜ |
| | Timeline / journal detail page | ⬜ |
| | Settings screen (notifications, consent, account) | ⬜ |
| | Full new-user journey E2E test | ⬜ |

**DoD:** Onboard → record → dashboard → review video with overlay.

**Blockers:**

---

### Week 21 · Sprint 11 · Notifications

**Dates:** _Start + 140 days → Start + 146 days_

| Owner | Task | Status |
|-------|------|--------|
| | FCM push OR email (SES) + in-app inbox | ⬜ |
| | Analysis-complete notification | ⬜ |
| | Journaling reminder (optional schedule) | ⬜ |
| | Quiet hours / preference schema | ⬜ |

**DoD:** User receives notification when analysis completes.

**Blockers:**

---

### Week 22 · Sprint 11 · Privacy · GATE 4

**Dates:** _Start + 147 days → Start + 153 days_

| Owner | Task | Status |
|-------|------|--------|
| | Data export (ZIP with all user data) | ⬜ |
| | Account deletion cascade (DB + Storage/S3) | ⬜ |
| | Privacy dashboard UI | ⬜ |
| | Medical disclaimer on insight screens | ⬜ |

**DoD:** **M5** — Export verified; delete removes all user data.

### Gate 4 Checklist

- [ ] GDPR export E2E pass
- [ ] Delete cascade verified (DB + Storage/S3)
- [ ] Privacy Policy + ToS published
- [ ] Pen test: no critical findings
- [ ] Medical disclaimer on all insight screens

**Blockers:**

---

### Week 23 · Sprint 12 · Hardening

**Dates:** _Start + 154 days → Start + 160 days_

| Owner | Task | Status |
|-------|------|--------|
| | Bug bash — all P0/P1 fixed | ⬜ |
| | Load test OR manual stress test | ⬜ |
| | Crashlytics / error monitoring live | ⬜ |
| | Demo accounts with 7+ seeded entries | ⬜ |

**DoD:** No open P0 bugs; demo flow rehearsed.

**Blockers:**

---

### Week 24 · Sprint 12 · Launch · GATE 5

**Dates:** _Start + 161 days → Start + 167 days_

| Owner | Task | Status |
|-------|------|--------|
| | Beta invites sent (target: 100 users) | ⬜ |
| | Backup screen recording of full flow | ⬜ |
| | On-call / incident runbook | ⬜ |
| | Demo day slides + disclaimer | ⬜ |

**DoD:** **M6** — Beta live; monitoring alerts configured.

### Gate 5 Checklist

- [ ] Load test 2× expected beta traffic
- [ ] Monitoring dashboards + alerts live
- [ ] On-call runbook for top 5 incidents
- [ ] Rollback tested
- [ ] 100 beta users onboarded (or demo-ready for college)
- [ ] Legal sign-off on user-facing copy

**Blockers:**

---

## Weekly Log

Use one row per week. Archive older rows as the project progresses.

| Week | Dates | Shipped | Carried Over | Blockers | Morale (1–5) |
|------|-------|---------|--------------|----------|--------------|
| 1 | | | | | |
| 2 | | | | | |
| 3 | | | | | |
| 4 | | | | | |

---

## Blockers & Risks (Live)

| # | Item | Impact | Owner | Mitigation | Status |
|---|------|--------|-------|------------|--------|
| 1 | GPU / Whisper latency | SLA miss | ML | Use medium model; 3-min cap | ⬜ |
| 2 | Scope creep (web, billing) | MVP delay | PM | Flutter+Firebase only | ⬜ |
| 3 | GDPR delete incomplete | Compliance | BE/FS | Deletion test suite | ⬜ |
| 4 | LLM clinical language | Legal | ML | Blocklist + templates | ⬜ |
| 5 | | | | | |

---

## Sprint Ceremonies Checklist

| Ceremony | When | Last Done | Notes |
|----------|------|-----------|-------|
| Sprint Planning | Monday W1 of sprint | | |
| Daily Standup | Daily 15 min | | |
| Sprint Demo | Friday W2 of sprint | | |
| Retrospective | Friday W2 of sprint | | |
| TDD Review (pre-sprint) | Before coding epic | | See Execution Plan §9 |

---

## Quick Links

| Doc | Purpose |
|-----|---------|
| `SOLENNE-Engineering-Execution-Plan.md` | Full sprint plan, epics, gates |
| `SOLENNE-Zero-Budget-Build-Plan.md` | College stack, Firebase checklist |
| `SOLENNE-SAD-PRD.md` | Product requirements |
| `SOLENNE-Executive-Summary.md` | Stakeholder overview |

---

*Update this file every Friday. Keep `Status` honest — blocked weeks are data, not failure.*
