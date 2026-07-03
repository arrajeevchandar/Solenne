from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


BACKEND_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_INPUT_DIR = BACKEND_ROOT / "input_videos"
DEFAULT_OUTPUT_DIR = BACKEND_ROOT / "outputs"


@dataclass(frozen=True)
class AnalyzerConfig:
    output_dir: Path = DEFAULT_OUTPUT_DIR
    whisper_model: str = "small"
    sample_fps: float = 1.0
    audio_sample_rate: int = 16000
    max_video_seconds: int = 180
    face_weight: float = 0.35
    voice_weight: float = 0.35
    text_weight: float = 0.30
    min_confidence_for_insight: float = 0.45


class AnalyzerError(RuntimeError):
    """Base error for expected analyzer failures."""


class DependencyMissingError(AnalyzerError):
    """Raised when an optional ML dependency or binary is missing."""


class MediaValidationError(AnalyzerError):
    """Raised when the input video cannot be used."""
