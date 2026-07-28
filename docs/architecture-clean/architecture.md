# Solenne — System Architecture (clean view)

A simplified, readable companion to [`docs/architecture-diagram.md`](../architecture-diagram.md).
Same system, same invariants — but the diagram carries **only the flow**, and all the
detail lives in the tables below it.

Solenne is **two independent apps that share no code**: a Flutter client and a Python
analyzer worker. There is no HTTP API between them — **Firestore is both the job queue
and the message bus**, and Cloudinary is the media store.

Two invariants get visual weight:

- **Grounding boundary** — only transcript-derived signals (topics, key phrases) may
  trigger a research-supported claim. Voice, face and fused affect metrics cannot.
- **Release-controlled catalog** — every citation comes from a human-reviewed,
  Git-versioned catalog. No live web research happens during journal processing.

---

## 1 · End-to-end flow

The whole system at a glance — eight steps, one direction, grouped by where they run.

```mermaid
%%{init: {
  "theme": "base",
  "themeVariables": {
    "fontFamily": "Inter, Segoe UI, Helvetica, sans-serif",
    "fontSize": "14px",
    "primaryColor": "#1E3A8A",
    "primaryTextColor": "#EAF1FF",
    "primaryBorderColor": "#60A5FA",
    "lineColor": "#8FA6D2",
    "textColor": "#E8EEFB",
    "clusterBkg": "#0F1A2E",
    "clusterBorder": "#2A3F63",
    "edgeLabelBackground": "#0F1A2E"
  },
  "flowchart": { "curve": "basis", "nodeSpacing": 55, "rankSpacing": 70, "padding": 16 }
}}%%
flowchart TB
  %% Grouped into the two phases the steps actually belong to. This wraps an
  %% 8-step chain into a readable block instead of one 16:1 ribbon.
  subgraph A["On the device"]
    direction LR
    REC["Record<br/>journal"]
    UP["Upload to<br/>Cloudinary"]
    TX["Firestore<br/>transaction"]
    REC --> UP --> TX
  end

  subgraph B2["On the worker"]
    direction LR
    WORK["Claim<br/>job"]
    PIPE["Analysis<br/>pipeline"]
    GRND["Grounded<br/>insights"]
    WRITE["Write<br/>results"]
    WORK --> PIPE --> GRND --> WRITE
  end

  LIVE["Daily Insight updates live — no refresh, no polling"]

  TX --> WORK
  WRITE --> LIVE

  classDef c fill:#1E3A8A,stroke:#60A5FA,stroke-width:1.5px,color:#EAF1FF
  classDef w fill:#172B52,stroke:#2563EB,stroke-width:1.5px,color:#DCE8FF
  classDef g fill:#3A2A08,stroke:#F5B841,stroke-width:2px,color:#FFF4DA
  classDef d fill:#123A34,stroke:#4ADE9B,stroke-width:1.5px,color:#DFFBF0
  class REC,UP,TX c
  class WORK,PIPE w
  class GRND g
  class WRITE,LIVE d
  style A  fill:#0D1729,stroke:#3B82F6,stroke-width:1.5px,color:#93C5FD
  style B2 fill:#0C1526,stroke:#2563EB,stroke-width:1.5px,color:#93C5FD
```

| Stage | Where it runs | Source |
|---|---|---|
| Record journal | Flutter client | `screens/recording/` |
| Upload to Cloudinary | Flutter client | `services/cloudinary/cloudinary_upload_service.dart` |
| Firestore transaction | Flutter client | `journal_repository.dart : saveJournal` |
| Worker claims job | Python worker | `worker/runner.py : watch()` |
| Analysis pipeline | Python worker | `pipeline/orchestrator.py` |
| Grounded insights | Python worker | `grounding/runtime.py` |
| Results written | Python worker | `worker/result_mapper.py` |
| Daily Insight updates | Flutter client | `journalByIdStreamProvider` |

---

## 2 · Client and shared state

The client only ever *creates* — every later write to a journal comes from the worker.

```mermaid
%%{init: {
  "theme": "base",
  "themeVariables": {
    "fontFamily": "Inter, Segoe UI, Helvetica, sans-serif",
    "fontSize": "13px",
    "lineColor": "#8FA6D2",
    "textColor": "#E8EEFB",
    "clusterBkg": "#0F1A2E",
    "clusterBorder": "#2A3F63",
    "edgeLabelBackground": "#0F1A2E"
  },
  "flowchart": { "curve": "basis", "nodeSpacing": 50, "rankSpacing": 62, "padding": 16 }
}}%%
flowchart TB
  subgraph CLIENT["Flutter client"]
    direction LR
    AUTH["Firebase Auth"]
    REC["Record<br/>pause · resume · preview"]
    UP["Cloudinary upload"]
    TX["Firestore transaction"]
    AUTH --> REC --> UP --> TX
  end

  subgraph READ["Reading surfaces"]
    direction LR
    HOME["Home<br/>3 latest days"]
    TL["Timeline &amp; Calendar<br/>120-day window"]
    DI["Daily Insight"]
  end

  subgraph STATE["Shared state"]
    direction LR
    CLD[("Cloudinary<br/>video + thumbnail")]
    FSJ[("Firestore journal<br/>users/{uid}/journals/{id}")]
    FSQ[("Firestore job queue<br/>analysis_jobs/{id}")]
  end

  UP --> CLD
  TX --> FSJ
  TX --> FSQ
  AUTH --> READ
  FSJ -. "live snapshot stream" .-> READ

  classDef c fill:#1E3A8A,stroke:#60A5FA,stroke-width:1.5px,color:#EAF1FF
  classDef s fill:#15264A,stroke:#3B82F6,stroke-width:1.5px,color:#DCE8FF
  classDef r fill:#123A34,stroke:#4ADE9B,stroke-width:1.5px,color:#DFFBF0
  class AUTH,REC,UP,TX c
  class CLD,FSJ,FSQ s
  class HOME,TL,DI r
  style CLIENT fill:#0D1729,stroke:#3B82F6,stroke-width:2px,color:#93C5FD
  style READ   fill:#08201C,stroke:#4ADE9B,stroke-width:2px,color:#6EE7B7
  style STATE  fill:#0C1526,stroke:#3B82F6,stroke-width:2px,color:#93C5FD
```

| Collection | Written by | Notes |
|---|---|---|
| `users/{uid}/journals/{journalId}` | client (create only), then worker | transcript · analysis · aiInsights · evidence · diagnostics · status |
| `analysis_jobs/{journalId}` | client (create, `status == 'queued'` only), then worker | status · processingStep · retryCount; index `status ASC, createdAt ASC` |

---

## 3 · Worker and analysis pipeline

```mermaid
%%{init: {
  "theme": "base",
  "themeVariables": {
    "fontFamily": "Inter, Segoe UI, Helvetica, sans-serif",
    "fontSize": "13px",
    "lineColor": "#8FA6D2",
    "textColor": "#E8EEFB",
    "clusterBkg": "#0F1A2E",
    "clusterBorder": "#2A3F63",
    "edgeLabelBackground": "#0F1A2E"
  },
  "flowchart": { "curve": "basis", "nodeSpacing": 48, "rankSpacing": 58, "padding": 16 }
}}%%
flowchart TB
  subgraph W["Worker loop"]
    direction LR
    POLL["Poll queued jobs<br/>every 5s · limit 5"]
    CLAIM["Transactional claim<br/>queued → processing"]
    VAL{"Validate<br/>user · journal · URL"}
    DL["Temporary<br/>download"]
    FAIL["Job failed<br/>retryCount++"]
    POLL --> CLAIM --> VAL
    VAL -- "rejected" --> FAIL
    VAL -- "accepted" --> DL
  end

  subgraph P["Pipeline — 7 stages"]
    direction TB
    subgraph PA[" "]
      direction LR
      P1["1 · Validate media"]
      P2["2 · Audio extraction"]
      P3["3 · Transcription"]
      P4["4 · Visual signals"]
      P1 --> P2 --> P3 --> P4
    end
    subgraph PB[" "]
      direction LR
      P5["5 · Voice features"]
      P6["6 · NLP"]
      P7["7 · Signal fusion"]
      P5 --> P6 --> P7
    end
    P4 --> P5
  end

  DL --> P1

  classDef w fill:#172B52,stroke:#2563EB,stroke-width:1.5px,color:#DCE8FF
  classDef x fill:#4A1414,stroke:#F87171,stroke-width:1.6px,color:#FFE4E4
  class POLL,CLAIM,VAL,DL w
  class P1,P2,P3,P4,P5,P6,P7 w
  class FAIL x
  style W fill:#0C1526,stroke:#2563EB,stroke-width:2px,color:#93C5FD
  style P fill:#0C1526,stroke:#2563EB,stroke-width:2px,color:#93C5FD
  %% Layout-only wrappers — invisible so only the two real groups read as boxes.
  style PA fill:none,stroke:none
  style PB fill:none,stroke:none
```

| Stage | Tooling | Output |
|---|---|---|
| 1 · Validate media | OpenCV probe | duration, readability |
| 2 · Audio extraction | FFmpeg | mono 16 kHz WAV |
| 3 · Transcription | Faster Whisper, int8 CPU, VAD | transcript |
| 4 · Visual signals | OpenCV Haar cascades | frame quality, facial signals |
| 5 · Voice features | librosa | energy, pitch, pause ratio |
| 6 · NLP | — | topics · key phrases · word count · confidence · sentiment · stress |
| 7 · Signal fusion | face 0.35 · voice 0.35 · text 0.30 | valence · arousal · congruence |

Download safety: HTTPS only, no redirects, 500 MB cap, auto-purged temp directory,
3 retries with exponential backoff (`worker/media_source.py`).

---

## 4 · Grounding boundary

The one structural rule in the system. Enforced by `retriever.py`, not by prompt text.

```mermaid
%%{init: {
  "theme": "base",
  "themeVariables": {
    "fontFamily": "Inter, Segoe UI, Helvetica, sans-serif",
    "fontSize": "13px",
    "lineColor": "#8FA6D2",
    "textColor": "#E8EEFB",
    "clusterBorder": "#F5B841",
    "edgeLabelBackground": "#0F1A2E"
  },
  "flowchart": { "curve": "basis", "nodeSpacing": 55, "rankSpacing": 60, "padding": 18 }
}}%%
flowchart TB
  P6["NLP<br/>topics · key phrases"]
  P7["Fusion<br/>voice · face · affect"]

  subgraph B["Grounding boundary"]
    direction LR
    OK2["✅ May trigger research<br/>kind ∈ topic, key_phrase"]
    NO["⛔ Never cited<br/>voice · face · fused metrics"]
  end

  PERS["Shown as personal signal only"]
  RETR["Retriever"]

  P6 --> OK2
  P7 --> NO
  OK2 --> RETR
  NO --> PERS

  classDef ok fill:#3A2A08,stroke:#F5B841,stroke-width:2.5px,color:#FFF4DA
  classDef no fill:#3F1D1D,stroke:#F87171,stroke-width:2px,color:#FFE4E4
  classDef w  fill:#172B52,stroke:#2563EB,stroke-width:1.5px,color:#DCE8FF
  class OK2 ok
  class NO,PERS no
  class P6,P7,RETR w
  style B fill:#241905,stroke:#F5B841,stroke-width:3px,color:#F5B841
```

`retrieve_claims` only counts facts whose `kind` is `topic` or `key_phrase`, so voice,
face and fused metrics have **no code path** to a research claim
(`grounding/retriever.py:20`).

---

## 5 · Catalog governance

```mermaid
%%{init: {
  "theme": "base",
  "themeVariables": {
    "fontFamily": "Inter, Segoe UI, Helvetica, sans-serif",
    "fontSize": "13px",
    "lineColor": "#8FA6D2",
    "textColor": "#E8EEFB",
    "edgeLabelBackground": "#0F1A2E"
  },
  "flowchart": { "curve": "basis", "nodeSpacing": 50, "rankSpacing": 55, "padding": 16 }
}}%%
flowchart LR
  PUB["PubMed-indexed<br/>public research"]
  REV{"Human release review<br/>≥ 2 reviewers"}
  CAT[("Git-versioned catalog<br/>grounding/catalog.json")]
  NOWEB>"No live web research<br/>during processing"]

  PUB --> REV -- "approved + active" --> CAT
  CAT -.-> NOWEB

  classDef g fill:#4A360C,stroke:#F5B841,stroke-width:2px,color:#FFF4DA
  class PUB,REV,CAT,NOWEB g
```

The catalog stores sources, **exact display claims**, limitations, support levels and
approved suggestions. No source text is ever copied at runtime.

---

## 6 · Insight generation and fallback ladder

```mermaid
%%{init: {
  "theme": "base",
  "themeVariables": {
    "fontFamily": "Inter, Segoe UI, Helvetica, sans-serif",
    "fontSize": "13px",
    "lineColor": "#8FA6D2",
    "textColor": "#E8EEFB",
    "clusterBkg": "#0F1A2E",
    "clusterBorder": "#2A3F63",
    "edgeLabelBackground": "#0F1A2E"
  },
  "flowchart": { "curve": "basis", "nodeSpacing": 48, "rankSpacing": 56, "padding": 16 }
}}%%
flowchart TB
  CRISIS{"Crisis language check<br/>runs first"}
  SAFE["Supportive card<br/>provider = safety"]
  FACTS["Observation facts"]
  MAP["Claim-category mapping<br/>5 categories"]
  RETR["Retrieve claim cards<br/>≤ 3, one per category"]
  GROQ["Groq drafts language only"]
  INJ["Server injects verified content<br/>≤ 2 citations per card"]
  CHK{"Provenance &amp; safety<br/>validation"}
  OK["Source-supported insight"]
  DET["Deterministic grounded card"]
  UDO["User-data-only card"]

  CRISIS -- "detected" --> SAFE
  CRISIS -- "clear" --> FACTS --> MAP --> RETR --> GROQ --> INJ --> CHK
  CHK -- "valid" --> OK
  CHK -. "retry once" .-> GROQ
  CHK -- "still invalid" --> DET
  DET -- "no claim / LLM unreachable" --> UDO

  classDef g fill:#1B2F57,stroke:#7DA6F5,stroke-width:1.5px,color:#E4EDFF
  classDef s fill:#3D2352,stroke:#C084FC,stroke-width:1.8px,color:#F5E9FF
  class CRISIS,FACTS,MAP,RETR,GROQ,INJ,CHK,OK,DET,UDO g
  class SAFE s
```

Three rungs on the ladder:

1. Two generate/validate attempts against the LLM.
2. A deterministic grounded card that still carries a real citation.
3. A user-data-only card — no citation.

Rung 2 is deliberately skipped when the LLM was never reachable, so a bare template
never gets a citation attached to it.

Groq drafts **title, summary, themes, mood, questions and allowed IDs** only — it never
writes claims or citations. The server injects exact evidence values, catalog claim text,
approved suggestions, limitations and canonical HTTPS citations. Validation checks that
no IDs were fabricated, no values altered, and catalog text is byte-identical.

---

## 7 · Runtime modes and delivery

```mermaid
%%{init: {
  "theme": "base",
  "themeVariables": {
    "fontFamily": "Inter, Segoe UI, Helvetica, sans-serif",
    "fontSize": "13px",
    "lineColor": "#8FA6D2",
    "textColor": "#E8EEFB",
    "clusterBkg": "#0F1A2E",
    "clusterBorder": "#2A3F63",
    "edgeLabelBackground": "#0F1A2E"
  },
  "flowchart": { "curve": "basis", "nodeSpacing": 50, "rankSpacing": 60, "padding": 16 }
}}%%
flowchart TB
  IN["Insight cards"]
  MODE{"GROUNDING_MODE"}

  %% The four modes are parallel alternatives with identical in/out edges, so
  %% Mermaid ignores the LR direction and stacks them. They're enumerated in the
  %% table below instead — the diagram shows the routing step itself.
  MOFF["off"]
  MSHA["shadow"]
  MENF["enforce"]
  MCOM["combined · default"]

  WRITE["Batched write<br/>to journal"]
  STREAM["Flutter snapshot<br/>listener"]
  UPDATE["Daily Insight<br/>re-renders"]

  IN --> MODE
  MODE --> MOFF --> WRITE
  MODE --> MSHA --> WRITE
  MODE --> MENF --> WRITE
  MODE --> MCOM --> WRITE
  WRITE --> STREAM --> UPDATE

  classDef m fill:#20325C,stroke:#D4A22F,stroke-width:1.6px,color:#FFF1D6
  classDef d fill:#123A34,stroke:#4ADE9B,stroke-width:1.5px,color:#DFFBF0
  classDef g fill:#1B2F57,stroke:#7DA6F5,stroke-width:1.5px,color:#E4EDFF
  class MOFF,MSHA,MENF,MCOM,MODE m
  class WRITE,STREAM,UPDATE d
  class IN g
```

| Mode | Written to `aiInsights` | Also written |
|---|---|---|
| `off` | existing insight pipeline output | — |
| `shadow` | existing output, unchanged | grounded output → `groundingShadowInsights` |
| `enforce` | validated grounded output only | — |
| `combined` *(default)* | narrative cards + grounded cards together | — |

The client needs no refresh and does no polling: the Daily Insight screen is bound to a
live snapshot listener on the same journal document, so it updates the moment the worker
commits its batch.

---

## Legend

| Colour | Layer |
|---|---|
| 🔵 Sapphire | Flutter client |
| 🔷 Deep blue cylinders | Cloud services — Cloudinary, Firestore |
| 🔹 Navy | Worker and analysis pipeline |
| 🟡 Gold | Grounding boundary and catalog governance |
| 🔴 Red | Blocked or failed paths |
| 🟣 Purple | Crisis-safety path |
| 🟠 Amber | `GROUNDING_MODE` routing |
| 🟢 Green | Result delivery |

Shapes: `[( )]` datastore · `{ }` decision · `> ]` annotation.

---

## Diagram ↔ code

| Section | Source |
|---|---|
| Client | `frontend/lib/features/auth/auth_providers.dart`, `frontend/lib/screens/recording/`, `frontend/lib/services/cloudinary/cloudinary_upload_service.dart`, `frontend/lib/features/journals/journal_repository.dart` |
| Reading surfaces | `frontend/lib/screens/home/home_screen.dart:570`, `screens/timeline/timeline_screen.dart`, `screens/insights/daily_insight_screen.dart` |
| Firestore schema and rules | `firestore.rules`, `firestore.indexes.json`, `backend/solenne_analyzer/worker/result_mapper.py` |
| Worker loop | `backend/solenne_analyzer/worker/runner.py`, `worker/firebase_gateway.py` |
| URL validation and download | `backend/solenne_analyzer/worker/media_source.py` |
| Analysis pipeline | `backend/solenne_analyzer/pipeline/orchestrator.py`, `pipeline/{media,transcribe,face,voice,nlp,fusion}.py` |
| Grounding boundary | `backend/solenne_analyzer/grounding/retriever.py:20`, `grounding/observations.py` |
| Grounding pipeline | `backend/solenne_analyzer/grounding/runtime.py`, `generator.py`, `assembler.py`, `validators.py` |
| Catalog governance | `backend/solenne_analyzer/grounding/catalog.py`, `grounding/catalog.json`, `grounding/models.py` |
| Runtime modes | `backend/solenne_analyzer/pipeline/llm_insights.py`, `config.py` |

---

## Notes on accuracy

- **Face analysis uses OpenCV Haar cascades**, not MediaPipe (`pipeline/face.py`).
  `backend/README.md` still says MediaPipe and is out of date.
- **Four runtime modes exist**, not three. `combined` is what `backend/.env.example`
  ships today.
- **Claim limits differ by stage**: the retriever supplies up to **3** claim cards to the
  model (`runtime.py:94`); the assembler renders at most **2** citations per card
  (`assembler.py:34`).
- **`analysis_jobs/{journalId}`** uses the journal ID as its document ID, and the client
  may only create that document with `status == 'queued'`.
