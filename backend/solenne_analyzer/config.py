from __future__ import annotations

from dataclasses import dataclass
import os
from pathlib import Path


BACKEND_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_INPUT_DIR = BACKEND_ROOT / "input_videos"
DEFAULT_OUTPUT_DIR = BACKEND_ROOT / "outputs"
DEFAULT_GROUNDING_CATALOG_PATH = (
    BACKEND_ROOT / "solenne_analyzer" / "grounding" / "catalog.json"
)


@dataclass(frozen=True)
class AnalyzerConfig:
    output_dir: Path = DEFAULT_OUTPUT_DIR
    whisper_model: str = "large-v3"
    whisper_device: str = "auto"
    whisper_compute_type: str = "default"
    whisper_language: str | None = None
    whisper_initial_prompt: str | None = None
    whisper_beam_size: int = 5
    whisper_vad_min_silence_ms: int = 500
    whisper_vad_speech_pad_ms: int = 300
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
    grounding_mode: str = "off"
    grounding_catalog_path: Path = DEFAULT_GROUNDING_CATALOG_PATH

    @classmethod
    def from_env(
        cls,
        *,
        output_dir: Path = DEFAULT_OUTPUT_DIR,
        whisper_model: str | None = None,
        whisper_device: str | None = None,
        whisper_compute_type: str | None = None,
        whisper_language: str | None = None,
        whisper_initial_prompt: str | None = None,
        max_video_seconds: int = 180,
        enable_llm_insights: bool | None = None,
        groq_model: str | None = None,
    ) -> "AnalyzerConfig":
        load_dotenv(BACKEND_ROOT / ".env")
        enabled = enable_llm_insights
        if enabled is None:
            enabled = _env_bool("ENABLE_LLM_INSIGHTS", default=False)
        grounding_mode = os.environ.get("GROUNDING_MODE", "off").strip().lower()
        if grounding_mode not in {"off", "shadow", "enforce", "combined"}:
            raise ValueError(
                "GROUNDING_MODE must be off, shadow, enforce, or combined."
            )
        catalog_value = os.environ.get("GROUNDING_CATALOG_PATH", "").strip()
        catalog_path = (
            Path(catalog_value).expanduser()
            if catalog_value
            else DEFAULT_GROUNDING_CATALOG_PATH
        )
        if not catalog_path.is_absolute():
            catalog_path = BACKEND_ROOT / catalog_path
        return cls(
            output_dir=output_dir,
            whisper_model=(
                whisper_model
                or os.environ.get("WHISPER_MODEL", "large-v3")
            ).strip(),
            whisper_device=(
                whisper_device
                or os.environ.get("WHISPER_DEVICE", "auto")
            ).strip(),
            whisper_compute_type=(
                whisper_compute_type
                or os.environ.get("WHISPER_COMPUTE_TYPE", "default")
            ).strip(),
            whisper_language=_optional_text(
                whisper_language
                if whisper_language is not None
                else os.environ.get("WHISPER_LANGUAGE")
            ),
            whisper_initial_prompt=_optional_text(
                whisper_initial_prompt
                if whisper_initial_prompt is not None
                else os.environ.get("WHISPER_INITIAL_PROMPT")
            ),
            whisper_beam_size=max(
                1, int(os.environ.get("WHISPER_BEAM_SIZE", "5"))
            ),
            whisper_vad_min_silence_ms=max(
                0,
                int(os.environ.get("WHISPER_VAD_MIN_SILENCE_MS", "500")),
            ),
            whisper_vad_speech_pad_ms=max(
                0, int(os.environ.get("WHISPER_VAD_SPEECH_PAD_MS", "300"))
            ),
            max_video_seconds=max_video_seconds,
            enable_llm_insights=enabled,
            groq_api_key=os.environ.get("GROQ_API_KEY"),
            groq_model=groq_model or os.environ.get("GROQ_MODEL", "llama-3.1-8b-instant"),
            llm_timeout_seconds=float(os.environ.get("LLM_TIMEOUT_SECONDS", "30")),
            grounding_mode=grounding_mode,
            grounding_catalog_path=catalog_path.resolve(),
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


def _optional_text(value: str | None) -> str | None:
    cleaned = str(value or "").strip()
    return cleaned or None
