# SOLENNE — Edge Cases & Failure Modes

**Purpose:** Known edge cases, expected behavior, and recovery patterns. Review before shipping each module.

---

## 1. Authentication & Session (M1)

| Edge Case | Expected Behavior | Implementation Notes |
|-----------|-------------------|----------------------|
| Email already registered | Show "account exists" + link to login | Catch `email-already-in-use` |
| Weak password | Inline validation before submit | Min 8 chars; Firebase rules |
| Network loss during register | Error banner + retry | Don't set onboardingComplete |
| Google Sign-In cancelled | Return to login, no error toast | Silent cancel |
| Token expired mid-session | Refresh or redirect to login | Firebase handles refresh |
| User deletes app mid-onboarding | Restart onboarding on reinstall | Check Firestore onboardingComplete |
| Clock skew / wrong timezone | User selects timezone explicitly | Don't rely on device only |
| Firebase Auth user exists but no Firestore doc | Create doc on first login | Migration helper in auth_repository |
| Logout during onboarding | Clear stack → login | Reset navigation |

---

## 2. Onboarding & Consent (M1)

| Edge Case | Expected Behavior | Implementation Notes |
|-----------|-------------------|----------------------|
| User denies all modality consents | Allow proceed; analysis limited to voice-only or text-only | Show warning about reduced insights |
| User accepts then revokes (M5) | Next journal respects new consent | Worker reads latest consent |
| Terms version bump | Re-prompt if stored version < current | Store `termsVersion` on user doc |
| Back button on onboarding | Go to previous step; don't skip consent | Pop nested navigator |
| Deep link to /home without onboarding | Redirect to onboarding | Router guard |
| 18+ gate false | Block account creation | Cannot proceed |
| Onboarding interrupted at step 4 | Resume from last saved step OR restart | Save `onboardingStep` optional |

---

## 3. Video Recording (M2)

| Edge Case | Expected Behavior | Implementation Notes |
|-----------|-------------------|----------------------|
| Camera permission denied | Explain + open settings button | permission_handler |
| Mic denied | Block record | Both required for video journal |
| Camera in use by another app | Error message | Catch CameraException |
| Recording hits 3:00 | Auto-stop + save file | Timer in RecordScreen |
| User stops at 0:05 | Allow upload or prompt re-record | Min duration warning optional (15s) |
| App backgrounded during record | Pause or stop recording | camera plugin behavior — test both platforms |
| Low disk space | Fail before record with message | Check path_provider space |
| Front vs back camera | Default front; toggle optional | P1 feature |
| Device rotation | Lock orientation or handle layout | Portrait lock recommended |
| Empty/corrupt local file | Block upload + allow re-record | Validate file size > 0 |

---

## 4. Upload & Storage (M2)

| Edge Case | Expected Behavior | Implementation Notes |
|-----------|-------------------|----------------------|
| Network drop mid-upload | Retry up to 3 times with exponential backoff | Resume not required MVP |
| Upload succeeds but Firestore write fails | Orphan file in Storage — cleanup job or manual | Write journal doc first with uploading status |
| Duplicate upload tap | Idempotent journal ID (UUID per session) | Disable button during upload |
| File > 100 MB | Reject before upload | Client-side size check + Storage rules |
| Auth token expires during upload | Refresh token and retry | Firebase SDK handles |
| Storage rules misconfigured | Clear error in logs | Test with rules emulator |
| Thumbnail generation fails | List shows placeholder icon | Non-blocking |
| User deletes account during upload | Upload may complete but user gone | Rare — acceptable MVP |

---

## 5. Journal List & Streaks (M2)

| Edge Case | Expected Behavior | Implementation Notes |
|-----------|-------------------|----------------------|
| No journals yet | Empty state + Record CTA | |
| 100+ journals | Paginate (limit 20) | Avoid read quota explosion |
| Streak: journal at 11:59 PM and 12:01 AM | Two different days — streak +1 | Use user timezone |
| Streak: two journals same day | Count once for streak | |
| Streak: miss one day | Reset to 1 on next journal | No forgiveness in MVP |
| Delete only journal | Streak recalculates | Recompute from history |
| Journal stuck in `uploading` | Show failed after timeout (10 min) | Client-side timeout |
| Clock change (DST) | Streak uses timezone-aware dates | use `timezone` package if needed |

---

## 6. Analysis Worker (M3)

| Edge Case | Expected Behavior | Implementation Notes |
|-----------|-------------------|----------------------|
| No jobs in queue | Sleep POLL_INTERVAL; log debug | Normal idle state |
| Two workers running | Both may claim — use transaction or `status` CAS | MVP: single laptop worker only |
| Job claimed but worker crashes | Job stuck in `processing` | Add stale job reaper (processing > 30 min → failed) |
| Video download 404 | Mark job failed | Storage path mismatch |
| ffmpeg missing | Fail fast with clear log | Pre-flight check in main.py |
| ffmpeg corrupt video | Job failed; errorMessage set | Catch stderr |
| Video with no audio track | Transcription empty; voice/NLP degraded | qualityScore low |
| Video with no detectable face | Skip face metrics; continue pipeline | face confidence = 0 |
| Face consent off | Skip face module entirely | Don't write facial block |
| Whisper OOM | Job failed; suggest smaller model | Use `small` + `int8` |
| Very long video (>3 min if bypassed) | Process or timeout at 15 min | Worker timeout |
| Empty transcript | NLP on empty string — neutral scores | Don't crash |
| librosa fails on silent audio | Voice metrics default + low confidence | |
| All modalities fail confidence | Job failed InsufficientDataError | User sees failed status |
| Partial write to Firestore | Use batch write for atomic journal update | |
| Baseline first entry | Create baseline with n=1, confidence ~0.05 | |
| Insight triggers on entry 1 | Suppress — need baseline confidence | Check in insights.py |
| FCM token missing | Skip push silently | Log info |
| FCM send fails | Don't fail job — already complete | Log warning |

---

## 7. Fusion & Baseline (M3)

| Edge Case | Expected Behavior | Implementation Notes |
|-----------|-------------------|----------------------|
| Only voice modality available | Re-normalize weights to voice=1.0 | |
| Valence out of range from model | Clamp to [-1, 1] | |
| Division by zero in Z-score | σ = 0 → use ε = 1e-6 | |
| Baseline with 21+ entries | Switch α from 0.10 to 0.05 | |
| Extreme outlier entry | EWMA adapts slowly — intentional | |
| User deletes old journals | Baseline not retroactively recomputed MVP | Document limitation |
| congruence with 1 modality | Return 1.0 (undefined incongruence) | Per SAD pseudocode |

---

## 8. Insights (M3/M4)

| Edge Case | Expected Behavior | Implementation Notes |
|-----------|-------------------|----------------------|
| Baseline confidence 0.59 | No new insights generated | Suppression |
| Multiple triggers same day | Max 1 insight per day MVP | Dedupe by date |
| Template produces clinical word | Blocklist filter / fallback generic | tests/test_insights.py |
| User dismisses insight | Mark dismissed; don't repeat same template 7 days | Optional P1 |
| Evidence references deleted journal | Show "entry unavailable" | Graceful UI |
| Empty insight list | Empty state on insights screen | |

---

## 9. Dashboard & Charts (M4)

| Edge Case | Expected Behavior | Implementation Notes |
|-----------|-------------------|----------------------|
| 1 data point | Chart shows dot + note "need more entries" | |
| Missing fused field on old journal | Skip point in chart | Null-safe |
| All valence null | Empty chart + message | |
| Baseline band with low confidence | Wider band or dashed style | Visual cue |
| fl_chart overflow | Scroll or scale | Test small screens |
| Query returns 7 entries but 3 incomplete | Chart only complete entries | Filter analysisStatus |

---

## 10. Notifications & FCM (M5)

| Edge Case | Expected Behavior | Implementation Notes |
|-----------|-------------------|----------------------|
| iOS permission denied | No push; in-app still works | Explain in settings |
| Android 13+ notification permission | Request runtime permission | |
| Token refresh | Update user doc on refresh | onTokenRefresh listener |
| App foreground notification | Show in-app banner or snackbar | FCM foreground handler |
| Tap notification app killed | Deep link opens correct screen | go_router initialLocation |
| Duplicate analysis complete push | Idempotent notification ID | Collapse by journalId |

---

## 11. Privacy & Deletion (M5)

| Edge Case | Expected Behavior | Implementation Notes |
|-----------|-------------------|----------------------|
| Delete all data | Remove journals, insights, baselines, consents, Storage videos | Batch delete |
| Delete account | Above + Auth user delete | Order: Storage → Firestore → Auth |
| Delete with queued job | Worker may fail on missing user — acceptable | Job fails gracefully |
| Revoke consent mid-processing | Current job uses consent at job start | Snapshot consent at processing start |
| Re-register same email after delete | Fresh account, no old data | New uid |

---

## 12. Firebase Quota & Cost

| Edge Case | Expected Behavior | Mitigation |
|-----------|-------------------|------------|
| Firestore reads exceeded | App errors | Paginate; cache; demo ≤20 users |
| Storage 5 GB full | Upload fails | Delete old test videos |
| Spark limit hit mid-demo | Pre-seed; monitor Console | Backup screen recording |
| Accidental Blaze upgrade | Budget alert $0 if upgraded | Stay Spark |

---

## 13. Platform-Specific

### iOS

| Edge Case | Behavior |
|-----------|----------|
| Simulator no camera | Use pre-recorded file injection for dev |
| Google Sign-In on simulator | May fail — use physical device |
| APNs not configured | No push until key uploaded |
| App Store guideline 4.8 | Need Apple Sign-In if Google offered — post-MVP |

### Android

| Edge Case | Behavior |
|-----------|----------|
| Emulator without Google Play | Google Sign-In fails |
| Background upload killed | Use foreground service post-MVP |
| Scoped storage | path_provider handles cache dir |

---

## 14. Error Message Guidelines (User-Facing)

| Situation | Message tone | Example |
|-----------|--------------|---------|
| Upload failed | Actionable | "Upload failed. Check your connection and try again." |
| Analysis failed | Non-alarming | "We couldn't analyze this entry. You can still watch your video." |
| Permission denied | Direct | "SOLENNE needs camera access to record journals." |
| Low quality | Gentle | "Lighting or audio was low — results may be less accurate." |
| Delete account | Serious | "This permanently deletes all journals and cannot be undone." |

**Never say:** "You seem depressed", "diagnosis", "disorder", "you should see a doctor" (except static crisis resource link in production).

---

## 15. Recovery Runbooks

### Stuck Job in `processing`

1. Firebase Console → `analysis_jobs/{id}`
2. Set `status: failed` or `queued` (via Admin SDK script)
3. Restart worker

### Orphan Storage File (no Firestore doc)

1. Identify path in Storage Console
2. Delete manually or run cleanup script

### Worker Won't Start

1. Check `serviceAccountKey.json` path
2. Check `FIREBASE_STORAGE_BUCKET` matches project
3. `pip install -r requirements.txt`
4. Verify ffmpeg on PATH

### Firestore Permission Denied for Valid User

1. Redeploy rules
2. Verify path `users/{auth.uid}/...`
3. Check user actually logged in (`FirebaseAuth.instance.currentUser`)

### Demo Day Worker Offline

1. Play backup screen recording
2. Use pre-seeded account with all analyses already complete

---

## 16. Security Edge Cases

| Attack / Mistake | Defense |
|------------------|---------|
| Client writes fake analysis metrics | Only worker (Admin SDK) writes metrics — rules deny client patch of facial/fused fields OR accept client can't write those fields (validate rules) |
| Client creates job for another userId | Rule: `request.resource.data.userId == request.auth.uid` |
| Scraping all jobs | Jobs readable only if resource.data.userId == auth.uid |
| Huge Firestore payload | Limit transcript segments count; truncate in worker |

**Recommended rule enhancement (M1):** Journal docs allow client create/update only on safe fields; worker uses Admin SDK for analysis fields. Alternatively, store analysis in subcollection `analysis/` with client read-only.

---

*Validate edge cases with tests in `03-Test-Catalog.md`*
