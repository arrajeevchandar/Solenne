from __future__ import annotations

from pathlib import Path
from typing import Any

from ..config import AnalyzerConfig
from ..schemas import TranscriptResult
from ..transcription import create_transcription_engine
from ..transcription.quality import segment_confidence


def transcribe_audio(audio_path: Path, config: AnalyzerConfig) -> TranscriptResult:
    """Compatibility boundary for the pipeline and existing integrations."""
    return create_transcription_engine(config).transcribe(audio_path)


def _transcription_confidence(
    segments: list[Any],
    *,
    fallback: float = 0.0,
) -> float:
    """Compatibility wrapper for existing confidence consumers and tests."""
    return segment_confidence(segments, fallback=fallback)
