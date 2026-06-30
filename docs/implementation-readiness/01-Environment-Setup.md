# SOLENNE — Environment Setup (Day 0)

**Purpose:** Complete this checklist once before Module 1. Every team member and every AI session should assume this is done.

**Reference:** `SOLENNE-Implementation-Playbook.md` §2

---

## 1. Machine Requirements

| Platform | Minimum |
|----------|---------|
| macOS | 13+ (for iOS development) |
| RAM | 16 GB (ML worker); 8 GB minimum for Flutter-only |
| Disk | 20 GB free (Flutter SDK, Android SDK, Python venv, Whisper model cache) |
| Network | Stable internet for Firebase |

---

## 2. Install Development Tools

Run in order. Verify each step before continuing.

### 2.1 Flutter & Dart

```bash
# Install Flutter 3.24+ via https://docs.flutter.dev/get-started/install
flutter --version    # Expect Flutter 3.24.x, Dart 3.5.x
flutter doctor -v    # Fix all ✗ items except optional items you won't use
```

**Required `flutter doctor` checks:**

- [ ] Flutter SDK
- [ ] Android toolchain (for Android)
- [ ] Xcode (for iOS, macOS only)
- [ ] Chrome (optional, for web debug)

### 2.2 Python & ffmpeg

```bash
python3 --version    # Expect 3.11.x
pip3 --version

# macOS
brew install ffmpeg

# Verify
ffmpeg -version
ffprobe -version
```

### 2.3 Firebase CLI & FlutterFire

```bash
npm install -g firebase-tools
firebase --version   # Expect 13.x

dart pub global activate flutterfire_cli
flutterfire --version
```

Add to PATH if needed:

```bash
export PATH="$PATH:$HOME/.pub-cache/bin"
```

### 2.4 Git

```bash
git --version
git config user.name   # Should be set (do not change global config in CI)
git config user.email
```

---

## 3. Firebase Project Setup

Complete in Firebase Console (https://console.firebase.google.com).

### 3.1 Create Project

- [ ] Project name: `solenne-dev` (or team-agreed name)
- [ ] Plan: **Spark (free)** — do NOT upgrade to Blaze unless intentional
- [ ] Disable Google Analytics if you want zero Google Analytics (optional)

### 3.2 Enable Services

- [ ] **Authentication** → Sign-in method → Email/Password: **Enabled**
- [ ] **Authentication** → Sign-in method → Google: **Enabled** (add support email)
- [ ] **Firestore Database** → Create database → **Production mode** (rules deployed immediately after)
- [ ] **Storage** → Get started → default bucket
- [ ] **Cloud Messaging** → enabled by default
- [ ] **Crashlytics** → optional, enable when iOS/Android apps registered

### 3.3 Register Apps

**Android:**

- [ ] Add Android app with package name e.g. `com.solenne.app`
- [ ] Download `google-services.json` → `mobile/android/app/google-services.json`
- [ ] Add SHA-1 for debug keystore (required for Google Sign-In):

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

**iOS (macOS only):**

- [ ] Add iOS app with bundle ID e.g. `com.solenne.app`
- [ ] Download `GoogleService-Info.plist` → `mobile/ios/Runner/GoogleService-Info.plist`
- [ ] Upload APNs key to Firebase → Project Settings → Cloud Messaging (for push in M5)

### 3.4 Service Account (Worker)

- [ ] Project Settings → Service Accounts → Generate new private key
- [ ] Save as `worker/serviceAccountKey.json` — **never commit**
- [ ] Note storage bucket name: `{project-id}.appspot.com`

---

## 4. Repository Bootstrap

```bash
cd /path/to/SPD-II   # or clone repo

# After mobile/ exists:
cd mobile
flutterfire configure   # Select project, platforms android + ios
flutter pub get
flutter analyze

# Python worker
cd ../worker
python3 -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt

# Copy env template
cp .env.example .env
# Edit .env with bucket name and paths
```

### 4.1 Worker `.env.example`

```env
FIREBASE_SERVICE_ACCOUNT=./serviceAccountKey.json
FIREBASE_STORAGE_BUCKET=solenne-xxxxx.appspot.com
WHISPER_MODEL=small
WHISPER_COMPUTE_TYPE=int8
POLL_INTERVAL_SEC=5
MAX_JOB_RETRIES=3
LOG_LEVEL=INFO
```

### 4.2 Deploy Firebase Rules

```bash
cd firebase
firebase login
firebase use solenne-dev   # your project id
firebase deploy --only firestore:rules,storage,firestore:indexes
```

---

## 5. Verify End-to-End (Smoke Test)

### 5.1 Flutter Runs

```bash
cd mobile
flutter devices
flutter run -d <device_id>
```

Expected: App launches (even if empty shell).

### 5.2 Firebase Auth (after M1 scaffold)

- [ ] Register test user in app
- [ ] User appears in Firebase Console → Authentication
- [ ] User doc created in Firestore (after M1)

### 5.3 Worker Connects (after M3 scaffold)

```bash
cd worker
source .venv/bin/activate
python main.py
```

Expected: Logs "Polling for jobs..." without auth errors.

### 5.4 Whisper Model Download (First Run)

First transcription downloads ~500 MB model. Run once:

```bash
python -c "from faster_whisper import WhisperModel; WhisperModel('small', compute_type='int8')"
```

---

## 6. IDE Setup (Recommended)

### VS Code / Cursor Extensions

- [ ] Dart
- [ ] Flutter
- [ ] Python
- [ ] Firebase (optional)

### Android Studio

- [ ] Android SDK 34+
- [ ] Emulator with Google Play (for Google Sign-In testing)

### Xcode (iOS)

- [ ] Open `mobile/ios/Runner.xcworkspace`
- [ ] Set development team for signing
- [ ] Run on simulator or device

---

## 7. CI Setup (GitHub Actions)

- [ ] Repository on GitHub
- [ ] Add secrets if needed (generally **not** for college path — no service account in CI for MVP)
- [ ] `.github/workflows/flutter-ci.yml` runs on PR

Local CI simulation:

```bash
cd mobile && flutter analyze && flutter test
cd worker && pytest tests/ -v
```

---

## 8. Team Onboarding Checklist

Each member confirms:

- [ ] Cloned repo
- [ ] Flutter doctor clean (for their target platform)
- [ ] Python venv + requirements installed
- [ ] ffmpeg on PATH
- [ ] Has **own** Firebase test account (not shared prod)
- [ ] Does **not** have `serviceAccountKey.json` unless running worker (Yanish / ML owner)
- [ ] Read `SOLENNE-Team-Work-Plan.md` for current module owner
- [ ] Can run app on device/emulator

---

## 9. Troubleshooting

| Problem | Fix |
|---------|-----|
| Google Sign-In fails Android | Add SHA-1 to Firebase; use emulator with Play Store |
| `firebase_options.dart` missing | Run `flutterfire configure` in `mobile/` |
| Firestore permission denied | Deploy rules; ensure user logged in; check path matches `users/{uid}/` |
| Worker auth error | Verify `serviceAccountKey.json` path and project ID |
| ffmpeg not found | `brew install ffmpeg` or add to PATH |
| Whisper OOM | Use `small` model + `int8`; close other apps |
| iOS build fails pods | `cd ios && pod install --repo-update` |
| Storage upload fails | Check rules, file size < 100 MB, auth token valid |

---

## 10. Pre-Module-1 Gate

**Do not start M1 implementation until:**

- [ ] Firebase project created (Spark)
- [ ] At least one platform runs (`flutter run`)
- [ ] Firebase rules file exists in repo
- [ ] `.gitignore` excludes secrets
- [ ] Team agrees on package name / bundle ID

---

*Next: `02-Module-Implementation-Guide.md` → Module M1*
