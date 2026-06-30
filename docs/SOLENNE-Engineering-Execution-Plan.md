# SOLENNE — Engineering Execution Plan

**Version:** 1.0.0  
**Date:** June 13, 2026  
**Source of Truth:** `SOLENNE-SAD-PRD.md` v1.0.0  
**Owner:** Technical Program Manager + Engineering Lead  
**Purpose:** Convert approved architecture into an executable build plan for a startup team

> **$0 college budget (Flutter + Firebase)?** Use **`SOLENNE-Zero-Budget-Build-Plan.md`** — mobile app on Firebase Spark (free) + local Python ML worker. This document describes the **paid AWS / microservices** path for when you have funding. Map Flutter features to the same epics/modules below; replace Next.js/web items with Flutter screens and Firestore with PostgreSQL when reading tables.

---

## How to Use This Document

| Document | Section | Use When |
|----------|---------|----------|
| PBS | §1 | Prioritizing products, staffing, roadmap communication |
| Module Breakdown | §2 | Sprint planning, ownership assignment, API contracts |
| Phase Plan | §3 | Milestone gates, dependency management |
| MVP Definition | §4 | Scope control, saying no |
| Engineering Epics | §5 | Jira/Linear backlog creation |
| Feature Order | §6 | Sequencing work, unblocking teammates |
| Sprint Plan | §7 | Weekly execution (12 sprints → MVP) |
| Dev Checklists | §8 | Module kickoff and ship gates |
| TDD Index | §9 | Pre-coding design reviews |
| Repo Roadmap | §10 | File/service creation order |
| Master Plan | §11 | Executive summary, gates, allocation |

**Team assumption for sprint plan (paid path):** 2 BE, 2 FE, 1 AI, 1 FS, 1 DevOps, 1 Designer (8 FTE).

**College team (Flutter + Firebase):** 2 Flutter, 1 Python/ML, 1 UI/design, 1 FS (Firebase rules + worker), 1 PM — see **`SOLENNE-Zero-Budget-Build-Plan.md`** § Sprint Plan. No DevOps role; Firebase Console replaces infra sprints.

---

# DOCUMENT 1: PRODUCT BREAKDOWN STRUCTURE (PBS)

```
SOLENNE
├── P1  Authentication & Identity System
├── P2  User Profile & Consent System
├── P3  Video Journal System
├── P4  Video Processing Pipeline
├── P5  AI Analysis System
├── P6  Multimodal Fusion Engine
├── P7  Personal Baseline Engine
├── P8  Insight Generation Engine
├── P9  Dashboard & Timeline (Web UI)
├── P10 Notification System
├── P11 Privacy & Data Rights System
├── P12 Settings & Onboarding UX
├── P13 Admin & Support System
├── P14 Analytics Platform
├── P15 Recommendation System
└── P16 Platform Infrastructure
```

## P1 — Authentication & Identity System

| Attribute | Value |
|-----------|-------|
| **Purpose** | Secure account creation, login, session management, OAuth, MFA |
| **Business Value** | Trust foundation for sensitive wellness data; enables retention via low-friction OAuth |
| **Dependencies** | P16 (Infrastructure), legal ToS/Privacy Policy |
| **Complexity** | Medium |
| **Priority** | P0 — Must ship first |
| **Estimated Effort** | 4 engineer-weeks |

## P2 — User Profile & Consent System

| Attribute | Value |
|-----------|-------|
| **Purpose** | Profiles, preferences, granular modality consent, wellness goals, timezone |
| **Business Value** | GDPR-compliant consent; personalization input; regulatory defensibility |
| **Dependencies** | P1 |
| **Complexity** | Medium |
| **Priority** | P0 |
| **Estimated Effort** | 3 engineer-weeks |

## P3 — Video Journal System

| Attribute | Value |
|-----------|-------|
| **Purpose** | Record, upload, list, review, delete daily video/audio journals |
| **Business Value** | Core product loop — without this, nothing else matters |
| **Dependencies** | P1, P2, P16 |
| **Complexity** | High |
| **Priority** | P0 |
| **Estimated Effort** | 8 engineer-weeks |

## P4 — Video Processing Pipeline

| Attribute | Value |
|-----------|-------|
| **Purpose** | Validate, transcode, extract audio, thumbnail, queue for AI |
| **Business Value** | Enables playback and downstream AI; SLA-critical path |
| **Dependencies** | P3, P16 (S3, MediaConvert, Kafka) |
| **Complexity** | High |
| **Priority** | P0 |
| **Estimated Effort** | 6 engineer-weeks |

## P5 — AI Analysis System

| Attribute | Value |
|-----------|-------|
| **Purpose** | Face, voice, NLP inference (Whisper, MediaPipe, prosody) |
| **Business Value** | Core differentiation — passive emotional signal extraction |
| **Dependencies** | P4, P16 (GPU/EKS) |
| **Complexity** | Very High |
| **Priority** | P0 |
| **Estimated Effort** | 12 engineer-weeks |

## P6 — Multimodal Fusion Engine

| Attribute | Value |
|-----------|-------|
| **Purpose** | Combine face/voice/text into wellness vector + interpretable composites |
| **Business Value** | Unified emotional fingerprint per journal entry |
| **Dependencies** | P5 |
| **Complexity** | High |
| **Priority** | P0 |
| **Estimated Effort** | 4 engineer-weeks |

## P7 — Personal Baseline Engine

| Attribute | Value |
|-----------|-------|
| **Purpose** | EWMA baselines, Z-score drift, behavioral event detection |
| **Business Value** | Personalized (not population-norm) insights — key moat |
| **Dependencies** | P6 |
| **Complexity** | High |
| **Priority** | P0 |
| **Estimated Effort** | 5 engineer-weeks |

## P8 — Insight Generation Engine

| Attribute | Value |
|-----------|-------|
| **Purpose** | Rule-based triggers + LLM phrasing + guardrails + evidence |
| **Business Value** | User-facing value delivery; drives engagement and retention |
| **Dependencies** | P7 |
| **Complexity** | High |
| **Priority** | P0 |
| **Estimated Effort** | 5 engineer-weeks |

## P9 — Dashboard & Timeline (Flutter Mobile UI)

| Attribute | Value |
|-----------|-------|
| **Purpose** | Dashboard, journal review, trends, insight center, calendar heatmap — **Flutter screens** |
| **Business Value** | Primary user experience; visualizes all backend value |
| **Dependencies** | P3, P5, P7, P8, Firebase Auth/Firestore (college) or REST API (paid) |
| **Complexity** | High |
| **Priority** | P0 |
| **Estimated Effort** | 10 engineer-weeks |
| **College stack** | `fl_chart`, Firestore snapshots, `go_router`, Riverpod |

## P10 — Notification System

| Attribute | Value |
|-----------|-------|
| **Purpose** | Push, email, in-app notifications; reminders; analysis-complete alerts |
| **Business Value** | Habit formation (journaling consistency); re-engagement |
| **Dependencies** | P1, P3, P8 |
| **Complexity** | Medium |
| **Priority** | P1 — MVP includes email + in-app; push post-MVP |
| **Estimated Effort** | 4 engineer-weeks |

## P11 — Privacy & Data Rights System

| Attribute | Value |
|-----------|-------|
| **Purpose** | Export, deletion, consent dashboard, audit visibility |
| **Business Value** | Legal compliance; user trust; beta launch gate |
| **Dependencies** | All data products (P2–P8) |
| **Complexity** | Medium |
| **Priority** | P0 for beta gate |
| **Estimated Effort** | 4 engineer-weeks |

## P12 — Settings & Onboarding UX

| Attribute | Value |
|-----------|-------|
| **Purpose** | Onboarding flow, settings, tutorial, baseline progress indicator |
| **Business Value** | Activation rate; consent completion; time-to-first-journal |
| **Dependencies** | P1, P2, P9 |
| **Complexity** | Medium |
| **Priority** | P0 |
| **Estimated Effort** | 4 engineer-weeks |

## P13 — Admin & Support System

| Attribute | Value |
|-----------|-------|
| **Purpose** | Internal user lookup, audit logs, feature flags, model version mgmt |
| **Business Value** | Operational support; not needed for MVP beta |
| **Dependencies** | P1, all services |
| **Complexity** | Medium |
| **Priority** | P2 — Post-MVP |
| **Estimated Effort** | 4 engineer-weeks |

## P14 — Analytics Platform

| Attribute | Value |
|-----------|-------|
| **Purpose** | Product analytics, funnels, anonymized event pipeline |
| **Business Value** | Measure DAU, retention, insight engagement |
| **Dependencies** | P16, frontend instrumentation |
| **Complexity** | Medium |
| **Priority** | P1 — Basic events at MVP; Snowflake post-MVP |
| **Estimated Effort** | 3 engineer-weeks (MVP scope) |

## P15 — Recommendation System

| Attribute | Value |
|-----------|-------|
| **Purpose** | Journal prompts, reminder timing, reflection questions |
| **Business Value** | Engagement lift; reduces blank-page friction |
| **Dependencies** | P7, P3 |
| **Complexity** | Low–Medium |
| **Priority** | P2 — Static prompts at MVP |
| **Estimated Effort** | 2 engineer-weeks |

## P16 — Platform Infrastructure

| Attribute | Value |
|-----------|-------|
| **Purpose** | EKS, RDS, S3, Kafka, CI/CD, Terraform, observability |
| **Business Value** | Everything runs on this; non-negotiable Day 1 |
| **Dependencies** | AWS account, domain, GitHub org |
| **Complexity** | High |
| **Priority** | P0 — Phase 0 |
| **Estimated Effort** | 8 engineer-weeks (ongoing) |

**Total MVP-scope effort (P0 products):** ~70 engineer-weeks → ~12 calendar weeks with 8 FTE (accounting for parallelization and overhead).

---

# DOCUMENT 2: MODULE BREAKDOWN DOCUMENT

## P1 — Authentication & Identity System

### M1.1 — Registration Module

| Field | Detail |
|-------|--------|
| **Description** | Email/password account creation with validation |
| **Responsibilities** | Validate input, hash password (argon2), create user record, issue tokens |
| **Inputs** | `{ email, password, display_name, timezone, consent }` |
| **Outputs** | `{ user_id, access_token, refresh_token }` |
| **Internal Components** | Validator, PasswordHasher, TokenIssuer, UserRepository |
| **APIs Consumed** | — |
| **APIs Exposed** | `POST /auth/register` |
| **Database Tables** | `users` |
| **Events Produced** | `user.registered` |
| **Events Consumed** | — |
| **Dependencies** | M16.1 (RDS), M16.3 (Secrets/JWT keys) |
| **Complexity** | 3/10 |
| **Team** | Backend |
| **Story Points** | 5 |

### M1.2 — Login & Session Module

| Field | Detail |
|-------|--------|
| **Description** | Credential verification, JWT issuance, refresh rotation |
| **Responsibilities** | Authenticate, issue 15min access + 7d refresh, rotate refresh on use |
| **Inputs** | `{ email, password }` or `{ refresh_token }` |
| **Outputs** | Token pair or 403 MFA challenge |
| **Internal Components** | AuthController, SessionStore, TokenBlacklist (Redis) |
| **APIs Consumed** | — |
| **APIs Exposed** | `POST /auth/login`, `POST /auth/refresh`, `DELETE /auth/sessions/{id}` |
| **Database Tables** | `users`, `sessions` (if opaque refresh) |
| **Events Produced** | `user.logged_in`, `session.revoked` |
| **Events Consumed** | — |
| **Dependencies** | M1.1, M16.2 (Redis) |
| **Complexity** | 5/10 |
| **Team** | Backend |
| **Story Points** | 8 |

### M1.3 — OAuth Module

| Field | Detail |
|-------|--------|
| **Description** | Google and Apple OIDC sign-in |
| **Responsibilities** | Verify id_token, link/create user, issue JWT |
| **Inputs** | `{ provider, id_token }` |
| **Outputs** | Token pair + user profile |
| **Internal Components** | OIDCVerifier (Google/Apple), OAuthUserLinker |
| **APIs Exposed** | `POST /auth/oauth/{provider}` |
| **Database Tables** | `users`, `oauth_identities` |
| **Events Produced** | `user.registered` (if new) |
| **Dependencies** | M1.2 |
| **Complexity** | 5/10 |
| **Team** | Backend |
| **Story Points** | 8 |

### M1.4 — MFA Module

| Field | Detail |
|-------|--------|
| **Description** | TOTP enrollment and verification |
| **Responsibilities** | Generate secret, verify 6-digit code, enforce on login |
| **Inputs** | `{ session_token, totp_code }` |
| **Outputs** | Full token pair |
| **APIs Exposed** | `POST /auth/mfa/enroll`, `POST /auth/mfa/verify`, `DELETE /auth/mfa` |
| **Database Tables** | `mfa_secrets` |
| **Complexity** | 6/10 |
| **Team** | Backend |
| **Story Points** | 8 |
| **MVP Note** | Defer to post-MVP (Won't Have) |

---

## P2 — User Profile & Consent System

### M2.1 — Profile Module

| Field | Detail |
|-------|--------|
| **Description** | CRUD for user profile fields |
| **Responsibilities** | Get/update display_name, avatar, timezone, locale, wellness_goal |
| **APIs Exposed** | `GET /users/me`, `PATCH /users/me` |
| **Database Tables** | `users`, `user_preferences` |
| **Events Produced** | `user.profile_updated` |
| **Dependencies** | M1.2 |
| **Complexity** | 2/10 |
| **Team** | Backend |
| **Story Points** | 3 |

### M2.2 — Consent Module

| Field | Detail |
|-------|--------|
| **Description** | Version-tracked granular consent per analysis modality |
| **Responsibilities** | Record consent grants/revocations with audit trail; enforce in pipeline |
| **Inputs** | `{ consent_type, granted, version }` |
| **Outputs** | Updated consent state |
| **APIs Exposed** | `GET /users/me/consent`, `PATCH /users/me/consent` |
| **Database Tables** | `consent_records` |
| **Events Produced** | `consent.changed` → consumed by Analysis Service |
| **Dependencies** | M2.1 |
| **Complexity** | 5/10 |
| **Team** | Backend |
| **Story Points** | 8 |

---

## P3 — Video Journal System

### M3.1 — Video Recorder (Flutter Mobile)

| Field | Detail |
|-------|--------|
| **Description** | Native camera capture via Flutter `camera` plugin — countdown, timer, preview |
| **Responsibilities** | Camera/mic permission, record/stop/pause, **3 min max** ($0 CPU budget), re-record, local file output |
| **Inputs** | Device camera/mic |
| **Outputs** | Local `File` (mp4), duration metadata |
| **Internal Components** | `RecordScreen`, `CameraController`, `CountdownOverlay`, `TimerWidget`, `PreviewPlayer` |
| **APIs Consumed** | — (local until Firebase Storage upload) |
| **APIs Exposed** | — |
| **Dependencies** | M9.1 (App shell / go_router) |
| **Complexity** | 7/10 |
| **Team** | Flutter |
| **Story Points** | 13 |
| **College build** | Upload via `firebase_storage`; no presigned S3 URLs |

### M3.2 — Journal Entry Module

| Field | Detail |
|-------|--------|
| **Description** | Journal CRUD, tags, streaks, prompts |
| **Responsibilities** | Create entry metadata, list/filter, soft delete, streak calculation |
| **APIs Exposed** | `POST /journals`, `GET /journals`, `GET /journals/{id}`, `PATCH`, `DELETE`, `GET /journals/streaks` |
| **Database Tables** | `journal_entries`, `journal_tags`, `streaks` |
| **Events Produced** | `journal.created`, `journal.deleted` |
| **Dependencies** | M2.1, M1.2 |
| **Complexity** | 5/10 |
| **Team** | Backend |
| **Story Points** | 8 |

### M3.3 — Upload Orchestrator

| Field | Detail |
|-------|--------|
| **Description** | **Paid:** Presigned S3 URLs. **Flutter+Firebase:** `StorageReference.putFile()` with progress stream |
| **Responsibilities** | Validate size (≤100MB), upload video, create `analysis_jobs` doc on complete |
| **APIs Exposed (paid)** | `POST /videos/upload/init`, `POST /videos/upload/complete` |
| **APIs Exposed (Firebase)** | Client SDK only; Security Rules enforce path `users/{uid}/videos/{journalId}/` |
| **APIs Consumed** | S3 (paid) or Firebase Storage (college) |
| **Database** | `video_metadata` + `journal_entries` (paid) or Firestore `journals/{id}` (college) |
| **Events Produced** | `video.uploaded` (paid) or Firestore `analysis_jobs` doc (college) |
| **Dependencies** | M3.2, M4.1 |
| **Complexity** | 6/10 |
| **Team** | Backend (paid) / Flutter (college) |
| **Story Points** | 8 |

### M3.4 — Journal List UI

| Field | Detail |
|-------|--------|
| **Description** | Paginated journal history with thumbnails and status badges |
| **APIs Consumed** | `GET /journals` |
| **Dependencies** | M3.2, M4.4 |
| **Complexity** | 4/10 |
| **Team** | Frontend |
| **Story Points** | 5 |

---

## P4 — Video Processing Pipeline

### M4.1 — Raw Storage Module

| Field | Detail |
|-------|--------|
| **Description** | S3 bucket management for raw/processed video |
| **Responsibilities** | Bucket policies, KMS encryption, lifecycle rules |
| **Inputs** | Client PUT via presigned URL |
| **Outputs** | S3 object key |
| **Events Produced** | S3 `ObjectCreated` → Lambda |
| **Dependencies** | M16.1 |
| **Complexity** | 4/10 |
| **Team** | DevOps + Backend |
| **Story Points** | 5 |

### M4.2 — Upload Validation Module

| Field | Detail |
|-------|--------|
| **Description** | Lambda validator on S3 event |
| **Responsibilities** | Magic byte check, ffprobe duration, size limits, ClamAV optional |
| **Inputs** | S3 event notification |
| **Outputs** | `upload_validated` or `upload_rejected` |
| **Events Produced** | `video.validated`, `video.rejected` |
| **Complexity** | 5/10 |
| **Team** | Backend |
| **Story Points** | 5 |

### M4.3 — Transcoding Module

| Field | Detail |
|-------|--------|
| **Description** | MediaConvert HLS + MP4 + audio extraction |
| **Responsibilities** | Submit job, poll completion, store outputs |
| **Inputs** | Validated raw S3 key |
| **Outputs** | HLS manifest, MP4, WAV sidecar, thumbnail |
| **Events Produced** | `video.processed` |
| **Events Consumed** | `video.validated` |
| **Database Tables** | `video_metadata` |
| **Complexity** | 6/10 |
| **Team** | Backend |
| **Story Points** | 8 |

### M4.4 — Playback Module

| Field | Detail |
|-------|--------|
| **Description** | CloudFront-signed or presigned playback URLs |
| **APIs Exposed** | `GET /videos/{id}/playback`, `GET /videos/{id}/status` |
| **Dependencies** | M4.3, M16.4 (CloudFront) |
| **Complexity** | 4/10 |
| **Team** | Backend |
| **Story Points** | 5 |

### M4.5 — Processing Queue Module

| Field | Detail |
|-------|--------|
| **Description** | Kafka topic management and event routing |
| **Responsibilities** | Topic creation, schema registry, DLQ |
| **Events Produced** | `video.processed` → analysis consumers |
| **Dependencies** | M16.5 (MSK or MVP: SQS) |
| **Complexity** | 5/10 |
| **Team** | DevOps + Backend |
| **Story Points** | 8 |

---

## P5 — AI Analysis System

### M5.1 — Analysis Orchestrator

| Field | Detail |
|-------|--------|
| **Description** | Coordinates parallel modality workers, aggregates results |
| **Responsibilities** | Job lifecycle, consent-aware modality dispatch, fusion trigger |
| **Inputs** | `video.processed` event |
| **Outputs** | Complete analysis record, `analysis.complete` event |
| **APIs Exposed** | `GET /analysis/{journal_id}`, `POST /analysis/{id}/reprocess` |
| **Database Tables** | `analysis_jobs` |
| **Events Consumed** | `video.processed` |
| **Events Produced** | `analysis.complete`, `analysis.failed` |
| **Dependencies** | M5.2–M5.5, M6.1 |
| **Complexity** | 7/10 |
| **Team** | Backend + AI |
| **Story Points** | 13 |

### M5.2 — Transcription Module (Whisper)

| Field | Detail |
|-------|--------|
| **Description** | Self-hosted Whisper large-v3 on GPU |
| **Responsibilities** | WAV → transcript with word timestamps |
| **Inputs** | Audio WAV from M4.3 |
| **Outputs** | Transcript text + segments JSON |
| **Internal Components** | Triton model server, Whisper worker, SegmentParser |
| **APIs Exposed** | gRPC `InferNLP/transcribe` (internal) |
| **Database Tables** | `transcripts` |
| **Complexity** | 8/10 |
| **Team** | AI |
| **Story Points** | 13 |

### M5.3 — Facial Analysis Module

| Field | Detail |
|-------|--------|
| **Description** | MediaPipe landmarks + emotion CNN |
| **Responsibilities** | Frame extraction 5fps, emotion probs, valence/arousal, blink/gaze/head |
| **Inputs** | Video frames |
| **Outputs** | `facial_metrics` record + timeline JSON |
| **Database Tables** | `facial_metrics` |
| **Events Consumed** | Consent check (skip if face opt-out) |
| **Complexity** | 9/10 |
| **Team** | AI |
| **Story Points** | 21 |

### M5.4 — Voice Analysis Module

| Field | Detail |
|-------|--------|
| **Description** | Parselmouth + librosa + Silero VAD |
| **Responsibilities** | Pitch, energy, jitter, shimmer, pauses, speaking rate, MFCCs |
| **Inputs** | WAV 16kHz mono |
| **Outputs** | `voice_metrics` record |
| **Database Tables** | `voice_metrics` |
| **Complexity** | 7/10 |
| **Team** | AI |
| **Story Points** | 13 |

### M5.5 — NLP Analysis Module

| Field | Detail |
|-------|--------|
| **Description** | Sentiment, emotion, topics, stress/fluency markers |
| **Responsibilities** | RoBERTa sentiment, GoEmotions, BERTopic/keyphrases, linguistic rules |
| **Inputs** | Transcript from M5.2 |
| **Outputs** | `emotion_metrics` record |
| **Database Tables** | `emotion_metrics` |
| **Complexity** | 7/10 |
| **Team** | AI |
| **Story Points** | 13 |

### M5.6 — GPU Inference Infrastructure

| Field | Detail |
|-------|--------|
| **Description** | Triton on EKS GPU node pool, model loading, batching |
| **Responsibilities** | Model deploy, health checks, KEDA autoscaling |
| **Dependencies** | M16.1 (EKS GPU pool) |
| **Complexity** | 8/10 |
| **Team** | DevOps + AI |
| **Story Points** | 13 |

---

## P6 — Multimodal Fusion Engine

### M6.1 — Late Fusion Module

| Field | Detail |
|-------|--------|
| **Description** | Weighted fusion of face/voice/text into wellness vector |
| **Responsibilities** | Re-normalize weights for missing modalities, compute congruence, engagement |
| **Inputs** | Modality feature objects from M5.3–M5.5 |
| **Outputs** | `FusedFeatureVector`, `feature_vectors` row, S3 Parquet |
| **Database Tables** | `feature_vectors` |
| **Events Produced** | `fusion.complete` |
| **Complexity** | 7/10 |
| **Team** | AI |
| **Story Points** | 13 |

---

## P7 — Personal Baseline Engine

### M7.1 — Baseline Update Module

| Field | Detail |
|-------|--------|
| **Description** | EWMA mean/variance per metric per user |
| **Responsibilities** | Incremental update after each fusion, confidence calculation |
| **Inputs** | `FusedFeatureVector` |
| **Outputs** | Updated `baselines` rows, baseline confidence score |
| **Database Tables** | `baselines` |
| **Events Consumed** | `fusion.complete` |
| **Complexity** | 6/10 |
| **Team** | AI + Backend |
| **Story Points** | 8 |

### M7.2 — Drift Detection Module

| Field | Detail |
|-------|--------|
| **Description** | Z-score per metric + disengagement index |
| **Responsibilities** | Classify drift types, track consecutive days |
| **Outputs** | `behavioral_events` records |
| **Database Tables** | `behavioral_events`, `baselines` |
| **Events Produced** | `drift.detected` |
| **Complexity** | 7/10 |
| **Team** | AI |
| **Story Points** | 13 |

### M7.3 — Trend Aggregation API

| Field | Detail |
|-------|--------|
| **Description** | Serve 7/30/90-day trends with baseline bands |
| **APIs Exposed** | `GET /timeline/trends`, `GET /timeline/calendar` |
| **Database Tables** | `feature_vectors`, `baselines`, TimescaleDB hypertables (post-MVP) |
| **Dependencies** | M7.1 |
| **Complexity** | 6/10 |
| **Team** | Backend |
| **Story Points** | 8 |

---

## P8 — Insight Generation Engine

### M8.1 — Insight Template Selector

| Field | Detail |
|-------|--------|
| **Description** | Rule engine mapping drift events → template IDs |
| **Inputs** | `behavioral_events`, trend aggregates, user context |
| **Outputs** | Template ID + structured fact JSON |
| **Complexity** | 5/10 |
| **Team** | AI + Backend |
| **Story Points** | 8 |

### M8.2 — LLM Insight Generator

| Field | Detail |
|-------|--------|
| **Description** | Constrained LLM phrasing with guardrails |
| **Responsibilities** | Slot-filling, diagnosis blocklist, numeric validation |
| **Inputs** | Template + evidence JSON |
| **Outputs** | Insight text + confidence |
| **Database Tables** | `insights` |
| **Events Produced** | `insight.generated` |
| **Complexity** | 7/10 |
| **Team** | AI |
| **Story Points** | 13 |

### M8.3 — Insight Feedback Module

| Field | Detail |
|-------|--------|
| **APIs Exposed** | `GET /insights`, `POST /insights/{id}/feedback`, `GET /insights/weekly-summary` |
| **Database Tables** | `insights`, `insight_feedback` |
| **Complexity** | 4/10 |
| **Team** | Backend |
| **Story Points** | 5 |

---

## P9 — Dashboard & Timeline (Web UI)

### M9.1 — App Shell & Navigation

| Field | Detail |
|-------|--------|
| **Description** | Layout, sidebar/mobile nav, auth middleware |
| **Team** | Frontend |
| **Story Points** | 8 |

### M9.2 — Dashboard Home

| Field | Detail |
|-------|--------|
| **Description** | Streak, today's metrics, latest insight, 7-day mini chart |
| **APIs Consumed** | journals, analysis, insights, trends |
| **Team** | Frontend |
| **Story Points** | 8 |

### M9.3 — Video Review Page

| Field | Detail |
|-------|--------|
| **Description** | Player + emotion timeline overlay + transcript |
| **APIs Consumed** | playback, analysis, timeline |
| **Team** | Frontend |
| **Story Points** | 13 |

### M9.4 — Timeline & Trends Page

| Field | Detail |
|-------|--------|
| **Description** | Trend charts, calendar heatmap, metric selector |
| **APIs Consumed** | `/timeline/trends`, `/timeline/calendar` |
| **Team** | Frontend |
| **Story Points** | 13 |

### M9.5 — Insight Center UI

| Field | Detail |
|-------|--------|
| **Description** | Insight cards, evidence drawer, feedback buttons |
| **Team** | Frontend |
| **Story Points** | 8 |

---

## P10 — Notification System

### M10.1 — In-App Notifications

| Field | Detail |
|-------|--------|
| **APIs Exposed** | `GET /notifications`, `PATCH /notifications/{id}/read` |
| **Database Tables** | `notifications` |
| **Events Consumed** | `analysis.complete`, `insight.generated` |
| **Story Points** | 5 |

### M10.2 — Email Notifications (SES)

| Field | Detail |
|-------|--------|
| **Description** | Analysis complete, weekly summary, reminders |
| **Events Consumed** | Same as M10.1 |
| **Story Points** | 5 |

### M10.3 — Push Notifications (FCM/APNs)

| Field | Detail |
|-------|--------|
| **MVP** | Won't Have — defer to post-MVP |
| **Story Points** | 13 (post-MVP) |

---

## P11 — Privacy & Data Rights

### M11.1 — Data Export Module

| Field | Detail |
|-------|--------|
| **APIs Exposed** | `GET /users/me/export`, `GET /users/me/export/{id}` |
| **Responsibilities** | Async job: JSON + MP4 ZIP to S3, 7-day link |
| **Story Points** | 8 |

### M11.2 — Data Deletion Module

| Field | Detail |
|-------|--------|
| **APIs Exposed** | `DELETE /users/me/data`, `DELETE /users/me` |
| **Responsibilities** | Cascade delete all tables + S3 purge |
| **Story Points** | 8 |

### M11.3 — Privacy Dashboard UI

| Field | Detail |
|-------|--------|
| **Description** | Consent toggles, data inventory, export/delete buttons |
| **Story Points** | 8 |

---

## P12 — Settings & Onboarding UX

### M12.1 — Onboarding Flow

| Field | Detail |
|-------|--------|
| **Screens** | Welcome → Consent → Tutorial → First journal |
| **Story Points** | 13 |

### M12.2 — Settings Pages

| Field | Detail |
|-------|--------|
| **Story Points** | 8 |

---

## P16 — Platform Infrastructure (Key Modules)

### M16.1 — Terraform Core (VPC, EKS, RDS, S3)

| Story Points | 21 | Team | DevOps |

### M16.2 — Redis/ElastiCache

| Story Points | 5 | Team | DevOps |

### M16.3 — Secrets Manager + External Secrets

| Story Points | 5 | Team | DevOps |

### M16.4 — CloudFront + WAF

| Story Points | 8 | Team | DevOps |

### M16.5 — Message Queue (MVP: SQS; Scale: MSK)

| Story Points | 8 | Team | DevOps |

### M16.6 — CI/CD Pipeline

| Story Points | 13 | Team | DevOps |

### M16.7 — Observability (OTel, Datadog, Grafana)

| Story Points | 8 | Team | DevOps |

**Module count:** 45 modules across 16 products.

---

# DOCUMENT 3: PHASE-WISE IMPLEMENTATION PLAN

## Phase 0 — Foundations (Weeks 1–2)

| Field | Detail |
|-------|--------|
| **Objective** | Runnable dev/staging environment; monorepo; CI green |
| **Modules** | M16.1, M16.3, M16.6, M16.7 (partial), shared-types package |
| **Deliverables** | EKS staging, RDS PostgreSQL, S3 buckets, GitHub Actions CI, docker-compose local dev, `/health` on scaffold services |
| **Dependencies** | AWS account, domain, GitHub org, legal ToS draft |
| **Risks** | EKS provisioning delays; Terraform state misconfiguration |
| **Success Criteria** | Engineer clones repo → `docker-compose up` → connect to staging RDS |
| **Duration** | 2 weeks |
| **Team** | DevOps (lead), FS (monorepo), BE (service scaffolds) |
| **Exit Criteria** | CI passes on main; staging URL accessible; README documents local setup |

## Phase 1 — Authentication & User (Weeks 3–4)

| Field | Detail |
|-------|--------|
| **Objective** | Users register, login, manage profile and consent |
| **Modules** | M1.1–M1.3, M2.1–M2.2, auth UI pages, migrations 001–003 |
| **Deliverables** | auth-service, user-service, login/register UI, JWT flow, OAuth Google |
| **Dependencies** | Phase 0 |
| **Risks** | OAuth app verification delay (Apple) |
| **Success Criteria** | E2E: register → login → update profile → grant consent |
| **Duration** | 2 weeks |
| **Team** | BE×2, FE×2, Designer (auth screens) |
| **Exit Criteria** | OpenAPI auth endpoints documented; 80% unit test coverage on auth |

## Phase 2 — Video Journaling (Weeks 5–7)

| Field | Detail |
|-------|--------|
| **Objective** | Record video in browser, upload to S3, list journals |
| **Modules** | M3.1–M3.4, M4.1–M4.2, M12.1 (partial), migrations 004–006 |
| **Deliverables** | journal-service, video-service (upload init/complete), VideoRecorder component, journal list UI |
| **Dependencies** | Phase 1 |
| **Risks** | Browser codec compatibility; large upload failures on mobile Safari |
| **Success Criteria** | Record 2-min video → upload → appears in journal list within 30s |
| **Duration** | 3 weeks |
| **Team** | BE×2, FE×2, DevOps (S3/CloudFront), Designer (recorder UX) |
| **Exit Criteria** | M1 milestone (SAD §25.7): First Upload |

## Phase 3 — Processing Pipeline (Weeks 8–9)

| Field | Detail |
|-------|--------|
| **Objective** | Transcode video, extract audio, generate thumbnail, queue events |
| **Modules** | M4.3–M4.5, M4.4, Lambda validators |
| **Deliverables** | MediaConvert integration, playback URLs, processing status API, thumbnail in list |
| **Dependencies** | Phase 2 |
| **Risks** | MediaConvert job failures; cost overrun on unoptimized presets |
| **Success Criteria** | Upload → transcode complete → playable HLS within 3 min |
| **Duration** | 2 weeks |
| **Team** | BE×2, DevOps, FS (Lambda) |
| **Exit Criteria** | `video.processed` event emitted reliably; DLQ configured |

## Phase 4 — AI Analysis MVP (Weeks 10–13)

| Field | Detail |
|-------|--------|
| **Objective** | Transcription + voice features + basic face emotion + NLP sentiment |
| **Modules** | M5.1–M5.6, M5.2–M5.5, migrations 007–011 |
| **Deliverables** | ai-inference-service, analysis-service, GPU pool, Whisper, MediaPipe+emotion, voice pipeline, NLP pipeline |
| **Dependencies** | Phase 3 |
| **Risks** | GPU capacity; Whisper latency > SLA; model accuracy below threshold |
| **Success Criteria** | Journal analyzed within 5 min; transcript + 3 modality summaries visible |
| **Duration** | 4 weeks |
| **Team** | AI (lead), BE, DevOps (GPU), FE (analysis status polling) |
| **Exit Criteria** | M2 milestone: First Analysis |

## Phase 5 — Fusion & Baseline (Weeks 14–16)

| Field | Detail |
|-------|--------|
| **Objective** | Wellness vector, personal baselines, trend API |
| **Modules** | M6.1, M7.1–M7.3, migrations 012–014 |
| **Deliverables** | Fusion engine, baseline engine, drift detection (Z-score only at MVP), trend endpoints |
| **Dependencies** | Phase 4 |
| **Risks** | Baseline instability with <7 entries; misleading trends shown too early |
| **Success Criteria** | 7-day trend chart with baseline band; baseline progress indicator in UI |
| **Duration** | 3 weeks |
| **Team** | AI, BE, FE (timeline page) |
| **Exit Criteria** | M3 milestone: First Trend |

## Phase 6 — Insights (Weeks 17–18)

| Field | Detail |
|-------|--------|
| **Objective** | Rule-based insights with LLM phrasing and evidence |
| **Modules** | M8.1–M8.3, M9.5, migrations 015–016 |
| **Deliverables** | insight-service, 5 insight templates, guardrails, insight center UI |
| **Dependencies** | Phase 5 (baseline confidence >0.5) |
| **Risks** | LLM hallucination; inappropriate clinical language |
| **Success Criteria** | User with 7+ entries receives insight with evidence drawer |
| **Duration** | 2 weeks |
| **Team** | AI, BE, FE, Designer (insight cards) |
| **Exit Criteria** | M4 milestone: First Insight |

## Phase 7 — Dashboard & Polish (Weeks 19–20)

| Field | Detail |
|-------|--------|
| **Objective** | Complete dashboard, video review overlays, onboarding finish |
| **Modules** | M9.2–M9.4, M9.3, M12.1–M12.2 |
| **Deliverables** | Dashboard home, emotion timeline overlay, calendar heatmap, full onboarding |
| **Dependencies** | Phases 4–6 |
| **Risks** | Chart performance with 90+ data points |
| **Success Criteria** | New user completes onboarding → records → sees dashboard populate |
| **Duration** | 2 weeks |
| **Team** | FE×2, Designer, BE (API polish) |
| **Exit Criteria** | Core user loop complete without manual intervention |

## Phase 8 — Notifications (Week 21)

| Field | Detail |
|-------|--------|
| **Objective** | In-app + email notifications for analysis complete and reminders |
| **Modules** | M10.1–M10.2, migrations 017–018 |
| **Deliverables** | notification-service, in-app center, email via SES, preference settings |
| **Dependencies** | Phase 6 |
| **Risks** | Email deliverability (SPF/DKIM) |
| **Success Criteria** | User receives email when analysis completes; daily reminder sends |
| **Duration** | 1 week |
| **Team** | BE, FE |
| **Exit Criteria** | Notification preferences respected including quiet hours |

## Phase 9 — Security & Compliance (Weeks 22–23)

| Field | Detail |
|-------|--------|
| **Objective** | GDPR export/delete, privacy dashboard, security hardening |
| **Modules** | M11.1–M11.3, audit_logs migration, WAF rules, pen test fixes |
| **Deliverables** | Export/delete workflows, privacy dashboard, audit logging, security scan clean |
| **Dependencies** | All data modules |
| **Risks** | Incomplete cascade delete; export job timeout on large accounts |
| **Success Criteria** | GDPR export E2E in staging; delete removes all S3 + DB rows |
| **Duration** | 2 weeks |
| **Team** | BE×2, FE, DevOps, FS (security review) |
| **Exit Criteria** | M5 milestone: Beta Ready |

## Phase 10 — Production Launch (Week 24)

| Field | Detail |
|-------|--------|
| **Objective** | Beta launch to 100–500 users with monitoring and support |
| **Modules** | M16.7 (complete), load test fixes, M14 (basic analytics) |
| **Deliverables** | Production deploy, Datadog dashboards, on-call runbook, beta invite flow |
| **Dependencies** | Phase 9 |
| **Risks** | Analysis SLA breach under load; unexpected GPU costs |
| **Success Criteria** | 100 beta users; 95% analysis within 5 min; zero P1 incidents in first 48h |
| **Duration** | 1 week |
| **Team** | All hands |
| **Exit Criteria** | Production readiness gate passed (Document §11) |

**Total MVP timeline:** 24 weeks (~12 two-week sprints)

---

# DOCUMENT 4: MVP DEFINITION

## MoSCoW

### Must Have (MVP — Beta Launch)

| Capability | Rationale |
|------------|-----------|
| Email/password + Google OAuth registration/login | Activation without friction |
| Granular consent (face/voice/text) at onboarding | Legal + trust requirement |
| Web video recording (browser) | Core loop |
| S3 upload with progress + retry | Reliability |
| Transcode + playback | User must review their journal |
| Whisper transcription | Foundational NLP signal |
| Basic facial emotion (7-class + valence) | Core differentiation |
| Voice energy, pitch, speaking rate, pauses | Prosody signal |
| NLP sentiment + basic topics | Language signal |
| Late fusion → wellness vector | Unified per-entry fingerprint |
| EWMA baseline + Z-score drift (no Isolation Forest) | Personalization MVP |
| 7-day trend chart with baseline band | Visible progress |
| 5 insight templates + LLM phrasing + evidence | User value delivery |
| Dashboard + journal list + video review + insight center | Complete UX |
| In-app + email notifications (analysis complete, reminder) | Habit formation |
| GDPR export + account/data deletion | Beta launch gate |
| Privacy dashboard + medical disclaimer | Compliance |
| Staging + production environments, CI/CD, basic monitoring | Operability |

### Should Have (MVP if time; otherwise Sprint 11–12)

| Capability | Notes |
|------------|-------|
| OAuth Apple | Often delayed by Apple review |
| Transcript user correction | Improves NLP accuracy |
| Calendar heatmap | High engagement visual |
| Weekly insight summary | Retention driver |
| Static journal prompts (5 templates) | Reduces blank-page anxiety |
| Basic product analytics (Amplitude) | Measure retention |
| Streak display + forgiveness rule | Gamification |

### Could Have (Post-MVP Month 7+)

| Capability | Notes |
|------------|-------|
| MFA | Security enhancement |
| Push notifications (FCM/APNs) | **College: FCM via Firebase (free).** Paid path: after mobile app |
| Mobile apps (iOS/Android) | Month 8 per SAD |
| Micro-expression model | Phase 2 AI |
| Isolation Forest anomaly detection | Requires more baseline data |
| Audio-only journaling mode | Accessibility |
| PDF export for therapist | Premium feature |
| Premium billing (Stripe) | Month 10 |
| Admin dashboard | Internal ops |
| TimescaleDB hypertables | Optimize at 10K+ users |

### Won't Have (Explicitly Excluded from MVP)

| Capability | Reason |
|------------|--------|
| Native mobile apps | **College: Flutter is primary.** Paid path: web-first, mobile Month 8 |
| Transformer fusion | Needs 100K+ users data |
| Self-hosted LLM for insights | Use API (GPT-4o-mini); cost acceptable at beta scale |
| Enterprise SSO (SAML) | No enterprise customers yet |
| Multi-region failover | Single region (us-east-1) sufficient for beta |
| Kafka/MSK | **Use SQS for MVP** — simpler ops |
| Feature store (Feast) | PostgreSQL sufficient for beta |
| Snowflake analytics warehouse | Amplitude only at MVP |
| Crisis detection auto-escalation | Legal review required; manual resource links only |
| Model training on user data | Opt-in only; no training pipeline at MVP |
| EU data region | US-only beta; EU before GA |
| Real-time WebSocket analysis progress | Poll every 5s is sufficient |
| Offline recording/sync | Complexity vs. beta need |
| Multi-language insights | English only at MVP |

## Scope Boundaries

**In scope (paid AWS path):** Single-region AWS, web client, English, 100–500 beta users, email+Google auth, 3-modality analysis, rule+LLM insights, 7-day trends.

**In scope (college Flutter + Firebase):** Flutter iOS/Android, Firebase Spark, English, 5–20 class users, email+Google auth, 3-modality analysis via local worker, template insights, 7-day trends, FCM push. See **`SOLENNE-Zero-Budget-Build-Plan.md`**.

**Out of scope (both):** Billing, enterprise, multi-region production, HIPAA BAA at college stage.

## Technical Shortcuts (Approved)

| Area | SAD Target | MVP Shortcut | Upgrade Path |
|------|------------|--------------|--------------|
| Message queue | Kafka/MSK | **SQS + SNS** | Migrate to MSK at 10K users |
| GPU inference | Triton multi-model | **Single Python worker pod** | Triton at 1K+ daily videos |
| Compute | EKS full | **EKS minimal (3 API + 1 GPU node)** | HPA/KEDA as load grows |
| LLM insights | Constrained Claude/GPT | **GPT-4o-mini API** with template-only fallback | Self-hosted if cost justifies |
| Baseline | EWMA + Z + Isolation Forest | **EWMA + Z-score only** | Add IF at Month 9 |
| Micro-expressions | I3D on CASME II | **Landmark velocity proxy** | Train ME model Month 9 |
| Fusion | Late fusion | Same (already MVP approach) | Transformer Phase 3 |
| Transcription | Whisper large-v3 | **Whisper medium** (faster/cheaper) | Upgrade to large-v3 at scale |
| CDN | CloudFront full | CloudFront for playback only | Expand for static assets |
| Observability | Datadog full | **Datadog APM + basic Grafana** | Full dashboards pre-GA |

## AI Simplifications

1. Face: MediaPipe + off-the-shelf FER model (no custom training)
2. Voice: Rule-based prosody mapping (no ML model for voice→emotion)
3. NLP: Pre-trained RoBERTa/GoEmotions (no fine-tuning)
4. Insights: 5 hardcoded templates (not 20+)
5. Confidence: Suppress insights when baseline confidence <0.6 (not 0.5)
6. No model versioning UI for users (backend tracks version only)

## Cost-Saving Decisions

- 1 g5.xlarge GPU node (not pool) with manual scale
- RDS db.t4g.large (not Multi-AZ for staging; Multi-AZ for prod only)
- S3 Intelligent-Tiering after 30 days
- No Reserved Instances until 10K users
- Single NAT Gateway in staging (3 in prod)
- LLM budget cap: $500/mo at beta scale

## What NOT to Build Initially

1. **admin-service** — use SQL + Retool temporarily
2. **recommendation-service** — hardcode 5 prompts in journal-service
3. **analytics-service** — Amplitude SDK in frontend only
4. **Mobile apps** — responsive web
5. **Billing/subscriptions** — free beta only
6. **Feature flags service** — env vars + config file
7. **OpenSearch** — PostgreSQL full-text on transcripts
8. **TimescaleDB** — store metrics in PostgreSQL JSONB initially
9. **MLflow registry** — S3 versioned model files + git tag
10. **Cross-region replication** — backup snapshots only

---

# DOCUMENT 5: ENGINEERING EPICS

## Epic E1: Platform Infrastructure

**Features:** Monorepo, Terraform staging, EKS, RDS, S3, CI/CD, local docker-compose  
**Tasks:** Init turbo repo; Terraform VPC+EKS+RDS+S3; GitHub Actions lint/test/build; Helm chart skeleton; docker-compose Postgres+Redis+LocalStack  
**Acceptance Criteria:** `main` branch deploys to staging automatically; health check returns 200  
**Dependencies:** AWS account, GitHub org  
**Estimate:** 21 SP | **Owner:** DevOps + FS

## Epic E2: User Authentication

**Features:** Registration, login, JWT, refresh, Google OAuth  
**Tasks:** Migration 001; auth-service scaffold; POST register/login/refresh; argon2 hashing; RS256 JWT; Google OIDC; auth UI pages; API client auth module  
**Acceptance Criteria:** User registers, logs in, token refresh works; OAuth creates/links account  
**Dependencies:** E1  
**Estimate:** 21 SP | **Owner:** BE1 + FE1

## Epic E3: User Profile & Consent

**Features:** Profile CRUD, consent records, preferences  
**Tasks:** Migrations 002–003; user-service; consent API; onboarding consent screen; consent enforcement middleware  
**Acceptance Criteria:** Consent changes persist with version; pipeline respects face opt-out  
**Dependencies:** E2  
**Estimate:** 13 SP | **Owner:** BE2 + FE2

## Epic E4: Journal Management

**Features:** Journal CRUD, tags, streaks, prompts  
**Tasks:** Migrations 004–005; journal-service; streak calculator; static prompts JSON  
**Acceptance Criteria:** Create/list/delete journals; streak increments correctly  
**Dependencies:** E3  
**Estimate:** 13 SP | **Owner:** BE1

## Epic E5: Video Upload & Storage

**Features:** Presigned upload, multipart, completion, validation  
**Tasks:** Migration 006; video-service; S3 presigned URLs; upload complete handler; frontend upload with retry  
**Acceptance Criteria:** 100MB video uploads direct to S3; checksum verified  
**Dependencies:** E4, E1  
**Estimate:** 21 SP | **Owner:** BE2 + FE1

## Epic E6: Video Recording UI

**Features:** Browser recorder, countdown, timer, preview, re-record  
**Tasks:** VideoRecorder component; MediaRecorder polyfill; mobile responsive; recording flow E2E  
**Acceptance Criteria:** Record 3-min video in Chrome/Safari/Firefox; preview before submit  
**Dependencies:** E4  
**Estimate:** 21 SP | **Owner:** FE1 + FE2 + Designer

## Epic E7: Video Transcoding Pipeline

**Features:** MediaConvert, HLS, audio extraction, thumbnails  
**Tasks:** Lambda validator; MediaConvert job template; SQS queue; video.processed event; playback URL API  
**Acceptance Criteria:** Raw upload → HLS playable within 3 min  
**Dependencies:** E5  
**Estimate:** 21 SP | **Owner:** BE1 + DevOps

## Epic E8: GPU Infrastructure & Model Serving

**Features:** GPU node pool, model loading, inference worker  
**Tasks:** EKS GPU node group; CUDA base Docker image; model download from S3; health endpoints; KEDA/SQS scaler (basic)  
**Acceptance Criteria:** GPU pod loads models and responds to health check  
**Dependencies:** E1, E7  
**Estimate:** 21 SP | **Owner:** DevOps + AI

## Epic E9: Transcription Pipeline

**Features:** Whisper inference, transcript storage, segments  
**Tasks:** Whisper medium Docker; inference worker; migration 007; transcript API; word timestamps  
**Acceptance Criteria:** 3-min audio transcribed in <90s; WER <10% on test set  
**Dependencies:** E7, E8  
**Estimate:** 21 SP | **Owner:** AI

## Epic E10: Facial Emotion Analysis

**Features:** MediaPipe landmarks, emotion classification, timeline  
**Tasks:** Frame extractor; MediaPipe integration; FER model inference; migration 009; consent skip logic  
**Acceptance Criteria:** Emotion timeline generated; skipped when face consent false  
**Dependencies:** E8, E3  
**Estimate:** 34 SP | **Owner:** AI

## Epic E11: Voice Feature Extraction

**Features:** Pitch, energy, pauses, jitter, shimmer, speaking rate  
**Tasks:** Silero VAD; Parselmouth features; librosa MFCCs; migration 010; voice timeline JSON  
**Acceptance Criteria:** Voice metrics match Praat reference within 5% tolerance on test clips  
**Dependencies:** E7, E9 (for speaking rate timestamps)  
**Estimate:** 21 SP | **Owner:** AI

## Epic E12: NLP Sentiment & Topics

**Features:** Sentiment, emotion, topics, stress markers  
**Tasks:** RoBERTa inference; GoEmotions; keyphrase extraction; migration 011; stress/fluency rules  
**Acceptance Criteria:** Sentiment correlates r>0.6 with labeled test set  
**Dependencies:** E9  
**Estimate:** 21 SP | **Owner:** AI

## Epic E13: Analysis Orchestration

**Features:** Job lifecycle, parallel workers, status API, polling  
**Tasks:** analysis-service; migration 008; SQS consumers; GET /analysis/{id}; frontend status polling  
**Acceptance Criteria:** Full pipeline completes; status transitions queued→processing→complete  
**Dependencies:** E9, E10, E11, E12  
**Estimate:** 21 SP | **Owner:** BE2 + AI

## Epic E14: Multimodal Fusion

**Features:** Late fusion, wellness vector, congruence, feature persistence  
**Tasks:** Fusion module; migration 012; S3 Parquet write; unit tests for missing modalities  
**Acceptance Criteria:** Fusion handles 1–3 modalities; wellness_vector persisted  
**Dependencies:** E13  
**Estimate:** 21 SP | **Owner:** AI

## Epic E15: Personal Baseline Engine

**Features:** EWMA update, confidence, Z-score drift, behavioral events  
**Tasks:** Baseline module; migrations 013–014; drift classifier; baseline progress API  
**Acceptance Criteria:** Baseline updates after each entry; Z-score computed correctly on test fixtures  
**Dependencies:** E14  
**Estimate:** 21 SP | **Owner:** AI + BE1

## Epic E16: Trend & Timeline API

**Features:** 7/30-day trends, calendar heatmap data  
**Tasks:** GET /timeline/trends; GET /timeline/calendar; query optimization; caching  
**Acceptance Criteria:** 30-day trend returns in <200ms p95  
**Dependencies:** E15  
**Estimate:** 13 SP | **Owner:** BE1

## Epic E17: Insight Generation

**Features:** Template selector, LLM generator, guardrails, evidence  
**Tasks:** insight-service; migrations 015–016; 5 templates; GPT-4o-mini integration; blocklist validator  
**Acceptance Criteria:** Insights cite correct metrics; no clinical terms in 100-sample eval  
**Dependencies:** E15  
**Estimate:** 21 SP | **Owner:** AI + BE2

## Epic E18: Dashboard & Core UI

**Features:** App shell, dashboard, journal list, navigation  
**Tasks:** Layout; dashboard widgets; journal cards; streak display; responsive mobile  
**Acceptance Criteria:** Dashboard loads <2s; shows latest journal and insight  
**Dependencies:** E4, E13, E17  
**Estimate:** 21 SP | **Owner:** FE1 + FE2 + Designer

## Epic E19: Video Review & Analysis Visualization

**Features:** Player, emotion overlay, transcript, confidence badges  
**Tasks:** HLS player; timeline overlay component; transcript display; analysis detail page  
**Acceptance Criteria:** Overlay syncs with playback ±500ms  
**Dependencies:** E7, E13  
**Estimate:** 21 SP | **Owner:** FE2

## Epic E20: Timeline & Insight Center UI

**Features:** Trend charts, heatmap, insight cards, evidence drawer, feedback  
**Tasks:** Recharts trends; calendar heatmap; InsightCard; EvidenceDrawer; feedback mutation  
**Acceptance Criteria:** User can trace insight to source journals via evidence  
**Dependencies:** E16, E17  
**Estimate:** 21 SP | **Owner:** FE1 + Designer

## Epic E21: Onboarding & Settings

**Features:** Multi-step onboarding, settings pages, baseline indicator  
**Tasks:** Onboarding wizard; settings layout; notification prefs UI; wellness goal selector  
**Acceptance Criteria:** Onboarding completes in <3 min median (user test)  
**Dependencies:** E3, E18  
**Estimate:** 21 SP | **Owner:** FE2 + Designer

## Epic E22: Notifications

**Features:** In-app inbox, email via SES, preferences, quiet hours  
**Tasks:** notification-service; migrations 017–018; SES templates; in-app notification center  
**Acceptance Criteria:** Analysis complete triggers in-app + email within 1 min  
**Dependencies:** E13, E17  
**Estimate:** 13 SP | **Owner:** BE2 + FE1

## Epic E23: Privacy & Data Rights

**Features:** Export, deletion, privacy dashboard  
**Tasks:** Async export job; cascade delete worker; privacy settings UI; audit log migration  
**Acceptance Criteria:** Export ZIP contains all user data; delete purges S3 within 24h  
**Dependencies:** All data epics  
**Estimate:** 21 SP | **Owner:** BE1 + FE2

## Epic E24: Observability & Production Hardening

**Features:** Datadog APM, Grafana dashboards, alerts, load test, WAF  
**Tasks:** OTel instrumentation; PagerDuty integration; k6 load test; WAF rules; runbooks  
**Acceptance Criteria:** Load test 2× beta traffic passes; alerts fire on synthetic failure  
**Dependencies:** E1, all services  
**Estimate:** 21 SP | **Owner:** DevOps + FS

## Epic E25: Beta Launch

**Features:** Prod deploy, invite flow, smoke tests, support playbook  
**Tasks:** Prod Terraform apply; DNS cutover; beta invite codes; launch checklist; status page  
**Acceptance Criteria:** 100 users onboarded; zero P1 in 48h; analysis SLA 95%  
**Dependencies:** E23, E24  
**Estimate:** 13 SP | **Owner:** All hands

**Total MVP epics:** 25 | **Total estimate:** ~520 SP (~65 SP/sprint × 8 people × 0.7 velocity factor)

---

# DOCUMENT 6: FEATURE IMPLEMENTATION ORDER

| # | Feature | Why This Order |
|---|---------|----------------|
| 1 | **Infrastructure (Terraform, EKS, RDS, S3)** | Nothing runs without compute, network, storage |
| 2 | **CI/CD + Monorepo scaffold** | Every subsequent commit needs automated test/deploy |
| 3 | **Database migrations 001–003 (users, consent)** | Auth and consent are FK roots for all user data |
| 4 | **Authentication (register, login, JWT)** | All APIs require authenticated identity |
| 5 | **User profile & consent APIs** | Pipeline and UI need consent before processing |
| 6 | **Auth UI (login, register)** | Enables manual testing of all subsequent features |
| 7 | **Journal service + migrations 004–005** | Video belongs to a journal entry entity |
| 8 | **Video upload (presigned S3, init/complete)** | Must exist before any video processing |
| 9 | **Video recorder UI** | Generates blobs for upload testing |
| 10 | **Upload validation Lambda** | Reject bad files before expensive transcode |
| 11 | **MediaConvert transcoding + thumbnail** | AI needs standardized audio/video formats |
| 12 | **SQS event queue (video.processed)** | Decouples transcode from analysis |
| 13 | **Playback URLs + journal list UI** | User sees value before AI completes |
| 14 | **GPU node + inference worker scaffold** | AI models need deployment target |
| 15 | **Audio extraction verification** | Whisper input must be 16kHz WAV |
| 16 | **Whisper transcription** | NLP and speaking rate depend on transcript |
| 17 | **Voice feature extraction** | Independent of face; parallelizable after audio ready |
| 18 | **Facial emotion analysis** | GPU-intensive; can parallel with voice after frames extracted |
| 19 | **NLP sentiment & topics** | Depends on transcript from step 16 |
| 20 | **Analysis orchestrator + status API** | Coordinates 16–19; unblocks frontend polling |
| 21 | **Analysis results UI (transcript + metrics)** | First AI value visible to user |
| 22 | **Late fusion engine** | Requires all modality outputs |
| 23 | **Feature vector persistence (migration 012)** | Baseline reads fused vectors |
| 24 | **EWMA baseline engine (migration 013)** | Needs ≥1 fused vector; improves with more |
| 25 | **Z-score drift detection (migration 014)** | Needs baseline established |
| 26 | **Trend API + timeline UI** | Needs historical feature vectors |
| 27 | **Insight template selector + LLM generator** | Needs drift events or trend deltas |
| 28 | **Insight center UI** | Displays output of step 27 |
| 29 | **Dashboard home (aggregate widgets)** | Pulls from journals, analysis, insights, trends |
| 30 | **Onboarding flow** | Better tested once core loop works |
| 31 | **In-app + email notifications** | Needs analysis.complete and insight events |
| 32 | **Privacy export/delete** | Requires all data stores to exist |
| 33 | **Observability + load testing** | Validate complete system under stress |
| 34 | **Production deploy + beta launch** | Final gate |

**Critical path:** 1 → 4 → 7 → 8 → 11 → 12 → 14 → 16 → 20 → 22 → 24 → 27 → 32 → 34 (14 sequential dependencies; rest parallelizable)

---

# DOCUMENT 7: SPRINT PLAN (2-Week Sprints → MVP)

**Team:** BE1, BE2 (Backend), FE1, FE2 (Frontend), AI (ML), FS (Full Stack), DevOps, Designer  
**Sprint velocity target:** ~60–70 SP/sprint  
**Ceremonies:** Mon planning, daily standup, Fri demo/retro

---

## Sprint 1 (Weeks 1–2): Foundation

| Field | Detail |
|-------|--------|
| **Goals** | Monorepo live; staging infra; CI green; local dev works |
| **Deliverables** | Terraform staging, EKS, RDS, S3, GitHub Actions, docker-compose, service scaffolds |
| **Tasks** | E1 all tasks; shared-types package; Helm skeleton; README |
| **Owners** | DevOps (E1 lead), FS (monorepo), BE1+BE2 (service hello-world) |
| **Risks** | AWS quota for GPU not needed yet; EKS learning curve |
| **DoD** | PR merges deploy to staging; `curl /health` → 200; engineer onboarding doc reviewed |

## Sprint 2 (Weeks 3–4): Authentication

| Field | Detail |
|-------|--------|
| **Goals** | Users register, login, OAuth Google |
| **Deliverables** | E2, E3 complete; auth UI; migrations 001–003 |
| **Tasks** | auth-service, user-service, JWT, Google OIDC, login/register pages, consent API |
| **Owners** | BE1 (auth), BE2 (user/consent), FE1+FE2 (auth UI), Designer (auth screens) |
| **Risks** | Google OAuth consent screen approval |
| **DoD** | Playwright: register → login → update profile; unit tests 80% auth |

## Sprint 3 (Weeks 5–6): Journal + Upload Backend

| Field | Detail |
|-------|--------|
| **Goals** | Journal CRUD; presigned upload end-to-end (API only) |
| **Deliverables** | E4, E5 (backend); migrations 004–006 |
| **Tasks** | journal-service, video-service, S3 presigned, upload complete, streak logic |
| **Owners** | BE1 (journal), BE2 (video), DevOps (S3 policies), FE1 (journal list stub) |
| **Risks** | S3 CORS misconfiguration |
| **DoD** | Postman/curl: create journal → get presigned URL → upload file → complete |

## Sprint 4 (Weeks 7–8): Video Recorder + Transcode

| Field | Detail |
|-------|--------|
| **Goals** | Browser recording; transcode pipeline; journal list with thumbnails |
| **Deliverables** | E6, E7; M1 First Upload milestone |
| **Tasks** | VideoRecorder, upload UI, MediaConvert, Lambda validator, playback API, journal list UI |
| **Owners** | FE1+FE2+Designer (recorder), BE1 (transcode), DevOps (Lambda), BE2 (playback) |
| **Risks** | Safari MediaRecorder quirks |
| **DoD** | E2E: record → upload → see in list with thumbnail; video plays back |

## Sprint 5 (Weeks 9–10): GPU + Transcription

| Field | Detail |
|-------|--------|
| **Goals** | GPU node live; Whisper transcribes audio |
| **Deliverables** | E8, E9; migration 007 |
| **Tasks** | GPU node group, inference Docker, Whisper worker, SQS consumer, transcript storage |
| **Owners** | AI (Whisper), DevOps (GPU), BE2 (analysis-service scaffold), FS (SQS wiring) |
| **Risks** | GPU instance availability; Whisper OOM on long videos |
| **DoD** | Manual test: upload video → transcript appears in DB within 5 min |

## Sprint 6 (Weeks 11–12): Face + Voice Analysis

| Field | Detail |
|-------|--------|
| **Goals** | Facial emotion + voice features extracted |
| **Deliverables** | E10, E11; migrations 009–010 |
| **Tasks** | MediaPipe pipeline, FER inference, Parselmouth features, Silero VAD, consent skip |
| **Owners** | AI (lead both), BE1 (integrate into orchestrator) |
| **Risks** | Face detection fails in poor lighting — quality score needed |
| **DoD** | facial_metrics and voice_metrics rows populated for test videos |

## Sprint 7 (Weeks 13–14): NLP + Analysis Orchestration

| Field | Detail |
|-------|--------|
| **Goals** | Full analysis pipeline end-to-end |
| **Deliverables** | E12, E13; migration 011; M2 First Analysis milestone |
| **Tasks** | NLP models, analysis orchestrator, status API, frontend polling, analysis results page (basic) |
| **Owners** | AI (NLP), BE2 (orchestrator), FE2 (analysis UI) |
| **Risks** | Pipeline timeout — need per-modality timeout handling |
| **DoD** | E2E: upload → all 3 modalities complete → user sees transcript + emotions |

## Sprint 8 (Weeks 15–16): Fusion + Baseline

| Field | Detail |
|-------|--------|
| **Goals** | Wellness vector; personal baselines; drift detection |
| **Deliverables** | E14, E15; migrations 012–014 |
| **Tasks** | Fusion module, baseline EWMA, Z-score, behavioral_events, baseline progress API |
| **Owners** | AI (fusion + baseline), BE1 (persist + API) |
| **Risks** | Edge case: user's first entry — null baseline handling |
| **DoD** | Unit tests pass on fusion fixtures; baseline updates on 2nd+ entry |

## Sprint 9 (Weeks 17–18): Trends + Insights

| Field | Detail |
|-------|--------|
| **Goals** | Trend charts; insight generation; M3 + M4 milestones |
| **Deliverables** | E16, E17, E20 (partial) |
| **Tasks** | Trend API, 5 insight templates, LLM integration, guardrails, insight center UI |
| **Owners** | BE1 (trends), AI (insights), FE1 (insight UI), Designer (insight cards) |
| **Risks** | LLM outputs clinical language — blocklist must be tested |
| **DoD** | User with 7 seeded entries sees trend chart + at least 1 insight with evidence |

## Sprint 10 (Weeks 19–20): Dashboard + Video Review + Onboarding

| Field | Detail |
|-------|--------|
| **Goals** | Complete core UX loop |
| **Deliverables** | E18, E19, E21 |
| **Tasks** | Dashboard, emotion overlay, timeline page, onboarding wizard, settings |
| **Owners** | FE1+FE2+Designer (UI), BE2 (API polish) |
| **Risks** | Chart render performance |
| **DoD** | New user journey: onboard → record → dashboard populated → review video with overlay |

## Sprint 11 (Weeks 21–22): Notifications + Privacy

| Field | Detail |
|-------|--------|
| **Goals** | Notifications live; GDPR export/delete |
| **Deliverables** | E22, E23 |
| **Tasks** | notification-service, SES, in-app inbox, export job, delete cascade, privacy dashboard |
| **Owners** | BE1 (privacy), BE2 (notifications), FE2 (privacy UI), FS (delete worker) |
| **Risks** | Cascade delete misses S3 prefix |
| **DoD** | Export ZIP verified; delete removes all user rows in staging |

## Sprint 12 (Weeks 23–24): Hardening + Beta Launch

| Field | Detail |
|-------|--------|
| **Goals** | Production ready; beta launch |
| **Deliverables** | E24, E25; M5 Beta Ready milestone |
| **Tasks** | Load test, WAF, Datadog dashboards, prod deploy, beta invites, smoke tests, bug bash |
| **Owners** | DevOps (lead), All |
| **Risks** | Last-minute P1 bugs; GPU cost spike |
| **DoD** | Production readiness gate passed; 100 beta users invited; on-call schedule live |

---

# DOCUMENT 8: DEVELOPMENT CHECKLISTS

## Module Checklist Template

Each module uses the same five checklists. Below: **Video Upload Orchestrator (M3.3)** as exemplar, then **index for all modules**.

### M3.3 Video Upload Orchestrator — Pre-Development

- [ ] TDD reviewed and approved (Video Upload TDD)
- [ ] OpenAPI spec for init/complete endpoints finalized
- [ ] S3 bucket policy and CORS configured in staging
- [ ] Quota limits defined per subscription tier (free: 500MB/10min)
- [ ] Error codes documented (400, 413, 422, 429)
- [ ] Security review: presigned URL expiry (15 min), content-type restriction
- [ ] Test videos prepared (small, large, corrupt, wrong MIME)

### M3.3 — Development

- [ ] `POST /videos/upload/init` implements quota check
- [ ] Presigned PUT URL generated with correct content-type binding
- [ ] Multipart upload supported for files >50MB
- [ ] `POST /videos/upload/complete` verifies checksum
- [ ] `video_metadata` row created with status `uploaded`
- [ ] `video.uploaded` event published to SQS
- [ ] Idempotency key on complete endpoint
- [ ] Unit tests: quota exceeded, invalid journal_id, expired URL
- [ ] Integration test with LocalStack S3

### M3.3 — Testing

- [ ] Upload 1MB, 50MB, 200MB test files successfully
- [ ] Reject file >500MB with 413
- [ ] Reject wrong content-type
- [ ] Complete called twice is idempotent
- [ ] Concurrent uploads for same user don't corrupt state
- [ ] Upload failure mid-stream doesn't orphan journal in bad state

### M3.3 — Deployment

- [ ] Environment variables in Secrets Manager (bucket name, KMS key)
- [ ] Helm values updated for video-service
- [ ] S3 CORS applied in production Terraform
- [ ] CloudWatch alarm on 5xx rate for upload endpoints
- [ ] Deployed to staging and smoke tested

### M3.3 — Production

- [ ] Presigned URL expiry verified in prod
- [ ] S3 access logs enabled
- [ ] Rate limiting configured (100 req/min free tier)
- [ ] Runbook: "Upload failures" documented
- [ ] Dashboard widget: upload success rate

---

## Checklist Index (All Modules)

For each module, create checklists following the template above. Status: **P** = Pre-dev, **D** = Dev, **T** = Test, **De** = Deploy, **Pr** = Prod.

| Module | P | D | T | De | Pr | TDD Required |
|--------|---|---|---|----|----|--------------|
| M1.1 Registration | ✓ | ✓ | ✓ | ✓ | ✓ | Auth TDD |
| M1.2 Login/Session | ✓ | ✓ | ✓ | ✓ | ✓ | Auth TDD |
| M1.3 OAuth | ✓ | ✓ | ✓ | ✓ | ✓ | Auth TDD |
| M2.1 Profile | ✓ | ✓ | ✓ | ✓ | ✓ | User TDD |
| M2.2 Consent | ✓ | ✓ | ✓ | ✓ | ✓ | Consent TDD |
| M3.1 Video Recorder | ✓ | ✓ | ✓ | ✓ | ✓ | Recording UX TDD |
| M3.2 Journal Entry | ✓ | ✓ | ✓ | ✓ | ✓ | Journal TDD |
| M3.3 Upload Orchestrator | ✓ | ✓ | ✓ | ✓ | ✓ | Video Upload TDD |
| M3.4 Journal List UI | ✓ | ✓ | ✓ | ✓ | ✓ | — |
| M4.1 Raw Storage | ✓ | ✓ | ✓ | ✓ | ✓ | Storage TDD |
| M4.2 Upload Validation | ✓ | ✓ | ✓ | ✓ | ✓ | Video Pipeline TDD |
| M4.3 Transcoding | ✓ | ✓ | ✓ | ✓ | ✓ | Video Pipeline TDD |
| M4.4 Playback | ✓ | ✓ | ✓ | ✓ | ✓ | Video Pipeline TDD |
| M4.5 Processing Queue | ✓ | ✓ | ✓ | ✓ | ✓ | Event Bus TDD |
| M5.1 Analysis Orchestrator | ✓ | ✓ | ✓ | ✓ | ✓ | Analysis TDD |
| M5.2 Transcription | ✓ | ✓ | ✓ | ✓ | ✓ | Transcription TDD |
| M5.3 Facial Analysis | ✓ | ✓ | ✓ | ✓ | ✓ | Emotion Analysis TDD |
| M5.4 Voice Analysis | ✓ | ✓ | ✓ | ✓ | ✓ | Voice Analysis TDD |
| M5.5 NLP Analysis | ✓ | ✓ | ✓ | ✓ | ✓ | NLP Pipeline TDD |
| M5.6 GPU Infrastructure | ✓ | ✓ | ✓ | ✓ | ✓ | ML Serving TDD |
| M6.1 Late Fusion | ✓ | ✓ | ✓ | ✓ | ✓ | Fusion Engine TDD |
| M7.1 Baseline Update | ✓ | ✓ | ✓ | ✓ | ✓ | Baseline Engine TDD |
| M7.2 Drift Detection | ✓ | ✓ | ✓ | ✓ | ✓ | Baseline Engine TDD |
| M7.3 Trend API | ✓ | ✓ | ✓ | ✓ | ✓ | Timeline API TDD |
| M8.1 Template Selector | ✓ | ✓ | ✓ | ✓ | ✓ | Insight Engine TDD |
| M8.2 LLM Generator | ✓ | ✓ | ✓ | ✓ | ✓ | Insight Engine TDD |
| M8.3 Insight Feedback | ✓ | ✓ | ✓ | ✓ | ✓ | — |
| M9.1–M9.5 UI Modules | ✓ | ✓ | ✓ | ✓ | ✓ | Frontend Architecture TDD |
| M10.1–M10.2 Notifications | ✓ | ✓ | ✓ | ✓ | ✓ | Notification TDD |
| M11.1–M11.3 Privacy | ✓ | ✓ | ✓ | ✓ | ✓ | Privacy/GDPR TDD |
| M12.1–M12.2 Onboarding | ✓ | ✓ | ✓ | ✓ | ✓ | — |
| M16.1–M16.7 Infrastructure | ✓ | ✓ | ✓ | ✓ | ✓ | Infrastructure TDD |

**Gate rule:** No module enters Development until Pre-Development checklist is 100% and TDD is approved by Tech Lead.

---

# DOCUMENT 9: TECHNICAL DESIGN DOCUMENTS (TDD) INDEX

| TDD | Purpose | Key Contents | Owner | When |
|-----|---------|--------------|-------|------|
| **Infrastructure TDD** | Define AWS topology for staging/prod | VPC layout, EKS config, RDS sizing, S3 buckets, IAM roles, Terraform module structure, cost estimates | DevOps | Before Sprint 1 |
| **CI/CD TDD** | Pipeline design | GitHub Actions stages, deploy flow, secrets injection, rollback procedure | DevOps | Before Sprint 1 |
| **Authentication TDD** | Auth system design | JWT claims, refresh rotation, OAuth flows, password policy, rate limits, threat model | BE1 | Before Sprint 2 |
| **User & Consent TDD** | Profile and consent model | Consent schema, version tracking, pipeline enforcement, audit requirements | BE2 | Before Sprint 2 |
| **Journal Service TDD** | Journal domain model | Entity relationships, streak algorithm, soft delete, tagging | BE1 | Before Sprint 3 |
| **Video Upload TDD** | Upload protocol | Presigned URL flow, multipart, checksum, quota, error handling, CORS | BE2 | Before Sprint 3 |
| **Video Pipeline TDD** | Transcode orchestration | MediaConvert templates, Lambda validation, event schema, DLQ, retry policy | BE1 + DevOps | Before Sprint 4 |
| **Event Bus TDD** | SQS/SNS design | Queue names, message schemas, idempotency, consumer groups, poison pill handling | FS | Before Sprint 4 |
| **Storage TDD** | S3 organization | Bucket layout, KMS keys, lifecycle, CORS, presigned URL policy | DevOps | Before Sprint 3 |
| **ML Serving TDD** | GPU inference infra | Docker base, model loading, batching, health checks, autoscaling, resource limits | AI + DevOps | Before Sprint 5 |
| **Transcription TDD** | Whisper pipeline | Model size, audio preprocessing, segment format, WER targets, timeout | AI | Before Sprint 5 |
| **Emotion Analysis TDD** | Facial pipeline | Frame rate, model choice, timeline format, confidence thresholds, opt-out behavior | AI | Before Sprint 6 |
| **Voice Analysis TDD** | Prosody extraction | Feature list, Praat parameters, VAD config, normalization, expected ranges | AI | Before Sprint 6 |
| **NLP Pipeline TDD** | Text analysis | Models, topic extraction approach, stress markers, fluency calculation | AI | Before Sprint 7 |
| **Analysis Orchestration TDD** | Job lifecycle | State machine, parallel execution, partial failure, reprocess flow | BE2 + AI | Before Sprint 7 |
| **Fusion Engine TDD** | Multimodal fusion | Weight table, missing modality handling, wellness vector schema, pseudocode | AI | Before Sprint 8 |
| **Baseline Engine TDD** | Personal baselines | EWMA parameters, confidence formula, Z-score thresholds, drift types | AI | Before Sprint 8 |
| **Insight Engine TDD** | Insight generation | Template catalog, LLM prompts, guardrails, blocklist, confidence scoring | AI | Before Sprint 9 |
| **Timeline API TDD** | Trend queries | SQL queries, caching, aggregation windows, baseline band calculation | BE1 | Before Sprint 9 |
| **Notification TDD** | Notification delivery | Channels, templates, quiet hours, preference schema, SES config | BE2 | Before Sprint 11 |
| **Privacy/GDPR TDD** | Data rights | Export format, deletion cascade order, retention, audit log scope | BE1 + Legal | Before Sprint 11 |
| **Frontend Architecture TDD** | Web app structure | Folder layout, state management, API client, auth middleware, error handling | FE1 | Before Sprint 2 |
| **Recording UX TDD** | Video capture UX | Browser support matrix, fallback behavior, accessibility, mobile layout | Designer + FE1 | Before Sprint 4 |
| **Security TDD** | Platform security | Encryption, RBAC, audit logging, WAF rules, pen test scope | FS + DevOps | Before Sprint 11 |
| **Observability TDD** | Monitoring plan | Metrics list, alert thresholds, dashboards, log retention, PII scrubbing | DevOps | Before Sprint 12 |

**Process:** TDDs stored in `docs/tdd/`; reviewed in architecture review (30 min); approved by Tech Lead before sprint planning.

---

# DOCUMENT 10: REPOSITORY IMPLEMENTATION PLAN

## 10.1 Exact Creation Order

> **College (Flutter + Firebase):** Follow **`SOLENNE-Zero-Budget-Build-Plan.md`** repo structure (`mobile/`, `worker/`, `firebase/`) instead of steps below. Paid AWS order remains valid for funded build.

### Week 1 — Day 1–2: Repository Bootstrap (Paid AWS path)

```
1. solenne/ (root)
2. solenne/.github/workflows/ci.yml
3. solenne/turbo.json
4. solenne/package.json (workspace root)
5. solenne/packages/shared-types/package.json
6. solenne/packages/shared-types/src/index.ts
7. solenne/docker-compose.yml
8. solenne/README.md
9. solenne/.env.example
10. solenne/infra/terraform/environments/staging/main.tf
```

### Week 1 — Flutter + Firebase bootstrap (College path)

```
1. solenne/ (root)
2. firebase/ — firebase.json, firestore.rules, storage.rules
3. mobile/ — flutter create . ; flutterfire configure
4. mobile/lib/main.dart, app.dart, core/router/
5. mobile/lib/features/auth/ — login, register
6. worker/ — main.py, firebase_client.py, requirements.txt
7. .github/workflows/flutter-ci.yml
8. README.md — Firebase setup + worker instructions
9. .gitignore — serviceAccountKey.json
```

### Week 1 — Day 3–5: Infrastructure + Service Scaffolds

```
11. infra/terraform/modules/vpc/
12. infra/terraform/modules/eks/
13. infra/terraform/modules/rds/
14. infra/terraform/modules/s3/
15. infra/terraform/modules/kms/
16. services/auth-service/package.json
17. services/auth-service/src/main.ts
18. services/auth-service/src/health.controller.ts
19. services/user-service/ (mirror scaffold)
20. services/journal-service/ (mirror scaffold)
21. services/video-service/ (mirror scaffold)
22. infra/helm/solenne/Chart.yaml
23. infra/helm/solenne/values-staging.yaml
24. infra/docker/Dockerfile.service (shared template)
25. .github/workflows/deploy-staging.yml
```

### Week 2: Migrations + Auth

```
26. migrations/postgres/001_users_and_auth.sql
27. migrations/postgres/002_user_preferences.sql
28. migrations/postgres/003_consent_records.sql
29. services/auth-service/src/auth.controller.ts
30. services/auth-service/src/auth.service.ts
31. services/auth-service/src/jwt.strategy.ts
32. services/user-service/src/users.controller.ts
33. services/user-service/src/consent.controller.ts
34. packages/api-client/src/client.ts
35. apps/web/package.json (Next.js init)
36. apps/web/app/layout.tsx
37. apps/web/app/providers.tsx
38. apps/web/lib/api/client.ts
39. apps/web/app/(auth)/login/page.tsx
40. apps/web/app/(auth)/register/page.tsx
```

### Week 3–4: Journal + Video Backend

```
41. migrations/postgres/004_journal_entries.sql
42. migrations/postgres/005_journal_tags.sql
43. migrations/postgres/006_video_metadata.sql
44. services/journal-service/src/journals.controller.ts
45. services/journal-service/src/streaks.service.ts
46. services/video-service/src/upload.controller.ts
47. services/video-service/src/s3.service.ts
48. infra/terraform/modules/s3/cors.tf
```

### Week 5–6: Frontend Recording + Transcode

```
49. apps/web/components/journal/VideoRecorder.tsx
50. apps/web/components/journal/UploadProgress.tsx
51. apps/web/app/(dashboard)/journal/record/page.tsx
52. apps/web/app/(dashboard)/page.tsx (journal list stub)
53. services/video-service/src/transcode.service.ts
54. infra/lambda/upload-validator/index.ts
55. infra/terraform/modules/mediaconvert/
```

### Week 7–8: Processing Events + Playback

```
56. infra/terraform/modules/sqs/
57. services/video-service/src/events/publisher.ts
58. services/video-service/src/playback.controller.ts
59. apps/web/components/journal/JournalCard.tsx
60. apps/web/app/(dashboard)/journal/[id]/page.tsx
```

### Week 9–10: AI Services

```
61. services/ai-inference-service/Dockerfile.gpu
62. services/ai-inference-service/src/main.py (or Node gRPC)
63. ml/models/whisper/ (model config)
64. ml/pipelines/inference/transcribe.py
65. migrations/postgres/007_transcripts.sql
66. migrations/postgres/008_analysis_jobs.sql
67. services/analysis-service/src/orchestrator.ts
68. services/analysis-service/src/consumers/video-processed.consumer.ts
```

### Week 11–12: Modality Workers

```
69. ml/pipelines/inference/face_emotion.py
70. ml/pipelines/inference/voice_features.py
71. ml/pipelines/inference/nlp_sentiment.py
72. migrations/postgres/009_facial_metrics.sql
73. migrations/postgres/010_voice_metrics.sql
74. migrations/postgres/011_emotion_metrics.sql
75. services/analysis-service/src/workers/ (face, voice, nlp)
```

### Week 13–14: Fusion + Baseline

```
76. ml/pipelines/fusion/late_fusion.py
77. migrations/postgres/012_feature_vectors.sql
78. migrations/postgres/013_baselines.sql
79. migrations/postgres/014_behavioral_events.sql
80. services/analysis-service/src/baseline/baseline_engine.py
81. services/analysis-service/src/baseline/drift_detector.py
```

### Week 15–16: Insights + Trends

```
82. services/insight-service/src/template_selector.ts
83. services/insight-service/src/llm_generator.ts
84. services/insight-service/src/guardrails.ts
85. migrations/postgres/015_insights.sql
86. migrations/postgres/016_insight_feedback.sql
87. services/analysis-service/src/timeline/trends.controller.ts
88. apps/web/app/(dashboard)/timeline/page.tsx
89. apps/web/app/(dashboard)/insights/page.tsx
90. apps/web/components/insights/InsightCard.tsx
91. apps/web/components/insights/EvidenceDrawer.tsx
```

### Week 17–20: UI Completion

```
92. apps/web/app/(dashboard)/layout.tsx (AppShell)
93. apps/web/components/trends/TrendChart.tsx
94. apps/web/components/trends/CalendarHeatmap.tsx
95. apps/web/components/journal/EmotionTimeline.tsx
96. apps/web/app/(onboarding)/consent/page.tsx
97. apps/web/app/(onboarding)/tutorial/page.tsx
98. apps/web/app/(dashboard)/settings/page.tsx
99. apps/web/app/(dashboard)/settings/privacy/page.tsx
```

### Week 21–22: Notifications + Privacy

```
100. services/notification-service/
101. migrations/postgres/017_notifications.sql
102. migrations/postgres/018_notification_preferences.sql
103. migrations/postgres/019_audit_logs.sql
104. services/user-service/src/export/export.worker.ts
105. services/user-service/src/deletion/deletion.worker.ts
```

### Week 23–24: Production

```
106. infra/terraform/environments/production/
107. infra/helm/solenne/values-prod.yaml
108. .github/workflows/deploy-production.yml
109. docs/runbooks/
110. tests/e2e/full-journey.spec.ts
111. tests/load/upload.k6.js
```

## 10.2 Roadmap Summary by Layer

| Layer | Order | Key Deliverables |
|-------|-------|------------------|
| **Infrastructure** | W1 → W24 | Terraform → EKS → GPU → SQS → Prod |
| **Database** | W2 → W22 | Migrations 001–019 sequential |
| **Backend Services** | W2 → W22 | auth → user → journal → video → analysis → insight → notification |
| **AI/ML** | W9 → W16 | Whisper → face → voice → NLP → fusion → baseline |
| **Frontend (paid web)** | W2 → W20 | auth → recorder → list → analysis → trends → insights → settings |
| **Flutter (college)** | W1 → W22 | Firebase init → auth → consent → camera → upload → analysis UI → trends → insights → FCM |
| **API** | W2 → W22 | Follows SAD §25.4 order exactly |

---

# DOCUMENT 11: MASTER IMPLEMENTATION PLAN

## 11.1 Executive Summary

SOLENNE MVP ships in **12 two-week sprints (24 weeks)** with an **8-person engineering team**. The critical path runs from infrastructure → auth → video upload → transcode → AI pipeline → fusion → baseline → insights → privacy → beta launch. MVP deliberately uses **SQS over Kafka**, **Whisper medium over large-v3**, and **Z-score-only drift detection** to reduce operational complexity while preserving core product value: daily video journal → multimodal analysis → personalized trends → explainable insights.

## 11.2 Products → Phases Map

| Product | Phase | Sprint |
|---------|-------|--------|
| P16 Infrastructure | 0 | 1 |
| P1 Auth | 1 | 2 |
| P2 User/Consent | 1 | 2 |
| P3 Video Journal | 2 | 3–4 |
| P4 Video Pipeline | 3 | 4–5 |
| P5 AI Analysis | 4 | 5–7 |
| P6 Fusion | 5 | 8 |
| P7 Baseline | 5 | 8 |
| P8 Insights | 6 | 9 |
| P9 Dashboard/UI | 7 | 9–10 |
| P10 Notifications | 8 | 11 |
| P11 Privacy | 9 | 11 |
| P12 Onboarding | 7 | 10 |
| Beta Launch | 10 | 12 |

## 11.3 Epics → Sprints Map

| Sprint | Epics |
|--------|-------|
| 1 | E1 |
| 2 | E2, E3 |
| 3 | E4, E5 (BE) |
| 4 | E5 (FE), E6, E7 |
| 5 | E8, E9 |
| 6 | E10, E11 |
| 7 | E12, E13 |
| 8 | E14, E15 |
| 9 | E16, E17, E20 (partial) |
| 10 | E18, E19, E21 |
| 11 | E22, E23 |
| 12 | E24, E25 |

## 11.4 Team Allocation (Steady State)

| Role | Primary Ownership | Secondary |
|------|-------------------|-----------|
| **BE1** | journal-service, trend API, privacy/export | analysis integration |
| **BE2** | video-service, analysis orchestrator, notifications | insight-service |
| **FE1** | dashboard, insights UI, timeline charts | onboarding |
| **FE2** | video recorder, journal review, settings/privacy UI | app shell |
| **AI** | all ml/ pipelines, fusion, baseline, insight LLM | analysis workers |
| **FS** | shared-types, api-client, event wiring, security review | auth assist |
| **DevOps** | all infra/, CI/CD, GPU, observability | Lambda functions |
| **Designer** | all UX flows, design system, wireframe → component specs | user testing |

## 11.5 Milestones & Dates (from Sprint 1 start)

| ID | Milestone | Sprint | Week | Gate |
|----|-----------|--------|------|------|
| M0 | Dev Environment | 1 | 2 | CI green, staging up |
| M1 | First Upload | 4 | 8 | Record + upload + list |
| M2 | First Analysis | 7 | 14 | Transcript + 3 modalities |
| M3 | First Trend | 9 | 18 | 7-day chart + baseline band |
| M4 | First Insight | 9 | 18 | Insight + evidence drawer |
| M5 | Beta Ready | 11 | 22 | GDPR export/delete pass |
| M6 | Beta Launch | 12 | 24 | 100 users, SLA 95% |

## 11.6 Dependency Graph (Critical Path)

```
Infra → Auth → Journal → Upload → Transcode → SQS
                                      ↓
                              GPU + Whisper
                                      ↓
                         Face ∥ Voice ∥ NLP
                                      ↓
                               Orchestrator
                                      ↓
                                  Fusion
                                      ↓
                                 Baseline
                                      ↓
                          Trends ∥ Insights
                                      ↓
                              Dashboard UX
                                      ↓
                          Notifications + Privacy
                                      ↓
                              Prod Launch
```

## 11.7 Deliverables by Milestone

| Milestone | User-Facing Deliverable | Engineering Deliverable |
|-----------|-------------------------|-------------------------|
| M0 | — | Staging URL, local dev |
| M1 | "I recorded my first journal" | Upload pipeline E2E |
| M2 | "I see what AI found in my video" | Full analysis pipeline |
| M3 | "I see my emotional trend" | Baseline + trend API + chart |
| M4 | "I got a personalized insight" | Insight engine + evidence UI |
| M5 | "I trust this with my data" | Export/delete + privacy dashboard |
| M6 | "I'm using SOLENNE daily" | Beta launch + monitoring |

## 11.8 Production Readiness Gates

### Gate 1 — End of Sprint 4 (First Upload)

- [ ] Upload success rate >99% in staging
- [ ] Transcode completes <3 min for 3-min video
- [ ] No P0/P1 bugs in recording flow

### Gate 2 — End of Sprint 7 (First Analysis)

- [ ] Analysis SLA <5 min for 95% of entries
- [ ] Consent opt-out verified for face modality
- [ ] Model outputs include confidence scores

### Gate 3 — End of Sprint 9 (Insights)

- [ ] Insights suppressed when baseline confidence <0.6
- [ ] Zero clinical terms in 100-insight sample
- [ ] Evidence drawer links to source journals

### Gate 4 — End of Sprint 11 (Beta Ready)

- [ ] GDPR export E2E pass
- [ ] Delete cascade verified (DB + S3)
- [ ] Privacy Policy + ToS published
- [ ] Pen test: no critical findings
- [ ] Medical disclaimer on all insight screens

### Gate 5 — End of Sprint 12 (Launch)

- [ ] Load test 2× expected beta traffic
- [ ] Datadog dashboards + PagerDuty alerts live
- [ ] On-call runbook for top 5 incidents
- [ ] Rollback tested in production
- [ ] 100 beta users onboarded
- [ ] Legal sign-off on user-facing copy

## 11.9 Risk Register (Top 10)

| # | Risk | Impact | Mitigation | Owner |
|---|------|--------|------------|-------|
| 1 | GPU capacity/availability | Analysis SLA miss | Start with 1 node; Deepgram fallback with consent | DevOps |
| 2 | Whisper latency too high | SLA miss | Use medium model; limit video to 5 min at MVP | AI |
| 3 | Safari recording failures | User churn | Browser matrix testing; audio-only fallback post-MVP | FE |
| 4 | LLM clinical language | Legal/reputation | Blocklist + template-only fallback | AI |
| 5 | Baseline misleading early users | Trust loss | Show confidence; suppress insights <0.6 | AI |
| 6 | GDPR delete incomplete | Compliance failure | Deletion integration test suite; S3 lifecycle audit | BE1 |
| 7 | Scope creep (web app, billing, Cloud Functions ML) | MVP delay | Flutter+Firebase only; worker stays local | TPM |
| 8 | OAuth Apple delay | Activation friction | Google-only at MVP; Apple Sprint 11 if ready | BE |
| 9 | Team bottleneck on AI engineer | Pipeline delay | FS upskilled on orchestrator; modular workers | Tech Lead |
| 10 | Cost overrun on GPU | Runway impact | Budget alerts; Whisper medium; 5-min max video | DevOps |

## 11.10 Post-MVP Roadmap Pointer

After Sprint 12, follow SAD §20 Months 7–12: beta scaling → mobile apps → advanced AI (micro-expressions, Isolation Forest) → premium billing → enterprise admin → GA at 100K capacity.

---

**END OF ENGINEERING EXECUTION PLAN**

*SOLENNE Engineering Execution Plan v1.0.0 — Derived from SOLENNE-SAD-PRD.md v1.0.0*
