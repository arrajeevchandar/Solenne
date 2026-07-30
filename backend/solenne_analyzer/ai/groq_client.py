from __future__ import annotations

import time

import httpx

from .prompts import INSIGHT_JSON_SCHEMA, SYSTEM_PROMPT, build_user_prompt
from .validators import (
    InsightQualityError,
    adaptive_insight_limit,
    parse_ai_insights_json,
    validate_ai_insight_quality,
)
from ..config import AnalyzerConfig
from ..schemas import AiInsight, LlmDiagnostics


GROQ_CHAT_COMPLETIONS_URL = "https://api.groq.com/openai/v1/chat/completions"
JSON_SCHEMA_MODEL_PREFIXES = ("openai/", "moonshotai/", "qwen/")


def generate_groq_insights(
    context: dict,
    config: AnalyzerConfig,
    token_estimate: int,
) -> tuple[list[AiInsight], LlmDiagnostics]:
    if not config.groq_api_key:
        return [], LlmDiagnostics(
            status="skipped",
            provider="groq",
            model=config.groq_model,
            tokenEstimate=token_estimate,
            failureReason="GROQ_API_KEY is not configured.",
        )

    started = time.perf_counter()
    diagnostics = LlmDiagnostics(
        status="failed",
        provider="groq",
        model=config.groq_model,
        tokenEstimate=token_estimate,
    )
    last_error: Exception | None = None
    quality_retry_used = False
    stop_after_quality_failure = False
    for response_format in _response_formats(config.groq_model):
        revision_feedback: str | None = None
        while True:
            try:
                content = _chat_completion(
                    context,
                    config,
                    response_format,
                    revision_feedback=revision_feedback,
                )
                insights = parse_ai_insights_json(content)[
                    : adaptive_insight_limit(context)
                ]
                validate_ai_insight_quality(insights, context)
                diagnostics.status = "complete"
                diagnostics.latencyMs = int((time.perf_counter() - started) * 1000)
                diagnostics.failureReason = None
                return insights, diagnostics
            except InsightQualityError as error:
                last_error = error
                diagnostics.failureReason = str(error)
                if quality_retry_used:
                    stop_after_quality_failure = True
                    break
                quality_retry_used = True
                revision_feedback = str(error)
            except Exception as error:
                last_error = error
                diagnostics.failureReason = str(error)
                if quality_retry_used:
                    stop_after_quality_failure = True
                break
        if stop_after_quality_failure:
            break
    diagnostics.latencyMs = int((time.perf_counter() - started) * 1000)
    if last_error:
        diagnostics.failureReason = str(last_error)
    return [], diagnostics


def _chat_completion(
    context: dict,
    config: AnalyzerConfig,
    response_format: dict,
    *,
    revision_feedback: str | None = None,
) -> str:
    card_limit = adaptive_insight_limit(context)
    payload = {
        "model": config.groq_model,
        "temperature": 0.25,
        "max_tokens": _max_output_tokens(card_limit),
        "response_format": response_format,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": build_user_prompt(
                    context,
                    revision_feedback=revision_feedback,
                ),
            },
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
                response = client.post(
                    GROQ_CHAT_COMPLETIONS_URL, headers=headers, json=payload
                )
                response.raise_for_status()
                data = response.json()
            break
        except httpx.HTTPStatusError as error:
            last_error = error
            if error.response.status_code not in {429, 500, 502, 503, 504}:
                raise
        except httpx.TransportError as error:
            last_error = error
        if attempt == 0:
            time.sleep(1)
    else:
        assert last_error is not None
        raise last_error
    choice = data["choices"][0]
    if choice.get("finish_reason") == "length":
        raise ValueError("Groq completion reached the output token limit.")
    return choice["message"]["content"]


def _max_output_tokens(card_limit: int) -> int:
    return max(1200, min(4800, 700 + (card_limit * 500)))


def _response_formats(model: str) -> list[dict]:
    formats: list[dict] = []
    if any(model.startswith(prefix) for prefix in JSON_SCHEMA_MODEL_PREFIXES):
        formats.append(_json_schema_format())
    formats.append({"type": "json_object"})
    return formats


def _json_schema_format() -> dict:
    return {
        "type": "json_schema",
        "json_schema": {
            "name": INSIGHT_JSON_SCHEMA["name"],
            "schema": INSIGHT_JSON_SCHEMA["schema"],
        },
    }
