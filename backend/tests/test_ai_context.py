import unittest

from solenne_analyzer.ai.context_builder import (
    MAX_KEY_EXCERPTS,
    MAX_KEY_EXCERPTS_TOTAL_CHARS,
    build_insight_context,
    estimate_tokens,
    key_excerpts,
)
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
        self.assertNotIn("runId", context)
        self.assertNotIn("run-1", str(context))
        self.assertNotIn("private/path", str(context))
        self.assertEqual(context["metrics"]["fused"]["overallValence"], 0.4)
        self.assertGreater(estimate_tokens(context), 0)

    def test_short_journal_keeps_full_hackathon_reasoning(self):
        transcript = (
            "I feel happy and sad about our result. I am happy because our team "
            "placed in the hackathon, and that achievement matters to me. I am sad "
            "because we missed the first position, and I keep wondering whether "
            "more preparation and effort could have changed the outcome."
        )
        result = AnalysisResult(
            runId="journal-hackathon-regression",
            sourceVideo="journal.mp4",
        )
        result.transcript.text = transcript
        result.transcript.wordCount = len(transcript.split())

        context = build_insight_context(result)

        self.assertEqual(context["transcript"]["keyExcerpts"], [transcript])
        self.assertEqual(context["transcript"]["text"], transcript)
        excerpt_text = " ".join(context["transcript"]["keyExcerpts"])
        self.assertIn("sad because", excerpt_text)
        self.assertIn("first position", excerpt_text)
        self.assertNotIn(result.runId, str(context))

    def test_long_journal_keeps_opening_and_salient_later_sentences(self):
        filler = [
            f"Routine detail number {index} continued without anything notable."
            for index in range(1, 25)
        ]
        transcript = " ".join(
            [
                "I started by describing the morning.",
                "Then I walked through the ordinary parts of the day!",
                *filler,
                "Later I felt sad and disappointed that our team missed first place?",
                "I was still proud of the effort we put into the hackathon.",
            ]
        )

        excerpts = key_excerpts(transcript)
        excerpt_text = " ".join(excerpts)

        self.assertEqual(excerpts[0], "I started by describing the morning.")
        self.assertEqual(
            excerpts[1],
            "Then I walked through the ordinary parts of the day!",
        )
        self.assertIn("sad and disappointed", excerpt_text)
        self.assertIn("proud of the effort", excerpt_text)
        self.assertLessEqual(len(excerpts), MAX_KEY_EXCERPTS)
        self.assertLessEqual(
            sum(len(excerpt) for excerpt in excerpts),
            MAX_KEY_EXCERPTS_TOTAL_CHARS,
        )

    def test_long_journal_excerpts_cover_middle_and_end_without_salience_terms(self):
        sentences = [
            f"Section {index} described a distinct ordinary event."
            for index in range(1, 31)
        ]

        excerpts = key_excerpts(" ".join(sentences))

        self.assertIn(sentences[0], excerpts)
        self.assertIn(sentences[-1], excerpts)
        self.assertTrue(any(sentence in excerpts for sentence in sentences[10:21]))

    def test_context_omits_full_transcript_above_six_hundred_words(self):
        result = AnalysisResult(runId="long", sourceVideo="journal.mp4")
        result.transcript.text = " ".join(f"word{index}" for index in range(601))
        result.transcript.wordCount = 601

        context = build_insight_context(result)

        self.assertEqual(context["transcript"]["text"], "")
        self.assertTrue(context["transcript"]["keyExcerpts"])


if __name__ == "__main__":
    unittest.main()
