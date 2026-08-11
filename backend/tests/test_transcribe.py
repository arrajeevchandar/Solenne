from pathlib import Path
import sys
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

from solenne_analyzer.config import AnalyzerConfig
from solenne_analyzer.pipeline.transcribe import (
    _transcription_confidence,
    transcribe_audio,
)
from solenne_analyzer.schemas import TranscriptResult
from solenne_analyzer.transcription.engine import (
    TranscriptionError,
    TranscriptionOptions,
)
from solenne_analyzer.transcription.faster_whisper_engine import (
    FasterWhisperEngine,
)
from solenne_analyzer.transcription.quality import transcription_confidence


class TranscriptionConfidenceTests(unittest.TestCase):
    def test_segment_quality_is_independent_from_language_detection(self):
        segments = [
            SimpleNamespace(
                text="This is a clearly recognized sentence",
                avg_logprob=-0.12,
                no_speech_prob=0.02,
            ),
            SimpleNamespace(
                text="with another readable part of the journal",
                avg_logprob=-0.18,
                no_speech_prob=0.01,
            ),
        ]

        confidence = _transcription_confidence(segments, fallback=0.21)

        self.assertGreater(confidence, 0.75)

    def test_segment_confidence_is_word_weighted(self):
        segments = [
            SimpleNamespace(
                text="one",
                avg_logprob=-2.0,
                no_speech_prob=0.0,
            ),
            SimpleNamespace(
                text="a longer clearly recognized segment with several useful words",
                avg_logprob=-0.1,
                no_speech_prob=0.0,
            ),
        ]

        confidence = _transcription_confidence(segments, fallback=0.0)

        self.assertGreater(confidence, 0.8)

    def test_language_probability_is_only_a_fallback_without_segment_scores(self):
        confidence = _transcription_confidence(
            [SimpleNamespace(text="words", avg_logprob=None)],
            fallback=0.37,
        )

        self.assertEqual(confidence, 0.37)

    def test_empty_transcript_has_zero_confidence(self):
        confidence = transcription_confidence(
            [
                SimpleNamespace(
                    text="",
                    avg_logprob=-0.01,
                    no_speech_prob=0.0,
                )
            ],
            text="",
            fallback=0.99,
        )

        self.assertEqual(confidence, 0.0)

    def test_repeated_segments_are_penalized(self):
        segments = [
            SimpleNamespace(
                text="Thank you for watching this video",
                avg_logprob=-0.05,
                no_speech_prob=0.0,
            )
            for _ in range(5)
        ]

        confidence = transcription_confidence(
            segments,
            text=" ".join(segment.text for segment in segments),
        )

        self.assertLess(confidence, 0.3)


class FasterWhisperEngineTests(unittest.TestCase):
    def test_forwards_stable_decoding_options_and_preserves_segments(self):
        fake_model = _FakeWhisperModel()
        whisper_module = SimpleNamespace(
            WhisperModel=Mock(return_value=fake_model)
        )
        options = _options(language="en", initial_prompt="Solenne journal")

        with patch.dict(sys.modules, {"faster_whisper": whisper_module}):
            result = FasterWhisperEngine(options).transcribe(Path("audio.wav"))

        whisper_module.WhisperModel.assert_called_once_with(
            "large-v3",
            device="auto",
            compute_type="default",
        )
        self.assertEqual(fake_model.audio_path, "audio.wav")
        self.assertEqual(fake_model.kwargs["beam_size"], 5)
        self.assertEqual(fake_model.kwargs["temperature"], 0.0)
        self.assertTrue(fake_model.kwargs["vad_filter"])
        self.assertTrue(fake_model.kwargs["condition_on_previous_text"])
        self.assertTrue(fake_model.kwargs["word_timestamps"])
        self.assertEqual(fake_model.kwargs["language"], "en")
        self.assertEqual(
            fake_model.kwargs["initial_prompt"],
            "Solenne journal",
        )
        self.assertEqual(
            fake_model.kwargs["vad_parameters"],
            {
                "min_silence_duration_ms": 500,
                "speech_pad_ms": 300,
            },
        )
        self.assertEqual(result.text, "Today felt much clearer.")
        self.assertEqual(result.wordCount, 4)
        self.assertEqual(result.language, "en")
        self.assertEqual(result.languageConfidence, 0.96)
        self.assertEqual(result.segments[0].start, 1.25)
        self.assertEqual(result.segments[0].end, 3.75)

    def test_omits_optional_language_and_prompt(self):
        fake_model = _FakeWhisperModel()
        whisper_module = SimpleNamespace(
            WhisperModel=Mock(return_value=fake_model)
        )

        with patch.dict(sys.modules, {"faster_whisper": whisper_module}):
            FasterWhisperEngine(_options()).transcribe(Path("audio.wav"))

        self.assertNotIn("language", fake_model.kwargs)
        self.assertNotIn("initial_prompt", fake_model.kwargs)

    def test_wraps_model_loading_failure(self):
        whisper_module = SimpleNamespace(
            WhisperModel=Mock(side_effect=RuntimeError("download failed"))
        )

        with patch.dict(sys.modules, {"faster_whisper": whisper_module}):
            with self.assertRaisesRegex(
                TranscriptionError,
                "large-v3.*could not be loaded",
            ):
                FasterWhisperEngine(_options()).transcribe(Path("audio.wav"))

    def test_compatibility_wrapper_uses_engine_contract(self):
        engine = Mock()
        expected = TranscriptResult(text="Stable contract", wordCount=2)
        engine.transcribe.return_value = expected

        with patch(
            "solenne_analyzer.pipeline.transcribe.create_transcription_engine",
            return_value=engine,
        ):
            result = transcribe_audio(Path("audio.wav"), AnalyzerConfig())

        self.assertIs(result, expected)
        engine.transcribe.assert_called_once_with(Path("audio.wav"))


def _options(
    *,
    language: str | None = None,
    initial_prompt: str | None = None,
) -> TranscriptionOptions:
    return TranscriptionOptions(
        model="large-v3",
        device="auto",
        compute_type="default",
        language=language,
        initial_prompt=initial_prompt,
        beam_size=5,
        vad_min_silence_ms=500,
        vad_speech_pad_ms=300,
    )


class _FakeWhisperModel:
    def __init__(self):
        self.audio_path = None
        self.kwargs = {}

    def transcribe(self, audio_path, **kwargs):
        self.audio_path = audio_path
        self.kwargs = kwargs
        segments = [
            SimpleNamespace(
                start=1.25,
                end=3.75,
                text=" Today felt much clearer. ",
                avg_logprob=-0.1,
                no_speech_prob=0.01,
            )
        ]
        info = SimpleNamespace(language="en", language_probability=0.96)
        return iter(segments), info


if __name__ == "__main__":
    unittest.main()
