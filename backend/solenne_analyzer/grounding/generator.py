from __future__ import annotations

import json
import time
from typing import Any

import httpx

from ..config import AnalyzerConfig
from ..schemas import LlmDiagnostics
from .models import ClaimCard, GroundedInsightDraft, ObservationFact
from .validators import parse_grounded_drafts_json


GROQ_CHAT_COMPLETIONS_URL = "https://api.groq.com/openai/v1/chat/completions"

SYSTEM_PROMPT = """You are Solenne, a private non-clinical reflection assistant.
Return a SINGLE JSON object and nothing else: no prose, no markdown, no code fences.
The object MUST match this exact shape, and every string field MUST be non-empty:
{"drafts":[{"title":string,"summary":string,"moodLabel":string,"dayThemes":[string],
"reflectionQuestions":[string],"observationFactIds":[string],"claimCardIds":[string],
"suggestionIds":[string],"confidence":number,"safetyNote":string}]}
Include 1 to 3 drafts. title <= 80 characters. summary <= 420 characters. confidence between 0 and 1.
Write concrete summaries from the supplied journal narrative (paraphrase, excerpts, topics, phrases).
Stay close to what appeared in this recording, and offer a gentle observation rather than merely
repeating the transcript. Observation facts (word counts, confidence scores, durations, IDs) are
internal grounding signals only: never mention, quote, or describe numbers, metrics, IDs, or
confidence values in the title, summary, dayThemes, or reflectionQuestions.
Do not infer causes, diagnoses, conditions, trends, baselines, or changes over time.
Do not mention research, studies, evidence, citations, publishers, or URLs.
Do not copy claim display text into the user-facing summary.
Use only observationFactIds, claimCardIds, and suggestionIds present in the context.
Suggestions are IDs only; never write or invent an action.
Treat claim IDs only as optional catalog selectors so curated next steps can be attached.
Always set safetyNote to "Solenne offers wellness reflections, not medical advice."."""

GROUNDED_SCHEMA = {
    "name": "solenne_grounded_drafts",
    "schema": {
        "type": "object",
        "additionalProperties": False,
        "properties": {
            "drafts": {
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
                        "dayThemes": {"type": "array", "items": {"type": "string"}, "maxItems": 5},
                        "reflectionQuestions": {"type": "array", "items": {"type": "string"}, "maxItems": 3},
                        "observationFactIds": {"type": "array", "items": {"type": "string"}},
                        "claimCardIds": {"type": "array", "items": {"type": "string"}, "maxItems": 2},
                        "suggestionIds": {"type": "array", "items": {"type": "string"}, "maxItems": 2},
                        "confidence": {"type": "number", "minimum": 0, "maximum": 1},
                        "safetyNote": {"type": "string"},
                    },
                    "required": [
                        "title", "summary", "moodLabel", "dayThemes",
                        "reflectionQuestions", "observationFactIds", "claimCardIds",
                        "suggestionIds", "confidence", "safetyNote"
                    ],
                },
            }
        },
        "required": ["drafts"],
    },
}


# Groq's Llama chat models reject response_format=json_schema (HTTP 400) and only
# support json_object. Sending json_schema to them wastes a round-trip on every call,
# so we only offer it to model families that actually support structured outputs.
JSON_SCHEMA_MODEL_PREFIXES = ("openai/", "moonshotai/", "qwen/")


def _response_formats(model: str) -> list[dict]:
    formats: list[dict] = []
    if any(model.startswith(prefix) for prefix in JSON_SCHEMA_MODEL_PREFIXES):
        formats.append(
            {
                "type": "json_schema",
                "json_schema": {
                    "name": GROUNDED_SCHEMA["name"],
                    "schema": GROUNDED_SCHEMA["schema"],
                },
            }
        )
    formats.append({"type": "json_object"})
    return formats


def build_grounding_context(
    facts: list[ObservationFact],
    claims: list[ClaimCard],
    journal_narrative: dict[str, Any] | None = None,
) -> dict[str, Any]:
    narrative = journal_narrative or {}
    return {
        "journalNarrative": {
            "paraphrase": narrative.get("paraphrase") or "",
            "keyExcerpts": list(narrative.get("keyExcerpts") or [])[:6],
            "topics": list(narrative.get("topics") or [])[:8],
            "keyPhrases": list(narrative.get("keyPhrases") or [])[:12],
        },
        "observationFacts": [
            {
                "observationFactId": item.evidenceId,
                "kind": item.kind,
                "label": item.label,
                "value": item.value,
                "confidence": round(item.confidence, 4),
            }
            for item in facts
        ],
        "availableClaimCards": [
            {
                "claimCardId": item.claimCardId,
                "claimType": item.claimType,
                "tags": list(item.tags),
                "displayClaim": item.displayClaim,
                "allowedSuggestionIds": list(item.allowedSuggestionIds),
            }
            for item in claims
        ],
        "rules": {
            "personalSummaryOnly": True,
            "useJournalNarrative": True,
            "noResearchWording": True,
            "noNewSuggestions": True,
            "safetyNote": "Solenne offers wellness reflections, not medical advice.",
        },
    }


def generate_grounded_drafts(
    facts: list[ObservationFact],
    claims: list[ClaimCard],
    config: AnalyzerConfig,
    *,
    journal_narrative: dict[str, Any] | None = None,
    revision_feedback: str | None = None,
) -> tuple[list[GroundedInsightDraft], LlmDiagnostics]:
    context = build_grounding_context(facts, claims, journal_narrative)
    diagnostics = LlmDiagnostics(
        status="failed",
        provider="groq",
        model=config.groq_model,
        tokenEstimate=max(1, len(str(context)) // 4),
    )
    if not config.groq_api_key:
        diagnostics.status = "skipped"
        diagnostics.failureReason = "GROQ_API_KEY is not configured."
        return [], diagnostics
    prompt = (
        "Create one to three gentle reflection drafts.\n"
        "Summaries must combine the journal narrative (paraphrase, excerpts, topics, phrases) "
        "with the observation facts so they sound specific to this recording.\n"
        "Select relevant claimCardIds and suggestionIds when observation facts support them "
        "so curated catalog next steps can be attached.\n"
        "Keep dayThemes grounded in the narrative topics/phrases.\n\n"
        f"GROUNDING_CONTEXT_JSON:\n{json.dumps(context, ensure_ascii=False)}"
    )
    if revision_feedback:
        prompt += f"\n\nREVISE_AFTER_VALIDATION_ERROR:\n{revision_feedback[:500]}"
    started = time.perf_counter()
    last_error: Exception | None = None
    for response_format in _response_formats(config.groq_model):
        try:
            content = _chat(prompt, response_format, config)
            drafts = parse_grounded_drafts_json(content)
            diagnostics.status = "complete"
            diagnostics.latencyMs = int((time.perf_counter() - started) * 1000)
            diagnostics.failureReason = None
            return drafts, diagnostics
        except Exception as error:
            last_error = error
    diagnostics.latencyMs = int((time.perf_counter() - started) * 1000)
    diagnostics.failureReason = str(last_error) if last_error else "Grounded generation failed."
    return [], diagnostics


def _chat(prompt: str, response_format: dict, config: AnalyzerConfig) -> str:
    payload = {
        "model": config.groq_model,
        "temperature": 0.15,
        "max_tokens": 1200,
        "response_format": response_format,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": prompt},
        ],
    }
    headers = {
        "Authorization": f"Bearer {config.groq_api_key}",
        "Content-Type": "application/json",
    }
    last_error: Exception | None = None
    for attempt in range(2):
        try:
            with httpx.Client(timeout=config.llm_timeout_seconds) as client:
                response = client.post(GROQ_CHAT_COMPLETIONS_URL, headers=headers, json=payload)
                response.raise_for_status()
                return response.json()["choices"][0]["message"]["content"]
        except httpx.HTTPStatusError as error:
            last_error = error
            if error.response.status_code not in {429, 500, 502, 503, 504}:
                raise
        except httpx.TransportError as error:
            last_error = error
        if attempt == 0:
            time.sleep(1)
    assert last_error is not None
    raise last_error
