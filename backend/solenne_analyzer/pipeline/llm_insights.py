from __future__ import annotations

from ..ai.context_builder import build_insight_context, estimate_tokens
from ..ai.groq_client import generate_groq_insights
from ..grounding.runtime import generate_grounded_insights
from ..schemas import AiInsight, AnalysisResult, LlmDiagnostics
from ..config import AnalyzerConfig


def generate_llm_insights(
    result: AnalysisResult,
    config: AnalyzerConfig,
) -> tuple[list[AiInsight], LlmDiagnostics, str]:
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
    combined = [*legacy_insights, *grounded]
    provider = _combined_provider(legacy_provider, grounded_provider, bool(grounded))
    return combined, legacy_diagnostics, provider


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
