# Solenne Backend ML Analyzer

Local-first Python backend for analyzing a Solenne video journal. This milestone
does not call Cloudinary, Firebase, Firestore, or the Flutter app. Put a video in
`backend/input_videos/`, run the analyzer, and inspect the output JSON/report.

## Setup

Use Python 3.10 or newer.

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

Install `ffmpeg` and make sure both `ffmpeg` and `ffprobe` are available on PATH.

## Run

```powershell
python -m solenne_analyzer analyze input_videos/sample.mp4
```

For a faster local smoke test, use a smaller Whisper model:

```powershell
python -m solenne_analyzer analyze input_videos/sample.mp4 --whisper-model base
```

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

## Notes

- This is not a medical or diagnostic system.
- Face analysis is intentionally lightweight and quality-aware for the MVP.
- The output schema is shaped so it can later be written to Firestore journal
  fields when Cloudinary/Firebase integration resumes.
- Do not commit videos, outputs, `.env`, or Firebase service account files.
