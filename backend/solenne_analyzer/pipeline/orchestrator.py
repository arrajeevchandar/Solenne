from __future__ import annotations

import json
import traceback
from collections.abc import Callable
from datetime import datetime
from pathlib import Path
from uuid import uuid4

from ..config import AnalyzerConfig
from ..schemas import AnalysisResult, FacialResult, TranscriptResult, utc_now_iso
from .face import analyze_face
from .fusion import fuse_modalities
from .insights import generate_insights
from .llm_insights import LlmInsightUnavailable, generate_llm_insights
from .media import extract_audio, normalize_audio, probe_media_duration, validate_video
from .nlp import analyze_text
from .transcribe import transcribe_audio
from .voice import analyze_voice


class PipelineRunner:
    def __init__(
        self,
        config: AnalyzerConfig | None = None,
        on_progress: Callable[[str], None] | None = None,
    ) -> None:
        self.config = config or AnalyzerConfig()
        self.on_progress = on_progress

    def analyze(self, video_path: Path, run_id: str | None = None) -> AnalysisResult:
        return self._analyze_video(video_path, run_id)

    def _analyze_video(self, video_path: Path, run_id: str | None = None) -> AnalysisResult:
        video_path = video_path.resolve()
        run_id = run_id or _build_run_id(video_path)
        run_dir = self.config.output_dir / run_id
        run_dir.mkdir(parents=True, exist_ok=True)
        error_path = run_dir / "error.txt"
        if error_path.exists():
            error_path.unlink()
        log_lines: list[str] = []
        result = AnalysisResult(
            runId=run_id,
            sourceVideo=str(video_path),
            entryType="video",
            analysisModalities=["face", "transcript", "voice", "text"],
        )

        try:
            self._log(log_lines, "validate", "starting")
            result.durationSeconds = validate_video(video_path, self.config)

            audio_path = run_dir / "audio.wav"
            self._log(log_lines, "media", "extracting audio")
            extract_audio(video_path, audio_path, self.config)

            self._log(log_lines, "transcribe", "running faster-whisper")
            result.transcript = transcribe_audio(audio_path, self.config)

            self._log(log_lines, "face", "sampling frames")
            result.facial = analyze_face(
                video_path,
                self.config,
                duration_seconds=result.durationSeconds,
            )

            self._log(log_lines, "voice", "extracting prosody")
            result.voice = analyze_voice(audio_path, result.transcript)

            self._log(log_lines, "nlp", "analyzing transcript")
            result.nlp = analyze_text(result.transcript.text)

            self._log(log_lines, "fusion", "combining modalities")
            result.fused = fuse_modalities(
                result.facial,
                result.voice,
                result.nlp,
                self.config,
            )

            self._generate_insights(result, log_lines)
            result.status = "complete"
            result.warnings = list(result.facial.warnings)
            self._log(log_lines, "complete", "analysis complete")
        except Exception as error:
            result.status = "failed"
            result.errorMessage = str(error)
            result.facial = result.facial or FacialResult()
            self._log(log_lines, "failed", str(error))
            error_path.write_text(
                traceback.format_exc(),
                encoding="utf-8",
            )
        finally:
            self._write_outputs(run_dir, result, log_lines)

        return result

    def analyze_audio(self, audio_path: Path, run_id: str | None = None) -> AnalysisResult:
        audio_path = audio_path.resolve()
        run_id = run_id or _build_run_id(audio_path)
        run_dir = self.config.output_dir / run_id
        run_dir.mkdir(parents=True, exist_ok=True)
        log_lines: list[str] = []
        result = AnalysisResult(
            runId=run_id,
            sourceVideo=str(audio_path),
            entryType="audio",
            analysisModalities=["transcript", "voice", "text"],
        )
        try:
            self._log(log_lines, "validate", "checking audio")
            result.durationSeconds = probe_media_duration(audio_path)
            if result.durationSeconds > self.config.max_video_seconds + 5:
                raise ValueError("Audio exceeds the configured journal duration limit.")
            normalized = run_dir / "audio.wav"
            self._log(log_lines, "media", "normalizing audio")
            normalize_audio(audio_path, normalized, self.config)
            self._log(log_lines, "transcribe", "running faster-whisper")
            result.transcript = transcribe_audio(normalized, self.config)
            self._log(log_lines, "voice", "extracting prosody")
            result.voice = analyze_voice(normalized, result.transcript)
            self._log(log_lines, "nlp", "analyzing transcript")
            result.nlp = analyze_text(result.transcript.text)
            self._log(log_lines, "fusion", "combining audio modalities")
            result.fused = fuse_modalities(result.facial, result.voice, result.nlp, self.config)
            self._generate_insights(result, log_lines)
            result.status = "complete"
            self._log(log_lines, "complete", "analysis complete")
        except Exception as error:
            result.status = "failed"
            result.errorMessage = str(error)
            self._log(log_lines, "failed", str(error))
            (run_dir / "error.txt").write_text(traceback.format_exc(), encoding="utf-8")
        finally:
            self._write_outputs(run_dir, result, log_lines)
        return result

    def analyze_written(self, text: str, run_id: str | None = None) -> AnalysisResult:
        normalized = text.strip()
        run_id = run_id or f"written-{uuid4().hex[:8]}"
        run_dir = self.config.output_dir / run_id
        run_dir.mkdir(parents=True, exist_ok=True)
        log_lines: list[str] = []
        result = AnalysisResult(
            runId=run_id,
            sourceVideo="written-journal.txt",
            entryType="written",
            analysisModalities=["text"],
            writtenText=normalized,
            transcript=TranscriptResult(),
        )
        try:
            self._log(log_lines, "validate", "checking written journal")
            if not normalized:
                raise ValueError("Written journal is empty.")
            if len(normalized) > 10_000:
                raise ValueError("Written journal exceeds 10,000 characters.")
            self._log(log_lines, "nlp", "analyzing written journal")
            result.nlp = analyze_text(normalized)
            self._log(log_lines, "fusion", "combining text modality")
            result.fused = fuse_modalities(result.facial, result.voice, result.nlp, self.config)
            self._generate_insights(result, log_lines)
            result.status = "complete"
            self._log(log_lines, "complete", "analysis complete")
        except Exception as error:
            result.status = "failed"
            result.errorMessage = str(error)
            self._log(log_lines, "failed", str(error))
            (run_dir / "error.txt").write_text(traceback.format_exc(), encoding="utf-8")
        finally:
            self._write_outputs(run_dir, result, log_lines)
        return result

    def _generate_insights(self, result: AnalysisResult, log_lines: list[str]) -> None:
        self._log(log_lines, "insights", "generating templates")
        result.insights = generate_insights(result, self.config)
        self._log(log_lines, "ai_insights", "checking LLM insight generation")
        try:
            result.aiInsights, result.llmDiagnostics, result.insightProvider = (
                generate_llm_insights(result, self.config)
            )
        except LlmInsightUnavailable as error:
            result.aiInsights = []
            result.llmDiagnostics = error.diagnostics
            result.insightProvider = "groq_error"
            raise

    def _write_outputs(
        self,
        run_dir: Path,
        result: AnalysisResult,
        log_lines: list[str],
    ) -> None:
        (run_dir / "analysis.json").write_text(
            json.dumps(result.to_dict(), indent=2, ensure_ascii=False),
            encoding="utf-8",
        )
        (run_dir / "transcript.txt").write_text(
            result.transcript.text,
            encoding="utf-8",
        )
        (run_dir / "summary.md").write_text(
            render_summary(result),
            encoding="utf-8",
        )
        (run_dir / "run.log").write_text("\n".join(log_lines) + "\n", encoding="utf-8")

    def _log(self, log_lines: list[str], step: str, message: str) -> None:
        log_lines.append(f"{utc_now_iso()} [{step}] {message}")
        if self.on_progress is not None:
            self.on_progress(step)


def render_summary(result: AnalysisResult) -> str:
    insights = "\n".join(
        f"- {insight.text} ({insight.confidence:.2f})" for insight in result.insights
    )
    if not insights:
        insights = "- No insight generated yet. More usable signal or future baseline data may be needed."
    ai_insights = "\n\n".join(
        _render_ai_insight(insight) for insight in result.aiInsights
    )
    if not ai_insights:
        ai_insights = "- No AI insight cards generated."

    return f"""# Solenne Analysis Summary

Run: `{result.runId}`  
Status: `{result.status}`  
Source: `{result.sourceVideo}`  
Created: `{result.createdAt}`

## Transcript

{result.narrativeText or "_No transcript or written journal available._"}

## Signals

- Facial valence: `{result.facial.valence:.3f}` confidence `{result.facial.confidence:.3f}`
- Voice energy: `{result.voice.energyMean:.5f}` pause ratio `{result.voice.pauseRatio:.3f}`
- Text sentiment: `{result.nlp.sentimentValence:.3f}` stress `{result.nlp.stressScore:.3f}`
- Overall valence: `{result.fused.overallValence:.3f}`
- Overall arousal: `{result.fused.overallArousal:.3f}`
- Congruence: `{result.fused.congruence:.3f}`

## Paraphrase

{result.nlp.paraphrase or "_No paraphrase available._"}

## Insights

{insights}

## AI Insight Cards

Provider: `{result.insightProvider}`  
LLM status: `{result.llmDiagnostics.status}`  
Model: `{result.llmDiagnostics.model or "n/a"}`

{ai_insights}

## Warnings

{_warnings(result)}
"""


def _warnings(result: AnalysisResult) -> str:
    warnings = list(result.warnings)
    if result.errorMessage:
        warnings.append(result.errorMessage)
    if not warnings:
        return "- None"
    return "\n".join(f"- {warning}" for warning in warnings)


def _render_ai_insight(insight) -> str:
    themes = ", ".join(insight.dayThemes) if insight.dayThemes else "none"
    suggestions = "\n".join(f"  - {item}" for item in insight.suggestions) or "  - None"
    questions = "\n".join(
        f"  - {item}" for item in insight.reflectionQuestions
    ) or "  - None"
    return f"""### {insight.title}

- Mood label: `{insight.moodLabel}`
- Confidence: `{insight.confidence:.2f}`
- Themes: {themes}
- Summary: {insight.summary}
- Suggestions:
{suggestions}
- Reflection questions:
{questions}
- Safety note: {insight.safetyNote}"""


def _build_run_id(video_path: Path) -> str:
    timestamp = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
    safe_stem = "".join(
        char if char.isalnum() or char in {"-", "_"} else "-"
        for char in video_path.stem
    ).strip("-")[:40]
    return f"{timestamp}-{safe_stem or 'video'}-{uuid4().hex[:8]}"
