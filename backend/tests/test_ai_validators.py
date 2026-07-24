import unittest

from solenne_analyzer.ai.validators import (
    parse_ai_insights_json,
    validate_ai_insight_payload,
)


class AiValidatorTest(unittest.TestCase):
    def test_validator_accepts_valid_payload(self):
        insights = validate_ai_insight_payload(
            {
                "aiInsights": [
                    {
                        "title": "Creative thread",
                        "summary": "Your reflection suggests creativity mattered today.",
                        "moodLabel": "reflective",
                        "dayThemes": ["creativity", "memory"],
                        "suggestions": ["Record one small creative moment tomorrow."],
                        "reflectionQuestions": ["What felt most alive today?"],
                        "evidence": {"overallValence": 0.2},
                        "confidence": 0.7,
                        "safetyNote": "Solenne offers wellness reflections, not medical advice.",
                    }
                ]
            }
        )

        self.assertEqual(len(insights), 1)
        self.assertEqual(insights[0].title, "Creative thread")

    def test_validator_rejects_missing_required_fields(self):
        with self.assertRaises(ValueError):
            validate_ai_insight_payload({"aiInsights": [{"title": "Incomplete", "summary": ""}]})

    def test_validator_normalizes_groq_insights_shape(self):
        insights = validate_ai_insight_payload(
            {
                "insights": [
                    {
                        "summary": "You reflected on creativity and memory.",
                        "suggestions": ["Record one small creative moment."],
                        "reflectionQuestions": ["What felt worth remembering?"],
                    }
                ]
            }
        )

        self.assertEqual(insights[0].moodLabel, "reflective")
        self.assertEqual(insights[0].safetyNote, "Solenne offers wellness reflections, not medical advice.")

    def test_validator_removes_transcript_and_internal_ids_from_evidence(self):
        insights = validate_ai_insight_payload(
            {
                "aiInsights": [
                    {
                        "summary": "A cautious reflection based on this entry.",
                        "evidence": {
                            "reason": "The language tone leaned more positive.",
                            "transcript": "Do not repeat the full journal here.",
                            "runId": "internal-run",
                            "journal_id": "internal-journal",
                            "metrics": {"overallValence": 0.5},
                        },
                    }
                ]
            }
        )

        self.assertEqual(
            insights[0].evidence,
            {
                "reason": "The language tone leaned more positive.",
                "metrics": {"overallValence": 0.5},
            },
        )

    def test_validator_rejects_blocked_clinical_language(self):
        payload = {
            "aiInsights": [
                {
                    "title": "Clinical conclusion",
                    "summary": "You have depression.",
                    "moodLabel": "low",
                    "dayThemes": [],
                    "suggestions": [],
                    "reflectionQuestions": [],
                    "evidence": {},
                    "confidence": 0.5,
                    "safetyNote": "",
                }
            ]
        }
        with self.assertRaises(ValueError):
            validate_ai_insight_payload(payload)

    def test_parse_json(self):
        insights = parse_ai_insights_json(
            '{"aiInsights":[{"title":"A","summary":"B","moodLabel":"C",'
            '"dayThemes":[],"suggestions":[],"reflectionQuestions":[],'
            '"evidence":{},"confidence":0.4,"safetyNote":"D"}]}'
        )

        self.assertEqual(insights[0].summary, "B")


if __name__ == "__main__":
    unittest.main()
