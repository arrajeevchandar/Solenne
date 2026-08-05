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

    def test_failed_model_uses_detailed_contextual_recovery_without_generic_titles(self):
        result = AnalysisResult(runId="run", sourceVideo="sample.mp4")
        result.transcript.text = (
            "I worked through a difficult project review and explained why the "
            "feedback mattered. I also described a conversation with my teammate "
            "and the changes we want to make before the next presentation. I felt "
            "more settled after writing down the priorities and choosing where to begin."
        )
        result.transcript.wordCount = len(result.transcript.text.split())
        result.transcript.confidence = 0.9
        result.nlp.paraphrase = (
            "I worked through a difficult project review. I described feedback "
            "and a conversation with my teammate."
        )
        result.nlp.topics = ["study"]
        result.nlp.keyPhrases = ["feedback", "teammate", "priorities"]

        insights, diagnostics, provider = generate_llm_insights(
            result,
            AnalyzerConfig(enable_llm_insights=True, groq_api_key=None),
        )

        self.assertEqual(provider, "fallback")
        self.assertEqual(diagnostics.status, "skipped")
        self.assertEqual(len(insights), 2)
        self.assertTrue(all(35 <= len(item.summary.split()) <= 75 for item in insights))
        self.assertTrue(all(len(item.suggestions) == 2 for item in insights))
        self.assertTrue(all(len(item.reflectionQuestions) == 2 for item in insights))
        self.assertTrue(all(item.evidence == {} for item in insights))
        self.assertFalse(
            {item.title for item in insights}
            & {"Reflection signal", "Reflection captured", "A note from this reflection"}
        )

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
        result.transcript.wordCount = 78
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
        result.transcript.text = "I want to hurt myself."
        result.insights = [
            Insight(templateId="T", text="Legacy card.", confidence=0.6)
        ]
        with (
            patch(
                "solenne_analyzer.pipeline.llm_insights.generate_grounded_insights"
            ) as grounded,
            patch(
                "solenne_analyzer.pipeline.llm_insights._generate_legacy_insights"
            ) as legacy,
        ):
            insights, diagnostics, provider = generate_llm_insights(
                result,
                AnalyzerConfig(
                    enable_llm_insights=True,
                    grounding_mode="combined",
                ),
            )

        grounded.assert_not_called()
        legacy.assert_not_called()
        self.assertEqual(insights[0].title, "You deserve immediate support")
        self.assertEqual(provider, "safety")
        self.assertEqual(diagnostics.grounding["reason"], "safety_bypass")

    def test_off_mode_uses_full_transcript_safety_bypass(self):
        result = AnalysisResult(runId="run", sourceVideo="sample.mp4")
        result.transcript.text = (
            ("I described an ordinary day without anything unusual. " * 35)
            + "I want to die."
        )

        with patch(
            "solenne_analyzer.pipeline.llm_insights.generate_groq_insights"
        ) as generate:
            insights, diagnostics, provider = generate_llm_insights(
                result,
                AnalyzerConfig(
                    enable_llm_insights=True,
                    groq_api_key="test-key",
                    grounding_mode="off",
                ),
            )

        generate.assert_not_called()
        self.assertEqual(provider, "safety")
        self.assertEqual(insights[0].title, "You deserve immediate support")
        self.assertEqual(diagnostics.grounding["reason"], "safety_bypass")

    def test_combined_mode_merges_exact_duplicate_with_grounded_evidence(self):
        result = AnalysisResult(runId="run", sourceVideo="sample.mp4")
        narrative = AiInsight(
            title="Mixed Emotions",
            summary=(
                "Happiness about the hackathon result sat beside disappointment about "
                "not reaching the position you had hoped for, while questions about "
                "preparation and effort made the achievement feel more complicated."
            ),
            moodLabel="bittersweet",
            dayThemes=["achievement", "effort"],
            suggestions=["Name what felt rewarding.", "Notice what still matters."],
            reflectionQuestions=[
                "What felt satisfying about the result?",
                "What would you approach differently next time?",
            ],
            safetyNote="Be gentle with yourself while holding both parts of the result.",
        )
        grounded = AiInsight(
            title="mixed-emotions!",
            summary=(
                "Your pride in the hackathon placement appeared alongside sadness about "
                "missing first place, while you questioned the preparation and team "
                "effort behind the result."
            ),
            moodLabel="bittersweet",
            dayThemes=["mixed emotions", "achievement"],
            suggestions=["Write down one moment you want to remember."],
            reflectionQuestions=[
                "What part of the placement feels worth carrying forward?",
                "What does first place represent to you?",
            ],
            safetyNote="Solenne offers wellness reflections, not medical advice.",
            evidence={
                "schemaVersion": 2,
                "rationale": "The reflection named both happiness and sadness.",
                "userEvidence": [],
                "externalReferences": [{"claimCardId": "claim-reflection"}],
                "verification": {"status": "source_supported"},
            },
        )
        diagnostics = LlmDiagnostics(
            status="complete", grounding={"status": "source_supported"}
        )
        with (
            patch(
                "solenne_analyzer.pipeline.llm_insights.generate_grounded_insights",
                return_value=([grounded], diagnostics, "groq_grounded"),
            ),
            patch(
                "solenne_analyzer.pipeline.llm_insights._generate_legacy_insights",
                return_value=(
                    [narrative],
                    LlmDiagnostics(status="complete"),
                    "groq",
                ),
            ),
        ):
            insights, _, provider = generate_llm_insights(
                result,
                AnalyzerConfig(
                    enable_llm_insights=True,
                    grounding_mode="combined",
                ),
            )

        self.assertEqual(len(insights), 1)
        self.assertEqual(insights[0].title, narrative.title)
        self.assertEqual(insights[0].summary, narrative.summary)
        self.assertEqual(insights[0].moodLabel, narrative.moodLabel)
        self.assertIn("Be gentle with yourself", insights[0].safetyNote)
        self.assertIn("not medical advice", insights[0].safetyNote)
        self.assertEqual(
            insights[0].suggestions,
            [
                "Write down one moment you want to remember.",
                "Name what felt rewarding.",
                "Notice what still matters.",
            ],
        )
        self.assertEqual(
            insights[0].dayThemes,
            ["achievement", "effort", "mixed emotions"],
        )
        self.assertEqual(provider, "groq_grounded")
        self.assertEqual(
            insights[0].evidence["verification"]["status"],
            "source_supported",
        )

    def test_combined_mode_does_not_append_non_source_fallback_card(self):
        result = AnalysisResult(runId="run", sourceVideo="sample.mp4")
        narrative = AiInsight(
            title="A fuller reflection",
            summary="A detailed narrative card remains the visible result.",
            moodLabel="reflective",
        )
        fallback = AiInsight(
            title="A note from this reflection",
            summary="A short fallback.",
            moodLabel="reflective",
            evidence={
                "schemaVersion": 2,
                "rationale": "Only journal observations were available.",
                "userEvidence": [],
                "externalReferences": [],
                "verification": {"status": "fallback"},
            },
        )
        with (
            patch(
                "solenne_analyzer.pipeline.llm_insights.generate_grounded_insights",
                return_value=(
                    [fallback],
                    LlmDiagnostics(
                        status="failed",
                        grounding={"status": "fallback"},
                    ),
                    "grounded_template",
                ),
            ),
            patch(
                "solenne_analyzer.pipeline.llm_insights._generate_legacy_insights",
                return_value=(
                    [narrative],
                    LlmDiagnostics(status="complete"),
                    "groq",
                ),
            ),
        ):
            insights, _, provider = generate_llm_insights(
                result,
                AnalyzerConfig(
                    enable_llm_insights=True,
                    grounding_mode="combined",
                ),
            )

        self.assertEqual(insights, [narrative])
        self.assertEqual(provider, "groq")

    def test_combined_merge_does_not_label_unsafe_legacy_wording_as_supported(self):
        result = AnalysisResult(runId="run", sourceVideo="sample.mp4")
        narrative = AiInsight(
            title="Deadline pressure",
            summary=(
                "You are anxious because of your deadline, and that means the work "
                "pressure is determining how you feel about the entire project."
            ),
            moodLabel="anxious",
            suggestions=["Treat the anxiety before returning to the task."],
            reflectionQuestions=["Why is the deadline causing your anxiety?"],
            safetyNote="Be kind to yourself.",
        )
        grounded = AiInsight(
            title="deadline-pressure!",
            summary=(
                "The deadline and unfinished work both stood out while you considered "
                "which expectation mattered most."
            ),
            moodLabel="reflective",
            dayThemes=["work", "deadline"],
            suggestions=["Take one short pause away from the task."],
            reflectionQuestions=[
                "Which expectation matters most?",
                "Where might a boundary help?",
            ],
            evidence={
                "schemaVersion": 2,
                "rationale": "The reflection named work and a deadline.",
                "userEvidence": [],
                "externalReferences": [{"claimCardId": "claim-work"}],
                "verification": {"status": "source_supported"},
            },
            confidence=0.8,
            safetyNote="Solenne offers wellness reflections, not medical advice.",
        )
        with (
            patch(
                "solenne_analyzer.pipeline.llm_insights.generate_grounded_insights",
                return_value=(
                    [grounded],
                    LlmDiagnostics(
                        status="complete",
                        grounding={"status": "source_supported"},
                    ),
                    "groq_grounded",
                ),
            ),
            patch(
                "solenne_analyzer.pipeline.llm_insights._generate_legacy_insights",
                return_value=(
                    [narrative],
                    LlmDiagnostics(status="complete"),
                    "groq",
                ),
            ),
        ):
            insights, _, _ = generate_llm_insights(
                result,
                AnalyzerConfig(
                    enable_llm_insights=True,
                    grounding_mode="combined",
                ),
            )

        self.assertEqual(insights, [grounded])
        self.assertNotIn("because of your", insights[0].summary.lower())

    def test_combined_mode_caps_cards_and_keeps_source_support(self):
        result = AnalysisResult(runId="run", sourceVideo="sample.mp4")
        result.transcript.wordCount = 100
        narrative = [
            AiInsight(title=f"Narrative {index}", summary="A narrative card.", moodLabel="")
            for index in range(1, 4)
        ]
        grounded = [
            AiInsight(
                title=f"Grounded {index}",
                summary="A grounded card.",
                moodLabel="",
                evidence={
                    "schemaVersion": 2,
                    "externalReferences": [{"claimCardId": f"claim-{index}"}],
                    "verification": {"status": "source_supported"},
                },
            )
            for index in range(1, 3)
        ]
        with (
            patch(
                "solenne_analyzer.pipeline.llm_insights.generate_grounded_insights",
                return_value=(
                    grounded,
                    LlmDiagnostics(
                        status="complete",
                        grounding={"status": "source_supported"},
                    ),
                    "groq_grounded",
                ),
            ),
            patch(
                "solenne_analyzer.pipeline.llm_insights._generate_legacy_insights",
                return_value=(
                    narrative,
                    LlmDiagnostics(status="complete"),
                    "groq",
                ),
            ),
        ):
            insights, _, _ = generate_llm_insights(
                result,
                AnalyzerConfig(
                    enable_llm_insights=True,
                    grounding_mode="combined",
                ),
            )

        self.assertEqual(len(insights), 3)
        self.assertTrue(
            any(item.evidence.get("schemaVersion") == 2 for item in insights)
        )

    def test_long_entry_can_surface_more_than_three_distinct_cards(self):
        result = AnalysisResult(runId="run", sourceVideo="sample.mp4")
        result.transcript.wordCount = 220
        narrative_subjects = [
            ("Team collaboration", "Your reflection explored teamwork, shared decisions, and how collaboration shaped the day."),
            ("Creative confidence", "Your journal described creative experimentation, growing confidence, and ideas you want to revisit."),
            ("Rest and energy", "Your words connected sleep, physical energy, and the quieter pace you needed after finishing."),
            ("Future priorities", "Your entry considered upcoming goals, personal priorities, and the commitments you may choose next."),
        ]
        narrative = [
            AiInsight(
                title=title,
                summary=summary,
                moodLabel="reflective",
            )
            for title, summary in narrative_subjects
        ]
        grounded_subjects = [
            ("Social connection", "Your journal named friendship, conversation, and the support you noticed from people around you."),
            ("Grounding routine", "Your reflection mentioned breathing, a deliberate pause, and the steadier attention you found afterward."),
        ]
        grounded = [
            AiInsight(
                title=title,
                summary=summary,
                moodLabel="reflective",
                evidence={
                    "schemaVersion": 2,
                    "externalReferences": [{"claimCardId": f"claim-{index}"}],
                    "verification": {"status": "source_supported"},
                },
            )
            for index, (title, summary) in enumerate(grounded_subjects, start=1)
        ]
        with (
            patch(
                "solenne_analyzer.pipeline.llm_insights.generate_grounded_insights",
                return_value=(
                    grounded,
                    LlmDiagnostics(
                        status="complete",
                        grounding={"status": "source_supported"},
                    ),
                    "groq_grounded",
                ),
            ),
            patch(
                "solenne_analyzer.pipeline.llm_insights._generate_legacy_insights",
                return_value=(
                    narrative,
                    LlmDiagnostics(status="complete"),
                    "groq",
                ),
            ),
        ):
            insights, _, _ = generate_llm_insights(
                result,
                AnalyzerConfig(
                    enable_llm_insights=True,
                    grounding_mode="combined",
                ),
            )

        self.assertEqual(len(insights), 5)
        self.assertGreater(len(insights), 3)
        self.assertTrue(any(item.evidence.get("schemaVersion") == 2 for item in insights))

    def test_semantic_duplicate_merges_without_matching_title(self):
        result = AnalysisResult(runId="run", sourceVideo="sample.mp4")
        result.transcript.wordCount = 80
        narrative = AiInsight(
            title="Pride and a missed target",
            summary=(
                "Your hackathon placement brought pride while the missed first-place "
                "target left disappointment about preparation and team effort."
            ),
            moodLabel="bittersweet",
        )
        grounded = AiInsight(
            title="A complicated achievement",
            summary=(
                "Your hackathon placement brought pride, while a missed first-place "
                "target left disappointment about team preparation and effort."
            ),
            moodLabel="bittersweet",
            evidence={
                "schemaVersion": 2,
                "rationale": "Your reflection named pride and disappointment.",
                "externalReferences": [{"claimCardId": "claim-reflection"}],
                "verification": {"status": "source_supported"},
            },
        )
        with (
            patch(
                "solenne_analyzer.pipeline.llm_insights.generate_grounded_insights",
                return_value=(
                    [grounded],
                    LlmDiagnostics(
                        status="complete",
                        grounding={"status": "source_supported"},
                    ),
                    "groq_grounded",
                ),
            ),
            patch(
                "solenne_analyzer.pipeline.llm_insights._generate_legacy_insights",
                return_value=(
                    [narrative],
                    LlmDiagnostics(status="complete"),
                    "groq",
                ),
            ),
        ):
            insights, _, _ = generate_llm_insights(
                result,
                AnalyzerConfig(
                    enable_llm_insights=True,
                    grounding_mode="combined",
                ),
            )

        self.assertEqual(len(insights), 1)
        self.assertEqual(
            insights[0].evidence["verification"]["status"],
            "source_supported",
        )

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
