from __future__ import annotations

import time

import httpx

from .prompts import INSIGHT_JSON_SCHEMA, SYSTEM_PROMPT, build_user_prompt
from .validators import (
    adaptive_insight_limit,
    is_substantive_insight_context,
    parse_ai_insights_json_partial,
    partition_ai_insights_by_quality,
    repair_sparse_ai_insight,
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
    card_limit = adaptive_insight_limit(context)
    minimum_cards = (
        2
        if is_substantive_insight_context(context) and card_limit >= 2
        else 1
    )
    accepted: list[AiInsight] = []
    last_error: Exception | None = None
    revision_feedback: str | None = None
    response_formats = _response_formats(config.groq_model)
    response_format = response_formats[0]
    repair_candidates: list[AiInsight] = []
    for attempt in range(2):
        diagnostics.revisionUsed = attempt > 0
        try:
            content = _chat_completion(
                context,
                config,
                response_format,
                revision_feedback=revision_feedback,
                accepted_cards=list(accepted),
                replacement_count=max(1, card_limit - len(accepted)),
            )
            parsed, parse_failures = parse_ai_insights_json_partial(content)
            remaining = max(0, card_limit - len(accepted))
            candidates = parsed[:remaining]
            valid, quality_failures = partition_ai_insights_by_quality(
                candidates,
                context,
                existing=accepted,
            )
            accepted.extend(valid)
            rejected_this_attempt = len(parse_failures) + len(candidates) - len(valid)
            diagnostics.rejectedCardCount += max(0, rejected_this_attempt)
            failures = [*parse_failures, *quality_failures]
            if len(accepted) < minimum_cards:
                failures.append(
                    f"return at least {minimum_cards} distinct insight cards"
                )
            repairable_messages = (
                "summary must contain at least",
                "return at least",
            )
            if candidates and failures and all(
                any(marker in failure for marker in repairable_messages)
                for failure in failures
            ):
                repair_candidates = candidates
            elif failures:
                repair_candidates = []
            diagnostics.validationWarnings.extend(
                item
                for item in failures
                if item not in diagnostics.validationWarnings
            )
            if not failures or attempt == 1:
                break
            revision_feedback = "; ".join(failures)
        except Exception as error:
            last_error = error
            message = str(error)
            diagnostics.failureReason = message
            if message not in diagnostics.validationWarnings:
                diagnostics.validationWarnings.append(message)
            if attempt == 1:
                break
            revision_feedback = message
            # A schema-capable model may still reject json_schema at runtime. Use
            # json_object for the single repair attempt in that case.
            if len(response_formats) > 1:
                response_format = response_formats[-1]

    if len(accepted) < minimum_cards and repair_candidates:
        repaired = [
            repair_sparse_ai_insight(item, context)
            for item in repair_candidates
        ]
        valid_repairs, repair_failures = partition_ai_insights_by_quality(
            repaired,
            context,
            existing=accepted,
        )
        accepted.extend(valid_repairs[: max(0, card_limit - len(accepted))])
        diagnostics.validationWarnings.extend(
            item
            for item in repair_failures
            if item not in diagnostics.validationWarnings
        )

    diagnostics.latencyMs = int((time.perf_counter() - started) * 1000)
    diagnostics.acceptedCardCount = len(accepted)
    if accepted:
        diagnostics.status = "complete"
        diagnostics.failureReason = None
        return accepted[:card_limit], diagnostics
    if last_error:
        diagnostics.failureReason = str(last_error)
    elif diagnostics.validationWarnings:
        diagnostics.failureReason = "; ".join(diagnostics.validationWarnings)
    return [], diagnostics


def _chat_completion(
    context: dict,
    config: AnalyzerConfig,
    response_format: dict,
    *,
    revision_feedback: str | None = None,
    accepted_cards: list[AiInsight] | None = None,
    replacement_count: int | None = None,
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
                    accepted_cards=[
                        {"title": item.title, "summary": item.summary}
                        for item in (accepted_cards or [])
                    ],
                    replacement_count=replacement_count,
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
