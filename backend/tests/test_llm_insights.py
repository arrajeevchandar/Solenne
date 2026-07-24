import unittest
from unittest.mock import patch

from solenne_analyzer.config import AnalyzerConfig
from solenne_analyzer.pipeline.llm_insights import generate_llm_insights
from solenne_analyzer.schemas import AiInsight, AnalysisResult, Insight, LlmDiagnostics


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

    def test_enforce_mode_uses_grounded_output(self):
        result = AnalysisResult(runId="run", sourceVideo="sample.mp4")
        grounded = AiInsight(
            title="Grounded",
            summary="A transcript theme appeared.",
            moodLabel="reflective",
        )
        diagnostics = LlmDiagnostics(
            status="complete", grounding={"status": "user_data_only"}
        )
        with patch(
            "solenne_analyzer.pipeline.llm_insights.generate_grounded_insights",
            return_value=([grounded], diagnostics, "groq_grounded"),
        ):
            insights, returned_diagnostics, provider = generate_llm_insights(
                result,
                AnalyzerConfig(
                    enable_llm_insights=True,
                    grounding_mode="enforce",
                ),
            )

        self.assertEqual(insights, [grounded])
        self.assertIs(returned_diagnostics, diagnostics)
        self.assertEqual(provider, "groq_grounded")

    def test_combined_mode_shows_legacy_and_grounded_cards(self):
        result = AnalysisResult(runId="run", sourceVideo="sample.mp4")
        result.insights = [
            Insight(
                templateId="T",
                text="This recording carried a grounded tone.",
                confidence=0.6,
            )
        ]
        grounded = AiInsight(
            title="Grounded",
            summary="A transcript theme appeared.",
            moodLabel="reflective",
            evidence={
                "schemaVersion": 2,
                "userEvidence": [],
                "externalReferences": [
                    {"claimCardId": "claim-work", "title": "Reviewed source"}
                ],
                "verification": {"status": "source_supported"},
            },
        )
        grounded_diagnostics = LlmDiagnostics(
            status="complete", grounding={"status": "source_supported"}
        )
        with patch(
            "solenne_analyzer.pipeline.llm_insights.generate_grounded_insights",
            return_value=([grounded], grounded_diagnostics, "groq_grounded"),
        ):
            insights, diagnostics, provider = generate_llm_insights(
                result,
                AnalyzerConfig(
                    enable_llm_insights=True,
                    groq_api_key=None,
                    grounding_mode="combined",
                ),
            )

        # Both a legacy narrative card and the grounded card are present.
        self.assertGreaterEqual(len(insights), 2)
        self.assertIn(grounded, insights)
        self.assertTrue(
            any(item.evidence.get("schemaVersion") == 2 for item in insights)
        )
        self.assertTrue(
            any(item.evidence.get("schemaVersion") != 2 for item in insights)
        )
        self.assertEqual(provider, "groq_grounded")
        self.assertEqual(diagnostics.grounding["status"], "source_supported")

    def test_combined_mode_surfaces_only_safety_insight_on_crisis(self):
        result = AnalysisResult(runId="run", sourceVideo="sample.mp4")
        result.insights = [
            Insight(templateId="T", text="Legacy card.", confidence=0.6)
        ]
        safety = AiInsight(
            title="You deserve immediate support",
            summary="Reach out now.",
            moodLabel="",
        )
        safety_diagnostics = LlmDiagnostics(
            status="skipped", grounding={"reason": "safety_bypass"}
        )
        with patch(
            "solenne_analyzer.pipeline.llm_insights.generate_grounded_insights",
            return_value=([safety], safety_diagnostics, "safety"),
        ):
            insights, diagnostics, provider = generate_llm_insights(
                result,
                AnalyzerConfig(
                    enable_llm_insights=True,
                    grounding_mode="combined",
                ),
            )

        self.assertEqual(insights, [safety])
        self.assertEqual(provider, "safety")

    def test_shadow_mode_preserves_legacy_output_and_stores_candidate(self):
        result = AnalysisResult(runId="run", sourceVideo="sample.mp4")
        result.insights = [
            Insight(
                templateId="T",
                text="This recording carried a grounded tone.",
                confidence=0.6,
            )
        ]
        shadow = AiInsight(
            title="Shadow",
            summary="A transcript theme appeared.",
            moodLabel="reflective",
        )
        shadow_diagnostics = LlmDiagnostics(
            status="complete", grounding={"status": "source_supported"}
        )
        with patch(
            "solenne_analyzer.pipeline.llm_insights.generate_grounded_insights",
            return_value=([shadow], shadow_diagnostics, "groq_grounded"),
        ):
            insights, diagnostics, provider = generate_llm_insights(
                result,
                AnalyzerConfig(
                    enable_llm_insights=True,
                    groq_api_key=None,
                    grounding_mode="shadow",
                ),
            )

        self.assertEqual(provider, "fallback")
        self.assertTrue(insights)
        self.assertEqual(result.groundingShadowInsights, [shadow])
        self.assertEqual(diagnostics.grounding["status"], "source_supported")


if __name__ == "__main__":
    unittest.main()
