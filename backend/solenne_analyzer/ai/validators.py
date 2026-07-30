from __future__ import annotations

import json
import re
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

MIN_SUBSTANTIVE_WORDS = 30
MIN_SUBSTANTIVE_CONFIDENCE = 0.45
MIN_SUMMARY_WORDS = 35
MAX_SUMMARY_WORDS = 75
MAX_AI_INSIGHTS = 8
MIN_EVIDENCE_REASON_WORDS = 8
MIN_SUPPORTING_ITEMS = 2
UNSUPPORTED_INFERENCE_PHRASES = {
    "analytical mindset",
    "reflective mindset",
    "your mindset",
    "your personality",
    "personality trait",
    "hidden intention",
}
THIRD_PERSON_SUBJECT_PHRASES = {
    "a student",
    "the student",
    "the user",
    "the speaker",
    "the person",
    "the journal owner",
}

_ANCHOR_STOP_WORDS = {
    "about",
    "after",
    "again",
    "also",
    "because",
    "been",
    "being",
    "could",
    "entry",
    "feel",
    "feeling",
    "felt",
    "from",
    "have",
    "journal",
    "reflection",
    "that",
    "their",
    "there",
    "these",
    "they",
    "this",
    "today",
    "very",
    "were",
    "what",
    "when",
    "with",
    "words",
    "would",
    "your",
    "youre",
}


class InsightQualityError(ValueError):
    """Raised when a valid AI payload is too sparse for a substantive entry."""


def parse_ai_insights_json(content: str) -> list[AiInsight]:
    payload = json.loads(content)
    return validate_ai_insight_payload(payload)


def validate_ai_insight_payload(payload: dict[str, Any]) -> list[AiInsight]:
    raw_items = payload.get("aiInsights") or payload.get("insights")
    if not isinstance(raw_items, list) or not raw_items:
        raise ValueError("AI response must include a non-empty aiInsights list.")
    insights: list[AiInsight] = []
    for item in raw_items[:MAX_AI_INSIGHTS]:
        if not isinstance(item, dict):
            raise ValueError("Each AI insight must be an object.")
        normalized = _normalize_item(item)
        insight = AiInsight(
            title=_clean_text(normalized["title"], max_len=80),
            summary=_clean_text(normalized["summary"], max_len=600),
            moodLabel=_clean_text(normalized["moodLabel"], max_len=48),
            dayThemes=_clean_list(normalized["dayThemes"], max_items=5, max_len=48),
            suggestions=_clean_list(normalized["suggestions"], max_items=4, max_len=140),
            reflectionQuestions=_clean_list(
                normalized["reflectionQuestions"], max_items=4, max_len=140
            ),
            evidence=_sanitize_evidence(normalized["evidence"]),
            confidence=clamp(float(normalized["confidence"]), 0.0, 1.0),
            safetyNote=_clean_text(normalized["safetyNote"], max_len=260),
        )
        _reject_blocked_language(insight)
        insights.append(insight)
    return insights


def is_substantive_insight_context(context: dict[str, Any]) -> bool:
    transcript = context.get("transcript")
    if not isinstance(transcript, dict):
        return False
    narrative = _context_narrative(context)
    if crisis_language_present(narrative):
        return False
    if _context_confidence_is_low(context):
        return False
    raw_word_count = transcript.get("wordCount", 0)
    try:
        word_count = int(raw_word_count)
    except (TypeError, ValueError):
        word_count = 0
    usable_word_count = _usable_narrative_word_count(transcript)
    if word_count <= 0:
        word_count = usable_word_count
    return (
        min(word_count, usable_word_count) >= MIN_SUBSTANTIVE_WORDS
        and bool(narrative.strip())
    )


def adaptive_insight_limit(context: dict[str, Any]) -> int:
    transcript = context.get("transcript")
    transcript = transcript if isinstance(transcript, dict) else {}
    narrative = _context_narrative(context)
    if crisis_language_present(narrative):
        return 1
    raw_word_count = transcript.get("wordCount", 0)
    try:
        word_count = int(raw_word_count)
    except (TypeError, ValueError):
        word_count = 0
    if word_count <= 0:
        word_count = _usable_narrative_word_count(transcript)
    return adaptive_insight_limit_for_word_count(word_count)


def adaptive_insight_limit_for_word_count(word_count: int) -> int:
    if word_count < 30:
        return 1
    if word_count < 80:
        return 2
    if word_count < 140:
        return 3
    if word_count < 220:
        return 4
    if word_count < 320:
        return 5
    if word_count < 450:
        return 6
    if word_count < 600:
        return 7
    return MAX_AI_INSIGHTS


def expected_day_theme_count(context: dict[str, Any]) -> int:
    metrics = context.get("metrics")
    metrics = metrics if isinstance(metrics, dict) else {}
    text_metrics = metrics.get("text")
    text_metrics = text_metrics if isinstance(text_metrics, dict) else {}
    values: list[str] = []
    for key in ("topics", "keyPhrases"):
        items = text_metrics.get(key)
        if isinstance(items, list):
            values.extend(str(item).strip() for item in items if str(item).strip())
    normalized = {
        clean
        for item in values
        if (clean := _normalized_comparison_text(item))
    }
    return min(2, len(normalized))


def validate_ai_insight_quality(
    insights: list[AiInsight],
    context: dict[str, Any],
) -> None:
    """Require rich, distinct cards only when the journal has enough source detail."""
    direct_address_failures = [
        f"card {index} summary must address the journal owner directly with you or your"
        for index, insight in enumerate(insights, start=1)
        if not _uses_direct_address(insight.summary)
    ]
    if direct_address_failures:
        raise InsightQualityError("; ".join(direct_address_failures))
    oversized = [
        f"card {index} summary must contain no more than {MAX_SUMMARY_WORDS} words"
        for index, insight in enumerate(insights, start=1)
        if len(_word_tokens(insight.summary)) > MAX_SUMMARY_WORDS
    ]
    if oversized:
        raise InsightQualityError("; ".join(oversized))

    if not is_substantive_insight_context(context):
        return

    failures: list[str] = []
    if adaptive_insight_limit(context) >= 2 and len(insights) < 2:
        failures.append("return at least 2 distinct insight cards")

    context_anchors = _context_anchor_tokens(context)
    seen_titles: set[str] = set()
    seen_summaries: set[str] = set()
    for index, insight in enumerate(insights, start=1):
        label = f"card {index}"
        title_key = _normalized_comparison_text(insight.title)
        summary_key = _normalized_comparison_text(insight.summary)
        if title_key in seen_titles:
            failures.append(f"{label} repeats another card title")
        elif title_key:
            seen_titles.add(title_key)
        if summary_key in seen_summaries:
            failures.append(f"{label} repeats another card summary")
        elif summary_key:
            seen_summaries.add(summary_key)

        if len(_word_tokens(insight.summary)) < MIN_SUMMARY_WORDS:
            failures.append(
                f"{label} summary must contain at least {MIN_SUMMARY_WORDS} words"
            )
        expected_anchors = min(2, len(context_anchors))
        summary_anchors = set(_word_tokens(insight.summary)) & context_anchors
        if len(summary_anchors) < expected_anchors:
            failures.append(
                f"{label} summary must name at least {expected_anchors} concrete "
                "details from the journal context"
            )
        expected_themes = expected_day_theme_count(context)
        if _distinct_text_count(insight.dayThemes) < expected_themes:
            failures.append(
                f"{label} must include at least {expected_themes} distinct day themes"
            )
        if _distinct_text_count(insight.suggestions) < MIN_SUPPORTING_ITEMS:
            failures.append(
                f"{label} must include at least {MIN_SUPPORTING_ITEMS} distinct suggestions"
            )
        if _distinct_text_count(insight.reflectionQuestions) < MIN_SUPPORTING_ITEMS:
            failures.append(
                f"{label} must include at least {MIN_SUPPORTING_ITEMS} distinct "
                "reflection questions"
            )
        reason = insight.evidence.get("reason")
        if (
            not isinstance(reason, str)
            or len(_word_tokens(reason)) < MIN_EVIDENCE_REASON_WORDS
        ):
            failures.append(
                f"{label} evidence.reason must contain at least "
                f"{MIN_EVIDENCE_REASON_WORDS} meaningful words"
            )
        elif len(set(_word_tokens(reason)) & context_anchors) < expected_anchors:
            failures.append(
                f"{label} evidence.reason must name at least {expected_anchors} "
                "concrete journal details"
            )

    if failures:
        raise InsightQualityError("; ".join(dict.fromkeys(failures)))


def _uses_direct_address(value: str) -> bool:
    lowered = " ".join(value.lower().replace("’", "'").split())
    if any(phrase in lowered for phrase in THIRD_PERSON_SUBJECT_PHRASES):
        return False
    return bool(
        re.search(
            r"\b(?:you|your|yours|yourself|you're|you've|you'll|you'd)\b",
            lowered,
        )
    )


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
    lowered = " ".join(text.lower().replace("’", "'").split())
    clear_phrases = (
        "kill myself",
        "end my life",
        "self harm",
        "self-harm",
        "suicide",
        "want to die",
        "don't want to live",
        "do not want to live",
    )
    if any(phrase in lowered for phrase in clear_phrases):
        return True
    if re.search(
        r"\bi\s+(?:want|wanted|plan|planned|intend|intended)\s+to\s+"
        r"(?:hurt|kill)\s+myself\b",
        lowered,
    ):
        return True
    if re.search(
        r"\bi\s+(?:might|may|could|will)\s+(?:hurt|kill)\s+myself\b",
        lowered,
    ):
        return True
    if re.search(
        r"\b(?:i am|i'm|i feel|i may be|i might be)\s+not safe"
        r"(?:\s+(?:right now|with myself|alone))?(?=\s*[.!?,;:]|$)",
        lowered,
    ):
        return True
    return bool(
        re.search(
            r"\bi\s+(?:can't|cannot)\s+go\s+on"
            r"(?:\s+(?:living|like this|this way|anymore|any longer|much longer))?"
            r"(?=\s*[.!?,;:]|$)",
            lowered,
        )
    )


def _usable_narrative_word_count(transcript: dict[str, Any]) -> int:
    paraphrase_count = len(_word_tokens(str(transcript.get("paraphrase") or "")))
    excerpts = transcript.get("keyExcerpts")
    excerpt_text = " ".join(
        str(item) for item in excerpts if isinstance(item, str)
    ) if isinstance(excerpts, list) else ""
    return max(paraphrase_count, len(_word_tokens(excerpt_text)))


def _context_confidence_is_low(context: dict[str, Any]) -> bool:
    transcript = context.get("transcript")
    transcript = transcript if isinstance(transcript, dict) else {}
    metrics = context.get("metrics")
    metrics = metrics if isinstance(metrics, dict) else {}
    text_metrics = metrics.get("text")
    text_metrics = text_metrics if isinstance(text_metrics, dict) else {}
    supplied = [
        value
        for value in (
            transcript.get("confidence"),
            text_metrics.get("confidence"),
        )
        if isinstance(value, (int, float))
    ]
    return bool(supplied) and min(float(value) for value in supplied) < (
        MIN_SUBSTANTIVE_CONFIDENCE
    )


def _context_narrative(context: dict[str, Any]) -> str:
    transcript = context.get("transcript")
    transcript = transcript if isinstance(transcript, dict) else {}
    values: list[str] = [
        str(transcript.get("paraphrase") or ""),
        str(transcript.get("text") or ""),
    ]
    excerpts = transcript.get("keyExcerpts")
    if isinstance(excerpts, list):
        values.extend(str(item) for item in excerpts if isinstance(item, str))
    metrics = context.get("metrics")
    metrics = metrics if isinstance(metrics, dict) else {}
    text_metrics = metrics.get("text")
    text_metrics = text_metrics if isinstance(text_metrics, dict) else {}
    for key in ("topics", "keyPhrases"):
        items = text_metrics.get(key)
        if isinstance(items, list):
            values.extend(str(item) for item in items if isinstance(item, str))
    template_insights = context.get("templateInsights")
    if isinstance(template_insights, list):
        for item in template_insights:
            if isinstance(item, dict):
                values.append(str(item.get("text") or ""))
    return " ".join(value for value in values if value).strip()


def _context_anchor_tokens(context: dict[str, Any]) -> set[str]:
    return {
        token
        for token in _word_tokens(_context_narrative(context))
        if len(token) >= 4 and token not in _ANCHOR_STOP_WORDS
    }


def _word_tokens(value: str) -> list[str]:
    return re.findall(r"[a-z0-9]+(?:'[a-z0-9]+)?", value.lower())


def _normalized_comparison_text(value: str) -> str:
    return " ".join(_word_tokens(value))


def _distinct_text_count(values: list[str]) -> int:
    return len(
        {
            normalized
            for value in values
            if (normalized := _normalized_comparison_text(value))
        }
    )


def _clean_text(value: Any, *, max_len: int) -> str:
    if not isinstance(value, str):
        raise ValueError("AI insight text fields must be strings.")
    clean = " ".join(value.split())
    if len(clean) <= max_len:
        return clean
    shortened = clean[:max_len].rstrip()
    return shortened.rsplit(" ", 1)[0] if " " in shortened else shortened


def _clean_list(value: Any, *, max_items: int, max_len: int) -> list[str]:
    if not isinstance(value, list):
        raise ValueError("AI insight list fields must be arrays.")
    return [_clean_text(item, max_len=max_len) for item in value if isinstance(item, str)][:max_items]


def _sanitize_evidence(value: Any) -> dict[str, Any]:
    if not isinstance(value, dict):
        return {}

    blocked_keys = {
        "runid",
        "journalid",
        "entryid",
        "userid",
        "sourcevideo",
        "videourl",
        "thumbnailurl",
        "transcript",
        "transcripttext",
    }

    def sanitize(item: Any, *, key: str = "") -> Any:
        normalized_key = "".join(
            character for character in key.lower() if character.isalnum()
        )
        if normalized_key in blocked_keys:
            return None
        if isinstance(item, dict):
            cleaned = {
                str(child_key): sanitize(child_value, key=str(child_key))
                for child_key, child_value in item.items()
            }
            return {
                child_key: child_value
                for child_key, child_value in cleaned.items()
                if child_value is not None
            }
        if isinstance(item, list):
            cleaned_items = [sanitize(child) for child in item[:12]]
            return [child for child in cleaned_items if child is not None]
        if isinstance(item, str):
            return _clean_text(item, max_len=320)
        if isinstance(item, (int, float, bool)) or item is None:
            return item
        return str(item)[:160]

    cleaned = sanitize(value)
    return cleaned if isinstance(cleaned, dict) else {}


def _reject_blocked_language(insight: AiInsight) -> None:
    reason = insight.evidence.get("reason")
    text = " ".join(
        [
            insight.title,
            insight.summary,
            insight.moodLabel,
            " ".join(insight.dayThemes),
            " ".join(insight.suggestions),
            " ".join(insight.reflectionQuestions),
            insight.safetyNote,
            reason if isinstance(reason, str) else "",
        ]
    ).lower()
    if any(term in text for term in BLOCKED_TERMS):
        raise ValueError("AI insight contains blocked clinical language.")
    if any(term in text for term in UNSUPPORTED_INFERENCE_PHRASES):
        raise InsightQualityError(
            "AI insight must not infer a personality or mindset."
        )
    if "medical advice" in text and "not medical advice" not in text:
        raise ValueError("AI insight contains blocked clinical language.")
