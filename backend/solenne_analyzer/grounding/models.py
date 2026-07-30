from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Any, Literal


ClaimType = Literal[
    "reflective_journaling",
    "rest_routines",
    "workload_breaks",
    "social_connection",
    "grounding_routines",
]
SupportLevel = Literal["strong", "moderate", "weak"]
CatalogStatus = Literal["draft", "approved", "inactive"]


@dataclass(frozen=True)
class ReviewApproval:
    reviewerId: str
    reviewedAt: str


@dataclass(frozen=True)
class SourceRecord:
    sourceId: str
    title: str
    publisher: str
    year: int
    url: str
    doi: str | None = None
    pmid: str | None = None
    licenseUsageNote: str = ""


@dataclass(frozen=True)
class ApprovedSuggestion:
    suggestionId: str
    text: str
    tags: tuple[str, ...]
    status: CatalogStatus
    approvals: tuple[ReviewApproval, ...] = ()
    active: bool = False

    @property
    def runtime_eligible(self) -> bool:
        return self.active and self.status == "approved" and _has_two_reviewers(self.approvals)


@dataclass(frozen=True)
class ClaimCard:
    claimCardId: str
    sourceId: str
    claimType: ClaimType
    displayClaim: str
    limitations: str
    tags: tuple[str, ...]
    supportLevel: SupportLevel
    allowedSuggestionIds: tuple[str, ...]
    status: CatalogStatus
    approvals: tuple[ReviewApproval, ...] = ()
    active: bool = False

    @property
    def runtime_eligible(self) -> bool:
        return (
            self.active
            and self.status == "approved"
            and self.supportLevel in {"strong", "moderate"}
            and _has_two_reviewers(self.approvals)
        )


@dataclass(frozen=True)
class GroundingCatalog:
    catalogVersion: str
    sources: tuple[SourceRecord, ...]
    claimCards: tuple[ClaimCard, ...]
    suggestions: tuple[ApprovedSuggestion, ...]

    @property
    def source_by_id(self) -> dict[str, SourceRecord]:
        return {item.sourceId: item for item in self.sources}

    @property
    def claim_by_id(self) -> dict[str, ClaimCard]:
        return {item.claimCardId: item for item in self.claimCards}

    @property
    def suggestion_by_id(self) -> dict[str, ApprovedSuggestion]:
        return {item.suggestionId: item for item in self.suggestions}


@dataclass(frozen=True)
class ObservationFact:
    evidenceId: str
    kind: Literal["topic", "key_phrase", "word_count", "transcript_confidence", "duration"]
    label: str
    value: str | int | float
    sourcePath: str
    journalIds: tuple[str, ...]
    confidence: float
    claimTypes: tuple[ClaimType, ...] = ()

    def to_evidence(self) -> dict[str, Any]:
        return {
            "evidenceId": self.evidenceId,
            "label": self.label,
            "value": self.value,
            "sourcePath": self.sourcePath,
            "journalIds": list(self.journalIds),
            "confidence": round(self.confidence, 4),
        }


@dataclass(frozen=True)
class GroundedInsightDraft:
    title: str
    summary: str
    moodLabel: str
    dayThemes: tuple[str, ...] = ()
    reflectionQuestions: tuple[str, ...] = ()
    observationFactIds: tuple[str, ...] = ()
    claimCardIds: tuple[str, ...] = ()
    suggestionIds: tuple[str, ...] = ()
    confidence: float = 0.0
    safetyNote: str = ""


@dataclass
class GroundingDiagnostics:
    mode: str
    status: str
    catalogVersion: str | None = None
    retrievedClaimIds: list[str] = field(default_factory=list)
    validationFailures: list[str] = field(default_factory=list)
    attempts: int = 0
    latencyMs: int | None = None
    reason: str | None = None

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


def _has_two_reviewers(approvals: tuple[ReviewApproval, ...]) -> bool:
    return len({item.reviewerId for item in approvals if item.reviewerId}) >= 2
