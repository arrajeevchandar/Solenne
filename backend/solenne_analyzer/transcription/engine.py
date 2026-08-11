from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Protocol

from ..config import AnalyzerConfig, AnalyzerError
from ..schemas import TranscriptResult


class TranscriptionError(AnalyzerError):
    """Raised when the configured transcription engine cannot complete."""


@dataclass(frozen=True)
class TranscriptionOptions:
    model: str
    device: str
    compute_type: str
    language: str | None
    initial_prompt: str | None
    beam_size: int
    vad_min_silence_ms: int
    vad_speech_pad_ms: int

    @classmethod
    def from_config(cls, config: AnalyzerConfig) -> "TranscriptionOptions":
        return cls(
            model=config.whisper_model,
            device=config.whisper_device,
            compute_type=config.whisper_compute_type,
            language=config.whisper_language,
            initial_prompt=config.whisper_initial_prompt,
            beam_size=config.whisper_beam_size,
            vad_min_silence_ms=config.whisper_vad_min_silence_ms,
            vad_speech_pad_ms=config.whisper_vad_speech_pad_ms,
        )


class TranscriptionEngine(Protocol):
    def transcribe(self, audio_path: Path) -> TranscriptResult:
        """Transcribe one extracted audio file into Solenne's stable schema."""


def create_transcription_engine(config: AnalyzerConfig) -> TranscriptionEngine:
    from .faster_whisper_engine import FasterWhisperEngine

    return FasterWhisperEngine(TranscriptionOptions.from_config(config))
