from types import SimpleNamespace
import unittest

from solenne_analyzer.pipeline.transcribe import _transcription_confidence


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


if __name__ == "__main__":
    unittest.main()
