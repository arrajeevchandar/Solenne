from __future__ import annotations

import time

import httpx

from .prompts import INSIGHT_JSON_SCHEMA, SYSTEM_PROMPT, build_user_prompt
from .validators import parse_ai_insights_json
from ..config import AnalyzerConfig
from ..schemas import AiInsight, LlmDiagnostics


GROQ_CHAT_COMPLETIONS_URL = "https://api.groq.com/openai/v1/chat/completions"


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
    for response_format in [_json_schema_format(), {"type": "json_object"}]:
        try:
            content = _chat_completion(context, config, response_format)
            insights = parse_ai_insights_json(content)
            diagnostics.status = "complete"
            diagnostics.latencyMs = int((time.perf_counter() - started) * 1000)
            diagnostics.failureReason = None
            return insights, diagnostics
        except Exception as error:
            last_error = error
            diagnostics.failureReason = str(error)
    diagnostics.latencyMs = int((time.perf_counter() - started) * 1000)
    if last_error:
        diagnostics.failureReason = str(last_error)
    return [], diagnostics


def _chat_completion(
    context: dict,
    config: AnalyzerConfig,
    response_format: dict,
) -> str:
    payload = {
        "model": config.groq_model,
        "temperature": 0.25,
        "max_tokens": 1200,
        "response_format": response_format,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": build_user_prompt(context)},
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
    return data["choices"][0]["message"]["content"]


def _json_schema_format() -> dict:
    return {
        "type": "json_schema",
        "json_schema": {
            "name": INSIGHT_JSON_SCHEMA["name"],
            "schema": INSIGHT_JSON_SCHEMA["schema"],
        },
    }
