# Solenne Backend ML Analyzer

Local-first Python backend for analyzing Solenne video journals. It supports
direct local files and a Firestore worker that consumes Cloudinary-backed
analysis jobs created by the Flutter app.

## Setup

Use Python 3.10 or newer.

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

Install `ffmpeg` and make sure both `ffmpeg` and `ffprobe` are available on PATH.
The current analyzer can also run without system ffmpeg because `imageio-ffmpeg`
provides a bundled executable.

## Run

```powershell
python -m solenne_analyzer analyze input_videos/sample.mp4
```

For a faster local smoke test, use a smaller Whisper model:

```powershell
python -m solenne_analyzer analyze input_videos/sample.mp4 --whisper-model base
```

To generate richer Groq-backed insight cards, create `backend/.env`:

```powershell
GROQ_API_KEY=your_key_here
GROQ_MODEL=llama-3.1-8b-instant
```

Then run:

```powershell
python -m solenne_analyzer analyze input_videos/sample.mp4 --whisper-model base --enable-llm-insights
```

If the key is missing or Groq fails, the analyzer still completes and writes
fallback AI insight cards.

## Source-supported insight grounding

The curated grounding layer is disabled by default. It uses transcript topics
and key phrases only; voice, face, fused metrics, and the rule-based stress
score never select research context.

Configure `backend/.env` with:

```env
GROUNDING_MODE=off
GROUNDING_CATALOG_PATH=solenne_analyzer/grounding/catalog.json
```

- `off` keeps the legacy insight path.
- `shadow` keeps legacy `aiInsights` and stores private
  `groundingShadowInsights` for comparison.
- `enforce` writes only validated evidence-v2 insights.

Validate or inspect the catalog before starting a worker:

```bash
python -m solenne_analyzer catalog validate
python -m solenne_analyzer catalog report
```

The bundled catalog contains research candidates in `draft` state. A claim or
suggestion becomes runtime-eligible only after two distinct human reviewers
approve it, set `status` to `approved`, and set `active` to `true`. Do not mark
AI-prepared drafts as human-approved. After review, replace the draft catalog
version with a release version such as `2026-07-v1` before enabling `enforce`.

Requeue one selected journal without backfilling history:

```bash
python -m solenne_analyzer reprocess \
  --user-id <firebase-uid> \
  --journal-id <journal-id>
```

## Firestore Worker

Generate a Firebase Admin private key from Firebase Console, save it as
`backend/serviceAccountKey.json`, and never commit it. Add these values to
`backend/.env`:

```dotenv
FIREBASE_PROJECT_ID=solenne-9324d
FIREBASE_SERVICE_ACCOUNT=serviceAccountKey.json
POLL_INTERVAL_SECONDS=5
CLOUDINARY_CLOUD_NAME=dqjd3lszl
CLOUDINARY_UPLOAD_FOLDER=solenne/journals
WHISPER_MODEL=base
MAX_VIDEO_SECONDS=180
```

Process one queued journal or keep the worker running:

```powershell
.\.venv\Scripts\python.exe -m solenne_analyzer worker --once
.\.venv\Scripts\python.exe -m solenne_analyzer worker --watch
.\.venv\Scripts\python.exe -m solenne_analyzer worker --job-id JOURNAL_ID
```

The worker validates the Cloudinary source, downloads into a temporary folder,
runs the full pipeline with Groq enabled, writes transcript/metrics/insights to
the journal document, and removes all temporary media. In Cloud Run, omit
`FIREBASE_SERVICE_ACCOUNT` and use the runtime service account through
Application Default Credentials.

## Test

```powershell
python -m unittest discover -s tests
```

Each run writes:

- `outputs/{run_id}/analysis.json`
- `outputs/{run_id}/summary.md`
- `outputs/{run_id}/transcript.txt`
- `outputs/{run_id}/run.log`
- `outputs/{run_id}/audio.wav`

## Current Pipeline

1. Validate local video and duration.
2. Extract mono 16kHz WAV audio with ffmpeg.
3. Transcribe speech with faster-whisper.
4. Sample video frames and detect face presence with MediaPipe.
5. Extract voice/prosody features with librosa.
6. Analyze transcript sentiment, stress terms, topics, and paraphrase.
7. Fuse face, voice, and text signals into Solenne wellness metrics.
8. Generate non-clinical template insights.
9. Optionally generate structured Groq-backed AI insight cards.

## Notes

- This is not a medical or diagnostic system.
- Face analysis is intentionally lightweight and quality-aware for the MVP.
- The Flutter app creates `analysis_jobs/{journalId}` atomically with each new
  journal. Existing unqueued journals are not backfilled automatically.
- The current unsigned Cloudinary upload preset is suitable only for this
  prototype. Production should use signed, private uploads.
- Do not commit videos, outputs, `.env`, or Firebase service account files.
