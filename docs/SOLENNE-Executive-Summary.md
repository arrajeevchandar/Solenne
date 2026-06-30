# SOLENNE — Executive Summary

**Intelligent Video Journal for Passive Mental Wellness Monitoring**

| | |
|---|---|
| **Document type** | Executive summary for mentor review |
| **Version** | 1.0 |
| **Date** | June 13, 2026 |
| **Team context** | College capstone / startup prototype |
| **Budget** | $0 (Firebase free tier + local ML processing) |
| **Platform** | Flutter mobile app (iOS & Android) |

---

## One-Line Pitch

SOLENNE turns a daily 2–3 minute video journal into personalized wellness insights by analyzing facial expression, voice, and speech—without mood sliders, clinical labels, or a cloud bill.

---

## The Problem

Mental wellness tools today ask users to rate their mood on a 1–5 scale. That approach fails in practice:

- People forget to log, or stop after a few days.
- Self-reports are biased—especially when someone is stressed or exhausted.
- Snapshots miss patterns that only show up over weeks.
- Clinical tools feel heavy, stigmatizing, and hard to access.

People already talk about their day. Nobody wants another form to fill out.

---

## Our Solution

SOLENNE is a **mobile video journal** where users record a short daily clip about their thoughts, feelings, and experiences. The app **passively analyzes** multiple signals:

| Signal | What we extract |
|--------|-----------------|
| **Face** | Emotion, expression variability, engagement cues |
| **Voice** | Energy, pitch, pace, pauses |
| **Speech** | Sentiment, topics, stress-related language patterns |

Over 7–14 days, the system learns each user’s **personal baseline**—not a population average—and detects meaningful **deviations** from their normal patterns.

**Example insight (wellness language, not diagnosis):**

> *“Your voice energy has decreased by 18% over the last 9 days compared to your usual baseline.”*

### What SOLENNE is

- A tool for **self-awareness** and emotional trend tracking  
- A **private** daily reflection habit with data-driven feedback  
- An early signal for the user (or a trusted coach/therapist) to pay attention  

### What SOLENNE is not

- **Not a medical device** — we do not diagnose depression, anxiety, or any clinical condition  
- **Not a replacement** for professional mental health care  
- **Not a surveillance product** — users control what is analyzed and can delete their data  

---

## Target Users

| Segment | Need |
|---------|------|
| **Students** | Stress during exams, consistency without extra homework |
| **Young professionals** | Burnout awareness, work-life patterns |
| **Remote workers** | Isolation and disengagement over time |
| **Wellness-minded adults** | Quantified emotional trends, not single-day guesses |

Our primary demo persona is a **graduate student** who wants to understand stress patterns before they become overwhelming—without trusting unreliable self-reports.

---

## How It Works (User Journey)

```
Sign up → Consent (face / voice / text) → Record 2–3 min journal
    → Upload to cloud → AI analysis (~5–8 min on college hardware)
    → View transcript + emotional summary → See 7-day trends
    → Receive personalized insight when baseline is established
```

1. **Onboarding** — Clear consent for each analysis type; medical disclaimer.  
2. **Daily journal** — Native camera recording in the Flutter app.  
3. **Analysis** — Transcription + multimodal AI pipeline.  
4. **Dashboard** — Streak, recent mood signals, latest insight.  
5. **Timeline** — Week-over-week trends compared to personal baseline.  

---

## Technology Approach

### College build ($0/month)

We deliberately chose a stack that a student team can run **without AWS credits or paid APIs**:

| Layer | Choice | Why |
|-------|--------|-----|
| **Mobile app** | Flutter | One codebase for iOS and Android; strong camera support |
| **Auth & database** | Firebase (Spark free tier) | Auth, Firestore, Storage, push notifications |
| **Video storage** | Firebase Storage | Secure, user-scoped uploads (5 GB free) |
| **AI processing** | Python worker on team laptop | Whisper (speech), MediaPipe (face), librosa (voice), sentiment NLP |
| **Insights** | Rule-based templates | Free, explainable, no hallucinated clinical claims |

The Flutter app talks directly to Firebase. A **local Python worker** polls for new videos, runs analysis, and writes results back to the database—avoiding expensive cloud GPU.

### Production vision (documented, not built yet)

We maintain a full **Software Architecture Document** for scale: AWS, microservices, GPU inference, GDPR compliance, and 1M-user capacity. That is our **roadmap north star** when the project moves beyond college prototype.

```
College today          →    Funded startup later
Flutter + Firebase     →    Flutter + AWS API backend
Local ML worker        →    Cloud GPU inference
Template insights      →    Guardrailed LLM insights
$0/month               →    ~$800+/month at beta scale
```

---

## Core Innovation

Three ideas differentiate SOLENNE from mood-tracking apps:

1. **Multimodal fusion** — Face, voice, and words are combined into one “wellness fingerprint” per entry, not three separate scores.  
2. **Personal baseline** — Insights compare you to *your* history, not generic norms.  
3. **Explainable insights** — Every observation links to specific metrics, dates, and journal entries so users can verify *why* they’re seeing it.  

---

## Scope: What We Are Building (MVP)

### In scope for mentor demo

- Email and Google sign-in  
- Granular privacy consent (face / voice / text)  
- In-app video recording (up to 3 minutes)  
- Upload, playback, and journal history  
- Full analysis pipeline: transcript, face, voice, text  
- 7-day emotional trend chart  
- Template-based personalized insights with evidence  
- Push notification when analysis completes  
- Privacy settings and data deletion  

### Out of scope for college MVP

- Paid subscriptions or App Store release  
- Web app  
- Clinical diagnosis or crisis automation  
- Cloud GPU or paid AI APIs (OpenAI, etc.)  
- Enterprise features (SSO, admin portal)  

---

## Project Plan

| Phase | Duration | Outcome |
|-------|----------|---------|
| **Foundation** | Weeks 1–2 | Firebase project, Flutter app, authentication |
| **Journaling** | Weeks 3–6 | Record, upload, journal list |
| **AI pipeline** | Weeks 7–12 | Transcription + face + voice + text analysis |
| **Intelligence** | Weeks 13–18 | Baselines, trends, insights, dashboard |
| **Polish & demo** | Weeks 19–24 | Notifications, privacy, mentor-ready demo |

**12 two-week sprints** to a demonstrable MVP. Timeline can compress to ~16 weeks if needed.

### Key milestones

| Milestone | Meaning |
|-----------|---------|
| **First upload** | User records and stores a journal video |
| **First analysis** | Transcript and emotion metrics appear in app |
| **First trend** | 7-day chart with personal baseline band |
| **First insight** | Personalized observation with supporting evidence |
| **Demo ready** | End-to-end flow stable for presentation |

---

## Success Metrics (College MVP)

| Metric | Target |
|--------|--------|
| End-to-end demo reliability | Works 3 times in a row without failure |
| Analysis completion | Within ~8 minutes for a 3-minute video |
| Onboarding time | Under 3 minutes to first journal |
| User comprehension | Mentor understands insight without technical explanation |
| Team learning | Documented architecture + working mobile prototype |

Post-college metrics (retention, DAU, insight engagement) are defined in our full PRD for when we pursue beta launch.

---

## Privacy & Ethics

SOLENNE handles sensitive personal data. Our design priorities:

- **Granular consent** — Users opt in separately to face, voice, and text analysis.  
- **Transparency** — Users see what is stored and can delete their account and data.  
- **Security** — Firebase Security Rules ensure users access only their own data.  
- **Language discipline** — All copy uses wellness observations, never diagnostic terms.  
- **Human agency** — Insights suggest reflection; they do not prescribe treatment.  

We are preparing for future GDPR-style requirements; full compliance work is planned for a funded launch.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Analysis too slow on laptop | Cap videos at 3 min; show progress in app; pre-process demo data |
| Firebase free tier limits | Target 5–20 demo users; compress stored metrics |
| Misinterpretation as medical tool | Disclaimers in app and presentation; mentor review of copy |
| Team ML complexity | Start with proven open-source models; template insights before LLM |
| Scope creep | Written MVP “won’t have” list; defer web and AWS until funded |

---

## Team & Documentation

We are not improvising—the project is backed by structured engineering docs:

| Document | Purpose |
|----------|---------|
| **SAD / PRD** | Full product requirements and production architecture (~2,900 lines) |
| **Engineering Execution Plan** | Epics, sprints, modules, dependencies |
| **Zero-Budget Build Plan** | Flutter + Firebase implementation guide |

This executive summary sits above those documents for stakeholders who need the **story and decisions**, not the API specs.

---

## Ask of Our Mentor

We would value feedback on:

1. **Scope** — Is the MVP ambitious but achievable for a college timeline?  
2. **Ethics** — Is our wellness-vs-diagnosis boundary clear and sufficient?  
3. **Demo strategy** — Live analysis vs. pre-seeded data for presentation day?  
4. **Next steps** — Prioritize App Store path, pilot users, or investor-ready architecture story?  

---

## Closing

SOLENNE meets people where they already are—talking about their day—and turns that habit into longitudinal emotional intelligence. We are building a **working Flutter prototype on a $0 stack** while documenting a **credible path to production scale**.

The combination of a demonstrable mobile product and a serious architecture plan shows we can ship now and grow later.

---

**Contact:** [Team name / lead email]  
**Repository:** [GitHub link when available]  
**Related docs:** `docs/SOLENNE-SAD-PRD.md` · `docs/SOLENNE-Zero-Budget-Build-Plan.md` · `docs/SOLENNE-Engineering-Execution-Plan.md` · **`docs/SOLENNE-Mentor-Pitch.md`** (presentation to mentor)
