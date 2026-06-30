# User Journey Lifecycle

**Scope:** End-user experience from install to daily habit  
**Modules:** M1 → M2 → M3 → M4 → M5

---

## Stages

```
Stage 1          Stage 2           Stage 3            Stage 4
Install    →    Register/Login  →   Onboarding    →    First Record
                                                      (empty home)

Stage 5          Stage 6           Stage 7            Stage 8
Upload/Queue →  View Analysis  →  Trends/Insights →  Daily Habit
                                                      (streak, push)
```

---

## Stage Details

| Stage | Name | Trigger | UI | Module |
|-------|------|---------|-----|--------|
| **1** | Install | Download APK / run from IDE | Splash | M1 |
| **2** | Authenticate | Register or login | Login/Register | M1 |
| **3** | Onboard | First login, !onboardingComplete | Wizard + consent | M1 |
| **4** | Activate | First record intent | Record screen | M2 |
| **5** | Core loop | Upload → queue → process | Journal list + status | M2, M3 |
| **6** | Understand | Analysis complete | Journal detail results | M3 |
| **7** | Insight | baseline confidence ≥ 0.6 | Dashboard + insights | M4 |
| **8** | Habit | 3+ journals/week | Streak, push, reminders | M5 |

---

## Success Metrics (MVP)

| Metric | Target |
|--------|--------|
| Onboarding completion | < 5 min |
| Time to first journal | Same session as onboarding |
| D7 retention (class demo) | Qualitative — user returns to record again |
| Baseline completion | 5 entries in 7 days |

---

## Drop-Off Points to Watch

| Stage | Risk | Mitigation |
|-------|------|------------|
| 3 Onboard | Too long | Skip optional steps; progress indicator |
| 4 First record | Camera fear | Tutorial + disclaimer |
| 5 Upload | Network fail | Retry + progress |
| 6 Analysis wait | 8 min CPU | Status steps + push (M5) |
| 7 Insights | Too early | Suppress until baseline mature |

---

## State Persistence

| Stage data | Firestore |
|------------|-----------|
| onboardingComplete | `users/{uid}` |
| consents | `users/{uid}/consents/*` |
| streak | `users/{uid}.streakCount` |
| fcmToken | `users/{uid}.fcmToken` |
