# SOLENNE — Module Implementation Guide (M1 → M5)

**Purpose:** Step-by-step build order, files to create, and exit gates for each major module.

**Reference:** `SOLENNE-Team-Work-Plan.md` · `SOLENNE-Implementation-Playbook.md`

---

## How to Use

1. Implement **only the current module** — do not skip ahead.
2. Create files in the order listed (reduces merge conflicts).
3. Check exit gate before handoff.
4. Write `docs/handoffs/M{N}.md` when done.

---

# Module M1 — Identity & First Run

**Owner:** Rajeev (Turn 1) · **Duration:** 4–5 weeks · **Depends on:** nothing

## Scope Summary

Firebase setup, Flutter scaffold, auth, onboarding, profile, security rules, app shell.

## Implementation Steps

### Step 1: Repository & Firebase (Days 1–3)

| # | Task | Files |
|---|------|-------|
| 1 | Root README with setup pointer | `README.md` |
| 2 | Gitignore secrets | `.gitignore` |
| 3 | Firebase config | `firebase/firebase.json`, `firestore.rules`, `storage.rules`, `firestore.indexes.json` |
| 4 | Create Flutter project | `mobile/` via `flutter create` |
| 5 | FlutterFire configure | `mobile/lib/firebase_options.dart` |
| 6 | CI workflow | `.github/workflows/flutter-ci.yml` |

### Step 2: App Shell (Days 4–7)

| # | Task | Files |
|---|------|-------|
| 7 | App entry + Firebase init | `mobile/lib/main.dart` |
| 8 | MaterialApp + theme | `mobile/lib/app.dart`, `core/theme/app_theme.dart` |
| 9 | Router + auth redirect | `core/router/app_router.dart`, `core/router/routes.dart` |
| 10 | Riverpod scope | wrap in `ProviderScope` |
| 11 | Bottom nav skeleton (tabs disabled/stub) | `core/widgets/main_shell.dart` |
| 12 | Constants | `core/constants/app_constants.dart` |

### Step 3: Authentication (Days 8–14)

| # | Task | Files |
|---|------|-------|
| 13 | Auth repository | `features/auth/data/auth_repository.dart` |
| 14 | Auth state provider | `features/auth/providers/auth_provider.dart` |
| 15 | Login screen | `features/auth/presentation/login_screen.dart` |
| 16 | Register screen | `features/auth/presentation/register_screen.dart` |
| 17 | Forgot password | `features/auth/presentation/forgot_password_screen.dart` |
| 18 | Google Sign-In | in auth_repository |
| 19 | Auth guard in router | redirect if !loggedIn |

### Step 4: Firestore User & Consent (Days 15–21)

| # | Task | Files |
|---|------|-------|
| 20 | User model | `models/user_profile.dart` |
| 21 | Consent model | `models/consent_record.dart` |
| 22 | Firestore service | `services/firestore_service.dart` |
| 23 | Create user doc on register | auth_repository |
| 24 | Onboarding wizard | `features/onboarding/presentation/onboarding_screen.dart` |
| 25 | Consent step (face/voice/text toggles) | `features/onboarding/widgets/consent_step.dart` |
| 26 | Terms + Privacy + 18+ steps | onboarding widgets |
| 27 | Wellness goal + timezone | onboarding widgets |
| 28 | Recording tutorial + disclaimer | onboarding widgets |
| 29 | Set `onboardingComplete: true` | firestore on finish |
| 30 | Skip onboarding if already complete | router redirect logic |

### Step 5: Profile & Settings Stub (Days 22–28)

| # | Task | Files |
|---|------|-------|
| 31 | Profile screen | `features/settings/presentation/profile_screen.dart` |
| 32 | Settings shell | `features/settings/presentation/settings_screen.dart` |
| 33 | Home placeholder (empty) | `features/dashboard/presentation/home_stub_screen.dart` |
| 34 | Deploy rules | `firebase deploy --only firestore:rules,storage` |

## M1 Exit Gate

- [ ] New user: install → register → onboard → land on empty home
- [ ] Returning user: login → skip onboarding → home
- [ ] Consent + profile visible in Firestore Console
- [ ] Google Sign-In works on target device
- [ ] Password reset email received
- [ ] Other teammates clone repo and run app from README
- [ ] `flutter analyze` clean; auth widget tests pass

## M1 Handoff Doc Must Include

- Firebase project ID and who has Console access
- Package name / bundle ID
- How to create a test user
- Known issues (e.g. iOS Google Sign-In quirks)

---

# Module M2 — Video Journal

**Owner:** Shambhavi (Turn 2) · **Duration:** 5–6 weeks · **Depends on:** M1

## Scope Summary

Record, upload, journal list, playback, streaks, analysis job trigger.

## Implementation Steps

### Step 1: Models & Services (Days 1–5)

| # | Task | Files |
|---|------|-------|
| 1 | Journal model | `models/journal_entry.dart` |
| 2 | Analysis job model | `models/analysis_job.dart` |
| 3 | Storage service | `services/storage_service.dart` |
| 4 | Journal repository | `features/journal/data/journal_repository.dart` |
| 5 | Streak calculator | `features/journal/domain/streak_service.dart` |

### Step 2: Recording (Days 6–14)

| # | Task | Files |
|---|------|-------|
| 6 | Permission flow | `services/permission_service.dart` |
| 7 | Record screen | `features/journal/presentation/record_screen.dart` |
| 8 | Camera controller wrapper | `features/journal/widgets/camera_preview_widget.dart` |
| 9 | Countdown overlay | `features/journal/widgets/countdown_overlay.dart` |
| 10 | Timer + 3-min auto-stop | record_screen |
| 11 | Preview before upload | `features/journal/presentation/preview_screen.dart` |
| 12 | Re-record flow | preview_screen |

### Step 3: Upload & Jobs (Days 15–21)

| # | Task | Files |
|---|------|-------|
| 13 | Upload with progress | journal_repository + UI progress bar |
| 14 | Retry on failure (3x backoff) | journal_repository |
| 15 | Create journal doc `uploading` → `queued` | firestore |
| 16 | Storage path `users/{uid}/videos/{journalId}/video.mp4` | storage_service |
| 17 | Thumbnail generation (optional frame capture) | journal_repository |
| 18 | Create `analysis_jobs/{jobId}` on upload complete | journal_repository |
| 19 | Update user streak + lastJournalDate | streak_service |

### Step 4: Journal List & Detail (Days 22–28)

| # | Task | Files |
|---|------|-------|
| 20 | Journal list screen | `features/journal/presentation/journal_list_screen.dart` |
| 21 | Status badges (uploading/queued/processing/complete/failed) | journal_list widgets |
| 22 | Pagination (limit 20) | journal_repository |
| 23 | Journal detail + video player | `features/journal/presentation/journal_detail_screen.dart` |
| 24 | Delete journal (Storage + Firestore) | journal_repository |
| 25 | FAB / Record CTA on home stub | home_stub_screen |
| 26 | Wire bottom nav: Home, Journals, Settings | main_shell |

## M2 Exit Gate

- [ ] Record → upload → journal appears in list with thumbnail
- [ ] Video plays back from Storage
- [ ] Delete removes Firestore doc and Storage file
- [ ] `analysis_jobs` doc created with `status: queued`
- [ ] Streak increments on consecutive days; resets correctly
- [ ] Upload retry works after airplane mode toggle
- [ ] 3-minute auto-stop verified

## M2 Handoff Doc Must Include

- Storage path convention
- Journal document field list
- How to manually inspect jobs in Firestore
- Sample video duration/size for worker testing

---

# Module M3 — AI Analysis Engine

**Owner:** Yanish (Turn 3) · **Duration:** 6–7 weeks · **Depends on:** M2

## Scope Summary

Full Python pipeline + Flutter analysis status/results UI.

## Implementation Steps

### Step 1: Worker Scaffold (Days 1–7)

| # | Task | Files |
|---|------|-------|
| 1 | Firebase Admin init | `worker/firebase_client.py` |
| 2 | Main poll loop | `worker/main.py` |
| 3 | Job claim + state updates | `worker/job_processor.py` |
| 4 | Download from Storage | `worker/pipeline/download.py` |
| 5 | Config from env | `worker/config.py`, `.env.example` |
| 6 | Worker README section | root `README.md` |

### Step 2: Media & Transcription (Days 8–14)

| # | Task | Files |
|---|------|-------|
| 7 | ffmpeg audio extract | `worker/pipeline/transcode.py` |
| 8 | faster-whisper transcribe | `worker/pipeline/transcribe.py` |
| 9 | Write transcript to journal | job_processor |
| 10 | processingStep updates | job_processor |

### Step 3: Modality Analysis (Days 15–28)

| # | Task | Files |
|---|------|-------|
| 11 | Load user consents | `worker/pipeline/consent.py` |
| 12 | Face analysis (MediaPipe) | `worker/pipeline/face.py` |
| 13 | Skip face if consent off | job_processor |
| 14 | Voice analysis (librosa) | `worker/pipeline/voice.py` |
| 15 | NLP (VADER) | `worker/pipeline/nlp.py` |
| 16 | Quality score | `worker/pipeline/quality.py` |
| 17 | Unit tests per module | `worker/tests/test_*.py` |

### Step 4: Fusion, Baseline, Insights (Days 29–35)

| # | Task | Files |
|---|------|-------|
| 18 | Late fusion | `worker/pipeline/fusion.py` |
| 19 | EWMA baseline | `worker/pipeline/baseline.py` |
| 20 | Template insights | `worker/pipeline/insights.py` |
| 21 | Orchestrator | `worker/pipeline/orchestrator.py` |
| 22 | Failure + retry logic | job_processor |

### Step 5: Flutter Analysis UI (Days 36–42)

| # | Task | Files |
|---|------|-------|
| 23 | Journal stream listener | journal_detail updates |
| 24 | Processing indicator + steps | `features/analysis/widgets/analysis_progress.dart` |
| 25 | Transcript view | `features/analysis/widgets/transcript_card.dart` |
| 26 | Modality summary cards | `features/analysis/widgets/modality_cards.dart` |
| 27 | Congruence + confidence display | analysis widgets |
| 28 | Failed state + message | journal_detail |
| 29 | Low quality warning | analysis widgets |

## M3 Exit Gate

- [ ] Worker: upload → full analysis in Firestore within ~8 min (3-min video)
- [ ] App auto-updates via listener (no manual refresh)
- [ ] Face skipped when user opted out in M1
- [ ] 2nd journal updates `baselines/` docs
- [ ] ≥1 template insight after sufficient entries
- [ ] README: how to run worker with venv
- [ ] pytest passes for fusion, baseline, consent skip

## M3 Handoff Doc Must Include

- Worker run command
- Expected processing times per step
- Firestore fields written by worker
- Insight trigger conditions
- How to reset/requeue a failed job manually

---

# Module M4 — Dashboard & Insights

**Owner:** Rajeev (Turn 4) · **Duration:** 4–5 weeks · **Depends on:** M3

## Scope Summary

Home dashboard, trends, insight center — read-only on worker output.

## Implementation Steps

### Step 1: Dashboard Home (Days 1–10)

| # | Task | Files |
|---|------|-------|
| 1 | Replace home stub | `features/dashboard/presentation/dashboard_screen.dart` |
| 2 | Streak widget | `features/dashboard/widgets/streak_widget.dart` |
| 3 | Latest journal summary | dashboard widgets |
| 4 | Record CTA | dashboard |
| 5 | Latest insight preview | dashboard widgets |
| 6 | Baseline progress ("3/7 entries") | `features/dashboard/widgets/baseline_progress.dart` |

### Step 2: Trends (Days 11–18)

| # | Task | Files |
|---|------|-------|
| 7 | Trend data provider | `features/timeline/providers/trend_provider.dart` |
| 8 | Query last 7 journals | firestore_service |
| 9 | Line chart valence/arousal | `features/timeline/presentation/timeline_screen.dart` |
| 10 | fl_chart baseline band | `features/timeline/widgets/trend_chart.dart` |
| 11 | Metric selector | timeline_screen |
| 12 | Empty states | timeline widgets |

### Step 3: Insights UI (Days 19–28)

| # | Task | Files |
|---|------|-------|
| 13 | Insight model | `models/insight.dart` |
| 14 | Insight list | `features/insights/presentation/insights_screen.dart` |
| 15 | Unread badge on nav | main_shell |
| 16 | Insight detail | `features/insights/presentation/insight_detail_screen.dart` |
| 17 | Evidence drawer | `features/insights/widgets/evidence_drawer.dart` |
| 18 | Helpful / not helpful | insight_detail |
| 19 | Suppress display if confidence < 0.6 | insights provider |
| 20 | Mark `isRead: true` on open | insight repository |

### Step 4: Navigation Polish (Days 29–35)

| # | Task | Files |
|---|------|-------|
| 21 | Bottom nav: Dashboard, Journals, Insights, Settings | main_shell |
| 22 | Deep link journal from evidence | router |
| 23 | Seed script or manual seed instructions | `docs/demo-seed.md` |

## M4 Exit Gate

- [ ] Dashboard populated with 7 seeded journal entries
- [ ] 7-day chart renders with baseline band
- [ ] ≥1 insight visible with evidence drawer
- [ ] Unread badge clears when insight opened
- [ ] Flow: login → dashboard → trends → insight → source journal
- [ ] Insights hidden when baseline confidence < 0.6

## M4 Handoff Doc Must Include

- How to seed demo data
- Chart metric definitions
- Insight list query (orderBy, filters)

---

# Module M5 — Trust, Notifications & Launch

**Owner:** Shambhavi (Turn 5) · **Duration:** 3–4 weeks · **Depends on:** M4

## Scope Summary

FCM, privacy, delete account, settings complete, demo polish.

## Implementation Steps

### Step 1: FCM (Days 1–10)

| # | Task | Files |
|---|------|-------|
| 1 | FCM service | `services/fcm_service.dart` |
| 2 | Request permission (iOS) | fcm_service |
| 3 | Save token to user doc | firestore_service |
| 4 | Handle foreground messages | fcm_service |
| 5 | Worker send on complete | `worker/notifications.py` |
| 6 | Deep link on tap | app_router |

### Step 2: In-App Notifications (Days 11–14)

| # | Task | Files |
|---|------|-------|
| 7 | Notification model | `models/app_notification.dart` |
| 8 | Notification center screen | `features/settings/presentation/notifications_screen.dart` |
| 9 | Deep links to journal/insight | notifications_screen |

### Step 3: Privacy & Data Rights (Days 15–21)

| # | Task | Files |
|---|------|-------|
| 10 | Privacy dashboard | `features/settings/presentation/privacy_screen.dart` |
| 11 | Consent revoke toggles | privacy_screen + firestore |
| 12 | Delete all data | `features/settings/data/deletion_service.dart` |
| 13 | Delete account (Auth + Firestore + Storage) | deletion_service |
| 14 | Confirm dialogs + irreversible warning | privacy UI |

### Step 4: Settings Complete & Demo (Days 22–28)

| # | Task | Files |
|---|------|-------|
| 15 | Change password | settings_screen |
| 16 | Notification prefs stub | settings_screen |
| 17 | About + version + disclaimer | settings_screen |
| 18 | Bug bash P0/P1 | — |
| 19 | Firebase rules audit | firestore.rules, storage.rules |
| 20 | Demo seed 2 accounts (7+ days) | script or doc |
| 21 | Android APK build | `flutter build apk` |
| 22 | Backup screen recording | demo assets |
| 23 | Final README | README.md |

## M5 Exit Gate

- [ ] Push received when analysis completes (physical device)
- [ ] Revoking face consent stops face on **next** entry
- [ ] Delete account removes Auth user and all data
- [ ] End-to-end demo without manual Firestore edits
- [ ] Second teammate runs demo from README alone
- [ ] Medical disclaimer on onboarding + insights

## M5 Handoff Doc Must Include

- Demo script (step-by-step)
- APK path or distribution method
- Known limitations for presentation
- Post-MVP backlog pointer

---

# Final Integration Week (All Three)

**Lead:** Yanish · **Duration:** 1–2 weeks · **After:** M5

| Task | Owner |
|------|-------|
| Full E2E demo rehearsal | All |
| Cross-device testing (iOS + Android) | All |
| Firestore rules pen-test (try cross-user access) | Rajeev |
| Worker stability (3 videos back-to-back) | Yanish |
| Slide deck: college prototype → scale architecture | PM / any |
| Record backup demo video | Shambhavi |

---

*Cross-reference tests: `03-Test-Catalog.md` · Edge cases: `04-Edge-Cases-And-Failure-Modes.md`*
