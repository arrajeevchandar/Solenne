from __future__ import annotations

from collections import Counter
import re

from ..ai.context_builder import build_insight_context, estimate_tokens
from ..ai.groq_client import generate_groq_insights
from ..ai.validators import (
    adaptive_insight_limit_for_word_count,
    crisis_language_present,
)
from ..grounding.runtime import generate_grounded_insights, generate_safety_insights
from ..grounding.validators import validate_grounded_user_language
from ..schemas import AiInsight, AnalysisResult, LlmDiagnostics
from ..config import AnalyzerConfig


def generate_llm_insights(
    result: AnalysisResult,
    config: AnalyzerConfig,
) -> tuple[list[AiInsight], LlmDiagnostics, str]:
    # Safety detection must always inspect the full transcript. Long-entry context
    # selection is intentionally bounded and may omit a crisis phrase near the end.
    if crisis_language_present(result.transcript.text):
        return generate_safety_insights(config)

    if config.grounding_mode == "enforce":
        return generate_grounded_insights(result, config)

    if config.grounding_mode == "combined":
        return _generate_combined_insights(result, config)

    legacy = _generate_legacy_insights(result, config)
    if config.grounding_mode == "shadow":
        shadow, shadow_diagnostics, _ = generate_grounded_insights(result, config)
        result.groundingShadowInsights = shadow
        legacy[1].grounding = shadow_diagnostics.grounding
    return legacy


def _generate_combined_insights(
    result: AnalysisResult,
    config: AnalyzerConfig,
) -> tuple[list[AiInsight], LlmDiagnostics, str]:
    """Serve legacy narrative insights alongside grounded, source-supported ones.

    Each grounded insight carries schema-v2 ``evidence`` with research references,
    so the frontend renders it as its own grounded card next to the narrative cards.
    """
    grounded, grounded_diagnostics, grounded_provider = generate_grounded_insights(
        result, config
    )
    # The grounded pipeline owns the crisis path; when it engages, surface only the
    # deterministic safety insight and skip the narrative cards entirely.
    if grounded_provider == "safety":
        return grounded, grounded_diagnostics, grounded_provider

    legacy_insights, legacy_diagnostics, legacy_provider = _generate_legacy_insights(
        result, config
    )
    legacy_diagnostics.grounding = grounded_diagnostics.grounding
    source_supported = [
        insight for insight in grounded if _is_source_supported(insight)
    ]
    grounded_to_show = source_supported or ([] if legacy_insights else grounded)
    combined = _combine_distinct_insights(
        legacy_insights,
        grounded_to_show,
        limit=adaptive_insight_limit_for_word_count(result.transcript.wordCount),
    )
    legacy_diagnostics.acceptedCardCount = len(combined)
    legacy_diagnostics.rejectedCardCount += grounded_diagnostics.rejectedCardCount
    legacy_diagnostics.revisionUsed = (
        legacy_diagnostics.revisionUsed or grounded_diagnostics.revisionUsed
    )
    legacy_diagnostics.validationWarnings.extend(
        item
        for item in grounded_diagnostics.validationWarnings
        if item not in legacy_diagnostics.validationWarnings
    )
    if combined and (
        legacy_diagnostics.status == "complete"
        or grounded_diagnostics.status == "complete"
    ):
        legacy_diagnostics.status = "complete"
        legacy_diagnostics.failureReason = None
    provider = _combined_provider(
        legacy_provider,
        grounded_provider,
        bool(grounded_to_show),
    )
    return combined, legacy_diagnostics, provider


def _combine_distinct_insights(
    narrative: list[AiInsight],
    grounded: list[AiInsight],
    *,
    limit: int = 8,
) -> list[AiInsight]:
    """Combine both paths without showing semantically duplicate reflections.

    Matching cards preserve richer safe narrative wording and grounded evidence.
    When the adaptive budget is exceeded, merged cards lead and the remaining
    narrative and grounded cards alternate in their original order.
    """
    limit = max(1, min(8, limit))
    combined: list[AiInsight] = []
    origins: list[str] = []
    merged_indexes: set[int] = set()

    for insight in narrative:
        existing_index = _matching_insight_index(combined, insight)
        if existing_index is not None:
            combined[existing_index] = _merge_duplicate_insights(
                combined[existing_index],
                insight,
            )
            merged_indexes.add(existing_index)
            continue
        combined.append(insight)
        origins.append("narrative")

    for insight in grounded:
        existing_index = _matching_insight_index(combined, insight)
        if existing_index is None:
            combined.append(insight)
            origins.append("grounded")
            continue
        combined[existing_index] = _merge_duplicate_insights(
            combined[existing_index],
            insight,
        )
        merged_indexes.add(existing_index)

    if len(combined) <= limit:
        return combined

    selected_indexes = sorted(merged_indexes)[:limit]
    narrative_indexes = [
        index
        for index, origin in enumerate(origins)
        if origin == "narrative" and index not in merged_indexes
    ]
    grounded_indexes = [
        index
        for index, origin in enumerate(origins)
        if origin == "grounded" and index not in merged_indexes
    ]
    while len(selected_indexes) < limit and (narrative_indexes or grounded_indexes):
        if narrative_indexes and len(selected_indexes) < limit:
            selected_indexes.append(narrative_indexes.pop(0))
        if grounded_indexes and len(selected_indexes) < limit:
            selected_indexes.append(grounded_indexes.pop(0))

    selected = [combined[index] for index in selected_indexes]
    supported = [item for item in combined if _is_source_supported(item)]
    if supported and not any(_is_source_supported(item) for item in selected):
        selected[-1] = supported[0]
    return selected


def _matching_insight_index(
    existing: list[AiInsight],
    candidate: AiInsight,
) -> int | None:
    for index, insight in enumerate(existing):
        if _normalized_title(insight.title) == _normalized_title(candidate.title):
            return index
        if _token_overlap(insight, candidate) >= 0.70:
            return index
    return None


def _token_overlap(left: AiInsight, right: AiInsight) -> float:
    left_tokens = _semantic_tokens(f"{left.title} {left.summary}")
    right_tokens = _semantic_tokens(f"{right.title} {right.summary}")
    if min(len(left_tokens), len(right_tokens)) < 3:
        return 0.0
    return len(left_tokens & right_tokens) / min(len(left_tokens), len(right_tokens))


def _semantic_tokens(value: str) -> set[str]:
    stop_words = {
        "a", "an", "and", "are", "as", "at", "because", "both", "but", "for",
        "from", "in", "is", "it", "of", "on", "or", "that", "the", "this",
        "to", "was", "were", "while", "with", "you", "your",
    }
    return {
        token
        for token in re.findall(r"[a-z0-9]+", value.lower())
        if token not in stop_words
    }


def _merge_duplicate_insights(
    left: AiInsight,
    right: AiInsight,
) -> AiInsight:
    if _is_schema_v2(right) and not _is_schema_v2(left):
        return _merge_matching_insights(left, right)
    if _is_schema_v2(left) and not _is_schema_v2(right):
        return _merge_matching_insights(right, left)

    richer, other = (
        (left, right)
        if len(left.summary.split()) >= len(right.summary.split())
        else (right, left)
    )
    merged = AiInsight(
        title=richer.title,
        summary=richer.summary,
        moodLabel=richer.moodLabel or other.moodLabel,
        dayThemes=_distinct_strings(
            [*richer.dayThemes, *other.dayThemes],
            limit=5,
        ),
        suggestions=_distinct_strings(
            [*richer.suggestions, *other.suggestions],
            limit=4,
        ),
        reflectionQuestions=_distinct_strings(
            [*richer.reflectionQuestions, *other.reflectionQuestions],
            limit=4,
        ),
        evidence=richer.evidence or other.evidence,
        confidence=max(richer.confidence, other.confidence),
        safetyNote=_merge_safety_notes(richer.safetyNote, other.safetyNote),
    )
    if _is_schema_v2(merged):
        try:
            validate_grounded_user_language(merged)
        except ValueError:
            return left if _is_schema_v2(left) else right
    return merged


def _merge_matching_insights(
    narrative: AiInsight,
    grounded: AiInsight,
) -> AiInsight:
    """Keep the richer journal prose while preserving validated v2 evidence."""
    summary = (
        narrative.summary
        if len(narrative.summary.split()) > len(grounded.summary.split())
        else grounded.summary
    )
    merged = AiInsight(
        title=narrative.title or grounded.title,
        summary=summary,
        moodLabel=narrative.moodLabel or grounded.moodLabel,
        dayThemes=_distinct_strings(
            [*narrative.dayThemes, *grounded.dayThemes],
            limit=5,
        ),
        suggestions=_distinct_strings(
            [*grounded.suggestions, *narrative.suggestions],
            limit=4,
        ),
        reflectionQuestions=_distinct_strings(
            [*grounded.reflectionQuestions, *narrative.reflectionQuestions],
            limit=4,
        ),
        evidence=grounded.evidence,
        confidence=grounded.confidence,
        safetyNote=_merge_safety_notes(
            narrative.safetyNote,
            grounded.safetyNote,
        ),
    )
    try:
        validate_grounded_user_language(merged)
    except ValueError:
        return grounded
    return merged


def _merge_safety_notes(narrative: str, grounded: str) -> str:
    narrative = " ".join(narrative.split())
    grounded = " ".join(grounded.split())
    if not narrative:
        return grounded
    if not grounded or grounded.casefold() in narrative.casefold():
        return narrative
    if narrative.casefold() in grounded.casefold():
        return grounded
    if "not medical advice" in narrative.casefold():
        return narrative

    separator = " " if narrative.endswith((".", "!", "?")) else ". "
    available = 260 - len(separator) - len(grounded)
    if available <= 0:
        return grounded
    if len(narrative) > available:
        narrative = narrative[:available].rstrip()
        if " " in narrative:
            narrative = narrative.rsplit(" ", 1)[0]
        narrative = narrative.rstrip(" ,;:-")
    return f"{narrative}{separator}{grounded}"


def _distinct_strings(values: list[str], *, limit: int) -> list[str]:
    output: list[str] = []
    seen: set[str] = set()
    for value in values:
        clean = " ".join(value.split())
        key = clean.casefold()
        if clean and key not in seen:
            seen.add(key)
            output.append(clean)
        if len(output) >= limit:
            break
    return output


def _normalized_title(value: str) -> str:
    return " ".join(re.findall(r"[a-z0-9]+", value.lower()))


def _is_schema_v2(insight: AiInsight) -> bool:
    return insight.evidence.get("schemaVersion") == 2


def _is_source_supported(insight: AiInsight) -> bool:
    verification = insight.evidence.get("verification")
    return (
        _is_schema_v2(insight)
        and isinstance(verification, dict)
        and verification.get("status") == "source_supported"
    )


def _combined_provider(
    legacy_provider: str,
    grounded_provider: str,
    has_grounded: bool,
) -> str:
    if has_grounded and grounded_provider == "groq_grounded":
        return "groq_grounded"
    return legacy_provider


def _generate_legacy_insights(
    result: AnalysisResult,
    config: AnalyzerConfig,
) -> tuple[list[AiInsight], LlmDiagnostics, str]:
    context = build_insight_context(result)
    token_estimate = estimate_tokens(context)
    if not config.enable_llm_insights:
        return [], LlmDiagnostics(
            status="not_requested",
            provider="groq",
            model=config.groq_model,
            tokenEstimate=token_estimate,
        ), "template"

    insights, diagnostics = generate_groq_insights(context, config, token_estimate)
    if diagnostics.status == "complete" and insights:
        return insights, diagnostics, "groq"
    return _contextual_fallback_ai_insights(result), diagnostics, "fallback"


def _contextual_fallback_ai_insights(result: AnalysisResult) -> list[AiInsight]:
    """Build journal-specific recovery cards without fabricated evidence."""
    themes = _fallback_themes(result)
    card_count = 2 if result.transcript.wordCount >= 30 and len(themes) >= 3 else 1
    cards: list[AiInsight] = []
    for index in range(card_count):
        pair_start = index * 2
        primary = themes[pair_start % len(themes)]
        secondary = themes[(pair_start + 1) % len(themes)]
        title = _fallback_title(primary, secondary)
        summary = _fallback_summary(primary, secondary, themes)
        cards.append(
            AiInsight(
                title=title[:1].upper() + title[1:],
                summary=summary,
                moodLabel=_mood_label(result),
                dayThemes=list(dict.fromkeys([primary, secondary])),
                suggestions=[
                    f"Write down what felt most important about {primary}.",
                    f"Choose one small next step connected to {secondary}.",
                ],
                reflectionQuestions=[
                    f"Which part of {primary} mattered most to you?",
                    f"What would you like to understand about {secondary}?",
                ],
                evidence={},
                confidence=min(
                    0.75,
                    max(result.transcript.confidence, result.nlp.confidence),
                ),
                safetyNote="Solenne offers wellness reflections, not medical advice.",
            )
        )
    return cards


def _mood_label(result: AnalysisResult) -> str:
    if result.fused.overallValence > 0.35:
        return "hopeful"
    if result.fused.overallValence < -0.35:
        return "heavy"
    if result.fused.overallArousal > 0.55:
        return "activated"
    return "reflective"


def _fallback_themes(result: AnalysisResult) -> list[str]:
    supplied = [
        clean
        for item in [*result.nlp.topics, *result.nlp.keyPhrases]
        if (clean := _clean_fallback_theme(item))
    ]
    transcript = result.transcript.text.lower()
    for source, display in (
        ("proud", "pride"),
        ("guilty", "guilt"),
        ("happy", "happiness"),
        ("sad", "sadness"),
    ):
        if re.search(rf"\b{source}\b", transcript):
            supplied.append(display)
    if re.search(r"\binteractions?\b", transcript):
        supplied.append("interactions")
    stop = {
        "about", "after", "again", "anything", "because", "being", "cannot", "could",
        "dont", "even", "everything", "feel", "feeling", "from", "give", "going",
        "good", "have", "honestly", "journal", "know", "like", "recently",
        "reflection", "right", "situation",
        "that", "their", "them", "there", "these", "they", "this", "today",
        "what", "when", "with", "would", "your", "youre",
    }
    counts = Counter(
        token
        for token in re.findall(r"[a-z0-9]+", result.transcript.text.lower())
        if len(token) >= 4 and token not in stop
    )
    supplied.extend(
        clean
        for token, _ in counts.most_common(10)
        if (clean := _clean_fallback_theme(token))
    )
    themes = list(dict.fromkeys(item for item in supplied if item))
    return (themes or ["today's experience", "what mattered"])[0:4]


def _clean_fallback_theme(value: str) -> str:
    clean = value.replace("_", " ").strip().lower()
    blocked = {
        "anything", "cannot", "can't", "done", "don't", "everything", "feel",
        "give", "good", "honestly", "know", "people", "point", "right",
        "self reflection", "situation", "something", "things", "understand",
    }
    if not clean or clean in blocked:
        return ""
    replacements = {
        "expect": "expectations",
        "expecting": "expectations",
        "guilty": "guilt",
        "proud": "pride",
    }
    return replacements.get(clean, clean)


def _fallback_summary(
    primary: str,
    secondary: str,
    themes: list[str],
) -> str:
    supporting = [item for item in themes if item not in {primary, secondary}][:2]
    support_text = (
        f" while also naming {_join_theme_labels(supporting)}"
        if supporting
        else ""
    )
    return (
        f"You returned to {primary} and {secondary}{support_text}. Your reflection "
        "held these parts together, giving you room to consider how they relate, "
        "which detail carried the most weight, and what you want to approach "
        "differently without forcing one part of the experience to cancel another."
    )


def _fallback_title(primary: str, secondary: str) -> str:
    emotions = {"pride", "guilt", "happiness", "sadness"}
    connector = " alongside " if {primary, secondary} <= emotions else " and "
    title = f"{primary}{connector}{secondary}"
    return title[:1].upper() + title[1:]


def _join_theme_labels(values: list[str]) -> str:
    if len(values) == 1:
        return values[0]
    return " and ".join(values)
