from __future__ import annotations

import json

from .validators import (
    adaptive_insight_limit,
    expected_day_theme_count,
    is_substantive_insight_context,
)


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
                "maxItems": 8,
                "items": {
                    "type": "object",
                    "additionalProperties": False,
                    "properties": {
                        "title": {"type": "string"},
                        "summary": {"type": "string", "maxLength": 600},
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
                            "maxItems": 4,
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
    accepted_cards: list[dict[str, str]] | None = None,
    replacement_count: int | None = None,
) -> str:
    card_limit = adaptive_insight_limit(context)
    theme_count = expected_day_theme_count(context)
    theme_requirement = (
        f"at least {theme_count} distinct concise day theme"
        f"{'s' if theme_count != 1 else ''}, "
        if theme_count
        else ""
    )
    quality_requirements = (
        "This entry contains enough journal detail for a substantive response. "
        f"Return between 2 and {card_limit} distinct insight cards according to the "
        "number of meaningful, non-overlapping themes actually supported by the entry; "
        "fewer than the maximum is better than padding or repetition. "
        "For each card, write a specific 35-to-75-word summary that connects 2 to 4 "
        "concrete details from the supplied journal context. Include "
        f"{theme_requirement}2 to 4 gentle, practical suggestions that are distinct, "
        "and 2 to 4 open-ended reflection questions that are distinct. "
        "Evidence is optional. When a concrete reason is supported, include a meaningful "
        "evidence.reason naming the supplied observations without quoting metric values. "
        "When no reliable reason is available, return evidence as an empty object. "
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
        accepted = accepted_cards or []
        accepted_context = (
            " The following cards were already accepted and must not be repeated: "
            f"{json.dumps(accepted, ensure_ascii=False)}."
            if accepted
            else ""
        )
        replacement_instruction = (
            f" Return at most {replacement_count} corrected replacement card"
            f"{'s' if replacement_count != 1 else ''} only."
            if replacement_count
            else " Revise the invalid cards only."
        )
        revision = (
            "\n\nThe previous response was structurally valid but too sparse or repetitive. "
            "Revise only the rejected material to satisfy every quality requirement above. "
            f"Address these issues: {revision_feedback[:900]}."
            f"{accepted_context}{replacement_instruction}"
        )
    return (
        "Generate Solenne app-ready wellness insights from this analysis context. "
        "The top-level JSON key must be exactly aiInsights, not insights. "
        "Every insight must include title, summary, moodLabel, dayThemes, "
        "suggestions, reflectionQuestions, evidence, confidence, and safetyNote. "
        "For evidence, return either an empty object or a short reason explaining which "
        "supplied observations prompted that specific insight, plus a metrics object "
        "containing only relevant supplied metrics. Keep any reason descriptive and do not "
        "quote numeric metric values in it. Tie the reason to journal details or cautious recording observations; "
        "do not infer a personality, mindset, hidden intention, or cause. Do not copy the "
        "transcript or include runId, journalId, sourceVideo, URLs, or other internal "
        "identifiers in evidence. "
        "Every summary must speak directly to the journal owner using you or your. "
        "Never describe them as a student, the user, the speaker, or the person. "
        "Keep each summary at no more than 75 words, each suggestion under 24 words, and "
        "each reflection question under 22 words. Use observations, not diagnoses. "
        f"{quality_requirements}\n\n"
        f"ANALYSIS_CONTEXT_JSON:\n{json.dumps(context, ensure_ascii=False)}"
        f"{revision}"
    )
