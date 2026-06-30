# SOLENNE — $0 College Build Plan (Flutter + Firebase)

**Version:** 1.1.0  
**Date:** June 13, 2026  
**Budget:** $0/month  
**Client:** **Flutter** (iOS + Android)  
**Backend:** **Firebase** (Auth, Firestore, Storage, FCM)  
**Context:** College mobile app — Firebase free tier + local Python ML worker  
**Source of Truth:** `SOLENNE-SAD-PRD.md` (production target) · `SOLENNE-Engineering-Execution-Plan.md` (paid path)

---

## Executive Summary

SOLENNE is a **Flutter mobile app** backed by **Firebase**, with a **local Python analysis worker** (team laptop) for CPU-based AI. No AWS, no Next.js web app, no paid APIs.

**Core strategy:**

1. **Flutter-first** — Single codebase for iOS and Android; camera recording native.
2. **Firebase Spark (free)** — Auth, Firestore, Storage, FCM; no Cloud Functions required at first.
3. **Firestore as database + job queue** — `analysis_jobs` collection polled by Python worker via Admin SDK.
4. **Firebase Storage** — Video uploads with Security Rules (user can only write own path).
5. **CPU-only AI locally** — `faster-whisper`, MediaPipe, librosa, VADER; worker writes results to Firestore.
6. **Template insights** — No paid LLM; optional Ollama on laptop.

When you have budget, migrate to the SAD AWS stack (or keep Firebase and add Cloud Run GPU worker) — see **Migration Map** at the end.

---

## $0 Stack vs Production SAD

| Component | Production SAD (Paid) | $0 College Build (Flutter + Firebase) | Cost |
|-----------|----------------------|----------------------------------------|------|
| **Client** | Next.js web + native mobile (Month 8) | **Flutter** (iOS + Android) | $0 |
| **Auth** | Custom JWT + OAuth on EKS | **Firebase Authentication** (email, Google) | $0 |
| **Database** | RDS PostgreSQL | **Cloud Firestore** | $0 (Spark limits) |
| **Video storage** | S3 + KMS | **Firebase Storage** | $0 (5 GB Spark) |
| **Backend API** | 11 microservices | **Firestore SDK in app** + Security Rules; no REST server required | $0 |
| **Job queue** | SQS / Kafka | **Firestore `analysis_jobs`** + Python poller | $0 |
| **Cloud logic** | Lambda / EKS | **Optional Cloud Functions** (Blaze, free quota) OR skip entirely | $0 |
| **Push notifications** | FCM/APNs custom | **Firebase Cloud Messaging (FCM)** | $0 |
| **Transcoding** | MediaConvert | **ffmpeg** in Python worker | $0 |
| **Transcription** | Whisper GPU | **faster-whisper `small`** on CPU (laptop) | $0 |
| **Face / voice / NLP** | GPU inference service | **Python worker** (MediaPipe, librosa, VADER) | $0 |
| **Insights** | GPT-4o-mini | **Jinja2 templates** in worker | $0 |
| **Analytics** | Amplitude + Snowflake | **Firebase Analytics** (free) | $0 |
| **Crash reporting** | Sentry / Datadog | **Firebase Crashlytics** (free) | $0 |
| **CI/CD** | GitHub Actions → EKS | **GitHub Actions** (Flutter test/build) + Firebase App Distribution (optional) | $0 |
| **Local dev ML** | — | **Docker optional** — worker runs on host Python | $0 |

**Monthly cost: $0** on Firebase Spark if you avoid Cloud Functions outbound billing and keep storage under 5 GB.

---

## Architecture (Flutter + Firebase + Local Worker)

```
┌─────────────────────────────────────────────────────────────────┐
│  Flutter App (iOS / Android)                                    │
│  • camera / image_picker — record video                         │
│  • firebase_auth — login, Google sign-in                        │
│  • cloud_firestore — journals, analysis, insights, baselines    │
│  • firebase_storage — upload / download videos                  │
│  • firebase_messaging — push (analysis complete, reminders)   │
│  • fl_chart — trend charts                                      │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  Firebase (Spark — free tier)                                 │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────────────┐ │
│  │ Auth        │  │ Firestore    │  │ Storage                 │ │
│  │             │  │              │  │ users/{uid}/videos/…    │ │
│  └─────────────┘  └──────────────┘  └─────────────────────────┘ │
│  Security Rules enforce: users read/write only their own data     │
└────────────────────────────┬────────────────────────────────────┘
                             │ Admin SDK (service account)
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  Python Analysis Worker (team laptop — `python worker/main.py`) │
│  1. Poll Firestore: analysis_jobs where status == "queued"      │
│  2. Download video from Firebase Storage                        │
│  3. ffmpeg → faster-whisper → MediaPipe → librosa → VADER       │
│  4. fusion → baseline → insight templates                       │
│  5. Write results to Firestore; set job status "complete"       │
│  6. Optional: trigger FCM via Admin SDK                         │
└─────────────────────────────────────────────────────────────────┘
```

**Why no Cloud Functions for MVP:** Spark plan limits functions; heavy ML cannot run in Functions anyway (timeout/memory). The worker-on-laptop pattern is standard for college ML demos and costs $0.

**Optional (later):** Cloud Function on `storage.object.finalized` → create `analysis_jobs` doc (requires **Blaze** plan with $0 budget alert — still free within quota).

---

## Firebase Spark Free Tier Limits (Plan For These)

| Resource | Free Limit | SOLENNE impact |
|----------|------------|------------------|
| **Firestore storage** | 1 GiB | Metadata OK; store metrics in docs, not raw timelines in MVP |
| **Firestore reads** | 50,000/day | ~500 reads/user/day → ~100 DAU max on free tier |
| **Firestore writes** | 20,000/day | 1 journal ≈ 10–20 writes (upload + analysis) |
| **Storage** | 5 GB stored | ~100 videos at ~50 MB each |
| **Storage download** | 1 GB/day | Playback counts — cache thumbnails locally |
| **Auth** | Unlimited | No concern |
| **FCM** | Free | No concern |
| **Crashlytics / Analytics** | Free | No concern |

**College demo (5–20 users):** Well within limits.

**Compress timelines in Firestore:** Store session-level aggregates in journal doc, not per-second arrays (keeps reads/writes small).

---

## Repository Structure

```
solenne/
├── mobile/                         # Flutter app
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app.dart
│   │   ├── core/
│   │   │   ├── theme/
│   │   │   ├── router/             # go_router
│   │   │   └── constants/
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   │   ├── data/           # Firebase Auth repo
│   │   │   │   ├── presentation/   # login, register screens
│   │   │   │   └── providers/
│   │   │   ├── onboarding/
│   │   │   │   └── consent_screen.dart
│   │   │   ├── journal/
│   │   │   │   ├── record_screen.dart
│   │   │   │   ├── journal_list_screen.dart
│   │   │   │   └── journal_detail_screen.dart
│   │   │   ├── analysis/
│   │   │   │   └── analysis_results_screen.dart
│   │   │   ├── dashboard/
│   │   │   │   └── dashboard_screen.dart
│   │   │   ├── timeline/
│   │   │   │   └── timeline_screen.dart
│   │   │   ├── insights/
│   │   │   │   └── insights_screen.dart
│   │   │   └── settings/
│   │   │       ├── settings_screen.dart
│   │   │       └── privacy_screen.dart
│   │   ├── models/                 # Journal, Analysis, Insight, etc.
│   │   └── services/
│   │       ├── firestore_service.dart
│   │       ├── storage_service.dart
│   │       └── fcm_service.dart
│   ├── pubspec.yaml
│   ├── android/
│   ├── ios/
│   └── firebase_options.dart       # FlutterFire CLI generated
├── worker/                         # Python ML worker (unchanged logic)
│   ├── main.py
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
│   ├── requirements.txt
│   └── serviceAccountKey.json      # GITIGNORE — Firebase Admin SDK
├── firebase/
│   ├── firestore.rules
│   ├── storage.rules
│   ├── firestore.indexes.json
│   └── firebase.json
├── docs/
└── README.md
```

**Remove from college build:** `apps/web/`, `docker-compose` Postgres/MinIO (optional: keep Docker only for worker env consistency).

---

## Firestore Data Model (Maps from SAD §9)

Use **user-scoped subcollections** for security rule simplicity.

```
users/{userId}
  ├── email, displayName, timezone, wellnessGoal, createdAt
  │
  ├── consents/{consentId}
  │     └── type, granted, version, createdAt
  │
  ├── journals/{journalId}
  │     ├── recordedAt, durationSeconds, status, tags[], recordingMode
  │     ├── storagePath, thumbnailPath, playbackUrl (optional)
  │     ├── analysisStatus: queued | processing | complete | failed
  │     ├── transcript: { text, wordCount, segments[] }
  │     ├── facial: { valence, arousal, emotionProbs, confidence, ... }
  │     ├── voice: { energyMean, pitchMean, speakingRate, pauseRatio, ... }
  │     ├── nlp: { sentimentValence, stressScore, topics[], ... }
  │     ├── fused: { overallValence, overallArousal, congruence, engagement, ... }
  │     └── wellnessVector: number[]  (32 floats — or omit and compute on read)
  │
  ├── baselines/{metricName}
  │     └── ewmaMean, ewmaVariance, sampleCount, confidence, updatedAt
  │
  ├── insights/{insightId}
  │     └── text, confidence, evidence{}, templateId, isRead, createdAt
  │
  └── profile (fields on user doc or subdoc)

analysis_jobs/{jobId}          # top-level OR users/{uid}/jobs/{jobId}
  ├── userId, journalId, status, createdAt, errorMessage
  └── Worker queries: where status == "queued" orderBy createdAt limit 1
```

**Security Rules (summary):**

```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /analysis_jobs/{jobId} {
      allow read: if request.auth != null && resource.data.userId == request.auth.uid;
      allow create: if request.auth != null && request.resource.data.userId == request.auth.uid;
      allow update, delete: if false;  // worker uses Admin SDK only
    }
  }
}
```

```javascript
// storage.rules
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /users/{userId}/videos/{journalId}/{fileName} {
      allow read, write: if request.auth != null && request.auth.uid == userId
                         && request.resource.size < 100 * 1024 * 1024; // 100MB
    }
  }
}
```

---

## Flutter Package Dependencies (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^3.0.0
  firebase_auth: ^5.0.0
  cloud_firestore: ^5.0.0
  firebase_storage: ^12.0.0
  firebase_messaging: ^15.0.0
  firebase_analytics: ^11.0.0
  firebase_crashlytics: ^4.0.0
  google_sign_in: ^6.0.0
  camera: ^0.11.0
  video_player: ^2.9.0
  path_provider: ^2.1.0
  permission_handler: ^11.0.0
  flutter_riverpod: ^2.5.0
  go_router: ^14.0.0
  fl_chart: ^0.69.0
  intl: ^0.19.0
```

---

## App Flow (Flutter)

### 1. Auth
- `FirebaseAuth.signInWithEmailAndPassword` / `createUserWithEmailAndPassword`
- `GoogleSignIn` → `signInWithCredential`
- On first login → onboarding consent screens → write `users/{uid}/consents/*`

### 2. Record Journal
- `camera` plugin: preview + record to temp file (max 3 min)
- Create `journals/{id}` doc with `status: uploading`
- `FirebaseStorage.ref('users/$uid/videos/$journalId/video.mp4').putFile()`
- `UploadTask.snapshotEvents` → progress UI
- On complete: create `analysis_jobs/{id}` with `status: queued`; update journal `analysisStatus: queued`

### 3. Analysis (background)
- Python worker picks up job, sets `processing`, runs pipeline, writes metrics into journal doc
- Flutter: `StreamBuilder` or `snapshots()` on journal doc → auto-updates UI

### 4. Dashboard / Trends
- Query last 7 journals: `users/{uid}/journals` orderBy `recordedAt` limit 7
- Chart `fused.overallValence` over time with `fl_chart`
- Baseline band from `baselines/*` docs

### 5. Push Notifications (FCM)
- Request permission on iOS
- Save `FCM token` to `users/{uid}.fcmToken`
- Worker sends notification on analysis complete via Firebase Admin `messaging.send()`

---

## Python Worker + Firebase Admin

```python
# worker/firebase_client.py (conceptual)
import firebase_admin
from firebase_admin import credentials, firestore, storage

cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred, {"storageBucket": "solenne-xxxxx.appspot.com"})
db = firestore.client()
bucket = storage.bucket()

def poll_jobs():
    return db.collection("analysis_jobs").where("status", "==", "queued").limit(1).stream()
```

```bash
# worker/.env
FIREBASE_SERVICE_ACCOUNT=./serviceAccountKey.json
FIREBASE_STORAGE_BUCKET=solenne-xxxxx.appspot.com
WHISPER_MODEL=small
```

**Setup:** Firebase Console → Project Settings → Service Accounts → Generate new private key (never commit; add to `.gitignore`).

---

## What to Build (MoSCoW — Flutter + Firebase)

### Must Have

| Feature | Implementation |
|---------|----------------|
| Email + Google login | Firebase Auth |
| Consent per modality | Firestore `consents` |
| In-app video recording | `camera` plugin, 3 min max |
| Upload with progress | Firebase Storage `putFile` |
| Journal list + playback | Firestore + `video_player` |
| Analysis pipeline | Local Python worker |
| Transcript + 3 modalities | Worker → Firestore journal fields |
| Fusion + baseline + Z-score | Worker Python (SAD §6–7) |
| 7-day trend chart | `fl_chart` |
| Template insights | Worker → `insights` collection |
| In-app notification badge | Firestore `insights.isRead` |
| Push on analysis complete | FCM |
| Medical disclaimer | Onboarding + insight screens |

### Should Have

- Apple Sign-In (required if you ship iOS with Google — App Store rule)
- Offline recording queue (record locally, upload when online)
- Calendar heatmap on timeline screen
- Crashlytics

### Could Have

- Cloud Function to auto-create `analysis_jobs` on upload (Blaze plan)
- Ollama insight phrasing via worker
- Firebase App Distribution for class beta

### Won't Have ($0 college)

- Web app (Flutter web optional — not priority)
- AWS / Postgres / MinIO stack
- Paid LLM APIs
- Cloud GPU
- MFA
- GDPR automated export (manual Firestore export from console for demo)
- App Store / Play Store paid release ($99 Apple / $25 Google — use debug builds + Firebase App Distribution for class)
- Micro-expression model
- 10-minute videos

---

## AI Simplifications (Unchanged from v1.0)

| SAD | $0 |
|-----|-----|
| Whisper large-v3 GPU | faster-whisper `small` CPU |
| Parselmouth | librosa |
| RoBERTa | VADER |
| GPT insights | Templates |
| Isolation Forest | Z-score only |

**Analysis time:** ~4–8 min per 3-min video on a laptop — show step progress in Flutter (`analysisStatus` + optional `processingStep` field).

---

## Revised Phases (Flutter + Firebase)

| Phase | Weeks | Objective | Exit Criteria |
|-------|-------|-----------|---------------|
| **0 — Firebase + Flutter** | 1–2 | Firebase project, Flutter scaffold, Auth working | Login on emulator/device |
| **1 — Consent & Profile** | 3 | Onboarding, Firestore user profile + consents | Consent saved in Firestore |
| **2 — Record + Upload** | 4–6 | Camera, Storage upload, journal list | Video plays back from Storage |
| **3 — Worker + Transcript** | 7–9 | Python worker, Whisper, Firestore write-back | Transcript in app after worker runs |
| **4 — Full Analysis** | 10–12 | Face, voice, NLP in worker | All metrics visible in journal detail |
| **5 — Baseline + Trends** | 13–15 | EWMA, trends, fl_chart | 7-day chart works |
| **6 — Insights + Dashboard** | 16–18 | Templates, insight list, dashboard | End-to-end insight with evidence |
| **7 — FCM + Polish** | 19–21 | Push, settings, privacy screens, disclaimers | Push on analysis complete |
| **8 — Demo** | 22–24 | Seed data, TestFlight/internal APK optional | Class demo ready |

---

## Revised Sprint Plan (College Team)

**Team:** 2 Flutter devs, 1 Python/ML, 1 UI/design, 1 full-stack (Firebase rules + worker), optional 1 PM

| Sprint | Focus | Deliverables |
|--------|-------|--------------|
| **1** | Firebase project, Flutter init, Auth UI | Email login works on device |
| **2** | Firestore models, security rules, profile | User doc + rules deployed |
| **3** | Consent onboarding | Full onboarding flow |
| **4** | Camera recording | Record ≤3 min to local file |
| **5** | Storage upload + journal CRUD | Upload progress, journal list |
| **6** | Worker scaffold + Admin SDK | Job created → worker logs job |
| **7** | ffmpeg + Whisper | Transcript in Firestore |
| **8** | Face + voice modules | facial + voice on journal doc |
| **9** | NLP + orchestration | Full analysis pipeline |
| **10** | Fusion + baseline | baselines collection updated |
| **11** | Trends + dashboard UI | fl_chart 7-day view |
| **12** | Insights + FCM + demo polish | MVP demo complete |

---

## Firebase Setup Checklist

- [ ] Create Firebase project (Spark plan)
- [ ] Register Android app (`google-services.json`)
- [ ] Register iOS app (`GoogleService-Info.plist`)
- [ ] Enable Authentication: Email/Password + Google
- [ ] Create Firestore database (production mode + rules)
- [ ] Create Storage bucket + rules
- [ ] Enable Cloud Messaging
- [ ] Enable Crashlytics (optional)
- [ ] Generate service account JSON for worker (gitignored)
- [ ] Run `flutterfire configure` in `mobile/`
- [ ] Deploy rules: `firebase deploy --only firestore:rules,storage`

---

## Environment & Secrets

| Secret | Where | Never commit |
|--------|-------|--------------|
| `google-services.json` | `mobile/android/app/` | OK in private repo; restrict if public |
| `GoogleService-Info.plist` | `mobile/ios/Runner/` | Same |
| `serviceAccountKey.json` | `worker/` | **Always gitignore** |
| Firebase config | `firebase_options.dart` | Generated by FlutterFire |

`.gitignore` must include:
```
worker/serviceAccountKey.json
**/*.p12
.env
```

---

## Cost Traps (Flutter + Firebase)

| Trap | Alternative |
|------|-------------|
| Blaze plan runaway | Budget alert $0; skip Cloud Functions |
| Storage bloat | 3 min cap, compress video in Flutter before upload |
| Firestore read explosion | Avoid listeners on large collections; paginate journals |
| Apple Developer $99 | Class demo via Android APK sideload or iOS Simulator recording |
| OpenAI API | Templates only |
| AWS | Don't use until funded |

---

## Migration Path: Firebase → Production SAD

| College ($0) | Intermediate | Production SAD |
|--------------|--------------|----------------|
| Flutter app | **Keep Flutter** | Flutter + optional web |
| Firebase Auth | Firebase or Auth0 | auth-service + JWT |
| Firestore | Firestore or Postgres sync | RDS PostgreSQL |
| Firebase Storage | Storage or S3 adapter | S3 + CloudFront |
| Local Python worker | **Cloud Run** + GPU or EKS worker | ai-inference-service |
| FCM | **Keep FCM** | notification-service |
| Template insights | OpenAI API | insight-service |

**Keep when migrating:** Flutter UI, feature folders, models, fusion/baseline Python, user stories.

**Replace:** Firestore direct access → REST/GraphQL API layer; worker deployment → cloud GPU.

---

## Demo Day Checklist

- [ ] Worker running on laptop with campus WiFi hotspot for Firebase
- [ ] Android APK installed on demo device (or iOS Simulator screen mirror)
- [ ] 2 demo accounts with 7+ days seeded data
- [ ] Backup screen recording of full flow
- [ ] Slide: Flutter + Firebase college prototype → AWS architecture at scale
- [ ] Disclaimer: not a medical device

---

## Summary

| Build ($0) | Don't build yet |
|------------|-----------------|
| Flutter mobile app | Next.js web app |
| Firebase Auth/Firestore/Storage/FCM | AWS EKS / RDS / S3 |
| Python worker + Admin SDK | Cloud Functions ML |
| faster-whisper on laptop | GPU cloud |
| Template insights | Paid LLM |
| Firebase Security Rules | Custom REST microservices |
| fl_chart trends | Separate analytics warehouse |

---

**Next step:** Scaffold `mobile/` Flutter project + `firebase/` rules + `worker/` Firebase poller — ready to generate on request.
