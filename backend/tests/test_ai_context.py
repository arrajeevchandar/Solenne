import unittest

from solenne_analyzer.ai.context_builder import build_insight_context, estimate_tokens
from solenne_analyzer.schemas import AnalysisResult


class AiContextTest(unittest.TestCase):
    def test_context_uses_source_label_and_metrics(self):
        result = AnalysisResult(
            runId="run-1",
            sourceVideo="C:/private/path/input_videos/sample.mp4",
            durationSeconds=12.3,
        )
        result.transcript.text = "I felt calm today. My goal is to remember this."
        result.transcript.wordCount = 9
        result.nlp.paraphrase = "I felt calm today."
        result.nlp.topics = ["self_reflection"]
        result.fused.overallValence = 0.4
        result.fused.confidence = 0.8

        context = build_insight_context(result)

        self.assertEqual(context["sourceLabel"], "sample.mp4")
        self.assertNotIn("private/path", str(context))
        self.assertEqual(context["metrics"]["fused"]["overallValence"], 0.4)
        self.assertGreater(estimate_tokens(context), 0)


if __name__ == "__main__":
    unittest.main()
