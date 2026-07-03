from __future__ import annotations

from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from typing import Any, Literal


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def clamp(value: float, low: float = -1.0, high: float = 1.0) -> float:
    return max(low, min(high, value))


@dataclass
class TranscriptSegment:
    start: float
    end: float
    text: str


@dataclass
class TranscriptResult:
    text: str = ""
    wordCount: int = 0
    segments: list[TranscriptSegment] = field(default_factory=list)
    language: str | None = None
    confidence: float = 0.0


@dataclass
class FacialResult:
    faceDetectedRatio: float = 0.0
    qualityScore: float = 0.0
    valence: float = 0.0
    arousal: float = 0.0
    confidence: float = 0.0
    warnings: list[str] = field(default_factory=list)


@dataclass
class VoiceResult:
    energyMean: float = 0.0
    pitchMean: float = 0.0
    speakingRate: float = 0.0
    pauseRatio: float = 0.0
    variability: float = 0.0
    confidence: float = 0.0


@dataclass
class NlpResult:
    sentimentValence: float = 0.0
    stressScore: float = 0.0
    topics: list[str] = field(default_factory=list)
    keyPhrases: list[str] = field(default_factory=list)
    paraphrase: str = ""
    confidence: float = 0.0


@dataclass
class FusedResult:
    overallValence: float = 0.0
    overallArousal: float = 0.0
    engagement: float = 0.0
    congruence: float = 0.0
    confidence: float = 0.0
    modalityWeights: dict[str, float] = field(default_factory=dict)


@dataclass
class Insight:
    templateId: str
    text: str
    confidence: float
    evidence: dict[str, Any] = field(default_factory=dict)


@dataclass
class AiInsight:
    title: str
    summary: str
    moodLabel: str
    dayThemes: list[str] = field(default_factory=list)
    suggestions: list[str] = field(default_factory=list)
    reflectionQuestions: list[str] = field(default_factory=list)
    evidence: dict[str, Any] = field(default_factory=dict)
    confidence: float = 0.0
    safetyNote: str = ""


@dataclass
class LlmDiagnostics:
    status: Literal["not_requested", "skipped", "complete", "failed"] = "not_requested"
    provider: str | None = None
    model: str | None = None
    tokenEstimate: int = 0
    latencyMs: int | None = None
    failureReason: str | None = None


@dataclass
class AnalysisResult:
    runId: str
    sourceVideo: str
    createdAt: str = field(default_factory=utc_now_iso)
    durationSeconds: float = 0.0
    transcript: TranscriptResult = field(default_factory=TranscriptResult)
    facial: FacialResult = field(default_factory=FacialResult)
    voice: VoiceResult = field(default_factory=VoiceResult)
    nlp: NlpResult = field(default_factory=NlpResult)
    fused: FusedResult = field(default_factory=FusedResult)
    insights: list[Insight] = field(default_factory=list)
    aiInsights: list[AiInsight] = field(default_factory=list)
    insightProvider: Literal["template", "groq", "fallback"] = "template"
    llmDiagnostics: LlmDiagnostics = field(default_factory=LlmDiagnostics)
    status: Literal["complete", "failed"] = "complete"
    warnings: list[str] = field(default_factory=list)
    errorMessage: str | None = None

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)
