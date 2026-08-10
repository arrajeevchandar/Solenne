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

    def test_key_phrases_exclude_common_filler_words(self):
        result = analyze_text(
            "Them like going because anything have what them like going, "
            "and I don't think everything in this situation is good or right, "
            "while painting a mural made creativity memorable."
        )

        self.assertNotIn("them", result.keyPhrases)
        self.assertNotIn("like", result.keyPhrases)
        self.assertNotIn("going", result.keyPhrases)
        self.assertNotIn("because", result.keyPhrases)
        self.assertNotIn("anything", result.keyPhrases)
        self.assertNotIn("don't", result.keyPhrases)
        self.assertNotIn("everything", result.keyPhrases)
        self.assertNotIn("situation", result.keyPhrases)
        self.assertIn("painting", result.keyPhrases)


if __name__ == "__main__":
    unittest.main()
