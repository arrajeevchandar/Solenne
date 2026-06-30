# SOLENNE — Mentor Pitch

**Why this project deserves your approval — and why the plan is already de-risked**

| | |
|---|---|
| **Project** | SOLENNE — Intelligent Video Journal for Passive Mental Wellness Monitoring |
| **Ask** | Endorse our project plan and semester scope — not funding, not IRB (unless you advise otherwise) |
| **Team** | College capstone / innovation project |
| **Budget** | $0 — Firebase free tier + open-source ML on team hardware |
| **Deliverable** | Working Flutter app + documented production architecture + live demo |

---

## Opening (30 seconds)

**Students track grades, steps, and sleep — but not the emotional patterns that predict burnout until it’s too late.**

SOLENNE is a mobile app where users record a 2–3 minute daily video journal. AI analyzes face, voice, and speech to surface **personalized wellness trends** — not a diagnosis, not a mood slider, not another app people abandon in a week.

We are not pitching a vague idea. We have **3,000+ lines of product and architecture documentation**, a **12-sprint execution plan**, and a **$0 technical stack** we can build this semester without AWS credits or paid APIs.

**We are asking you to approve a plan that is scoped to succeed.**

---

## Why mentors say no — and how we answer each objection

### “It’s too ambitious for a college team.”

**Our answer:** We split the project into two layers on purpose.

| Layer | What it is | When |
|-------|------------|------|
| **Semester deliverable** | Flutter app + Firebase + local Python worker + demo | Weeks 1–24 (compressible to 16) |
| **Future vision** | Full AWS architecture for 1M users | Documented only — not built now |

The MVP is **one mobile app, one database, one worker script** — not eleven microservices. We have a written **“Won’t Have”** list that explicitly excludes web apps, cloud GPU, paid LLMs, App Store launch, and clinical features.

**Proof:** Milestone gates at weeks 8, 14, 18, and 24 — each with pass/fail criteria. If ML slips, we still demo upload + transcript + partial analysis. If trends slip, we still demo journal + analysis. The plan degrades gracefully.

---

### “AI/ML projects never finish — students get stuck on models.”

**Our answer:** We use **pre-trained open-source models**, not custom training.

| Task | Tool | Custom training? |
|------|------|------------------|
| Speech-to-text | Whisper (`small`, CPU) | No |
| Face / emotion | MediaPipe + off-the-shelf classifier | No |
| Voice prosody | librosa (pitch, energy, pauses) | No |
| Text sentiment | VADER | No |
| Insights | Rule-based templates | No |

Our innovation is **multimodal fusion + personal baseline math** — engineering integration and product design, not a PhD thesis. The algorithms are specified with formulas and pseudocode in our architecture doc.

**Fallback for demo day:** Pre-processed sample journals so the presentation never depends on live GPU luck. Live analysis is a bonus, not a single point of failure.

---

### “Mental health + AI is ethically dangerous.”

**Our answer:** We designed the ethical boundary **before** the feature list.

| Principle | How we enforce it |
|-----------|-------------------|
| **Not a medical device** | Fixed disclaimer on onboarding and every insight screen |
| **No diagnosis language** | Blocklist in insight templates; wellness observations only |
| **User control** | Separate consent for face, voice, and text; delete-all-data supported |
| **Explainability** | Every insight shows evidence: metric, baseline, date range |
| **Human agency** | App suggests reflection — never prescribes treatment or medication |

We are building **self-awareness tooling**, analogous to a mood journal with better signal — not a clinical screening instrument. We welcome your review of user-facing copy before demo.

If you require IRB review for a pilot with classmates, we will follow your guidance. For a **team-only demo with synthetic or volunteer consent**, we stay within standard capstone bounds.

---

### “There’s no budget — how is this real?”

**Our answer:** The $0 stack is a **feature, not a compromise**.

| Need | Free solution |
|------|----------------|
| Mobile app | Flutter (open source) |
| Auth, DB, storage, push | Firebase Spark (free tier) |
| Video hosting | Firebase Storage (5 GB) |
| ML inference | Python worker on a team laptop |
| CI | GitHub Actions (free for students) |

**Cost this semester: $0/month.**

This mirrors how many YC companies started: Firebase + local scripts → cloud scale later. Our architecture doc already maps **exactly** how to migrate to AWS when funded. You get academic rigor **and** startup realism.

---

### “How is this different from existing apps?”

**Our answer:** Three concrete differentiators — each demonstrable in the final presentation.

1. **Passive multimodal capture** — Users talk naturally; we don’t ask them to tap emoji moods.
2. **Personal baseline** — “You vs. your last 14 days,” not “you vs. everyone else.”
3. **Cross-signal insights** — e.g. *“Your words sound positive, but your voice energy is below your baseline”* — incongruence humans miss.

Existing apps do **one** of these. SOLENNE combines all three in one daily habit.

---

### “Will students actually use it?”

**Our answer:** We optimize for **habit, not accuracy theater**.

- Recording takes 2–3 minutes — less effort than writing.
- Streaks and push notifications when analysis completes.
- Insights only after baseline confidence is high enough — we don’t fake precision on day one.

For the capstone, success is **5–20 demo users** (classmates), not 10,000 MAU. Engagement metrics are defined for post-college beta; semester success is a **reliable end-to-end demo**.

---

### “Where is the academic / learning value?”

**Our answer:** SOLENNE touches multiple disciplines your program likely cares about:

| Domain | What students learn |
|--------|---------------------|
| **Mobile engineering** | Flutter, camera, Firebase, security rules |
| **Backend / distributed systems** | Async job pipeline, event-driven worker pattern |
| **ML systems** | Multimodal pipelines, inference on constrained hardware |
| **Data science** | Time-series baselines, Z-score drift, confidence scoring |
| **Product & UX** | Consent flows, sensitive-data UX, explainable AI |
| **Software architecture** | Full SAD/PRD — same artifact type used in industry |
| **Ethics & privacy** | GDPR-oriented design, wellness vs. clinical boundaries |

This is not a tutorial app. It is a **production-shaped system** at prototype scale — the kind of portfolio piece that reads well to employers and graduate committees.

---

## What you will see at the end of the semester

We commit to **five visible deliverables**:

1. **Working Flutter app** — record, upload, playback, dashboard, trends, insights  
2. **Live or recorded demo** — full user journey in under 5 minutes  
3. **Architecture documentation** — SAD/PRD (~3,000 lines), execution plan, zero-budget guide  
4. **Technical presentation** — problem, fusion/baseline approach, ethics, live walkthrough  
5. **Repository** — clean README, Firebase rules, worker code, sprint history  

You will not receive slides-only vaporware.

---

## Timeline — conservative and checkpointed

```
Weeks  1–2   Firebase + Flutter + Auth          ✓ Gate: login works
Weeks  3–6   Record + Upload + Journal list      ✓ Gate: First Upload
Weeks  7–12  Whisper + Face + Voice + NLP       ✓ Gate: First Analysis
Weeks 13–18  Baseline + Trends + Insights       ✓ Gate: First Insight
Weeks 19–24  Polish + Privacy + Demo            ✓ Gate: Demo Ready
```

**If we fall behind:** We cut optional features (calendar heatmap, Ollama phrasing, Apple Sign-In) — never the core loop.

**If we are ahead:** We add pilot users or polish insight copy — not AWS migration.

---

## Risk matrix (honest — with owners)

| Risk | Likelihood | Impact | Mitigation | Owner |
|------|------------|--------|------------|-------|
| ML too slow on laptop | Medium | Medium | 3-min cap; progress UI; pre-seeded demo data | ML lead |
| Firebase quota exceeded | Low | Low | ≤20 users; metric compression | Mobile lead |
| Scope creep | Medium | High | Written MoSCoW; mentor check-in at week 6 | PM |
| Ethical misinterpretation | Low | High | Disclaimers; mentor copy review | Whole team |
| Team member availability | Medium | Medium | Modular sprints; paired ownership | Tech lead |

We report **green / yellow / red** at each checkpoint — no surprises at final presentation.

---

## Comparison: typical rejected capstone vs. SOLENNE

| Typical rejected project | SOLENNE |
|--------------------------|---------|
| “We’ll use AI to detect depression” | Wellness trends only; explicit non-diagnosis |
| “We’ll build an app” (no spec) | 3,000+ lines of PRD/SAD + sprint plan |
| Needs cloud budget | $0 Firebase + local worker |
| Custom model training required | Pre-trained pipelines only |
| Single-platform or web-only | Flutter → iOS + Android |
| No ethics plan | Consent, deletion, explainability built in |
| All-or-nothing demo | Graceful degradation at every milestone |
| Dies after semester | Documented path to production scale |

---

## What we are asking you to approve

We are **not** asking for money, lab equipment, or extended deadlines.

We **are** asking you to:

1. **Approve SOLENNE as our official project** for this capstone / innovation cycle.  
2. **Confirm scope** — Flutter MVP + documented production architecture (not full AWS build).  
3. **Agree to a mid-semester check-in** (week 6 or 8) against milestone gates.  
4. **Flag any IRB or institutional requirement** early if we pilot with volunteers outside the team.  
5. **Optional:** Review insight/disclaimer copy before public demo.  

---

## One slide summary (for your deck)

```
SOLENNE
Daily video journal → passive AI → personal wellness trends

Problem:   Mood apps fail (bias, churn, no longitudinal signal)
Solution:  Multimodal analysis vs. YOUR baseline — not diagnosis
Stack:     Flutter + Firebase + open-source ML — $0/month
Semester:  Working app + full architecture docs + live demo
Risk:      Scoped MVP, pre-trained models, ethical guardrails, fallback demo
Ask:       Approve plan + mid-semester checkpoint
```

---

## Closing

Most student projects fail because they are **either** too vague **or** too brittle.

SOLENNE is neither. We have the **documentation of a startup**, the **scope of a achievable capstone**, and the **ethics framing of a sensitive-data product** — before writing production code.

We are not asking you to bet on our ambition. We are asking you to approve a plan that **already accounts for failure modes** and still delivers something worth presenting, publishing in a portfolio, and extending after graduation.

**SOLENNE is ready to build. We hope it is ready for your approval.**

---

**Prepared by:** [Team name]  
**Date:** June 13, 2026  
**Supporting documents:**  
- `SOLENNE-Executive-Summary.md` — stakeholder overview  
- `SOLENNE-SAD-PRD.md` — full product & architecture  
- `SOLENNE-Zero-Budget-Build-Plan.md` — Flutter + Firebase implementation  
- `SOLENNE-Engineering-Execution-Plan.md` — sprints, epics, modules  

**Suggested mentor response:** Approve / Approve with conditions: _______________
