from __future__ import annotations

import json
from typing import Any

from ..schemas import AiInsight, clamp


BLOCKED_TERMS = {
    "diagnosis",
    "diagnose",
    "clinical",
    "you have depression",
    "you are depressed",
    "bipolar episode",
    "manic episode",
    "disorder",
}


def parse_ai_insights_json(content: str) -> list[AiInsight]:
    payload = json.loads(content)
    return validate_ai_insight_payload(payload)


def validate_ai_insight_payload(payload: dict[str, Any]) -> list[AiInsight]:
    raw_items = payload.get("aiInsights") or payload.get("insights")
    if not isinstance(raw_items, list) or not raw_items:
        raise ValueError("AI response must include a non-empty aiInsights list.")
    insights: list[AiInsight] = []
    for item in raw_items[:3]:
        if not isinstance(item, dict):
            raise ValueError("Each AI insight must be an object.")
        normalized = _normalize_item(item)
        insight = AiInsight(
            title=_clean_text(normalized["title"], max_len=80),
            summary=_clean_text(normalized["summary"], max_len=420),
            moodLabel=_clean_text(normalized["moodLabel"], max_len=48),
            dayThemes=_clean_list(normalized["dayThemes"], max_items=5, max_len=48),
            suggestions=_clean_list(normalized["suggestions"], max_items=4, max_len=140),
            reflectionQuestions=_clean_list(
                normalized["reflectionQuestions"], max_items=3, max_len=140
            ),
            evidence=normalized["evidence"] if isinstance(normalized["evidence"], dict) else {},
            confidence=clamp(float(normalized["confidence"]), 0.0, 1.0),
            safetyNote=_clean_text(normalized["safetyNote"], max_len=260),
        )
        _reject_blocked_language(insight)
        insights.append(insight)
    return insights


def _normalize_item(item: dict[str, Any]) -> dict[str, Any]:
    summary = item.get("summary") or item.get("text") or item.get("insight") or ""
    if not str(summary).strip():
        raise ValueError("AI insight must include a non-empty summary.")
    title = item.get("title") or _title_from_summary(str(summary))
    return {
        "title": title,
        "summary": summary,
        "moodLabel": item.get("moodLabel") or item.get("mood") or "reflective",
        "dayThemes": item.get("dayThemes") or item.get("themes") or [],
        "suggestions": item.get("suggestions") or [],
        "reflectionQuestions": item.get("reflectionQuestions") or item.get("questions") or [],
        "evidence": item.get("evidence") or {},
        "confidence": item.get("confidence", 0.65),
        "safetyNote": item.get("safetyNote") or "Solenne offers wellness reflections, not medical advice.",
    }


def _title_from_summary(summary: str) -> str:
    words = [word.strip(".,:;!?") for word in summary.split() if word.strip()]
    if not words:
        return "Reflection insight"
    return " ".join(words[:5]).capitalize()


def crisis_language_present(text: str) -> bool:
    lowered = text.lower()
    return any(
        phrase in lowered
        for phrase in [
            "kill myself",
            "end my life",
            "self harm",
            "suicide",
            "hurt myself",
            "not safe",
        ]
    )


def _clean_text(value: Any, *, max_len: int) -> str:
    if not isinstance(value, str):
        raise ValueError("AI insight text fields must be strings.")
    return " ".join(value.split())[:max_len]


def _clean_list(value: Any, *, max_items: int, max_len: int) -> list[str]:
    if not isinstance(value, list):
        raise ValueError("AI insight list fields must be arrays.")
    return [_clean_text(item, max_len=max_len) for item in value if isinstance(item, str)][:max_items]


def _reject_blocked_language(insight: AiInsight) -> None:
    text = " ".join(
        [
            insight.title,
            insight.summary,
            insight.moodLabel,
            " ".join(insight.dayThemes),
            " ".join(insight.suggestions),
            " ".join(insight.reflectionQuestions),
            insight.safetyNote,
        ]
    ).lower()
    if any(term in text for term in BLOCKED_TERMS):
        raise ValueError("AI insight contains blocked clinical language.")
    if "medical advice" in text and "not medical advice" not in text:
        raise ValueError("AI insight contains blocked clinical language.")
