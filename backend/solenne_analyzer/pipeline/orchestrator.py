from __future__ import annotations

import json
import traceback
from datetime import datetime
from pathlib import Path
from uuid import uuid4

from ..config import AnalyzerConfig
from ..schemas import AnalysisResult, FacialResult, utc_now_iso
from .face import analyze_face
from .fusion import fuse_modalities
from .insights import generate_insights
from .media import extract_audio, validate_video
from .nlp import analyze_text
from .transcribe import transcribe_audio
from .voice import analyze_voice


class PipelineRunner:
    def __init__(self, config: AnalyzerConfig | None = None) -> None:
        self.config = config or AnalyzerConfig()

    def analyze(self, video_path: Path, run_id: str | None = None) -> AnalysisResult:
        video_path = video_path.resolve()
        run_id = run_id or _build_run_id(video_path)
        run_dir = self.config.output_dir / run_id
        run_dir.mkdir(parents=True, exist_ok=True)
        error_path = run_dir / "error.txt"
        if error_path.exists():
            error_path.unlink()
        log_lines: list[str] = []
        result = AnalysisResult(runId=run_id, sourceVideo=str(video_path))

        try:
            self._log(log_lines, "validate", "starting")
            result.durationSeconds = validate_video(video_path, self.config)

            audio_path = run_dir / "audio.wav"
            self._log(log_lines, "media", "extracting audio")
            extract_audio(video_path, audio_path, self.config)

            self._log(log_lines, "transcribe", "running faster-whisper")
            result.transcript = transcribe_audio(audio_path, self.config)

            self._log(log_lines, "face", "sampling frames")
            result.facial = analyze_face(video_path, self.config)

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

            self._log(log_lines, "insights", "generating templates")
            result.insights = generate_insights(result, self.config)
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


def render_summary(result: AnalysisResult) -> str:
    insights = "\n".join(
        f"- {insight.text} ({insight.confidence:.2f})" for insight in result.insights
    )
    if not insights:
        insights = "- No insight generated yet. More usable signal or future baseline data may be needed."

    return f"""# Solenne Analysis Summary

Run: `{result.runId}`  
Status: `{result.status}`  
Source: `{result.sourceVideo}`  
Created: `{result.createdAt}`

## Transcript

{result.transcript.text or "_No transcript available._"}

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


def _build_run_id(video_path: Path) -> str:
    timestamp = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
    safe_stem = "".join(
        char if char.isalnum() or char in {"-", "_"} else "-"
        for char in video_path.stem
    ).strip("-")[:40]
    return f"{timestamp}-{safe_stem or 'video'}-{uuid4().hex[:8]}"
