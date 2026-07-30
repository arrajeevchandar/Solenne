import unittest

from solenne_analyzer.pipeline.insights import generate_insights
from solenne_analyzer.schemas import AnalysisResult, FusedResult


class InsightsTest(unittest.TestCase):
    def test_insights_are_non_clinical(self):
        result = AnalysisResult(runId="run", sourceVideo="video.mp4")
        result.fused = FusedResult(
            overallValence=-0.7,
            overallArousal=0.5,
            engagement=0.6,
            congruence=0.8,
            confidence=0.8,
        )

        insights = generate_insights(result)

        self.assertTrue(insights)
        self.assertTrue(
            all("diagnosis" not in insight.text.lower() for insight in insights)
        )
        self.assertTrue(
            all("depression" not in insight.text.lower() for insight in insights)
        )
        self.assertTrue(all("runId" not in insight.evidence for insight in insights))
        self.assertTrue(all("reason" in insight.evidence for insight in insights))
        self.assertTrue(all("metrics" in insight.evidence for insight in insights))

    def test_insights_suppressed_when_confidence_is_low(self):
        result = AnalysisResult(runId="run", sourceVideo="video.mp4")
        result.fused = FusedResult(confidence=0.1, overallValence=-0.8)

        self.assertEqual(generate_insights(result), [])


if __name__ == "__main__":
    unittest.main()
