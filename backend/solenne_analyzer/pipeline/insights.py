from __future__ import annotations

from ..config import AnalyzerConfig
from ..schemas import AnalysisResult, Insight


def generate_insights(
    result: AnalysisResult,
    config: AnalyzerConfig | None = None,
) -> list[Insight]:
    config = config or AnalyzerConfig()
    fused = result.fused
    if fused.confidence < config.min_confidence_for_insight:
        return []

    insights: list[Insight] = []
    metrics = {
        "overallValence": fused.overallValence,
        "overallArousal": fused.overallArousal,
        "congruence": fused.congruence,
    }

    if fused.congruence < 0.45:
        insights.append(
            Insight(
                templateId="T3_congruence",
                text=(
                    "Your words, voice, and expression did not fully line up. "
                    "It may be worth revisiting what felt mixed or unresolved today."
                ),
                confidence=min(0.9, fused.confidence),
                evidence={
                    "reason": (
                        "This appeared because the available language, voice, and visual "
                        "tone were less closely aligned in this recording."
                    ),
                    "metrics": metrics,
                },
            )
        )
    elif fused.overallValence >= 0.35:
        insights.append(
            Insight(
                templateId="T4_positive_tone",
                text=(
                    "This reflection carried a more positive tone. Notice what supported "
                    "that steadier moment so you can return to it later."
                ),
                confidence=min(0.9, fused.confidence),
                evidence={
                    "reason": (
                        "This appeared because the combined tone estimate leaned more "
                        "positive in this recording."
                    ),
                    "metrics": metrics,
                },
            )
        )
    elif fused.overallValence <= -0.35:
        insights.append(
            Insight(
                templateId="T1_lower_tone",
                text=(
                    "This recording carried a heavier tone. Consider naming one "
                    "small thing that could make the next hour easier."
                ),
                confidence=min(0.85, fused.confidence),
                evidence={
                    "reason": (
                        "This appeared because the combined tone estimate leaned more "
                        "subdued in this recording."
                    ),
                    "metrics": metrics,
                },
            )
        )

    if result.facial.warnings:
        insights.append(
            Insight(
                templateId="Q1_quality_warning",
                text=(
                    "Some visual signals were limited by recording quality, so the result "
                    "leans more on voice and words."
                ),
                confidence=0.65,
                evidence={
                    "reason": (
                        "This appeared because the visual input contained recording-quality "
                        "limitations, so it was given less weight."
                    ),
                    "warnings": result.facial.warnings,
                },
            )
        )

    return _guardrail(insights)


def _guardrail(insights: list[Insight]) -> list[Insight]:
    blocked = {"diagnosis", "depression", "disorder", "clinical", "medical"}
    safe: list[Insight] = []
    for insight in insights:
        lowered = insight.text.lower()
        if not any(term in lowered for term in blocked):
            safe.append(insight)
    return safe[:3]
