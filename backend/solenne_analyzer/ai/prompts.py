from __future__ import annotations

import json

from .validators import expected_day_theme_count, is_substantive_insight_context


SYSTEM_PROMPT = """You are Solenne, a private wellness journal insight assistant.
You generate calm, grounded reflections from a user's own journal data.
You are not a clinician and must not diagnose, treat, or imply medical certainty.
Use only the supplied data. Do not invent events, identities, symptoms, or causes.
Treat facial and voice metrics as weak signals, not facts.
Write in second person with gentle, practical wording.
If crisis or self-harm language appears, prioritize a supportive safety note and avoid productivity advice.
Return only valid JSON that matches the requested schema."""


INSIGHT_JSON_SCHEMA = {
    "name": "solenne_ai_insights",
    "schema": {
        "type": "object",
        "additionalProperties": False,
        "properties": {
            "aiInsights": {
                "type": "array",
                "minItems": 1,
                "maxItems": 3,
                "items": {
                    "type": "object",
                    "additionalProperties": False,
                    "properties": {
                        "title": {"type": "string"},
                        "summary": {"type": "string"},
                        "moodLabel": {"type": "string"},
                        "dayThemes": {
                            "type": "array",
                            "items": {"type": "string"},
                            "maxItems": 5,
                        },
                        "suggestions": {
                            "type": "array",
                            "items": {"type": "string"},
                            "maxItems": 4,
                        },
                        "reflectionQuestions": {
                            "type": "array",
                            "items": {"type": "string"},
                            "maxItems": 3,
                        },
                        "evidence": {"type": "object"},
                        "confidence": {"type": "number", "minimum": 0, "maximum": 1},
                        "safetyNote": {"type": "string"},
                    },
                    "required": [
                        "title",
                        "summary",
                        "moodLabel",
                        "dayThemes",
                        "suggestions",
                        "reflectionQuestions",
                        "evidence",
                        "confidence",
                        "safetyNote",
                    ],
                },
            }
        },
        "required": ["aiInsights"],
    },
}


def build_user_prompt(
    context: dict,
    *,
    revision_feedback: str | None = None,
) -> str:
    theme_count = expected_day_theme_count(context)
    theme_requirement = (
        f"at least {theme_count} distinct concise day theme"
        f"{'s' if theme_count != 1 else ''}, "
        if theme_count
        else ""
    )
    quality_requirements = (
        "This entry contains enough journal detail for a substantive response. "
        "Return 2 distinct insight cards with different titles and different focuses. "
        "For each card, write a specific 15-to-70-word summary that connects at least "
        "two concrete details from the supplied journal context. Include "
        f"{theme_requirement}at least 2 gentle, practical suggestions that are distinct, "
        "and at least 2 open-ended reflection questions that are distinct. "
        "The evidence.reason must be a meaningful sentence of at least 8 words that "
        "names the supplied observations behind that card without quoting metric values. "
        "Do not pad, repeat, or restate the same idea across cards. "
        if is_substantive_insight_context(context)
        else (
            "This entry has limited usable detail or needs a safety-first response. "
            "One focused card is acceptable, and safety responses may leave suggestions "
            "or reflectionQuestions empty. Do not invent detail to make the response longer. "
        )
    )
    revision = ""
    if revision_feedback:
        revision = (
            "\n\nThe previous response was structurally valid but too sparse or repetitive. "
            "Revise it to satisfy every quality requirement above. Address these issues: "
            f"{revision_feedback[:600]}"
        )
    return (
        "Generate Solenne app-ready wellness insights from this analysis context. "
        "The top-level JSON key must be exactly aiInsights, not insights. "
        "Every insight must include title, summary, moodLabel, dayThemes, "
        "suggestions, reflectionQuestions, evidence, confidence, and safetyNote. "
        "For evidence, return a short reason explaining which supplied observations "
        "prompted that specific insight and a metrics object containing only relevant "
        "supplied metrics. Keep the reason descriptive and do not quote numeric metric "
        "values in it. Tie the reason to journal details or cautious recording observations; "
        "do not infer a personality, mindset, hidden intention, or cause. Do not copy the "
        "transcript or include runId, journalId, sourceVideo, URLs, or other internal "
        "identifiers in evidence. "
        "Keep each summary under 70 words, each suggestion under 24 words, and "
        "each reflection question under 22 words. Use observations, not diagnoses. "
        f"{quality_requirements}\n\n"
        f"ANALYSIS_CONTEXT_JSON:\n{json.dumps(context, ensure_ascii=False)}"
        f"{revision}"
    )
