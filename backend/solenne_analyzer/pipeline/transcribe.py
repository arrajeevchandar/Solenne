from __future__ import annotations

import math
from pathlib import Path
from typing import Any

from ..config import AnalyzerConfig, DependencyMissingError
from ..schemas import TranscriptResult, TranscriptSegment


def transcribe_audio(audio_path: Path, config: AnalyzerConfig) -> TranscriptResult:
    try:
        from faster_whisper import WhisperModel
    except ImportError as error:
        raise DependencyMissingError(
            "faster-whisper is required for transcription. Run pip install -r backend/requirements.txt."
        ) from error

    model = WhisperModel(config.whisper_model, device="cpu", compute_type="int8")
    segments_iter, info = model.transcribe(
        str(audio_path),
        beam_size=5,
        vad_filter=True,
    )
    segments: list[TranscriptSegment] = []
    confidence_segments: list[Any] = []
    text_parts: list[str] = []
    for segment in segments_iter:
        clean = segment.text.strip()
        if not clean:
            continue
        segments.append(
            TranscriptSegment(
                start=float(segment.start),
                end=float(segment.end),
                text=clean,
            )
        )
        confidence_segments.append(segment)
        text_parts.append(clean)
    text = " ".join(text_parts).strip()
    language_confidence = float(
        getattr(info, "language_probability", 0.0) or 0.0
    )
    return TranscriptResult(
        text=text,
        wordCount=len(text.split()),
        segments=segments,
        language=getattr(info, "language", None),
        confidence=_transcription_confidence(
            confidence_segments,
            fallback=language_confidence,
        ),
        languageConfidence=max(0.0, min(1.0, language_confidence)),
    )


def _transcription_confidence(
    segments: list[Any],
    *,
    fallback: float = 0.0,
) -> float:
    """Estimate text quality independently from language detection confidence.

    Faster Whisper's ``language_probability`` answers how certain the detector is
    about the language label; it is not a confidence score for the recognized text.
    Segment average log probabilities and no-speech probabilities describe the
    actual transcription more directly, so use a word-weighted mean of those values.
    """
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
        speech_probability = max(0.0, min(1.0, speech_probability))
        segment_score = math.exp(min(0.0, float(raw_log_probability)))
        weighted_score += segment_score * speech_probability * weight
        total_weight += weight
    if total_weight:
        return max(0.0, min(1.0, weighted_score / total_weight))
    return max(0.0, min(1.0, float(fallback or 0.0)))
