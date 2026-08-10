# Solenne

**A private video-journaling prototype for non-clinical wellness reflection.**

Solenne lets a person record a short video journal, then asynchronously turns
their speech, voice, and visual signals into a transcript, wellness metrics,
and gentle reflection prompts. It is designed to support self-awareness—not to
diagnose, treat, or replace professional mental-health care.

> **Prototype status:** this repository contains a working Flutter client and
> Python analysis worker. Features described as future plans in `docs/` may not
> yet be implemented.

## What it does

- Authenticates users with Firebase email/password authentication.
- Captures or selects a video journal in Flutter and uploads it to Cloudinary.
- Creates a Firestore-backed analysis job alongside the journal entry.
- Processes queued jobs in a Python worker: transcription, face/visual signal
  sampling, voice/prosody analysis, text sentiment analysis, and signal fusion.
- Writes transcript, metrics, progress, and insight cards back to Firestore.
- Updates the journal and insight UI live through Firestore snapshot listeners.
- Optionally generates structured, guardrailed insight cards with Groq and can
  attach only human-approved research claims from the local grounding catalog.

## Architecture

```text
Flutter app
  |  Firebase Auth + Firestore listeners
  |  upload video
  v
Cloudinary ----------------------> Firestore
                                       |
                                       | analysis_jobs (queue)
                                       v
                             Python analysis worker
                                       |
                                       | Admin SDK writes results
                                       v
                            users/{uid}/journals/{journalId}
                                       |
                                       v
                              Flutter UI updates live
```

There is intentionally **no REST or GraphQL server**. Firestore is the seam
between the client and the worker: the client queues a job, and the worker
claims, processes, and completes it. See the detailed
[system architecture](docs/ARCHITECTURE.md).

## Technology stack

| Layer | Technologies | Purpose |
| --- | --- | --- |
| Client | Flutter, Dart, Material UI | Android, iOS, and web journal experience |
| Client state | Riverpod | Dependency injection and reactive state |
| Identity & data | Firebase Authentication, Cloud Firestore | User accounts, journals, job queue, live result updates |
| Media | `camera`, `image_picker`, `video_player`, Cloudinary | Video capture, playback, upload, and delivery |
| Worker | Python 3.11, Docker, Firebase Admin SDK | Background analysis and secure result writes |
| Transcription | faster-whisper, FFmpeg | Local speech-to-text from journal audio |
| Visual signals | MediaPipe, OpenCV | Lightweight, quality-aware frame and face analysis |
| Voice & text | librosa, NumPy, SciPy, VADER Sentiment | Prosody, pause/energy, sentiment, stress-term, and topic features |
| AI insights | Groq API (`llama-3.1-8b-instant`) | Optional structured reflection cards with fallback templates |
| Grounding | Local JSON catalog + deterministic retrieval | Optional research-supported claims without a vector database |

## Repository layout

```text
frontend/                     Flutter application
  lib/screens/                App screens: auth, recording, timeline, insights
  lib/features/               Auth, journal data models, repositories, providers
  lib/services/cloudinary/    Direct Cloudinary media upload

backend/                      Python analyzer and queue worker
  solenne_analyzer/pipeline/  Media, transcription, face, voice, NLP, fusion
  solenne_analyzer/worker/    Firestore polling, job claims, progress, results
  solenne_analyzer/grounding/ Evidence catalog and validation
  tests/                      Backend unit tests

docs/                         Product, architecture, lifecycle, and delivery docs
firestore.rules               Client-access security rules
firestore.indexes.json        Firestore query indexes
```

## Getting started

### Prerequisites

- Flutter SDK compatible with Dart `^3.10.7`
- Python 3.10+ (the worker Docker image uses Python 3.11)
- A Firebase project with Email/Password authentication and Cloud Firestore
- A Cloudinary cloud and unsigned upload preset for prototype media uploads
- `ffmpeg` and `ffprobe` on your `PATH` (or `imageio-ffmpeg`'s bundled binary)

### 1. Run the Flutter app

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

Use `flutter run -d <device-id>` for an Android device. Android Firebase needs
`frontend/android/app/google-services.json`; web Firebase settings are in
`frontend/lib/firebase_options.dart`.

The client supports overriding Cloudinary configuration at launch:

```bash
flutter run -d chrome \
  --dart-define=CLOUDINARY_CLOUD_NAME=your-cloud-name \
  --dart-define=CLOUDINARY_UPLOAD_PRESET=your-unsigned-preset
```

### 2. Set up the analysis worker

```bash
cd backend
python -m venv .venv
source .venv/bin/activate   # Windows PowerShell: .\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

Create `backend/.env` locally (do not commit it):

```dotenv
FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_SERVICE_ACCOUNT=serviceAccountKey.json
POLL_INTERVAL_SECONDS=5

CLOUDINARY_CLOUD_NAME=your-cloud-name
CLOUDINARY_UPLOAD_FOLDER=solenne/journals
WHISPER_MODEL=base
MAX_VIDEO_SECONDS=180

# Optional: richer structured insight cards
GROQ_API_KEY=your-groq-api-key
GROQ_MODEL=llama-3.1-8b-instant

# Optional: off, shadow, enforce, or combined
GROUNDING_MODE=off
```

Download a Firebase Admin service-account key into
`backend/serviceAccountKey.json`, or configure Application Default Credentials
when the worker runs on Cloud Run.

Process one job or keep polling for jobs:

```bash
python -m solenne_analyzer worker --once
python -m solenne_analyzer worker --watch
```

### 3. Analyze a local video (without Firestore)

```bash
cd backend
python -m solenne_analyzer analyze input_videos/sample.mp4 --whisper-model base
```

The analyzer writes its artifacts to `backend/outputs/<run-id>/`.

## Verification

```bash
# Flutter
cd frontend
flutter analyze
flutter test
flutter build apk --debug
```

```bash
# Python worker
cd backend
python -m unittest discover -s tests
```

## Data model and security

- Profiles: `users/{uid}`
- Journals: `users/{uid}/journals/{journalId}`
- Queue: `analysis_jobs/{journalId}`

Firestore rules allow a signed-in user to create and read only their own
journals and jobs. The client cannot update completed analysis results; those
are written by the worker through the Firebase Admin SDK. The worker also
restricts downloads to validated Cloudinary URLs, caps media size, and deletes
temporary media after each job. Review [firestore.rules](firestore.rules) and
the [architecture security notes](docs/ARCHITECTURE.md#why-the-queue-seam-matters)
before deployment.

## Important limitations

- Solenne is a wellness/self-reflection prototype, **not a medical device**.
- Insights are observational and non-diagnostic; they should never be treated
  as clinical advice or crisis support.
- Cloudinary's unsigned uploads are a prototype-only choice. Use signed,
  private uploads for a production deployment.
- The grounding catalog starts as reviewable research drafts. Only claims
  approved by two distinct human reviewers are eligible for runtime use.
- FCM, production CI/CD, Firebase Hosting, and a conventional API service are
  not currently implemented in this repository.

## Documentation

- [System architecture](docs/ARCHITECTURE.md)
- [Product requirements and software architecture document](docs/SOLENNE-SAD-PRD.md)
- [Engineering execution plan](docs/SOLENNE-Engineering-Execution-Plan.md)
- [Implementation readiness playbook](docs/implementation-readiness/SOLENNE-Implementation-Playbook.md)
- [Backend details](backend/README.md)
- [Flutter client details](frontend/README.md)

## Contributing

Keep sensitive material out of version control: `.env` files, Firebase service
accounts, uploaded videos, generated analysis output, and API keys must not be
committed. Run the relevant frontend and backend checks before opening a pull
request. See [AGENTS.md](AGENTS.md) for repository conventions.

## License

No license has been declared for this repository. All rights are reserved unless
the project maintainers add a license file.
