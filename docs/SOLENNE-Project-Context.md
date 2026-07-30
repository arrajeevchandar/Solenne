# Solenne — Complete Project Context Document

> **Purpose**: Upload this single file to ChatGPT for full project context.
> **Source of truth**: Generated from the actual codebase on the `feat/yansih` branch (July 28, 2026). Every field name, type, weight, and file path has been verified against source code.

---

## 1. What is Solenne?

Solenne is an **AI-powered video journaling app for emotional wellness**. Users record a short daily video (up to 3 minutes) talking about their day. The app passively analyzes their facial expressions, voice prosody, and speech content using multimodal AI, then presents personalized wellness insights — not diagnoses — backed by research citations.

**Key principle**: Solenne is a wellness self-awareness tool. It never diagnoses mental health conditions. All language is non-clinical.

---

## 2. System Architecture

### Architecture Style: 3-Tier with Firestore as Job Queue

**Critical design decision**: The Flutter client and Python backend **never communicate directly**. There are no REST endpoints, no GraphQL, no Cloud Functions. The two halves are decoupled entirely through:
- **Cloud Firestore** — acts as both the database AND the job queue (`analysis_jobs` collection)
- **Cloudinary** — acts as the video transport layer

### Tier 1 — Presentation Layer (Flutter Client)
- Flutter app (Web + Android + iOS)
- State management: Riverpod
- Authentication: Firebase Auth (email/password only)
- Video upload: Direct to Cloudinary (unsigned upload preset, no server intermediary)
- Data persistence: Cloud Firestore with real-time snapshot listeners
- Navigation: Imperative `Navigator.push` with custom `fadeThroughRoute()` (go_router declared in pubspec but unused)

### Tier 2 — Application Logic (Python Worker)
- Standalone Python process (Docker / Cloud Run)
- Polls Firestore `analysis_jobs` for `status == "queued"` jobs
- Downloads video from Cloudinary with SSRF protection
- Runs 9-stage analysis pipeline + grounding layer
- Writes results back to Firestore via Firebase Admin SDK
- No web server, no HTTP endpoints

### Tier 3 — Data Layer
- **Cloud Firestore**: `users/{uid}`, `users/{uid}/journals/{id}`, `analysis_jobs/{id}`
- **Cloudinary**: Video storage + CDN (unsigned upload preset, cloud name: `dqjd3lszl`)
- **Groq API**: Sole LLM provider (model: `llama-3.1-8b-instant`)

### Data Flow (Numbered Steps)
1. User records video → Flutter app
2. App uploads video → Cloudinary (returns publicId + CDN URL)
3. App writes journal doc + analysis job atomically → Firestore (single transaction)
4. App also updates user doc (lastJournalAt) in same transaction
5. Python Worker polls → finds queued job → claims it (status: queued → processing)
6. Worker downloads video → Cloudinary (with SSRF guard: validates URL, caps bytes, no redirects)
7. Worker runs 9-stage pipeline + grounding layer
8. Worker writes analysis results → Firestore journal doc (via Admin SDK)
9. Worker updates job status → complete/failed
10. Firestore snapshot listener → Flutter app shows insights in real-time

---

## 3. Technology Stack

### Frontend (Flutter Client)
| Technology | Version | Purpose |
|---|---|---|
| Flutter | SDK ^3.10.7 | Cross-platform UI framework |
| Dart | (bundled with Flutter) | Programming language |
| firebase_core | ^4.3.0 | Firebase initialization |
| firebase_auth | ^6.1.2 | Email/password authentication |
| cloud_firestore | ^6.1.0 | Database + real-time listeners |
| flutter_riverpod | ^3.0.3 | State management |
| camera | ^0.11.3 | Video recording |
| video_player | ^2.10.1 | Video playback |
| http | ^1.6.0 | Cloudinary upload HTTP calls |
| google_fonts | ^6.3.2 | Typography (Roboto) |
| intl | ^0.20.2 | Date/time formatting |
| url_launcher | ^6.3.2 | Opening external URLs |
| permission_handler | ^12.0.1 | Camera/mic permissions |
| image_picker | ^1.2.3 | Image selection |
| path_provider | ^2.1.5 | Local file paths |
| go_router | ^17.0.1 | Declared but unused — navigation is imperative |

### Backend (Python Worker)
| Technology | Version | Purpose |
|---|---|---|
| Python | 3.10+ | Runtime |
| faster-whisper | >=1.0.3 | Speech-to-text (local CPU, no cloud API) |
| firebase-admin | >=6.6.0 | Firestore read/write via Admin SDK |
| httpx | >=0.28.1 | HTTP client for video download + Groq API |
| mediapipe | >=0.10.14 | Face detection and landmark analysis |
| opencv-python | >=4.10.0 | Video frame sampling |
| librosa | >=0.10.2 | Voice prosody extraction |
| vaderSentiment | >=3.3.2 | Sentiment analysis |
| numpy | >=1.26.4 | Numerical operations |
| scipy | >=1.13.1 | Signal processing |
| imageio-ffmpeg | >=0.5.1 | Bundled FFmpeg for audio extraction |
| soundfile | >=0.12.1 | Audio file I/O |
| pytest | >=8.2.0 | Testing |

### External Services
| Service | Purpose |
|---|---|
| Firebase Auth | Email/password authentication |
| Cloud Firestore | Database + job queue |
| Cloudinary | Video storage + CDN (cloud: dqjd3lszl, folder: solenne/journals) |
| Groq API | LLM inference (llama-3.1-8b-instant) |

### What is NOT used (by design)
| Not Used | Replacement |
|---|---|
| REST/GraphQL API endpoints | Firestore `analysis_jobs` queue |
| Firebase Storage | Cloudinary |
| Cloud Functions | Standalone Python worker (Docker) |
| Firebase Hosting | Not configured |
| OpenAI / Anthropic / Gemini | Groq only |
| Cloud Speech-to-Text | faster-whisper (local CPU) |
| Vector database / embeddings | Deterministic keyword-to-claimType match over static catalog |
| Push notifications (FCM) | Planned but not implemented |
| CI/CD | None |

---

## 4. Module Design

### Module 1: Authentication
- **Files**: `frontend/lib/features/auth/auth_providers.dart`, `frontend/lib/screens/auth/`
- Email/password sign-up and login via Firebase Auth
- Riverpod auth state providers
- Protected route navigation

### Module 2: Video Recording
- **Files**: `frontend/lib/screens/recording/recording_screen.dart`, `recording_preview_screen.dart`, `entry_saved_screen.dart`
- Camera access with pause/resume controls
- Recording timer and duration tracking
- Preview with playback before saving
- Direct upload to Cloudinary via unsigned preset (HTTP POST)
- Entry saved confirmation screen

### Module 3: Journal Management
- **Files**: `frontend/lib/features/journals/journal_repository.dart`, `journal_entry.dart`, `insight_evidence.dart`
- Atomic Firestore transaction: creates journal doc + analysis job + updates user doc
- Real-time journal streaming via Firestore snapshots
- Date range filtering
- Journal deletion (batch delete: journal + analysis job)
- Analysis version tracking (current: `2026-07-v3-rich-grounded`)

### Module 4: Analysis Pipeline (Backend)
- **Files**: `backend/solenne_analyzer/pipeline/` (orchestrator.py, face.py, voice.py, nlp.py, fusion.py, insights.py, llm_insights.py, media.py, transcribe.py)
- 9-stage sequential pipeline (see Section 5)
- Output: `AnalysisResult` dataclass with all signal data

### Module 5: AI Insights & Grounding (Backend)
- **Files**: `backend/solenne_analyzer/ai/` (groq_client.py, context_builder.py, prompts.py, validators.py)
- **Files**: `backend/solenne_analyzer/grounding/` (runtime.py, observations.py, retriever.py, generator.py, assembler.py, validators.py, catalog.py, catalog.json, models.py)
- LLM insight generation via Groq API
- Research catalog with 40K+ bytes of curated references
- Grounding layer with 4 modes: off, shadow, enforce, combined
- Crisis language detection with deterministic safety cards
- Evidence-v2 schema for research-backed insights

### Module 6: Worker (Backend)
- **Files**: `backend/solenne_analyzer/worker/` (runner.py, firebase_gateway.py, media_source.py, result_mapper.py)
- Firestore job queue polling (configurable interval via POLL_INTERVAL_SECONDS)
- Transactional job claiming (queued to processing)
- SSRF-guarded video download (URL validation, byte cap, no redirects, host must be `res.cloudinary.com`)
- Result mapping and Firestore write-back
- Progress reporting per pipeline stage
- Error handling with retry count

### Module 7: Dashboard & Insights Display
- **Files**: `frontend/lib/screens/home/home_screen.dart`, `frontend/lib/screens/insights/daily_insight_screen.dart`, `insights_screen.dart`, `frontend/lib/screens/timeline/`
- Home dashboard with greeting, streak, recent journals
- Timeline view with chronological entries
- Insights overview screen
- Daily Insight screen: AI insight cards, evidence display, video player, transcript, signal meters

### Module 8: User Profile
- **Files**: `frontend/lib/screens/profile/`, `frontend/lib/screens/onboarding/`
- User profile management
- Streak tracking (lastJournalAt)
- Onboarding flow
- Sign out

---

## 5. Analysis Pipeline (9 Stages)

The pipeline runs sequentially in `PipelineRunner.analyze()`:

| Stage | Name | Technology | Input to Output |
|---|---|---|---|
| 1 | Validate Video | Python + FFprobe | Video file -> duration (capped at 180s) |
| 2 | Extract Audio | FFmpeg | Video -> mono 16kHz WAV |
| 3 | Transcribe Speech | faster-whisper | Audio -> TranscriptResult (text, segments, word count, language, confidence) |
| 4 | Analyze Face | MediaPipe + OpenCV | Video frames (sampled at 1 FPS) -> FacialResult (faceDetectedRatio, valence, arousal, qualityScore, confidence) |
| 5 | Analyze Voice | librosa | Audio + transcript -> VoiceResult (energyMean, pitchMean, speakingRate, pauseRatio, variability, confidence) |
| 6 | Analyze Text (NLP) | VADER Sentiment | Transcript text -> NlpResult (sentimentValence, stressScore, topics, keyPhrases, paraphrase, confidence) |
| 7 | Fuse Modalities | Weighted average | Face(0.35) + Voice(0.35) + Text(0.30) -> FusedResult (overallValence, overallArousal, engagement, congruence, confidence) |
| 8 | Template Insights | Rule-based | FusedResult -> list of Insight (templateId, text, confidence, evidence) |
| 9 | LLM Insights | Groq API + Grounding | Full AnalysisResult -> AiInsight cards (title, summary, moodLabel, themes, suggestions, reflectionQuestions, evidence, safetyNote) |

### Fusion Weights
- Face: **0.35**
- Voice: **0.35**
- Text: **0.30**
- Minimum confidence for insight: **0.45**

---

## 6. Grounding Layer

The grounding layer ensures AI insights are backed by research evidence.

### Modes (configured via `GROUNDING_MODE` env var)
| Mode | Behavior |
|---|---|
| `off` | Legacy Groq narrative cards only |
| `shadow` | Legacy cards served; grounded results stored privately in `groundingShadowInsights` |
| `enforce` | Only validated evidence-v2 insights are served |
| `combined` | Both legacy and grounded cards; duplicates merged with richer wording |

### Pipeline
1. **Crisis Check** — Scans transcript for crisis/safety language -> deterministic safety card (short-circuits all LLM calls)
2. **Observation Extraction** — Extracts observations from transcript topics and key phrases only (NOT from voice, face, or fused metrics)
3. **Catalog Retrieval** — Matches observations against static `catalog.json` using deterministic keyword-to-claimType mapping
4. **Evidence Generation** — Produces evidence-v2 structure with user data points and external research references
5. **Validation** — Validates all citations, URLs (HTTPS only), support levels, and schema compliance

### Evidence-v2 Schema
Each AI insight contains an `evidence` object with:
- `schemaVersion`: 2
- `rationale`: explanation text
- `userEvidence[]`: items from the user's own data (evidenceId, label, value, sourcePath, journalIds, confidence)
- `externalReferences[]`: research citations (claimCardId, sourceId, title, publisher, year, url, doi, pmid, matchedClaim, limitations, supportLevel)
- `verification`: metadata (status, method, catalogVersion, reason)

---

## 7. Database Design (Firestore)

### Collection: `users/{uid}`
| Field | Type | Description |
|---|---|---|
| lastJournalAt | Timestamp | Date of most recent journal |
| updatedAt | Timestamp | Server-generated |
| createdAt | Timestamp | Server-generated |

### Collection: `users/{uid}/journals/{id}`
| Field | Type | Description |
|---|---|---|
| id | String | Document ID (microsecond timestamp) |
| userId | String | Owner's Firebase UID |
| prompt | String | Journal prompt (default: "Daily reflection") |
| recordedAt | Timestamp | When video was recorded |
| durationSeconds | Integer | Video length in seconds |
| cloudinaryPublicId | String | Cloudinary public ID |
| videoUrl | String | Cloudinary CDN URL |
| thumbnailUrl | String | Thumbnail URL (auto-generated from video URL if empty) |
| uploadStatus | String | "saved" |
| analysisStatus | String | "not_started" or "queued" or "processing" or "complete" or "failed" |
| analysisStep | String | Current pipeline stage name |
| analysisVersion | String | e.g. "2026-07-v3-rich-grounded" |
| analysisError | String (nullable) | Error message if failed |
| analysisStartedAt | Timestamp (nullable) | When processing began |
| analysisCompletedAt | Timestamp (nullable) | When processing finished |
| title | String | AI-generated title for the journal |
| moodLabel | String (nullable) | AI-determined mood label |
| insightProvider | String | "template" or "groq" or "fallback" or "groq_grounded" or "grounded_template" or "safety" |
| createdAt | Timestamp | Server-generated |
| updatedAt | Timestamp | Server-generated |

**Embedded sub-documents in each journal:**

| Sub-document | Key Fields |
|---|---|
| `transcript` | text, wordCount, language, confidence |
| `facial` | faceDetectedRatio, qualityScore, valence (-1 to 1), arousal (-1 to 1), confidence, warnings[] |
| `voice` | energyMean, pitchMean, speakingRate, pauseRatio, variability, confidence |
| `nlp` | sentimentValence (-1 to 1), stressScore (0-1), topics[], keyPhrases[], paraphrase, confidence |
| `fused` | overallValence (-1 to 1), overallArousal (-1 to 1), engagement (0-1), congruence (0-1), confidence, modalityWeights |
| `templateInsights[]` | templateId, text, confidence, evidence |
| `aiInsights[]` | title, summary, moodLabel, dayThemes[], suggestions[], reflectionQuestions[], evidence{}, confidence, safetyNote |
| `llmDiagnostics` | status, provider, model, tokenEstimate, latencyMs, failureReason, grounding{} |

### Collection: `analysis_jobs/{id}`
| Field | Type | Description |
|---|---|---|
| userId | String | Owner's Firebase UID |
| journalId | String | Same as document ID (matches journal ID) |
| status | String | "queued" or "processing" or "complete" or "failed" |
| processingStep | String | Current pipeline stage |
| retryCount | Integer | Default 0 |
| analysisVersion | String | Pipeline version identifier |
| createdAt | Timestamp | Server-generated |
| startedAt | Timestamp (nullable) | When worker claimed the job |
| completedAt | Timestamp (nullable) | When worker finished |
| errorMessage | String (nullable) | Error details if failed |

---

## 8. Firestore Security Rules

- Users can read/write/update their own `users/{uid}` profile, but cannot delete it
- Journal `create` requires: `userId == auth.uid`, `id == journalId`, `analysisStatus == 'queued'`
- Journal `update: if false` — only the Admin SDK (worker) can update journals with analysis results
- Journal `delete` allowed by owner
- Analysis job `create` requires: matching userId, journalId == jobId, status == 'queued', retryCount == 0, AND a `getAfter()` cross-check that the corresponding journal exists and is owned by the same user
- Analysis job `update: if false` — only Admin SDK can mutate
- Analysis job `delete` allowed by owner

---

## 9. Frontend Screens

| Screen | File | Description |
|---|---|---|
| App Shell | `screens/app_shell.dart` | Bottom navigation (Home, Timeline, Insights, Profile) |
| Login | `screens/auth/` | Email/password sign-in |
| Sign Up | `screens/auth/` | Email/password registration |
| Onboarding | `screens/onboarding/` | First-time user flow |
| Home | `screens/home/home_screen.dart` | Dashboard with greeting, streak, recent journals, FAB to record |
| Recording | `screens/recording/recording_screen.dart` | Camera preview, pause/resume, timer, stop button |
| Recording Preview | `screens/recording/recording_preview_screen.dart` | Video playback, retake, save and analyze |
| Entry Saved | `screens/recording/entry_saved_screen.dart` | Success confirmation, analysis status |
| Timeline | `screens/timeline/` | Chronological journal list with date filtering |
| Insights | `screens/insights/insights_screen.dart` | Overview with summary cards, trends |
| Daily Insight | `screens/insights/daily_insight_screen.dart` | Full insight view: video, transcript, AI cards, evidence, signals |
| Profile | `screens/profile/` | User info, streak stats, sign out |

---

## 10. File Structure

```
Solenne/
├── frontend/                          # Flutter client
│   ├── lib/
│   │   ├── main.dart                  # App entry point
│   │   ├── app.dart                   # MaterialApp configuration
│   │   ├── firebase_options.dart      # Firebase config (auto-generated)
│   │   ├── core/
│   │   │   └── config/app_config.dart # Cloudinary cloud name, upload preset
│   │   ├── features/
│   │   │   ├── auth/auth_providers.dart
│   │   │   ├── journals/
│   │   │   │   ├── journal_entry.dart      # JournalEntry + AiInsight models
│   │   │   │   ├── journal_repository.dart # CRUD + Firestore transactions
│   │   │   │   └── insight_evidence.dart   # Evidence-v2 display models
│   │   │   └── recording/
│   │   ├── screens/
│   │   │   ├── app_shell.dart         # Tab navigation shell
│   │   │   ├── auth/                  # Login, signup screens
│   │   │   ├── home/home_screen.dart  # Dashboard
│   │   │   ├── recording/            # Record, preview, saved screens
│   │   │   ├── insights/             # Daily insight, insights overview
│   │   │   ├── timeline/             # Journal timeline
│   │   │   ├── profile/              # User profile
│   │   │   └── onboarding/           # First-time flow
│   │   ├── services/
│   │   │   └── cloudinary/cloudinary_providers.dart
│   │   ├── routing/                   # Navigation helpers
│   │   └── theme/                     # App theming
│   ├── test/                          # Widget + unit tests
│   ├── assets/
│   │   ├── fonts/Roboto/             # Bundled font files
│   │   └── images/                   # Logo assets
│   ├── android/, ios/, web/          # Platform projects
│   └── pubspec.yaml
│
├── backend/                           # Python analyzer
│   ├── solenne_analyzer/
│   │   ├── __main__.py               # CLI entry point
│   │   ├── main.py                   # CLI argument parsing
│   │   ├── config.py                 # AnalyzerConfig + env loading
│   │   ├── schemas.py                # All data classes (AnalysisResult, etc.)
│   │   ├── pipeline/
│   │   │   ├── orchestrator.py       # PipelineRunner (9-stage)
│   │   │   ├── media.py              # FFmpeg audio extraction
│   │   │   ├── transcribe.py         # faster-whisper
│   │   │   ├── face.py               # MediaPipe face analysis
│   │   │   ├── voice.py              # librosa prosody
│   │   │   ├── nlp.py                # VADER sentiment + NLP
│   │   │   ├── fusion.py             # Weighted multimodal fusion
│   │   │   ├── insights.py           # Template-based insights
│   │   │   └── llm_insights.py       # Groq LLM insight orchestration
│   │   ├── ai/
│   │   │   ├── groq_client.py        # Groq API HTTP client
│   │   │   ├── context_builder.py    # Builds LLM prompt context
│   │   │   ├── prompts.py            # System + user prompts
│   │   │   └── validators.py         # LLM output validation
│   │   ├── grounding/
│   │   │   ├── runtime.py            # Grounding orchestration + modes
│   │   │   ├── observations.py       # Observation extraction
│   │   │   ├── retriever.py          # Catalog lookup
│   │   │   ├── generator.py          # Evidence generation
│   │   │   ├── assembler.py          # Insight assembly
│   │   │   ├── validators.py         # Evidence validation
│   │   │   ├── catalog.py            # Catalog management CLI
│   │   │   ├── catalog.json          # Static research reference catalog
│   │   │   └── models.py             # Grounding data models
│   │   └── worker/
│   │       ├── runner.py             # AnalysisWorker (poll + process loop)
│   │       ├── firebase_gateway.py   # Firestore read/write operations
│   │       ├── media_source.py       # SSRF guard + video download
│   │       └── result_mapper.py      # AnalysisResult to Firestore mapping
│   ├── tests/                        # Backend test suite
│   ├── requirements.txt
│   ├── Dockerfile
│   └── README.md
│
├── firestore.rules                   # Security rules
├── firestore.indexes.json            # Composite indexes
├── firebase.json                     # Firebase project config
├── .gitignore                        # Root gitignore
└── docs/                             # Documentation
    ├── ARCHITECTURE.md               # Most up-to-date architecture doc
    └── ... (planning/design docs)
```

---

## 11. Environment Variables (Backend)

| Variable | Required | Description |
|---|---|---|
| GROQ_API_KEY | Yes (for LLM) | Groq API authentication key |
| GROQ_MODEL | No | Default: llama-3.1-8b-instant |
| ENABLE_LLM_INSIGHTS | No | Default: false. Set to "true" to enable |
| GROUNDING_MODE | No | Default: "off". Options: off, shadow, enforce, combined |
| GROUNDING_CATALOG_PATH | No | Default: built-in catalog.json |
| LLM_TIMEOUT_SECONDS | No | Default: 30 |
| FIREBASE_PROJECT_ID | Yes (worker) | Firebase project ID (solenne-9324d) |
| FIREBASE_SERVICE_ACCOUNT | Yes (local) | Path to service account JSON |
| POLL_INTERVAL_SECONDS | No | Default: 5 |
| CLOUDINARY_CLOUD_NAME | Yes (worker) | Cloudinary cloud (dqjd3lszl) |
| CLOUDINARY_UPLOAD_FOLDER | No | Default: solenne/journals |
| WHISPER_MODEL | No | Default: small |
| MAX_VIDEO_SECONDS | No | Default: 180 |

---

## 12. Known Limitations and Security

- **No personal baselines** — planned in docs but not implemented; insights compare individual entries, not longitudinal trends
- **No consent flow** — planned granular face/voice/text opt-in not built
- **No push notifications** — FCM planned but not implemented
- **No Google/Apple OAuth** — only email/password auth
- **No web hosting** — Firebase Hosting not configured
- **No CI/CD** — no GitHub Actions or Cloud Build
- **Unsigned Cloudinary preset** — suitable only for prototype/development
- **Worker SSRF guard** — validates `res.cloudinary.com` host, HTTPS only, no redirects, byte cap
- **Journal updates blocked by security rules** — only Admin SDK (worker) can write analysis results; clients cannot tamper with results
- **go_router unused** — declared as dependency but all navigation is imperative

---

## 13. CLI Commands

```bash
# Frontend
cd frontend
flutter pub get
flutter run -d chrome                              # Web
flutter run -d <device-id>                         # Android/iOS
flutter analyze
flutter test

# Backend
cd backend
python -m venv .venv && pip install -r requirements.txt

# Local analysis
python -m solenne_analyzer analyze input_videos/sample.mp4 --whisper-model base

# With LLM insights
python -m solenne_analyzer analyze input_videos/sample.mp4 --whisper-model base --enable-llm-insights

# Firestore worker
python -m solenne_analyzer worker --watch           # Continuous polling
python -m solenne_analyzer worker --once            # Process one job
python -m solenne_analyzer worker --job-id <ID>     # Specific job

# Catalog management
python -m solenne_analyzer catalog validate
python -m solenne_analyzer catalog report

# Reprocess a journal
python -m solenne_analyzer reprocess --user-id <uid> --journal-id <id>

# Tests
python -m unittest discover -s tests
```
