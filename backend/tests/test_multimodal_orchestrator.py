import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from solenne_analyzer.config import AnalyzerConfig
from solenne_analyzer.schemas import TranscriptResult, VoiceResult
from solenne_analyzer.pipeline.orchestrator import PipelineRunner


class MultimodalOrchestratorTests(unittest.TestCase):
    def test_audio_never_calls_face_analysis(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "entry.m4a"
            source.write_bytes(b"audio")
            runner = PipelineRunner(AnalyzerConfig(output_dir=root / "outputs"))
            with (
                patch(
                    "solenne_analyzer.pipeline.orchestrator.probe_media_duration",
                    return_value=20.0,
                ),
                patch("solenne_analyzer.pipeline.orchestrator.normalize_audio"),
                patch(
                    "solenne_analyzer.pipeline.orchestrator.transcribe_audio",
                    return_value=TranscriptResult(text="A calm day", wordCount=3),
                ),
                patch(
                    "solenne_analyzer.pipeline.orchestrator.analyze_voice",
                    return_value=VoiceResult(confidence=0.8),
                ),
                patch("solenne_analyzer.pipeline.orchestrator.analyze_face") as face,
                patch.object(PipelineRunner, "_generate_insights"),
            ):
                result = runner.analyze_audio(source, run_id="audio-test")

            self.assertEqual(result.status, "complete")
            self.assertEqual(result.entryType, "audio")
            self.assertNotIn("face", result.analysisModalities)
            face.assert_not_called()

    def test_written_never_calls_media_transcript_face_or_voice(self):
        with tempfile.TemporaryDirectory() as directory:
            runner = PipelineRunner(
                AnalyzerConfig(output_dir=Path(directory) / "outputs")
            )
            with (
                patch("solenne_analyzer.pipeline.orchestrator.extract_audio") as media,
                patch("solenne_analyzer.pipeline.orchestrator.transcribe_audio") as transcribe,
                patch("solenne_analyzer.pipeline.orchestrator.analyze_face") as face,
                patch("solenne_analyzer.pipeline.orchestrator.analyze_voice") as voice,
                patch.object(PipelineRunner, "_generate_insights"),
            ):
                result = runner.analyze_written(
                    "I finished a difficult task and felt relieved.",
                    run_id="written-test",
                )

            self.assertEqual(result.status, "complete")
            self.assertEqual(result.entryType, "written")
            self.assertEqual(result.analysisModalities, ["text"])
            self.assertEqual(result.transcript.text, "")
            self.assertTrue(result.writtenText)
            media.assert_not_called()
            transcribe.assert_not_called()
            face.assert_not_called()
            voice.assert_not_called()


if __name__ == "__main__":
    unittest.main()
