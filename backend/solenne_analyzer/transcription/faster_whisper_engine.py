from __future__ import annotations

from pathlib import Path
from typing import Any

from ..config import DependencyMissingError
from ..schemas import TranscriptResult, TranscriptSegment
from .engine import TranscriptionError, TranscriptionOptions
from .quality import transcription_confidence


class FasterWhisperEngine:
    def __init__(self, options: TranscriptionOptions) -> None:
        self.options = options
        self._model: Any | None = None

    def transcribe(self, audio_path: Path) -> TranscriptResult:
        model = self._load_model()
        kwargs: dict[str, Any] = {
            "beam_size": self.options.beam_size,
            "temperature": 0.0,
            "vad_filter": True,
            "vad_parameters": {
                "min_silence_duration_ms": self.options.vad_min_silence_ms,
                "speech_pad_ms": self.options.vad_speech_pad_ms,
            },
            "condition_on_previous_text": True,
            "word_timestamps": True,
        }
        if self.options.language is not None:
            kwargs["language"] = self.options.language
        if self.options.initial_prompt is not None:
            kwargs["initial_prompt"] = self.options.initial_prompt
        try:
            segments_iter, info = model.transcribe(str(audio_path), **kwargs)
            raw_segments = list(segments_iter)
        except Exception as error:
            raise TranscriptionError(
                "Whisper could not transcribe the extracted journal audio."
            ) from error

        segments: list[TranscriptSegment] = []
        scored_segments: list[Any] = []
        text_parts: list[str] = []
        for segment in raw_segments:
            clean = str(getattr(segment, "text", "") or "").strip()
            if not clean:
                continue
            segments.append(
                TranscriptSegment(
                    start=float(segment.start),
                    end=float(segment.end),
                    text=clean,
                )
            )
            scored_segments.append(segment)
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
            confidence=transcription_confidence(
                scored_segments,
                text=text,
                fallback=language_confidence,
            ),
            languageConfidence=_clamp(language_confidence),
        )

    def _load_model(self):
        if self._model is not None:
            return self._model
        try:
            from faster_whisper import WhisperModel
        except ImportError as error:
            raise DependencyMissingError(
                "faster-whisper is required for transcription. "
                "Run pip install -r backend/requirements.txt."
            ) from error
        try:
            self._model = WhisperModel(
                self.options.model,
                device=self.options.device,
                compute_type=self.options.compute_type,
            )
        except Exception as error:
            raise TranscriptionError(
                f"Whisper model '{self.options.model}' could not be loaded."
            ) from error
        return self._model


def _clamp(value: float) -> float:
    return max(0.0, min(1.0, value))
