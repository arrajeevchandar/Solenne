from __future__ import annotations

import logging
import re
import time

from ..ai.validators import (
    adaptive_insight_limit_for_word_count,
    crisis_language_present,
)
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
    validate_draft_quality,
    validate_draft_references,
)


LOGGER = logging.getLogger("solenne.grounding")


def generate_grounded_insights(
    result: AnalysisResult,
    config: AnalyzerConfig,
) -> tuple[list[AiInsight], LlmDiagnostics, str]:
    started = time.perf_counter()
    if crisis_language_present(result.transcript.text):
        return generate_safety_insights(config, started=started)

    grounding = GroundingDiagnostics(mode=config.grounding_mode, status="starting")

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
    card_limit = adaptive_insight_limit_for_word_count(result.transcript.wordCount)
    retrieved = retrieve_claims(facts, catalog, limit=5)
    grounding.retrievedClaimIds = [item.claimCardId for item in retrieved]
    journal_narrative = build_journal_narrative(result)
    last_llm = LlmDiagnostics(
        status="not_requested",
        provider="groq",
        model=config.groq_model,
    )
    revision_feedback: str | None = None
    accepted_drafts: list[GroundedInsightDraft] = []
    accepted_insights: list[AiInsight] = []
    seen_titles: set[str] = set()
    validation_warnings: list[str] = []
    rejected_total = 0
    for attempt in range(1, 3):
        grounding.attempts = attempt
        drafts, last_llm = generate_grounded_drafts(
            facts,
            retrieved,
            config,
            journal_narrative=journal_narrative,
            revision_feedback=revision_feedback,
            accepted_drafts=accepted_drafts,
            max_drafts=max(1, min(5, card_limit) - len(accepted_drafts)),
        )
        grounding.validationFailures.extend(
            item
            for item in last_llm.validationWarnings
            if item not in grounding.validationFailures
        )
        rejected_total += last_llm.rejectedCardCount
        validation_warnings.extend(
            item
            for item in last_llm.validationWarnings
            if item not in validation_warnings
        )
        if not drafts:
            failure = last_llm.failureReason or "Grounded generation returned no drafts."
            LOGGER.warning("Grounded draft generation failed on attempt %s: %s", attempt, failure)
            grounding.validationFailures.append(failure)
            if last_llm.status == "skipped":
                break
            revision_feedback = failure
            continue
        valid_drafts, valid_insights, failures = _validate_grounded_drafts_individually(
            drafts,
            facts,
            retrieved,
            catalog,
            journal_narrative,
            seen_titles,
        )
        accepted_drafts.extend(valid_drafts)
        accepted_insights.extend(valid_insights)
        last_llm.acceptedCardCount = len(accepted_insights)
        rejected_total += len(failures)
        last_llm.rejectedCardCount = rejected_total
        last_llm.revisionUsed = attempt > 1
        validation_warnings.extend(
            item for item in failures if item not in validation_warnings
        )
        last_llm.validationWarnings = list(validation_warnings)
        if failures:
            revision_feedback = "; ".join(failures)
            LOGGER.warning(
                "Grounded draft validation failed on attempt %s: %s",
                attempt,
                revision_feedback,
            )
            grounding.validationFailures.extend(
                item for item in failures if item not in grounding.validationFailures
            )
            continue
        if accepted_insights:
            return _grounded_success(
                accepted_insights,
                last_llm,
                grounding,
                started,
            )

    if accepted_insights:
        last_llm.rejectedCardCount = rejected_total
        last_llm.revisionUsed = grounding.attempts > 1
        last_llm.validationWarnings = list(validation_warnings)
        return _grounded_success(
            accepted_insights,
            last_llm,
            grounding,
            started,
        )

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


def _validate_grounded_drafts_individually(
    drafts: list[GroundedInsightDraft],
    facts: list[ObservationFact],
    retrieved: list[ClaimCard],
    catalog: GroundingCatalog,
    journal_narrative: dict,
    seen_titles: set[str],
) -> tuple[list[GroundedInsightDraft], list[AiInsight], list[str]]:
    valid_drafts: list[GroundedInsightDraft] = []
    valid_insights: list[AiInsight] = []
    failures: list[str] = []
    for index, draft in enumerate(drafts):
        try:
            cleaned = sanitize_draft_references([draft], facts, retrieved, catalog)[0]
            title_key = " ".join(re.findall(r"[a-z0-9]+", cleaned.title.lower()))
            if title_key and title_key in seen_titles:
                raise ValueError(f"drafts[{index}] repeats an accepted title.")
            validate_draft_references([cleaned], facts, retrieved, catalog)
            validate_draft_quality(
                [cleaned],
                retrieved,
                catalog,
                journal_narrative,
            )
            insights = assemble_insights([cleaned], facts, retrieved, catalog)
            validate_assembled_insights(insights, facts, catalog)
        except ValueError as error:
            failures.append(f"drafts[{index}]: {error}")
            continue
        if title_key:
            seen_titles.add(title_key)
        valid_drafts.append(cleaned)
        valid_insights.extend(insights)
    return valid_drafts, valid_insights, failures


def _grounded_success(
    insights: list[AiInsight],
    diagnostics: LlmDiagnostics,
    grounding: GroundingDiagnostics,
    started: float,
) -> tuple[list[AiInsight], LlmDiagnostics, str]:
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
    diagnostics.status = "complete"
    diagnostics.failureReason = None
    diagnostics.acceptedCardCount = len(insights)
    diagnostics.grounding = grounding.to_dict()
    return insights, diagnostics, "groq_grounded"


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
        validate_draft_quality(
            cleaned,
            retrieved,
            catalog,
            build_journal_narrative(result),
        )
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
    used_claims = [
        claim
        for claim in retrieved
        if any(claim.claimType in fact.claimTypes for fact in matched_facts)
    ][:2]
    if not used_claims:
        return None

    narrative = build_journal_narrative(result)
    themes = _grounded_themes(
        [
            *(str(fact.value) for fact in matched_facts),
            *list(narrative.get("topics") or []),
            *list(narrative.get("keyPhrases") or []),
        ]
    )
    paraphrase = str(narrative.get("paraphrase") or "").strip()
    excerpts = [
        str(item).strip()
        for item in (narrative.get("keyExcerpts") or [])
        if str(item).strip()
    ]
    summary = (
        _thematic_grounded_summary(themes)
        if len(themes) >= 2
        else _deterministic_summary(paraphrase, excerpts, themes)
    )

    observation_ids = tuple(fact.evidenceId for fact in matched_facts[:4])
    claim_ids = tuple(claim.claimCardId for claim in used_claims)
    suggestion_ids = tuple(
        dict.fromkeys(
            suggestion_id
            for claim in used_claims
            for suggestion_id in claim.allowedSuggestionIds
        )
    )[:2]
    return GroundedInsightDraft(
        title=_grounded_title(themes),
        summary=summary,
        moodLabel="reflective",
        dayThemes=tuple(themes),
        reflectionQuestions=(
            "What felt most important to name in this reflection?",
            "Which part of this experience would you like to understand more clearly?",
        ),
        observationFactIds=observation_ids,
        claimCardIds=claim_ids,
        suggestionIds=suggestion_ids,
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
    excerpts = [
        str(item).strip()
        for item in (narrative.get("keyExcerpts") or [])
        if str(item).strip()
    ]
    summary = _deterministic_summary(
        paraphrase,
        excerpts,
        topics or phrases,
    )
    return AiInsight(
        title=_grounded_title(topics or phrases),
        summary=summary,
        moodLabel="reflective",
        dayThemes=topics or phrases,
        suggestions=[
            "Write down one detail from this experience that you want to carry forward.",
            "Choose one part of this reflection that you may want to revisit gently.",
        ],
        reflectionQuestions=[
            "What felt most important to name in this reflection?",
            "Which part of this experience would you like to understand more clearly?",
        ],
        evidence={
            "schemaVersion": 2,
            "rationale": _observation_rationale(selected),
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


def generate_safety_insights(
    config: AnalyzerConfig,
    *,
    started: float | None = None,
) -> tuple[list[AiInsight], LlmDiagnostics, str]:
    grounding = GroundingDiagnostics(
        mode=config.grounding_mode,
        status="fallback",
        reason="safety_bypass",
        latencyMs=0 if started is None else _elapsed_ms(started),
    )
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


def _deterministic_summary(
    paraphrase: str,
    excerpts: list[str],
    themes: list[str],
) -> str:
    source_text = " ".join([paraphrase, *excerpts]).strip()
    substantive = len(source_text.split()) >= 30
    parts: list[str] = []
    for candidate in [paraphrase, *excerpts]:
        clean = " ".join(candidate.split())
        for existing in parts:
            if existing in clean:
                clean = clean.replace(existing, "", 1).strip()
        if not clean or any(clean == item for item in parts):
            continue
        parts.append(clean)
        if len(" ".join(parts).split()) >= 55 or len(parts) >= 4:
            break
    if parts:
        combined = _replace_third_person_subjects(" ".join(parts))
        if not re.search(
            r"\b(?:you|your|yours|yourself)\b",
            combined,
            re.IGNORECASE,
        ):
            combined = f"You described this experience in your own words: {combined}"
        if substantive and len(combined.split()) < 35 and themes:
            combined += (
                f" Your words also returned to {_join_words(themes[:3])}, leaving "
                "you room to decide which part matters most now."
            )
        return _truncate_summary(combined)
    if themes:
        return (
            f"Your reflection included themes of {_join_words(themes)}, giving you "
            "a few distinct parts of the experience to consider."
        )
    return (
        "Your reflection was captured, but there was not enough transcript detail "
        "for a source-supported interpretation."
    )


def _grounded_title(themes: list[str]) -> str:
    replacements = {
        "guilty": "guilt",
        "proud": "pride",
        "happy": "happiness",
        "sad": "sadness",
    }
    cleaned = [
        replacements.get(value, value)
        for item in themes
        if (value := " ".join(str(item).replace("_", " ").lower().split()))
        and value not in {"self reflection", "reflection"}
    ]
    cleaned = list(dict.fromkeys(cleaned))
    if len(cleaned) >= 2:
        title = f"{cleaned[0]} alongside {cleaned[1]}"
    elif cleaned:
        title = f"Exploring {cleaned[0]}"
    else:
        title = "What stood out in your words"
    return title[:1].upper() + title[1:]


def _grounded_themes(values: list[str]) -> list[str]:
    replacements = {
        "expect": "expectations",
        "expecting": "expectations",
        "guilty": "guilt",
        "proud": "pride",
        "happy": "happiness",
        "sad": "sadness",
    }
    blocked = {
        "anything", "cannot", "done", "don't", "everything", "feel", "give",
        "good", "honestly", "know", "people", "point", "right",
        "self reflection", "situation", "something", "understand", "youre",
    }
    output: list[str] = []
    for item in values:
        clean = " ".join(str(item).replace("_", " ").lower().split())
        clean = replacements.get(clean, clean)
        if not clean or clean in blocked or clean in output:
            continue
        output.append(clean)
    return (output or ["what mattered", "your experience"])[:4]


def _thematic_grounded_summary(themes: list[str]) -> str:
    opening = (
        f"You named {themes[0]} alongside {themes[1]}"
        if len(themes) == 2
        else (
            f"You named {themes[0]} alongside {themes[1]} while also returning to "
            f"{_join_words(themes[2:4])}"
        )
    )
    return (
        f"{opening}. Your reflection held these parts together, giving you room to "
        "consider how they relate, which detail carried the most weight, and what "
        "you want to carry forward without forcing one part of the experience to "
        "cancel another."
    )


def _truncate_summary(value: str) -> str:
    clean = " ".join(value.split())
    words = clean.split()
    if len(words) > 75:
        clean = " ".join(words[:75]).rstrip(" ,;:-")
    return _truncate_words(clean, 600)


def _truncate_words(value: str, max_chars: int) -> str:
    clean = " ".join(value.split())
    if len(clean) <= max_chars:
        return clean
    shortened = clean[:max_chars].rstrip()
    if " " in shortened:
        shortened = shortened.rsplit(" ", 1)[0]
    return shortened.rstrip(" ,;:-")


def _replace_third_person_subjects(value: str) -> str:
    clean = " ".join(value.split())
    replacements = (
        (r"\b(?:a|the) student was\b", "you were"),
        (r"\b(?:a|the) student is\b", "you are"),
        (r"\bthe (?:user|speaker|person|journal owner) was\b", "you were"),
        (r"\bthe (?:user|speaker|person|journal owner) is\b", "you are"),
        (r"\b(?:a|the) student\b", "you"),
        (r"\bthe (?:user|speaker|person|journal owner)\b", "you"),
    )
    for pattern, replacement in replacements:
        clean = re.sub(pattern, replacement, clean, flags=re.IGNORECASE)
    return clean


def _observation_rationale(facts: list[ObservationFact]) -> str:
    values = [
        str(item.value).strip()
        for item in facts
        if item.kind in {"topic", "key_phrase"} and str(item.value).strip()
    ]
    if values:
        return (
            f"This appeared because your reflection included {_join_words(values[:3])}. "
            "The note stays close to those words and leaves their personal meaning open."
        )
    return (
        "This appeared because the available journal detail supported a cautious "
        "observation, while leaving its personal meaning for you to decide."
    )


def _elapsed_ms(started: float) -> int:
    return int((time.perf_counter() - started) * 1000)
