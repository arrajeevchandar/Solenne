# SOLENNE — Test Catalog

**Purpose:** Every test case to run before marking a module complete. Use for manual QA and automated test authoring.

**Priority key:** **P0** = must pass for exit gate · **P1** = should pass · **P2** = nice to have

---

## 1. Global / Cross-Module Tests

| ID | Type | Priority | Test Case | Expected Result |
|----|------|----------|-----------|-----------------|
| G-01 | Security | P0 | User A tries to read User B's journal doc | Permission denied |
| G-02 | Security | P0 | Client tries to update `analysis_jobs` status | Permission denied |
| G-03 | Security | P0 | Upload to another user's Storage path | Permission denied |
| G-04 | Security | P1 | Upload file > 100 MB | Rejected by Storage rules |
| G-05 | Lint | P0 | `flutter analyze` | No issues |
| G-06 | Unit | P0 | `flutter test` | All pass |
| G-07 | Unit | P0 | `pytest worker/tests/` | All pass |
| G-08 | UX | P0 | Medical disclaimer visible in onboarding | Text present |
| G-09 | UX | P0 | No diagnostic language in insight templates | Blocklist scan pass |

---

## 2. Module M1 — Identity & First Run

### 2.1 Automated Unit / Widget Tests

| ID | File (suggested) | Test Case | Expected |
|----|------------------|-----------|----------|
| M1-U-01 | `test/features/auth/auth_repository_test.dart` | Valid email/password register | User created, no throw |
| M1-U-02 | auth_repository_test | Invalid email format | Validation error |
| M1-U-03 | auth_repository_test | Password < 8 chars | Validation error |
| M1-U-04 | auth_repository_test | Login wrong password | AuthException |
| M1-U-05 | `test/features/onboarding/consent_test.dart` | All consents false still allows proceed with warning | onboardingComplete set |
| M1-U-06 | consent_test | Consent doc schema | type, granted, version, createdAt |
| M1-U-07 | `test/core/router/auth_redirect_test.dart` | Unauthenticated → /login | Redirect |
| M1-U-08 | auth_redirect_test | Authenticated + !onboarding → /onboarding | Redirect |
| M1-U-09 | auth_redirect_test | Authenticated + onboarding → /home | Redirect |

### 2.2 Integration Tests

| ID | Priority | Test Case | Steps | Expected |
|----|----------|-----------|-------|----------|
| M1-I-01 | P0 | Email registration E2E | Register → onboard → home | Home visible, Firestore user doc |
| M1-I-02 | P0 | Returning user | Login existing → home | Skips onboarding |
| M1-I-03 | P1 | Google Sign-In | Tap Google → select account | Logged in |
| M1-I-04 | P1 | Password reset | Forgot password → email | Reset email sent |
| M1-I-05 | P0 | Logout | Logout from settings | Returns to login |

### 2.3 Manual QA

| ID | Priority | Test Case | Expected |
|----|----------|-----------|----------|
| M1-M-01 | P0 | Fresh install onboarding time | < 5 min user effort |
| M1-M-02 | P0 | Timezone saved correctly | Matches device or selection |
| M1-M-03 | P0 | Teammate clone + run | Works from README alone |
| M1-M-04 | P1 | Rotate device during onboarding | State preserved |
| M1-M-05 | P1 | Kill app mid-onboarding | Resumes or restarts cleanly |

---

## 3. Module M2 — Video Journal

### 3.1 Automated Tests

| ID | File | Test Case | Expected |
|----|------|-----------|----------|
| M2-U-01 | `test/features/journal/streak_service_test.dart` | First journal ever | streak = 1 |
| M2-U-02 | streak_service_test | Same day second journal | streak unchanged |
| M2-U-03 | streak_service_test | Next day journal | streak + 1 |
| M2-U-04 | streak_service_test | Skip one day | streak resets to 1 |
| M2-U-05 | `test/models/journal_entry_test.dart` | Serialize/deserialize journal | Round-trip OK |
| M2-U-06 | `test/services/storage_service_test.dart` | Storage path format | `users/{uid}/videos/{id}/video.mp4` |

### 3.2 Integration Tests

| ID | Priority | Test Case | Expected |
|----|----------|-----------|----------|
| M2-I-01 | P0 | Record → upload → list | Journal in list, status queued |
| M2-I-02 | P0 | Playback | Video plays |
| M2-I-03 | P0 | Delete journal | Removed from list + Storage |
| M2-I-04 | P0 | analysis_jobs created | Doc exists, status queued, correct userId |
| M2-I-05 | P1 | Upload retry | Airplane mode mid-upload → retry succeeds |
| M2-I-06 | P0 | 3-minute auto-stop | Recording stops at 180s |

### 3.3 Manual QA

| ID | Priority | Test Case | Expected |
|----|----------|-----------|----------|
| M2-M-01 | P0 | Deny camera permission | Clear error + settings link |
| M2-M-02 | P0 | Deny mic permission | Cannot record |
| M2-M-03 | P0 | Re-record before upload | Old local file discarded |
| M2-M-04 | P1 | Low storage device | Graceful error |
| M2-M-05 | P1 | Background app during upload | Upload continues or resumes |
| M2-M-06 | P0 | Thumbnail visible in list | Image loads |
| M2-M-07 | P1 | Status badge transitions | uploading → queued |

---

## 4. Module M3 — AI Analysis Engine

### 4.1 Python Unit Tests

| ID | File | Test Case | Expected |
|----|------|-----------|----------|
| M3-U-01 | `tests/test_fusion.py` | All 3 modalities present | Fused valence/arousal in range |
| M3-U-02 | test_fusion.py | Face missing (consent off) | Weights re-normalized voice+text |
| M3-U-03 | test_fusion.py | All modalities low confidence | InsufficientDataError |
| M3-U-04 | `tests/test_baseline.py` | First entry | Baseline created, low confidence |
| M3-U-05 | test_baseline.py | Second entry | EWMA updated |
| M3-U-06 | test_baseline.py | Z-score calculation | Matches formula ±ε |
| M3-U-07 | `tests/test_insights.py` | Valence drop trigger | T1 template selected |
| M3-U-08 | test_insights.py | Blocklist word in output | Rejected/rewritten |
| M3-U-09 | `tests/test_consent.py` | Face consent false | face.py not called |
| M3-U-10 | `tests/test_transcribe.py` | Sample audio file | Non-empty transcript |
| M3-U-11 | `tests/test_orchestrator.py` | Mock pipeline | Journal doc fields populated |

### 4.2 Worker Integration Tests

| ID | Priority | Test Case | Expected |
|----|----------|-----------|----------|
| M3-I-01 | P0 | Process queued job | status → complete |
| M3-I-02 | P0 | Failed download | status → failed, errorMessage set |
| M3-I-03 | P1 | Retry failed job (retryCount < 3) | Re-queued or retried |
| M3-I-04 | P0 | processingStep updates | Visible in Firestore during run |
| M3-I-05 | P0 | Corrupt video file | status failed, no partial crash |

### 4.3 Flutter Tests

| ID | Priority | Test Case | Expected |
|----|----------|-----------|----------|
| M3-F-01 | P0 | Listener updates UI on status change | Progress → complete without refresh |
| M3-F-02 | P0 | Transcript renders | Text matches Firestore |
| M3-F-03 | P0 | Face card hidden when no facial data | UI adapts |
| M3-F-04 | P1 | Failed analysis state | Error message + optional retry hint |
| M3-F-05 | P1 | Low quality warning | Banner when qualityScore < 0.5 |

### 4.4 Manual QA (Worker)

| ID | Priority | Test Case | Expected |
|----|----------|-----------|----------|
| M3-M-01 | P0 | 3-min video full pipeline | Complete in ≤ 8 min |
| M3-M-02 | P0 | 2 videos sequential | Both complete |
| M3-M-03 | P0 | Worker stopped mid-job | Job failed or stuck — manual recovery documented |
| M3-M-04 | P1 | No face visible video | Low face confidence; pipeline continues |
| M3-M-05 | P0 | Face consent off | No facial block in journal doc |

---

## 5. Module M4 — Dashboard & Insights

### 5.1 Automated Tests

| ID | File | Test Case | Expected |
|----|------|-----------|----------|
| M4-U-01 | `test/features/timeline/trend_provider_test.dart` | 7 journals query | 7 points returned |
| M4-U-02 | trend_provider_test | < 2 journals | Empty chart state |
| M4-U-03 | `test/features/insights/insight_filter_test.dart` | confidence 0.5 | Insight suppressed |
| M4-U-04 | insight_filter_test | confidence 0.7 | Insight shown |
| M4-U-05 | `test/features/dashboard/baseline_progress_test.dart` | 3 entries | Shows 3/7 |

### 5.2 Manual QA

| ID | Priority | Test Case | Expected |
|----|----------|-----------|----------|
| M4-M-01 | P0 | Dashboard with 7 entries | Streak, latest journal, chart preview |
| M4-M-02 | P0 | 7-day chart | Valence line + baseline band |
| M4-M-03 | P0 | Insight evidence drawer | Links to correct journal IDs |
| M4-M-04 | P0 | Open insight | isRead true, badge clears |
| M4-M-05 | P0 | Helpful feedback | Stored in Firestore |
| M4-M-06 | P1 | Empty insights list | Friendly empty state |
| M4-M-07 | P0 | Navigate evidence → journal | Opens journal detail |

---

## 6. Module M5 — Trust & Launch

### 6.1 Automated Tests

| ID | File | Test Case | Expected |
|----|------|-----------|----------|
| M5-U-01 | `test/features/settings/deletion_service_test.dart` | Delete all data mock | All collections deleted |
| M5-U-02 | deletion_service_test | Delete account | Auth delete called |
| M5-U-03 | `test/features/settings/consent_revoke_test.dart` | Revoke face | Consent doc updated |

### 6.2 Manual QA

| ID | Priority | Test Case | Expected |
|----|----------|-----------|----------|
| M5-M-01 | P0 | FCM on analysis complete | Notification on device |
| M5-M-02 | P0 | Tap notification | Opens journal/insight |
| M5-M-03 | P0 | Revoke face → new journal | No facial metrics |
| M5-M-04 | P0 | Delete all data | Journals, insights, baselines gone |
| M5-M-05 | P0 | Delete account | Cannot login; data gone |
| M5-M-06 | P0 | Change password | New password works |
| M5-M-07 | P0 | Full demo script | 10-min uninterrupted flow |
| M5-M-08 | P1 | iOS notification permission denied | In-app still works |

---

## 7. End-to-End Demo Script (Final Gate)

Run before class demo. **P0 — all steps must pass.**

| Step | Action | Verify |
|------|--------|--------|
| 1 | Worker running on laptop | Log: polling |
| 2 | Login demo account | Dashboard loads |
| 3 | Record 30–60s journal | Upload completes |
| 4 | Wait for analysis | Push received (M5) or status complete |
| 5 | Open journal detail | Transcript + metrics visible |
| 6 | Open dashboard trends | Chart shows data point |
| 7 | Open insights | ≥1 card with evidence |
| 8 | Open privacy screen | Data summary accurate |
| 9 | Logout → login second account | Data isolated |
| 10 | (Optional) Delete test entry | Removed cleanly |

---

## 8. Performance Benchmarks

| ID | Metric | Target | How to Measure |
|----|--------|--------|----------------|
| P-01 | Analysis time (3-min video) | ≤ 8 min p95 | Worker logs |
| P-02 | Upload time (50 MB WiFi) | ≤ 2 min | Client timer |
| P-03 | Dashboard load | ≤ 2 s | Flutter DevTools |
| P-04 | Firestore listener latency | ≤ 2 s | Status UI update |
| P-05 | App cold start | ≤ 3 s | Stopwatch |

---

## 9. Test Data Fixtures

### 9.1 Sample Users

| Account | Purpose |
|---------|---------|
| `demo1@solenne.test` | Primary demo — 7+ seeded journals |
| `demo2@solenne.test` | Secondary — privacy/delete tests |
| `fresh@solenne.test` | Empty — onboarding tests |

### 9.2 Sample Videos (Worker Tests)

| File | Duration | Purpose |
|------|----------|---------|
| `fixtures/short_clear.mp4` | 30s, face visible | Happy path |
| `fixtures/no_face.mp4` | 30s, no face | Face confidence low |
| `fixtures/noisy_audio.mp4` | 60s | Voice quality test |
| `fixtures/corrupt.mp4` | invalid | Failure handling |

Store in `worker/tests/fixtures/` (git LFS or download script if large).

---

## 10. CI Test Matrix

| Job | Command | When |
|-----|---------|------|
| Flutter analyze | `flutter analyze` | Every PR |
| Flutter unit | `flutter test` | Every PR |
| Worker unit | `pytest worker/tests -v` | Every PR |
| Android build | `flutter build apk --debug` | PR to main |
| Integration | Manual / nightly | Pre-demo |

---

*Map failures to edge cases: `04-Edge-Cases-And-Failure-Modes.md`*
