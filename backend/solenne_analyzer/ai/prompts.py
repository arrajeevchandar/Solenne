from __future__ import annotations

import json


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


def build_user_prompt(context: dict) -> str:
    return (
        "Generate Solenne app-ready wellness insights from this analysis context. "
        "The top-level JSON key must be exactly aiInsights, not insights. "
        "Every insight must include title, summary, moodLabel, dayThemes, "
        "suggestions, reflectionQuestions, evidence, confidence, and safetyNote. "
        "Keep each summary under 70 words, each suggestion under 24 words, and "
        "each reflection question under 22 words. Use observations, not diagnoses.\n\n"
        f"ANALYSIS_CONTEXT_JSON:\n{json.dumps(context, ensure_ascii=False)}"
    )
