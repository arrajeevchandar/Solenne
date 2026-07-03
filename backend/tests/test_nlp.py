import unittest

from solenne_analyzer.pipeline.nlp import analyze_text


class NlpTest(unittest.TestCase):
    def test_analyze_text_extracts_sentiment_topics_and_paraphrase(self):
        result = analyze_text(
            "I felt calm after class today. The project deadline was stressful, "
            "but walking helped me feel better."
        )

        self.assertGreater(result.confidence, 0)
        self.assertTrue(result.paraphrase.startswith("I felt calm"))
        self.assertIn("study", result.topics)
        self.assertIn("project", result.keyPhrases)
        self.assertGreater(result.stressScore, 0)

    def test_empty_text_is_safe(self):
        result = analyze_text("")

        self.assertEqual(result.confidence, 0)
        self.assertEqual(result.paraphrase, "")
        self.assertEqual(result.topics, [])


if __name__ == "__main__":
    unittest.main()
