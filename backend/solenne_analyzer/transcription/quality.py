from __future__ import annotations

import math
import re
from typing import Any


_NON_WORD = re.compile(r"[^a-z0-9]+")


def transcription_confidence(
    segments: list[Any],
    *,
    text: str,
    fallback: float = 0.0,
) -> float:
    if not text.strip():
        return 0.0
    confidence = segment_confidence(segments, fallback=fallback)
    repetition_ratio = _duplicate_segment_ratio(segments)
    if repetition_ratio >= 0.4:
        confidence *= max(0.25, 1.0 - repetition_ratio)
    return _clamp(confidence)


def segment_confidence(
    segments: list[Any],
    *,
    fallback: float = 0.0,
) -> float:
    """Estimate recognition quality independently from language detection."""
    weighted_score = 0.0
    total_weight = 0
    for segment in segments:
        text = str(getattr(segment, "text", "") or "").strip()
        weight = max(1, len(text.split()))
        raw_log_probability = getattr(segment, "avg_logprob", None)
        if not isinstance(raw_log_probability, (int, float)) or not math.isfinite(
            raw_log_probability
        ):
            continue
        speech_probability = 1.0 - float(
            getattr(segment, "no_speech_prob", 0.0) or 0.0
        )
        speech_probability = _clamp(speech_probability)
        segment_score = math.exp(min(0.0, float(raw_log_probability)))
        weighted_score += segment_score * speech_probability * weight
        total_weight += weight
    if total_weight:
        return _clamp(weighted_score / total_weight)
    return _clamp(float(fallback or 0.0))


def _duplicate_segment_ratio(segments: list[Any]) -> float:
    normalized = [
        _NON_WORD.sub(" ", str(getattr(segment, "text", "") or "").lower()).strip()
        for segment in segments
    ]
    normalized = [text for text in normalized if len(text.split()) >= 3]
    if len(normalized) < 3:
        return 0.0
    duplicate_count = len(normalized) - len(set(normalized))
    return duplicate_count / len(normalized)


def _clamp(value: float) -> float:
    return max(0.0, min(1.0, value))
