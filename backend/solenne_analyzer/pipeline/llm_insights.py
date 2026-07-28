from __future__ import annotations

import re

from ..ai.context_builder import build_insight_context, estimate_tokens
from ..ai.groq_client import generate_groq_insights
from ..ai.validators import crisis_language_present
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
    combined = _combine_distinct_insights(legacy_insights, grounded_to_show)
    provider = _combined_provider(
        legacy_provider,
        grounded_provider,
        bool(grounded_to_show),
    )
    return combined, legacy_diagnostics, provider


def _combine_distinct_insights(
    narrative: list[AiInsight],
    grounded: list[AiInsight],
) -> list[AiInsight]:
    """Combine both paths without showing the same titled reflection twice.

    An exact normalized-title collision merges the stronger journal narrative with
    the validated evidence-v2 payload. Distinct narrative cards are preserved, so
    combined mode still presents both personal interpretation and reviewed public
    context.
    """
    combined: list[AiInsight] = []
    title_indexes: dict[str, int] = {}
    for insight in narrative:
        key = _normalized_title(insight.title)
        if key and key in title_indexes:
            continue
        if key:
            title_indexes[key] = len(combined)
        combined.append(insight)
    for insight in grounded:
        key = _normalized_title(insight.title)
        existing_index = title_indexes.get(key) if key else None
        if existing_index is None:
            if key:
                title_indexes[key] = len(combined)
            combined.append(insight)
            continue
        combined[existing_index] = _merge_matching_insights(
            combined[existing_index],
            insight,
        )
    if len(combined) <= 3:
        return combined
    selected = combined[:3]
    if grounded and not any(_is_schema_v2(item) for item in selected):
        selected[-1] = grounded[0]
    return selected


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
            limit=3,
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
    return _fallback_ai_insights(result), diagnostics, "fallback"


def _fallback_ai_insights(result: AnalysisResult) -> list[AiInsight]:
    if result.insights:
        return [
            AiInsight(
                title="Reflection signal",
                summary=insight.text,
                moodLabel=_mood_label(result),
                dayThemes=result.nlp.topics[:4] or result.nlp.keyPhrases[:4],
                suggestions=[
                    "Notice one small moment from today that you may want to remember tomorrow."
                ],
                reflectionQuestions=[
                    "What felt most important in this reflection?",
                    "What is one gentle next step from here?",
                ],
                evidence=insight.evidence,
                confidence=insight.confidence,
                safetyNote="Solenne offers wellness reflections, not medical advice.",
            )
            for insight in result.insights[:2]
        ]
    return [
        AiInsight(
            title="Reflection captured",
            summary=(
                "Your entry was saved and analyzed. The strongest available signals came "
                "from your words, voice, and overall reflection pattern."
            ),
            moodLabel=_mood_label(result),
            dayThemes=result.nlp.topics[:4] or result.nlp.keyPhrases[:4],
            suggestions=[
                "Choose one sentence from today that you want to carry forward.",
                "Record again tomorrow and compare what feels different.",
            ],
            reflectionQuestions=[
                "What did this reflection help you notice?",
                "What would make tomorrow feel a little steadier?",
            ],
            evidence={
                "reason": (
                    "This appeared because the available recording signals were strong "
                    "enough to support a cautious reflection about this entry."
                ),
                "metrics": {
                    "overallValence": result.fused.overallValence,
                    "overallArousal": result.fused.overallArousal,
                    "confidence": result.fused.confidence,
                },
            },
            confidence=min(0.75, result.fused.confidence),
            safetyNote="Solenne offers wellness reflections, not medical advice.",
        )
    ]


def _mood_label(result: AnalysisResult) -> str:
    if result.fused.overallValence > 0.35:
        return "hopeful"
    if result.fused.overallValence < -0.35:
        return "heavy"
    if result.fused.overallArousal > 0.55:
        return "activated"
    return "reflective"
