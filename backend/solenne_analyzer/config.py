from __future__ import annotations

from dataclasses import dataclass
import os
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
    enable_llm_insights: bool = False
    groq_api_key: str | None = None
    groq_model: str = "llama-3.1-8b-instant"
    llm_timeout_seconds: float = 30.0

    @classmethod
    def from_env(
        cls,
        *,
        output_dir: Path = DEFAULT_OUTPUT_DIR,
        whisper_model: str = "small",
        max_video_seconds: int = 180,
        enable_llm_insights: bool | None = None,
        groq_model: str | None = None,
    ) -> "AnalyzerConfig":
        load_dotenv(BACKEND_ROOT / ".env")
        enabled = enable_llm_insights
        if enabled is None:
            enabled = _env_bool("ENABLE_LLM_INSIGHTS", default=False)
        return cls(
            output_dir=output_dir,
            whisper_model=whisper_model,
            max_video_seconds=max_video_seconds,
            enable_llm_insights=enabled,
            groq_api_key=os.environ.get("GROQ_API_KEY"),
            groq_model=groq_model or os.environ.get("GROQ_MODEL", "llama-3.1-8b-instant"),
            llm_timeout_seconds=float(os.environ.get("LLM_TIMEOUT_SECONDS", "30")),
        )


class AnalyzerError(RuntimeError):
    """Base error for expected analyzer failures."""


class DependencyMissingError(AnalyzerError):
    """Raised when an optional ML dependency or binary is missing."""


class MediaValidationError(AnalyzerError):
    """Raised when the input video cannot be used."""


def load_dotenv(path: Path) -> None:
    if not path.exists():
        return
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        os.environ.setdefault(key, value)


def _env_bool(name: str, *, default: bool) -> bool:
    value = os.environ.get(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}
