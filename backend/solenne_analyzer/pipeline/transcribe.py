from __future__ import annotations

from pathlib import Path

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
        text_parts.append(clean)
    text = " ".join(text_parts).strip()
    return TranscriptResult(
        text=text,
        wordCount=len(text.split()),
        segments=segments,
        language=getattr(info, "language", None),
        confidence=float(getattr(info, "language_probability", 0.0) or 0.0),
    )
