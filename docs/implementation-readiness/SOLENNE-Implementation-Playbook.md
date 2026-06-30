# SOLENNE — Implementation Playbook

**Version:** 1.0.0  
**Date:** June 17, 2026  
**Audience:** Engineering team + AI coding assistants  
**Build path:** Flutter + Firebase Spark ($0) + Python ML worker  
**Team:** Rajeev · Shambhavi · Yanish (3-person rotation)

> This document consolidates everything needed to implement SOLENNE without re-reading five separate planning docs. For production AWS architecture, see `SOLENNE-SAD-PRD.md`. For week-by-week tracking, see `SOLENNE-Weekly-Tracker.md`.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Tech Stack & Pinned Versions](#2-tech-stack--pinned-versions)
3. [Requirement Analysis](#3-requirement-analysis)
4. [System Architecture](#4-system-architecture)
5. [Repository Structure](#5-repository-structure)
6. [Firestore Data Model](#6-firestore-data-model)
7. [Lifecycle Stages](#7-lifecycle-stages)
8. [Analysis Pipeline Specification](#8-analysis-pipeline-specification)
9. [Module Implementation Order](#9-module-implementation-order)
10. [Security & Compliance](#10-security--compliance)
11. [Observability & Limits](#11-observability--limits)
12. [AI Session Protocol](#12-ai-session-protocol)
13. [Definition of Done (Global)](#13-definition-of-done-global)
14. [Post-MVP Migration Map](#14-post-mvp-migration-map)

---

## 1. Executive Summary

### What SOLENNE Is

A **Flutter mobile app** where users record 2–3 minute daily video journals. A **Python worker** on a team laptop extracts face, voice, and text signals, fuses them into a personal wellness fingerprint, compares against an **EWMA baseline**, and generates **template-based insights**. Data lives in **Firebase** (Auth, Firestore, Storage, FCM).

### What Success Looks Like (MVP)

| Milestone | User outcome | Week (approx.) |
|-----------|--------------|----------------|
| M0 | Team can clone repo and run app | 2 |
| M1 | Record → upload → journal list | 8 |
| M2 | Upload → transcript + 3 modalities | 14 |
| M3 | 7-day trend chart + baseline band | 18 |
| M4 | ≥1 insight with evidence drawer | 18 |
| M5 | Delete account + privacy pass | 22 |
| M6 | Demo-ready for class | 24 |

### Five Major Modules (Ownership)

| Module | Owner (Turn) | Duration | Depends on |
|--------|--------------|----------|------------|
| **M1** Identity & First Run | Rajeev (1) | 4–5 wks | — |
| **M2** Video Journal | Shambhavi (2) | 5–6 wks | M1 |
| **M3** AI Analysis Engine | Yanish (3) | 6–7 wks | M2 |
| **M4** Dashboard & Insights | Rajeev (4) | 4–5 wks | M3 |
| **M5** Trust, Notifications & Launch | Shambhavi (5) | 3–4 wks | M4 |

**Rule:** One person owns one module end-to-end. No splitting modules across people.

---

## 2. Tech Stack & Pinned Versions

### 2.1 Stack Overview

| Layer | Technology | Role |
|-------|------------|------|
| **Mobile client** | Flutter 3.24+ / Dart 3.5+ | iOS + Android UI |
| **State management** | flutter_riverpod 2.5.x | App state, providers |
| **Routing** | go_router 14.x | Deep links, auth guards |
| **Backend (BaaS)** | Firebase Spark (free) | Auth, DB, storage, push |
| **ML worker** | Python 3.11 | Poll jobs, run pipeline |
| **Media** | ffmpeg CLI | Audio extract, transcode |
| **Transcription** | faster-whisper `small` | CPU transcription |
| **Face** | MediaPipe Face Mesh | Landmarks, emotion proxy |
| **Voice** | librosa 0.10.x | Pitch, energy, pauses |
| **NLP** | VADER (vaderSentiment) | Sentiment, stress markers |
| **Charts** | fl_chart 0.69.x | 7-day trend lines |
| **CI** | GitHub Actions | Flutter analyze/test/build |

### 2.2 Development Tooling (Install Before M1)

| Tool | Minimum Version | Purpose |
|------|-----------------|---------|
| Flutter SDK | 3.24.0 | Mobile app |
| Dart SDK | 3.5.0 | Bundled with Flutter |
| Python | 3.11.x | ML worker |
| pip | 24.x | Python packages |
| ffmpeg | 6.x | Media processing (system PATH) |
| Firebase CLI | 13.x | Deploy rules, emulators |
| FlutterFire CLI | 1.0.x | `flutterfire configure` |
| Git | 2.x | Version control |
| Xcode | 15+ (macOS, iOS) | iOS builds |
| Android Studio | 2024.x | Android SDK, emulator |
| CocoaPods | 1.15+ | iOS dependencies |

### 2.3 Flutter Dependencies (`mobile/pubspec.yaml`)

Use these exact major versions. Patch updates are OK within the same minor.

```yaml
name: solenne
description: SOLENNE — Intelligent Video Journal
publish_to: 'none'
version: 0.1.0+1

environment:
  sdk: '>=3.5.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # Firebase (keep versions aligned — use flutter pub upgrade carefully)
  firebase_core: ^3.8.0
  firebase_auth: ^5.3.0
  cloud_firestore: ^5.5.0
  firebase_storage: ^12.3.0
  firebase_messaging: ^15.1.0
  firebase_analytics: ^11.3.0
  firebase_crashlytics: ^4.1.0

  # Auth
  google_sign_in: ^6.2.0

  # Media
  camera: ^0.11.0+2
  video_player: ^2.9.2
  path_provider: ^2.1.4
  permission_handler: ^11.3.1

  # App architecture
  flutter_riverpod: ^2.6.1
  go_router: ^14.6.0

  # UI / utils
  fl_chart: ^0.69.2
  intl: ^0.19.0
  uuid: ^4.5.1
  connectivity_plus: ^6.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  mockito: ^5.4.4
  build_runner: ^2.4.13
  integration_test:
    sdk: flutter
```

### 2.4 Python Worker Dependencies (`worker/requirements.txt`)

```txt
# Firebase
firebase-admin==6.6.0
google-cloud-firestore==2.19.0
google-cloud-storage==2.18.2

# ML / media
faster-whisper==1.1.0
mediapipe==0.10.18
librosa==0.10.2
vaderSentiment==3.3.2
numpy==1.26.4
opencv-python-headless==4.10.0.84
scipy==1.14.1

# Utils
python-dotenv==1.0.1
Pillow==11.0.0
Jinja2==3.1.4

# Testing
pytest==8.3.3
pytest-mock==3.14.0
```

**System dependency:** `ffmpeg` and `ffprobe` must be on PATH. Verify with `ffmpeg -version`.

**Optional (Apple Silicon):** Use `whisper` with `int8` compute type in faster-whisper for speed.

### 2.5 Firebase Services (Spark Plan)

| Service | Enabled | Notes |
|---------|---------|-------|
| Authentication | Email/Password + Google | Apple Sign-In post-MVP |
| Cloud Firestore | Native mode | Deploy rules before any client writes |
| Firebase Storage | Default bucket | 100 MB max per upload (rules) |
| Cloud Messaging | FCM | iOS needs APNs key in Firebase Console |
| Analytics | Optional | Free |
| Crashlytics | Optional | Free |
| Cloud Functions | **Disabled for MVP** | Avoid Blaze billing |
| Blaze plan | **Not required** | Worker uses Admin SDK from laptop |

### 2.6 Firebase Spark Limits (Design Constraints)

| Resource | Free limit | MVP implication |
|----------|------------|-----------------|
| Firestore storage | 1 GiB | Store aggregates, not per-frame arrays |
| Firestore reads | 50,000/day | Paginate journals; avoid broad listeners |
| Firestore writes | 20,000/day | ~10–20 writes per journal lifecycle |
| Storage | 5 GB total | ~100 videos @ 50 MB; enforce 3-min cap |
| Storage download | 1 GB/day | Cache thumbnails locally |
| Auth | Unlimited | — |
| FCM | Free | — |

**Target demo scale:** 5–20 users. Well within Spark limits.

### 2.7 Secrets & Files (Never Commit)

| File | Location | Git |
|------|----------|-----|
| `serviceAccountKey.json` | `worker/` | **GITIGNORE** |
| `google-services.json` | `mobile/android/app/` | OK in private repo |
| `GoogleService-Info.plist` | `mobile/ios/Runner/` | OK in private repo |
| `firebase_options.dart` | `mobile/lib/` | Generated by FlutterFire |
| `.env` | `worker/` | **GITIGNORE** |

Required `.gitignore` entries:

```
worker/serviceAccountKey.json
worker/.env
**/*.p12
.env
*.local
```

---

## 3. Requirement Analysis

### 3.1 Functional Requirements (MVP — College Path)

#### FR-1: Identity & Authentication

| ID | Requirement | Priority | Module |
|----|-------------|----------|--------|
| FR-1.1 | Email/password registration and login | P0 | M1 |
| FR-1.2 | Google Sign-In | P0 | M1 |
| FR-1.3 | Password reset via email | P0 | M1 |
| FR-1.4 | Auth-guarded routes (logged-out → login) | P0 | M1 |
| FR-1.5 | Logout clears session | P0 | M1 |
| FR-1.6 | MFA | Won't have | — |
| FR-1.7 | Apple Sign-In | Should have (iOS + Google rule) | Post-M1 |

#### FR-2: Onboarding & Consent

| ID | Requirement | Priority | Module |
|----|-------------|----------|--------|
| FR-2.1 | Multi-step onboarding wizard | P0 | M1 |
| FR-2.2 | Terms of Service + Privacy Policy acceptance (versioned) | P0 | M1 |
| FR-2.3 | 18+ age gate | P0 | M1 |
| FR-2.4 | Granular consent: face / voice / text (independent toggles) | P0 | M1 |
| FR-2.5 | Wellness goal selection | P0 | M1 |
| FR-2.6 | Timezone capture | P0 | M1 |
| FR-2.7 | Recording tutorial + medical disclaimer | P0 | M1 |
| FR-2.8 | Skip onboarding for returning users with completed profile | P0 | M1 |
| FR-2.9 | Baseline progress indicator stub | P0 | M1 (stub) → M4 (real) |

#### FR-3: User Profile

| ID | Requirement | Priority | Module |
|----|-------------|----------|--------|
| FR-3.1 | View/edit display name | P0 | M1 |
| FR-3.2 | View/edit timezone and wellness goal | P0 | M1 |
| FR-3.3 | Profile linked from settings | P0 | M1 / M5 |

#### FR-4: Video Journal

| ID | Requirement | Priority | Module |
|----|-------------|----------|--------|
| FR-4.1 | Camera + mic permission flow | P0 | M2 |
| FR-4.2 | Record with countdown and visible timer | P0 | M2 |
| FR-4.3 | Auto-stop at 3 minutes | P0 | M2 |
| FR-4.4 | Local preview before upload | P0 | M2 |
| FR-4.5 | Re-record before submit | P0 | M2 |
| FR-4.6 | Upload to Firebase Storage with progress | P0 | M2 |
| FR-4.7 | Retry failed upload | P0 | M2 |
| FR-4.8 | Journal list with thumbnails and status badges | P0 | M2 |
| FR-4.9 | Video playback from Storage | P0 | M2 |
| FR-4.10 | Delete journal (Firestore + Storage) | P0 | M2 |
| FR-4.11 | Daily streak counter | P0 | M2 |
| FR-4.12 | Create `analysis_jobs` doc on upload complete | P0 | M2 |
| FR-4.13 | Optional tags (#work, #family) | Should have | M2 |
| FR-4.14 | Offline record + sync later | Could have | Post-MVP |
| FR-4.15 | Audio-only mode | Won't have | — |

#### FR-5: AI Analysis

| ID | Requirement | Priority | Module |
|----|-------------|----------|--------|
| FR-5.1 | Worker polls `analysis_jobs` where status = `queued` | P0 | M3 |
| FR-5.2 | Download video, extract audio (ffmpeg) | P0 | M3 |
| FR-5.3 | Transcription (faster-whisper small) | P0 | M3 |
| FR-5.4 | Face analysis (MediaPipe) — skip if consent off | P0 | M3 |
| FR-5.5 | Voice analysis (librosa) | P0 | M3 |
| FR-5.6 | NLP (VADER) | P0 | M3 |
| FR-5.7 | Late fusion → wellness metrics on journal doc | P0 | M3 |
| FR-5.8 | EWMA baseline update in `baselines/` | P0 | M3 |
| FR-5.9 | Template insight generation | P0 | M3 |
| FR-5.10 | Real-time status in app (`analysisStatus` listener) | P0 | M3 |
| FR-5.11 | Results UI: transcript, modality cards, confidence | P0 | M3 |
| FR-5.12 | Congruence score (cross-modal agreement) | P0 | M3 |
| FR-5.13 | Low-quality recording warning | Should have | M3 |
| FR-5.14 | Re-process after consent change | Could have | Post-MVP |

#### FR-6: Dashboard & Insights

| ID | Requirement | Priority | Module |
|----|-------------|----------|--------|
| FR-6.1 | Home dashboard: streak, latest journal, record CTA | P0 | M4 |
| FR-6.2 | 7-day valence/arousal chart (fl_chart) | P0 | M4 |
| FR-6.3 | Baseline confidence band overlay | P0 | M4 |
| FR-6.4 | Baseline progress ("X/7 entries") | P0 | M4 |
| FR-6.5 | Insight list with unread badge | P0 | M4 |
| FR-6.6 | Insight detail + evidence drawer (source journals) | P0 | M4 |
| FR-6.7 | Helpful / not helpful feedback | P0 | M4 |
| FR-6.8 | Suppress insights when baseline confidence < 0.6 | P0 | M4 |
| FR-6.9 | 30/90-day trends | Won't have | Post-MVP |
| FR-6.10 | Calendar heatmap | Should have | Post-MVP |

#### FR-7: Notifications & Trust

| ID | Requirement | Priority | Module |
|----|-------------|----------|--------|
| FR-7.1 | FCM push on analysis complete | P0 | M5 |
| FR-7.2 | Save FCM token to user doc | P0 | M5 |
| FR-7.3 | In-app notification list + deep links | P0 | M5 |
| FR-7.4 | Privacy dashboard (what's stored) | P0 | M5 |
| FR-7.5 | Revoke modality consent (affects next analysis) | P0 | M5 |
| FR-7.6 | Delete all user data | P0 | M5 |
| FR-7.7 | Delete account (Auth + Firestore + Storage) | P0 | M5 |
| FR-7.8 | Settings: password change, about, disclaimer | P0 | M5 |
| FR-7.9 | GDPR automated export ZIP | Won't have (manual console export for demo) | — |

### 3.2 Non-Functional Requirements

| ID | Category | Requirement | Target |
|----|----------|-------------|--------|
| NFR-1 | Performance | Analysis completion (3-min video, laptop) | ≤ 8 min (p95) |
| NFR-2 | Performance | App cold start | < 3 s on mid-range device |
| NFR-3 | Performance | Dashboard load | < 2 s with 7 journals |
| NFR-4 | Reliability | Upload retry on network failure | 3 retries with backoff |
| NFR-5 | Security | User data isolation | Firestore + Storage rules enforced |
| NFR-6 | Security | Worker-only job updates | Clients cannot update `analysis_jobs` |
| NFR-7 | Privacy | Consent enforced in pipeline | Skip modalities when opted out |
| NFR-8 | Compliance | Medical disclaimer visible | Onboarding + insights |
| NFR-9 | Compliance | Not a medical device | No diagnostic language |
| NFR-10 | Maintainability | Module handoff doc | `docs/handoffs/M{N}.md` per module |
| NFR-11 | Cost | Monthly Firebase bill | $0 on Spark |
| NFR-12 | Accessibility | Minimum tap targets | 44×44 pt |
| NFR-13 | Localization | English only at MVP | — |

### 3.3 User Story Traceability (MVP Subset)

From 120 stories in SAD-PRD, these are **in scope** for college MVP:

| Epic | Stories | Module |
|------|---------|--------|
| Onboarding | 1, 2, 4, 5, 6, 7, 9, 11, 12, 13, 15 | M1 |
| Journaling | 17, 18, 19, 20, 22, 25, 31, 35 | M2 |
| Analysis | 36, 37, 40, 42, 43, 47, 49 | M3 |
| Trends | 51, 55, 64 | M4 |
| Insights | 66, 67, 68, 69, 71, 78, 83, 80, 110 | M3/M4 |
| Notifications | 86, 87, 93, 94, 95 | M5 |
| Privacy | 96, 99, 105, 110, 118 | M5 |
| Settings | 111, 114, 118 | M5 |

---

## 4. System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Flutter App (iOS / Android)                                    │
│  camera · firebase_auth · cloud_firestore · firebase_storage    │
│  firebase_messaging · fl_chart · go_router · riverpod           │
└────────────────────────────┬────────────────────────────────────┘
                             │ Client SDK (authenticated)
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  Firebase Spark                                                 │
│  Auth │ Firestore (users, journals, jobs, insights, baselines) │
│  Storage (users/{uid}/videos/{journalId}/) │ FCM               │
│  Security Rules: user-scoped read/write                         │
└────────────────────────────┬────────────────────────────────────┘
                             │ Admin SDK (service account)
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  Python Worker (team laptop)                                    │
│  poll jobs → download → ffmpeg → whisper → mediapipe → librosa  │
│  → VADER → fusion → baseline → insights → write Firestore       │
│  → optional FCM push                                            │
└─────────────────────────────────────────────────────────────────┘
```

### Data Flow (Happy Path)

1. User records video → local file.
2. App creates `users/{uid}/journals/{journalId}` with `analysisStatus: uploading`.
3. App uploads to `users/{uid}/videos/{journalId}/video.mp4`.
4. On complete: update journal `analysisStatus: queued`; create `analysis_jobs/{jobId}`.
5. Worker claims job → `processing` → runs pipeline → writes metrics to journal doc.
6. Worker updates job `complete`; sets journal `analysisStatus: complete`.
7. Worker updates baselines; may create insight doc.
8. App listener refreshes UI; FCM notifies user (M5).

---

## 5. Repository Structure

```
solenne/
├── mobile/                         # Flutter app
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app.dart
│   │   ├── core/
│   │   │   ├── theme/
│   │   │   ├── router/             # go_router + auth redirect
│   │   │   └── constants/
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   ├── onboarding/
│   │   │   ├── journal/
│   │   │   ├── analysis/
│   │   │   ├── dashboard/
│   │   │   ├── timeline/
│   │   │   ├── insights/
│   │   │   └── settings/
│   │   ├── models/
│   │   └── services/               # firestore, storage, fcm
│   ├── test/
│   ├── integration_test/
│   ├── pubspec.yaml
│   └── firebase_options.dart
├── worker/
│   ├── main.py                     # poll loop
│   ├── firebase_client.py
│   ├── pipeline/
│   │   ├── transcode.py
│   │   ├── transcribe.py
│   │   ├── face.py
│   │   ├── voice.py
│   │   ├── nlp.py
│   │   ├── fusion.py
│   │   ├── baseline.py
│   │   └── insights.py
│   ├── tests/
│   ├── requirements.txt
│   └── .env.example
├── firebase/
│   ├── firestore.rules
│   ├── storage.rules
│   ├── firestore.indexes.json
│   └── firebase.json
├── docs/
│   └── implementation-readiness/   # THIS FOLDER
├── .github/workflows/
│   ├── flutter-ci.yml
│   └── worker-ci.yml
├── .gitignore
└── README.md
```

### File Creation Order (Week 1 Bootstrap)

1. Root `.gitignore`, `README.md`
2. `firebase/` rules + `firebase.json`
3. `flutter create mobile` → `flutterfire configure`
4. `mobile/lib/main.dart`, `app.dart`, `core/router/app_router.dart`
5. `mobile/lib/features/auth/` (login, register)
6. `worker/main.py`, `firebase_client.py`, `requirements.txt`
7. `.github/workflows/flutter-ci.yml`
8. Deploy rules: `firebase deploy --only firestore:rules,storage`

---

## 6. Firestore Data Model

### 6.1 Collections

```
users/{userId}
  Fields: email, displayName, timezone, wellnessGoal, onboardingComplete,
          fcmToken, createdAt, updatedAt, streakCount, lastJournalDate

users/{userId}/consents/{consentId}
  Fields: type (face|voice|text|terms|privacy|age), granted, version, createdAt

users/{userId}/journals/{journalId}
  Fields: recordedAt, durationSeconds, storagePath, thumbnailPath,
          analysisStatus, processingStep, tags[], streakDay
  Nested (written by worker):
    transcript: { text, wordCount, segments[] }
    facial: { valence, arousal, emotionProbs, confidence, faceDetected }
    voice: { energyMean, pitchMean, speakingRate, pauseRatio, confidence }
    nlp: { sentimentValence, stressScore, topics[], confidence }
    fused: { overallValence, overallArousal, congruence, engagement, expressiveness }
    qualityScore: number (0-1)

users/{userId}/baselines/{metricName}
  Fields: ewmaMean, ewmaVariance, sampleCount, confidence, updatedAt

users/{userId}/insights/{insightId}
  Fields: text, confidence, evidence{}, templateId, isRead, helpful,
          createdAt, suppressedReason

analysis_jobs/{jobId}
  Fields: userId, journalId, status, processingStep, createdAt,
          startedAt, completedAt, errorMessage, retryCount
```

### 6.2 `analysisStatus` State Values

| Value | Set by | Meaning |
|-------|--------|---------|
| `uploading` | Flutter | Upload in progress |
| `queued` | Flutter | Upload done; job created |
| `processing` | Worker | Pipeline running |
| `complete` | Worker | All metrics written |
| `failed` | Worker | Unrecoverable error |

### 6.3 Required Firestore Indexes

```json
{
  "indexes": [
    {
      "collectionGroup": "journals",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "recordedAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "analysis_jobs",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "ASCENDING" }
      ]
    }
  ]
}
```

### 6.4 Security Rules (Summary)

- `users/{userId}/**`: read/write if `request.auth.uid == userId`
- `analysis_jobs`: client can **create** and **read** own jobs; **update/delete denied** (worker uses Admin SDK)
- Storage `users/{userId}/videos/**`: read/write if auth.uid matches; max 100 MB

Full rules in `SOLENNE-Zero-Budget-Build-Plan.md` § Firestore Data Model.

---

## 7. Lifecycle Stages

### 7.1 Product Lifecycle (24 Weeks)

| Phase | Weeks | Objective | Exit |
|-------|-------|-----------|------|
| 0 — Firebase + Flutter | 1–2 | Project live, auth works | Login on device |
| 1 — Consent & Profile | 3 | Onboarding complete | Consent in Firestore |
| 2 — Record + Upload | 4–6 | Core journal loop | Video plays back |
| 3 — Worker + Transcript | 7–9 | Whisper pipeline | Transcript in app |
| 4 — Full Analysis | 10–12 | 3 modalities | Metrics in journal detail |
| 5 — Baseline + Trends | 13–15 | EWMA + charts | 7-day chart works |
| 6 — Insights + Dashboard | 16–18 | Template insights | Evidence drawer works |
| 7 — FCM + Polish | 19–21 | Push + settings | Push on complete |
| 8 — Demo | 22–24 | Seed data, APK | Class demo |

### 7.2 Module Lifecycle (Per M1–M5)

Each module follows:

```
Plan → Pre-dev checklist → Implement → Test → Exit gate → Handoff doc → Demo
```

| Stage | Activities | Gate |
|-------|------------|------|
| **Plan** | Read module section in 02-Module-Implementation-Guide | Scope agreed |
| **Pre-dev** | Env verified (01-Environment-Setup); rules deployed | Checklist 100% |
| **Implement** | Feature code + unit tests | PR ready |
| **Test** | Module tests from 03-Test-Catalog | All P0 tests pass |
| **Exit gate** | Module-specific checklist in Team Work Plan | All boxes checked |
| **Handoff** | Write `docs/handoffs/M{N}.md` | Next owner unblocked |

### 7.3 Analysis Job State Machine

```
                    ┌──────────┐
         create     │  queued  │◄── Flutter (upload complete)
                    └────┬─────┘
                         │ worker claims
                         ▼
                    ┌──────────┐
                    │processing│◄── worker sets processingStep
                    └────┬─────┘
              success    │    failure (retry < 3)
                         ▼         │
                    ┌──────────┐   ▼
                    │ complete │  failed
                    └──────────┘
```

**Worker `processingStep` values (optional field for UI):**

`downloading` → `transcoding` → `transcribing` → `face` → `voice` → `nlp` → `fusion` → `baseline` → `insights`

### 7.4 User Journey Lifecycle

```
Install → Register/Login → Onboarding → Home (empty)
  → Record → Upload → Queued → Processing → Complete
  → View results → Dashboard trends (after ≥2 entries)
  → Insights (after baseline confidence ≥ 0.6)
  → Daily habit (streak, reminders, push)
```

### 7.5 SDLC for AI-Assisted Sessions

1. **Scope:** One module subsection or one feature at a time.
2. **Context:** Paste relevant Playbook section + current file paths.
3. **Implement:** Match existing conventions; minimal diff.
4. **Verify:** Run tests listed in 03-Test-Catalog for that feature.
5. **Document:** Update handoff if schema or setup changed.

---

## 8. Analysis Pipeline Specification

### 8.1 AI Simplifications (College vs Production SAD)

| Component | Production SAD | College MVP |
|-----------|----------------|-------------|
| Transcription | Whisper large-v3 GPU | faster-whisper `small` CPU |
| Voice | Parselmouth | librosa |
| NLP | RoBERTa + GoEmotions | VADER |
| Insights | GPT-4o-mini | Jinja2 templates |
| Drift | EWMA + Z + Isolation Forest | EWMA + Z-score only |
| Fusion | Late fusion | Same |

### 8.2 Modality Weights (Late Fusion)

```python
MODALITY_WEIGHTS = {'face': 0.35, 'voice': 0.35, 'text': 0.30}
# Re-normalize when modalities missing (consent off or low confidence)
CONFIDENCE_THRESHOLD = 0.5  # skip modality below this
```

### 8.3 Baseline Engine Parameters

| Parameter | Value |
|-----------|-------|
| EWMA α (days 1–21) | 0.10 |
| EWMA α (after day 21) | 0.05 |
| Minimum entries for insight | 5 in 7 days |
| Full baseline confidence | 21 days |
| Z-alert threshold | \|z\| > 2.0 |
| Insight suppression | baseline confidence < 0.6 |

**Confidence formula:**

```
confidence = min(1.0, (n / 21) * consistency_factor * quality_factor)
consistency_factor = entries_last_14_days / 14  (cap 1.0)
quality_factor = mean(recording_quality_scores)
```

**EWMA update:**

```
μ_t = α * x_t + (1 - α) * μ_{t-1}
σ_t = sqrt(α * (x_t - μ_t)² + (1 - α) * σ_{t-1}²)
```

### 8.4 Insight Templates (Minimum 5)

| Template ID | Trigger | Example output |
|-------------|---------|----------------|
| `T1_valence_drop` | z(valence) < -2 for 3+ days | "Your emotional tone has been lower than your usual baseline this week." |
| `T2_energy_drop` | z(voice energy) < -1.5 | "Your voice energy has been quieter than your personal norm." |
| `T3_congruence_low` | congruence < 0.4 | "Your words and tone haven't fully aligned lately — that's common during stress." |
| `T4_positive_trend` | z(valence) > +1.5 for 5 days | "You've been sounding more positive compared to your baseline." |
| `T5_volatility_high` | z(volatility) > 2.0 | "Your emotional expression has varied more than usual recently." |

**Guardrails:** No clinical terms (diagnosis, disorder, depression, bipolar, etc.). Always append wellness disclaimer.

### 8.5 Worker Main Loop (Pseudocode)

```python
while True:
    jobs = db.collection("analysis_jobs").where("status", "==", "queued").limit(1).stream()
    for job_doc in jobs:
        job = job_doc.reference
        data = job_doc.to_dict()
        try:
            job.update({"status": "processing", "startedAt": SERVER_TIMESTAMP})
            video_path = download_video(data["userId"], data["journalId"])
            audio_path = extract_audio(video_path)          # ffmpeg
            transcript = transcribe(audio_path)             # faster-whisper
            consents = get_consents(data["userId"])
            facial = analyze_face(video_path) if consents.face else None
            voice = analyze_voice(audio_path)
            nlp = analyze_text(transcript.text)
            fused = fuse(facial, voice, nlp)
            update_baseline(data["userId"], fused)
            maybe_create_insight(data["userId"], fused)
            write_journal_results(data["userId"], data["journalId"], ...)
            job.update({"status": "complete", "completedAt": SERVER_TIMESTAMP})
            send_fcm_if_token(data["userId"])
        except Exception as e:
            handle_failure(job, e)
    sleep(POLL_INTERVAL_SEC)  # e.g. 5
```

---

## 9. Module Implementation Order

See **`02-Module-Implementation-Guide.md`** for file-by-file build lists.

**Critical dependency chain:**

```
M1 (Auth, rules, onboarding)
  → M2 (Record, upload, journal list)
    → M3 (Worker + analysis UI)
      → M4 (Dashboard, charts, insights UI)
        → M5 (FCM, privacy, delete, demo)
```

**Do not start M4 until M3 writes real metrics to Firestore.**  
**Do not start M3 until M2 creates `analysis_jobs` on upload.**

---

## 10. Security & Compliance

### 10.1 Security Checklist

- [ ] Firestore rules deployed before any production data
- [ ] Storage rules enforce user path + size limit
- [ ] `analysis_jobs` not client-writable (except create)
- [ ] Service account key gitignored; rotate if leaked
- [ ] No API keys in source code
- [ ] Auth guard on all routes except login/register/onboarding
- [ ] Consent checked in worker before face/text processing

### 10.2 Privacy & Legal (MVP)

- Medical disclaimer on onboarding and insight screens
- "Not a medical device" language
- Consent version stored with timestamp
- Delete account removes: Auth user, all Firestore subcollections, Storage prefix
- No training on user data
- No selling/sharing data (state in Privacy Policy)

### 10.3 Insight Language Blocklist

Reject or rewrite insights containing:

`diagnos`, `disorder`, `bipolar`, `schizophren`, `prescri`, `medication`, `suicid` (except crisis resource link in production — manual only for MVP), `clinical`, `disorder`, `patholog`

---

## 11. Observability & Limits

### 11.1 Logging (Worker)

Log to stdout with structured fields: `jobId`, `userId`, `journalId`, `step`, `duration_ms`, `error`.

### 11.2 Crashlytics (Flutter)

Wrap `main()` with Firebase Crashlytics; log non-fatal upload/analysis errors.

### 11.3 Cost Traps

| Trap | Mitigation |
|------|------------|
| Blaze plan accidental | Stay on Spark; no Cloud Functions |
| Storage bloat | 3-min cap; compress before upload |
| Read explosion | Paginate journals (limit 20); single doc listeners |
| OpenAI API | Templates only |
| Apple Dev $99 | Android APK sideload or simulator for demo |

---

## 11.4 CI Pipeline (Minimum)

**Flutter (`flutter-ci.yml`):**

```yaml
- flutter analyze
- flutter test
- flutter build apk --debug  # or ios --no-codesign
```

**Worker (`worker-ci.yml`):**

```yaml
- pip install -r requirements.txt
- pytest worker/tests/ -v
```

---

## 12. AI Session Protocol

### 12.1 Prompt Template (Copy for Each Session)

```
Project: SOLENNE — Flutter + Firebase + Python worker ($0 college MVP)
Current module: M{N} — {name}
Owner: {name}
Reference: docs/implementation-readiness/02-Module-Implementation-Guide.md § M{N}

Task: {specific feature}
Constraints:
- Match repo structure in Playbook §5
- Use pinned deps in Playbook §2
- Enforce Firestore schema in Playbook §6
- Handle edge cases in 04-Edge-Cases-And-Failure-Modes.md
- Add tests from 03-Test-Catalog.md § M{N}

Do not: add AWS services, paid LLM APIs, or scope from post-MVP list.
```

### 12.2 Module Start Prompts

**M1 — Identity & First Run**

> Scaffold Flutter app with go_router, Riverpod, Firebase Auth (email + Google), Firestore user profile, multi-step onboarding with granular consent, security rules, auth guard. Exit: new user register → onboard → empty home; returning user skips onboarding.

**M2 — Video Journal**

> Implement camera recording (3 min max, countdown, timer), Storage upload with progress/retry, journal CRUD with thumbnails, streak logic, playback, delete cascade, create analysis_jobs on upload complete.

**M3 — AI Analysis Engine**

> Build Python worker: poll analysis_jobs, ffmpeg, faster-whisper, MediaPipe (consent-aware), librosa, VADER, fusion, EWMA baseline, template insights. Flutter: real-time analysisStatus listener, results UI on journal detail.

**M4 — Dashboard & Insights**

> Home dashboard with streak, fl_chart 7-day trends with baseline band, insight list/detail with evidence drawer, helpful feedback, suppress when baseline confidence < 0.6.

**M5 — Trust & Launch**

> FCM setup, push on analysis complete, privacy dashboard, consent revoke, delete all data + delete account, settings complete, demo seed script, README polish.

### 12.3 What to Attach to AI Context

| Always | Sometimes |
|--------|-----------|
| Current module section from 02-Module-Implementation-Guide | Relevant existing file paths |
| Firestore schema for touched collections | Screenshot of bug |
| Exit gate checklist | Firebase rules if changing security |

---

## 13. Definition of Done (Global)

A feature is **done** when:

1. Code merged to `develop` (or agreed main branch).
2. P0 tests in 03-Test-Catalog pass for that feature.
3. No new analyzer/linter errors (`flutter analyze`, worker lint if configured).
4. Firestore/Storage rules updated if schema or paths changed.
5. README or handoff updated if setup steps changed.
6. Tested on at least one physical device or emulator.
7. Medical disclaimer preserved where required.

A **module** is **done** when all exit gate items in `SOLENNE-Team-Work-Plan.md` are checked and `docs/handoffs/M{N}.md` exists.

---

## 14. Post-MVP Migration Map

When funded, migrate incrementally — do not rewrite Flutter UI.

| College MVP | Next step | Production SAD |
|-------------|-----------|----------------|
| Flutter app | Keep | + optional web |
| Firebase Auth | Auth0 or custom JWT | auth-service |
| Firestore | Sync or API layer | PostgreSQL RDS |
| Firebase Storage | S3 adapter | S3 + CloudFront |
| Local Python worker | Cloud Run GPU | ai-inference-service on EKS |
| Template insights | OpenAI API | insight-service + guardrails |
| FCM | Keep | notification-service |
| Z-score only | + Isolation Forest | Full baseline engine |

---

## Appendix A: Related Documents

| Path | Content |
|------|---------|
| `docs/SOLENNE-SAD-PRD.md` | Full PRD, 120 stories, production architecture |
| `docs/SOLENNE-Zero-Budget-Build-Plan.md` | Firebase rules, app flow, MoSCoW |
| `docs/SOLENNE-Team-Work-Plan.md` | 3-person rotation, exit gates |
| `docs/SOLENNE-Engineering-Execution-Plan.md` | Epics, paid path, TDD index |
| `docs/SOLENNE-Weekly-Tracker.md` | 24-week sprint tracking |

---

*End of Implementation Playbook v1.0.0*
