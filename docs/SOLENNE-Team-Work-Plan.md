# SOLENNE — Major Modules & 3-Person Work Plan

**Version:** 2.0.0  
**Date:** June 17, 2026  
**Team:** Rajeev · Shambhavi · Yanish  
**Stack:** Flutter + Firebase + Python ML worker

---

## How We Work

Each person takes **one full major module** — a large, self-contained chunk of the app — and owns it **start to finish** before handing off to the next person.

| Rule | Detail |
|------|--------|
| **One module = one owner** | That person builds everything inside the module (UI + Firebase + worker code if applicable) |
| **Rotation** | Rajeev → Shambhavi → Yanish → Rajeev → … |
| **While someone builds** | The other two review PRs, test on device, update docs — they do **not** split the module |
| **Handoff** | Module is done when its **Exit Gate** passes; owner writes a short handoff note |
| **Order matters** | Modules must be done in sequence — each depends on the previous |

**Timeline:** ~4–6 weeks per major module · 5 modules · ~24 weeks total to MVP

---

## App Module Map (High Level)

SOLENNE mobile app breaks into **5 major modules**. Everything in the app belongs to exactly one of these.

```
┌─────────────────────────────────────────────────────────────────┐
│  MODULE 1 — Identity & First Run                                │
│  Firebase setup · App shell · Auth · Onboarding · Profile       │
└────────────────────────────┬────────────────────────────────────┘
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  MODULE 2 — Video Journal                                       │
│  Record · Upload · Journal list · Playback · Streaks            │
└────────────────────────────┬────────────────────────────────────┘
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  MODULE 3 — AI Analysis Engine                                  │
│  Python worker · Transcript · Face/Voice/NLP · Results UI       │
└────────────────────────────┬────────────────────────────────────┘
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  MODULE 4 — Dashboard & Insights                                │
│  Home screen · Trend charts · Insight cards · Evidence          │
└────────────────────────────┬────────────────────────────────────┘
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  MODULE 5 — Trust, Notifications & Launch                     │
│  Push · Privacy · Settings · Delete account · Demo polish       │
└─────────────────────────────────────────────────────────────────┘
```

---

## Rotation Schedule

| Turn | Major Module | Owner | Est. Duration | Depends On |
|------|--------------|-------|---------------|------------|
| **1** | M1 — Identity & First Run | **Rajeev** | 4–5 weeks | — |
| **2** | M2 — Video Journal | **Shambhavi** | 5–6 weeks | M1 |
| **3** | M3 — AI Analysis Engine | **Yanish** | 6–7 weeks | M2 |
| **4** | M4 — Dashboard & Insights | **Rajeev** | 4–5 weeks | M3 |
| **5** | M5 — Trust, Notifications & Launch | **Shambhavi** | 3–4 weeks | M4 |
| **Final** | Integration & demo (all three) | **Yanish leads** | 1–2 weeks | M5 |

> **Note:** Yanish's second turn is the heaviest module (M3 — worker + ML). Rajeev returns for M4 after M3 ships. Shambhavi closes with M5. All three integrate for demo week.

---

# The 5 Major Modules

---

## Module 1 — Identity & First Run

**Owner:** Rajeev (Turn 1)  
**One-line summary:** Everything from app install until a logged-in user with a completed profile is ready to record their first journal.

This module combines what was previously split into Platform, Auth, Onboarding, and Profile — **one person, one module**.

### What's inside this module

| Area | Features |
|------|----------|
| **Platform** | Firebase project (Spark), Flutter app scaffold, `flutterfire configure`, repo structure |
| **App shell** | Theme, `go_router` navigation, bottom nav skeleton, Riverpod setup |
| **Security rules** | Firestore + Storage rules (user-scoped paths) |
| **Authentication** | Email register/login, Google Sign-In, password reset, logout, auth guard |
| **Onboarding** | Welcome flow, Terms/Privacy acceptance, 18+ gate, modality consent (face/voice/text), wellness goal, timezone, recording tutorial, medical disclaimer |
| **Profile** | View/edit display name, timezone, wellness goal; profile screen linked from settings stub |
| **First-run logic** | Skip onboarding if already complete; new users forced through consent |

### Screens delivered

- Login · Register · Forgot Password  
- Onboarding wizard (multi-step)  
- Profile · Settings (shell only — filled in M5)

### Exit gate

- [ ] New user: install → register → onboard → land on empty home  
- [ ] Returning user: login → skip onboarding → home  
- [ ] Consent + profile data visible in Firestore  
- [ ] Other team members can clone repo and run the app  

---

## Module 2 — Video Journal

**Owner:** Shambhavi (Turn 2)  
**One-line summary:** The core product loop — record a video journal, upload it, see it in history, play it back.

### What's inside this module

| Area | Features |
|------|----------|
| **Recording** | Camera/mic permissions, preview, countdown, timer, 3-min auto-stop, local preview, re-record |
| **Upload** | Firebase Storage upload with progress bar, retry on failure, journal Firestore doc creation |
| **Job trigger** | Create `analysis_jobs` doc when upload completes; set `analysisStatus: queued` |
| **Journal list** | Paginated history, thumbnails, status badges (uploading / queued / processing / complete / failed) |
| **Streaks** | Consecutive-day counter |
| **Playback** | Video player from Storage, play/pause/seek |
| **Journal detail** | Metadata (date, duration), delete entry (Firestore + Storage) |
| **Home stub** | Empty dashboard placeholder with "Record" FAB — replaced in M4 |

### Screens delivered

- Record (camera) · Preview before upload  
- Journal list · Journal detail (video player)

### Exit gate

- [ ] Record → upload → journal appears in list with thumbnail  
- [ ] Video plays back from Storage  
- [ ] Delete removes entry from list and Storage  
- [ ] `analysis_jobs` doc created on successful upload  
- [ ] Streak updates correctly  

---

## Module 3 — AI Analysis Engine

**Owner:** Yanish (Turn 3)  
**One-line summary:** The Python worker that processes videos plus all Flutter UI that shows analysis progress and results.

This is the **largest module** — backend pipeline and frontend results together.

### What's inside this module

| Area | Features |
|------|----------|
| **Worker scaffold** | Python + Firebase Admin SDK, poll `analysis_jobs`, job state machine |
| **Media processing** | Download video from Storage, ffmpeg audio extraction |
| **Transcription** | faster-whisper (`small`, CPU) → transcript on journal doc |
| **Face analysis** | MediaPipe — valence, arousal, emotion probs (skip if consent off) |
| **Voice analysis** | librosa — energy, pitch, speaking rate, pause ratio |
| **NLP** | VADER — sentiment, stress markers, topic stubs |
| **Fusion & baseline** | Wellness vector on journal doc; EWMA baselines in `baselines/` collection |
| **Insight generation** | Template-based insights written to `insights/` collection |
| **Status UI (Flutter)** | Real-time `analysisStatus` listener, processing steps, failed/retry state |
| **Results UI (Flutter)** | Transcript view, face/voice/NLP summary cards, confidence scores, congruence score, low-quality warning |

### Code paths

- `worker/` — entire Python pipeline  
- `mobile/lib/features/analysis/` — results + status widgets  
- Updates to journal detail from M2 (analysis sections)

### Exit gate

- [ ] Worker on laptop: upload → full analysis in Firestore within ~8 min  
- [ ] App auto-updates when worker writes (no manual refresh)  
- [ ] Face analysis skipped when user opted out in M1  
- [ ] 2nd journal entry updates baselines  
- [ ] At least 1 template insight generated after enough entries  
- [ ] README documents how to run the worker  

---

## Module 4 — Dashboard & Insights

**Owner:** Rajeev (Turn 4)  
**One-line summary:** Everything the user sees to understand their emotional patterns — home dashboard, trend charts, and insight center.

Reads data written by M3; does **not** rebuild the worker.

### What's inside this module

| Area | Features |
|------|----------|
| **Dashboard home** | Streak widget, latest journal summary, record CTA, latest insight preview, baseline progress ("3/7 entries") |
| **Trend charts** | 7-day valence/arousal line chart (`fl_chart`), baseline confidence band overlay |
| **Timeline** | Full trends screen, metric selector, empty states |
| **Insight list** | Cards sorted by date, unread badge on nav |
| **Insight detail** | Full text, confidence %, evidence drawer (links to source journals) |
| **Insight feedback** | Helpful / not helpful, dismiss, suppress when baseline confidence <0.6 |
| **Navigation** | Replace M2 home stub with real dashboard; wire bottom nav tabs |

### Screens delivered

- Dashboard (home) · Timeline/Trends  
- Insights list · Insight detail

### Exit gate

- [ ] Dashboard populated with 7 seeded journal entries  
- [ ] 7-day chart renders with baseline band  
- [ ] ≥1 insight visible with evidence drawer  
- [ ] Unread badge clears when insight opened  
- [ ] Full flow: login → dashboard → trends → insight → source journal  

---

## Module 5 — Trust, Notifications & Launch

**Owner:** Shambhavi (Turn 5)  
**One-line summary:** Push notifications, privacy controls, full settings, account deletion, and demo-ready polish.

### What's inside this module

| Area | Features |
|------|----------|
| **Push (FCM)** | Permission request, save token to user doc, worker sends push on analysis complete |
| **In-app notifications** | Notification list, deep links to journal/insight |
| **Privacy dashboard** | What's stored, consent revoke toggles (face/voice/text) |
| **Data rights** | Delete all data, delete account (Firestore + Storage + Auth cascade) |
| **Settings (complete)** | Change password, notification prefs stub, about/version, medical disclaimer |
| **Demo prep** | Seed 2 demo accounts (7+ days data), backup screen recording, Android APK build |
| **Hardening** | Bug bash P0/P1, Firebase rules final audit, README final polish |

### Screens delivered

- Settings (complete) · Privacy dashboard · Notification center

### Exit gate

- [ ] Push received when analysis completes  
- [ ] Revoking face consent stops face analysis on next entry  
- [ ] Delete account removes all user data  
- [ ] End-to-end demo works without manual intervention  
- [ ] Second team member can run full demo from README alone  

---

# Module Summary Table

Use this to confirm scope before each turn starts.

| # | Module | Owner | Size | Flutter | Worker | Firebase |
|---|--------|-------|------|---------|--------|----------|
| **M1** | Identity & First Run | Rajeev | Medium | ✅ All | — | Setup + rules |
| **M2** | Video Journal | Shambhavi | Large | ✅ All | — | Storage + journals |
| **M3** | AI Analysis Engine | Yanish | **XL** | ✅ Results UI | ✅ All | Jobs + metrics |
| **M4** | Dashboard & Insights | Rajeev | Large | ✅ All | — | Read-only queries |
| **M5** | Trust & Launch | Shambhavi | Medium | ✅ All | FCM hook | Privacy/delete |

---

# What Each Person Owns (Total)

| Person | Modules | Primary skills used |
|--------|---------|---------------------|
| **Rajeev** | M1, M4 | Flutter UI, Firebase Auth/Firestore, charts |
| **Shambhavi** | M2, M5 | Flutter camera/storage, FCM, privacy flows |
| **Yanish** | M3 (+ demo lead) | Python ML, worker pipeline, analysis UI |

---

# Handoff Checklist (Every Module)

When you finish your module, the next person should be able to start **without asking you questions**.

- [ ] All Exit Gate items checked  
- [ ] PR merged to `develop`  
- [ ] `docs/handoffs/M{N}.md` written: what shipped, how to run, known bugs, Firestore schema changes  
- [ ] 15-min demo to the other two  
- [ ] README updated if setup changed  

---

# Feature Ownership Map

Quick reference: where does each user-facing capability live?

| User capability | Module |
|-----------------|--------|
| Sign up / log in | M1 |
| Accept consent / onboard | M1 |
| Edit profile | M1 |
| Record video journal | M2 |
| Upload & see journal list | M2 |
| Play back video | M2 |
| See analysis processing status | M3 |
| Read transcript & AI metrics | M3 |
| View 7-day emotional trends | M4 |
| Read personalized insights | M4 |
| Get push when analysis done | M5 |
| Manage privacy / delete account | M5 |
| Demo-ready app | M5 |

---

# Post-MVP (Not in Any Module Above)

These are explicitly **out of scope** for the 5 modules. Add as Module 6+ later if needed.

- Apple Sign-In · MFA · Biometric lock  
- 30/90-day trends · Calendar heatmap  
- Audio-only recording · Offline upload queue  
- LLM insight phrasing (Ollama) · Paid APIs  
- GDPR automated export ZIP · App Store release  
- Web app · AWS migration  

---

## Related Docs

| Document | Use |
|----------|-----|
| `SOLENNE-Zero-Budget-Build-Plan.md` | Architecture, repo structure, Firestore schema |
| `SOLENNE-Engineering-Execution-Plan.md` | Detailed sub-module specs (M1.1–M12.2) |
| `SOLENNE-Weekly-Tracker.md` | Week-by-week status during each module |

---

*One person. One module. Full ownership. Then hand off.*
