# Repository Guidelines

## Project Structure & Module Organization

Solenne is split into two applications. `frontend/` contains the Flutter client: production Dart code lives in `lib/`, feature-specific code in `lib/features/` and `lib/screens/`, shared UI and configuration in `lib/core/`, tests in `test/`, and bundled fonts/images in `assets/`. Platform projects are under `android/`, `ios/`, and `web/`.

`backend/` contains the Python analyzer. The `solenne_analyzer/` package holds CLI entry points, schemas, configuration, AI integrations, and pipeline stages; backend tests live in `backend/tests/`. Keep sample inputs in `backend/input_videos/` and generated artifacts in `backend/outputs/`; neither should contain committed user data. Product and engineering references belong in `docs/`.

## Build, Test, and Development Commands

Run commands from the relevant application directory.

- `cd frontend && flutter pub get` installs Dart dependencies.
- `flutter run -d chrome` launches the web client; use `flutter run -d <device-id>` for Android.
- `flutter analyze` applies the configured Flutter lints.
- `flutter test` runs client unit and widget tests.
- `flutter build apk --debug` verifies an Android debug build.
- `cd backend && python -m venv .venv && pip install -r requirements.txt` prepares Python 3.10+.
- `python -m solenne_analyzer analyze input_videos/sample.mp4 --whisper-model base` runs a local analysis.
- `python -m unittest discover -s tests` runs the backend suite.

## Coding Style & Naming Conventions

Use two-space indentation in Dart and four spaces in Python. Format Dart with `dart format .` and follow `flutter_lints` from `analysis_options.yaml`. Name Dart and Python files `snake_case`; use `UpperCamelCase` for Dart types, `lowerCamelCase` for Dart members, and `snake_case` for Python functions. Keep pipeline stages small and preserve the non-clinical language used by existing insight code.

## Testing Guidelines

Add tests with every behavior change. Name Python files `test_<subject>.py` and Dart files `<subject>_test.dart`. Prefer deterministic unit tests; isolate Firebase, Cloudinary, Groq, media files, and network access behind mocks or fixtures. Run both suites when changing shared data contracts.

## Commit & Pull Request Guidelines

Recent commits use brief, imperative summaries such as `added images` and `ui improvements timeline`. Keep subjects concise but more specific, for example `fix timeline gallery layout`. PRs should explain scope, list verification commands, link relevant issues, and include screenshots or recordings for UI changes. Call out schema, configuration, or dependency changes explicitly.

## Security & Configuration

Never commit `.env`, videos, generated outputs, Firebase service-account files, or secrets. Store `GROQ_API_KEY` in `backend/.env`; treat the prototype Cloudinary unsigned preset as development-only configuration.
