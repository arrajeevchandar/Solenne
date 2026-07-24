from __future__ import annotations

import logging
import time

from ..ai.validators import crisis_language_present
from ..config import AnalyzerConfig
from ..schemas import AiInsight, AnalysisResult, LlmDiagnostics
from .assembler import assemble_insights
from .catalog import CatalogError, load_catalog
from .generator import generate_grounded_drafts
from .models import (
    ClaimCard,
    GroundedInsightDraft,
    GroundingCatalog,
    GroundingDiagnostics,
    ObservationFact,
)
from .observations import build_journal_narrative, build_observation_facts
from .retriever import retrieve_claims
from .validators import (
    sanitize_draft_references,
    validate_assembled_insights,
    validate_draft_references,
)


LOGGER = logging.getLogger("solenne.grounding")


def generate_grounded_insights(
    result: AnalysisResult,
    config: AnalyzerConfig,
) -> tuple[list[AiInsight], LlmDiagnostics, str]:
    started = time.perf_counter()
    grounding = GroundingDiagnostics(mode=config.grounding_mode, status="starting")
    if crisis_language_present(result.transcript.text):
        grounding.status = "fallback"
        grounding.reason = "safety_bypass"
        grounding.latencyMs = _elapsed_ms(started)
        return (
            [_safety_insight()],
            LlmDiagnostics(
                status="skipped",
                provider="deterministic",
                model=None,
                failureReason=None,
                grounding=grounding.to_dict(),
            ),
            "safety",
        )

    facts = build_observation_facts(
        result,
        min_confidence=config.min_confidence_for_insight,
    )
    eligible_facts = [item for item in facts if item.claimTypes]
    if not eligible_facts:
        grounding.status = "user_data_only"
        grounding.reason = "insufficient_transcript_signal"
        grounding.latencyMs = _elapsed_ms(started)
        return (
            [_user_data_only_insight(result, facts, grounding.reason, None)],
            LlmDiagnostics(
                status="skipped",
                provider="deterministic",
                model=None,
                failureReason=None,
                grounding=grounding.to_dict(),
            ),
            "grounded_template",
        )

    try:
        catalog = load_catalog(config.grounding_catalog_path)
    except CatalogError as error:
        grounding.status = "fallback"
        grounding.reason = "catalog_unavailable"
        grounding.validationFailures.append(str(error))
        grounding.latencyMs = _elapsed_ms(started)
        return (
            [_user_data_only_insight(result, facts, grounding.reason, None)],
            LlmDiagnostics(
                status="failed",
                provider="deterministic",
                model=None,
                failureReason=str(error),
                grounding=grounding.to_dict(),
            ),
            "grounded_template",
        )

    grounding.catalogVersion = catalog.catalogVersion
    retrieved = retrieve_claims(facts, catalog, limit=3)
    grounding.retrievedClaimIds = [item.claimCardId for item in retrieved]
    journal_narrative = build_journal_narrative(result)
    last_llm = LlmDiagnostics(
        status="not_requested",
        provider="groq",
        model=config.groq_model,
    )
    revision_feedback: str | None = None
    for attempt in range(1, 3):
        grounding.attempts = attempt
        drafts, last_llm = generate_grounded_drafts(
            facts,
            retrieved,
            config,
            journal_narrative=journal_narrative,
            revision_feedback=revision_feedback,
        )
        if not drafts:
            failure = last_llm.failureReason or "Grounded generation returned no drafts."
            LOGGER.warning("Grounded draft generation failed on attempt %s: %s", attempt, failure)
            grounding.validationFailures.append(failure)
            if last_llm.status == "skipped":
                break
            revision_feedback = failure
            continue
        try:
            drafts = sanitize_draft_references(drafts, facts, retrieved, catalog)
            validate_draft_references(drafts, facts, retrieved, catalog)
            insights = assemble_insights(drafts, facts, retrieved, catalog)
            validate_assembled_insights(insights, facts, catalog)
            grounding.status = (
                "source_supported"
                if any(
                    item.evidence["verification"]["status"] == "source_supported"
                    for item in insights
                )
                else "user_data_only"
            )
            grounding.reason = None if grounding.status == "source_supported" else "no_catalog_match"
            grounding.latencyMs = _elapsed_ms(started)
            last_llm.grounding = grounding.to_dict()
            return insights, last_llm, "groq_grounded"
        except ValueError as error:
            revision_feedback = str(error)
            LOGGER.warning(
                "Grounded draft validation failed on attempt %s: %s",
                attempt,
                revision_feedback,
            )
            grounding.validationFailures.append(revision_feedback)

    # The LLM was reachable but could not produce a usable draft, while a curated claim
    # did match the transcript. Build a deterministic grounded draft from the journal
    # narrative and the retrieved claim so the source-supported evidence still reaches
    # the user. This keeps every guardrail: only approved claims, catalog-authored claim
    # text, and no invented research wording. When the LLM was never reachable
    # (no API key), we deliberately do NOT attach a citation to bare template text.
    if last_llm.status != "skipped":
        deterministic = _deterministic_grounded_insights(
            result, facts, retrieved, catalog
        )
        if deterministic is not None:
            grounding.status = "source_supported"
            grounding.reason = None
            grounding.latencyMs = _elapsed_ms(started)
            last_llm.grounding = grounding.to_dict()
            return deterministic, last_llm, "grounded_template"

    grounding.status = "fallback"
    grounding.reason = (
        "llm_unavailable" if last_llm.status == "skipped" else "validation_failed"
    )
    grounding.latencyMs = _elapsed_ms(started)
    last_llm.grounding = grounding.to_dict()
    return (
        [_user_data_only_insight(result, facts, grounding.reason, catalog)],
        last_llm,
        "grounded_template",
    )


def _deterministic_grounded_insights(
    result: AnalysisResult,
    facts: list[ObservationFact],
    retrieved: list[ClaimCard],
    catalog: GroundingCatalog,
) -> list[AiInsight] | None:
    """Assemble a source-supported insight without the LLM.

    Returns ``None`` when no curated claim matched a transcript fact, so callers can
    fall through to the plain user-data-only card.
    """
    if not retrieved:
        return None
    draft = _deterministic_draft(result, facts, retrieved)
    if draft is None:
        return None
    try:
        cleaned = sanitize_draft_references([draft], facts, retrieved, catalog)
        validate_draft_references(cleaned, facts, retrieved, catalog)
        insights = assemble_insights(cleaned, facts, retrieved, catalog)
        validate_assembled_insights(insights, facts, catalog)
    except ValueError as error:
        LOGGER.warning("Deterministic grounded assembly failed: %s", error)
        return None
    if not any(
        item.evidence["verification"]["status"] == "source_supported"
        for item in insights
    ):
        return None
    return insights


def _deterministic_draft(
    result: AnalysisResult,
    facts: list[ObservationFact],
    retrieved: list[ClaimCard],
) -> GroundedInsightDraft | None:
    matched_facts = [
        fact
        for fact in facts
        if fact.kind in {"topic", "key_phrase"}
        and any(claim.claimType in fact.claimTypes for claim in retrieved)
    ]
    if not matched_facts:
        return None
    matched_types = {claim.claimType for claim in retrieved}
    used_claims = [
        claim
        for claim in retrieved
        if any(claim.claimType in fact.claimTypes for fact in matched_facts)
    ][:2]
    if not used_claims:
        return None

    narrative = build_journal_narrative(result)
    themes = [str(fact.value) for fact in matched_facts][:3]
    paraphrase = str(narrative.get("paraphrase") or "").strip()
    excerpts = [
        str(item).strip()
        for item in (narrative.get("keyExcerpts") or [])
        if str(item).strip()
    ]
    if paraphrase:
        summary = paraphrase[:280]
    elif excerpts:
        summary = excerpts[0][:280]
    elif themes:
        summary = f"This reflection touched on {_join_words(themes)}."
    else:
        summary = "This reflection was captured in your own words."

    observation_ids = tuple(fact.evidenceId for fact in matched_facts[:4])
    claim_ids = tuple(claim.claimCardId for claim in used_claims)
    return GroundedInsightDraft(
        title="A grounded note from this reflection",
        summary=summary,
        moodLabel="reflective",
        dayThemes=tuple(themes),
        reflectionQuestions=("What felt most important to name in this reflection?",),
        observationFactIds=observation_ids,
        claimCardIds=claim_ids,
        suggestionIds=(),
        confidence=min(
            0.75, max((fact.confidence for fact in matched_facts), default=0.0)
        ),
        safetyNote="Solenne offers wellness reflections, not medical advice.",
    )


def _user_data_only_insight(
    result: AnalysisResult,
    facts: list[ObservationFact],
    reason: str,
    catalog: GroundingCatalog | None,
) -> AiInsight:
    narrative = build_journal_narrative(result)
    topics = [str(item.value) for item in facts if item.kind == "topic"][:3]
    if not topics:
        topics = list(narrative.get("topics") or [])[:3]
    phrases = [str(item.value) for item in facts if item.kind == "key_phrase"][:3]
    if not phrases:
        phrases = list(narrative.get("keyPhrases") or [])[:3]
    selected = [item for item in facts if item.kind in {"topic", "key_phrase"}][:4]
    if not selected:
        selected = [item for item in facts if item.kind == "word_count"]
    paraphrase = str(narrative.get("paraphrase") or "").strip()
    excerpts = [str(item).strip() for item in (narrative.get("keyExcerpts") or []) if str(item).strip()]
    if paraphrase:
        summary = paraphrase[:280]
    elif excerpts:
        summary = excerpts[0][:280]
    elif topics:
        summary = f"This reflection included themes of {_join_words(topics)}."
    elif phrases:
        summary = f"A few words that stood out in this reflection were {_join_words(phrases)}."
    else:
        summary = (
            "Your reflection was captured, but there was not enough transcript detail "
            "for a source-supported interpretation."
        )
    return AiInsight(
        title="A note from this reflection",
        summary=summary,
        moodLabel="reflective",
        dayThemes=topics or phrases,
        suggestions=[],
        reflectionQuestions=["What felt most important to name in this reflection?"],
        evidence={
            "schemaVersion": 2,
            "userEvidence": [item.to_evidence() for item in selected],
            "externalReferences": [],
            "verification": {
                "status": "fallback" if reason not in {"no_catalog_match"} else "user_data_only",
                "method": "journal_observation",
                "catalogVersion": catalog.catalogVersion if catalog else None,
                "reason": reason,
            },
        },
        confidence=min(0.75, max((item.confidence for item in selected), default=0.0)),
        safetyNote="Solenne offers wellness reflections, not medical advice.",
    )


def _safety_insight() -> AiInsight:
    return AiInsight(
        title="You deserve immediate support",
        summary=(
            "If you may be in immediate danger or might act on these thoughts, "
            "contact local emergency services now and reach out to someone you trust."
        ),
        moodLabel="",
        dayThemes=[],
        suggestions=[],
        reflectionQuestions=[],
        evidence={
            "schemaVersion": 2,
            "userEvidence": [],
            "externalReferences": [],
            "verification": {
                "status": "fallback",
                "method": "deterministic_safety_bypass",
                "catalogVersion": None,
                "reason": "safety_bypass",
            },
        },
        confidence=0.0,
        safetyNote=(
            "Solenne is not an emergency service. Seek immediate local help and stay "
            "with a trusted person if you can."
        ),
    )


def _join_words(values: list[str]) -> str:
    if len(values) == 1:
        return values[0]
    return ", ".join(values[:-1]) + f" and {values[-1]}"


def _elapsed_ms(started: float) -> int:
    return int((time.perf_counter() - started) * 1000)
