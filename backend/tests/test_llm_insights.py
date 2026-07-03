import unittest

from solenne_analyzer.config import AnalyzerConfig
from solenne_analyzer.pipeline.llm_insights import generate_llm_insights
from solenne_analyzer.schemas import AnalysisResult, Insight


class LlmInsightsTest(unittest.TestCase):
    def test_not_requested_keeps_template_provider(self):
        result = AnalysisResult(runId="run", sourceVideo="sample.mp4")

        ai_insights, diagnostics, provider = generate_llm_insights(
            result,
            AnalyzerConfig(enable_llm_insights=False),
        )

        self.assertEqual(ai_insights, [])
        self.assertEqual(diagnostics.status, "not_requested")
        self.assertEqual(provider, "template")

    def test_missing_key_produces_fallback_cards(self):
        result = AnalysisResult(runId="run", sourceVideo="sample.mp4")
        result.insights = [
            Insight(
                templateId="T",
                text="This reflection carried a grounded tone.",
                confidence=0.6,
                evidence={"overallValence": 0.2},
            )
        ]

        ai_insights, diagnostics, provider = generate_llm_insights(
            result,
            AnalyzerConfig(enable_llm_insights=True, groq_api_key=None),
        )

        self.assertEqual(diagnostics.status, "skipped")
        self.assertEqual(provider, "fallback")
        self.assertTrue(ai_insights)


if __name__ == "__main__":
    unittest.main()
