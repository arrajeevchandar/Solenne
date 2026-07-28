import unittest

from solenne_analyzer.ai.validators import (
    InsightQualityError,
    crisis_language_present,
    parse_ai_insights_json,
    validate_ai_insight_payload,
    validate_ai_insight_quality,
)


class AiValidatorTest(unittest.TestCase):
    def test_crisis_detector_ignores_benign_technical_and_travel_phrases(self):
        benign = [
            "The build is not safe to deploy.",
            "I can't go on with this testing approach.",
            "I cannot go on holiday until the release is finished.",
        ]

        self.assertTrue(all(not crisis_language_present(item) for item in benign))

    def test_crisis_detector_keeps_immediate_first_person_phrases(self):
        crisis = [
            "I am not safe right now.",
            "I can't go on anymore.",
            "I might hurt myself.",
        ]

        self.assertTrue(all(crisis_language_present(item) for item in crisis))

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

    def test_quality_validator_accepts_rich_distinct_cards(self):
        insights = validate_ai_insight_payload(_rich_payload())

        validate_ai_insight_quality(insights, _substantive_context())

    def test_quality_validator_rejects_sparse_substantive_cards(self):
        insights = validate_ai_insight_payload(_saved_sparse_payload())

        with self.assertRaises(InsightQualityError) as raised:
            validate_ai_insight_quality(insights, _substantive_context())

        self.assertIn("summary must contain at least 15 words", str(raised.exception))
        self.assertIn("at least 2 distinct day themes", str(raised.exception))
        self.assertIn("at least 2 distinct suggestions", str(raised.exception))
        self.assertIn(
            "at least 2 distinct reflection questions",
            str(raised.exception),
        )

    def test_quality_validator_rejects_repeated_cards(self):
        payload = _rich_payload()
        payload["aiInsights"][1]["title"] = payload["aiInsights"][0]["title"]
        payload["aiInsights"][1]["summary"] = payload["aiInsights"][0]["summary"]
        insights = validate_ai_insight_payload(payload)

        with self.assertRaises(InsightQualityError) as raised:
            validate_ai_insight_quality(insights, _substantive_context())

        self.assertIn("repeats another card title", str(raised.exception))
        self.assertIn("repeats another card summary", str(raised.exception))

    def test_quality_validator_rejects_inferred_mindset_reasoning(self):
        payload = _rich_payload()
        payload["aiInsights"][1]["evidence"]["reason"] = (
            "Your speech patterns indicate a reflective and analytical mindset "
            "focused on learning from the experience."
        )
        with self.assertRaises(ValueError) as raised:
            validate_ai_insight_payload(payload)

        self.assertIn(
            "must not infer a personality or mindset",
            str(raised.exception),
        )

    def test_quality_validator_allows_sparse_low_signal_card(self):
        insights = validate_ai_insight_payload(
            {"aiInsights": [{"summary": "A brief reflection was captured."}]}
        )
        context = {
            "transcript": {
                "wordCount": 20,
                "paraphrase": (
                    "I felt tired after class and wanted to capture that before resting."
                ),
                "keyExcerpts": [
                    "I felt tired after class and wanted to capture that before resting."
                ],
            }
        }

        validate_ai_insight_quality(insights, context)

    def test_quality_validator_allows_sparse_low_confidence_card(self):
        insights = validate_ai_insight_payload(
            {"aiInsights": [{"summary": "A cautious reflection was captured."}]}
        )
        context = _substantive_context()
        context["transcript"]["confidence"] = 0.2

        validate_ai_insight_quality(insights, context)

    def test_quality_validator_uses_visible_narrative_not_original_length(self):
        insights = validate_ai_insight_payload(
            {"aiInsights": [{"summary": "A brief visible reflection was captured."}]}
        )
        context = {
            "transcript": {
                "wordCount": 120,
                "paraphrase": "The opening described an ordinary morning.",
                "keyExcerpts": ["The opening described an ordinary morning."],
                "confidence": 0.9,
            },
            "metrics": {"text": {"confidence": 0.9}},
        }

        validate_ai_insight_quality(insights, context)

    def test_quality_validator_allows_sparse_safety_card(self):
        insights = validate_ai_insight_payload(
            {
                "aiInsights": [
                    {
                        "summary": "Please reach out to someone you trust right now.",
                        "safetyNote": "Seek immediate local support.",
                    }
                ]
            }
        )
        context = {
            "transcript": {
                "wordCount": 30,
                "paraphrase": "I want to die and do not feel safe.",
                "keyExcerpts": ["I want to die and do not feel safe."],
            }
        }

        validate_ai_insight_quality(insights, context)

def _substantive_context() -> dict:
    return {
        "transcript": {
            "wordCount": 78,
            "paraphrase": (
                "You felt happy about the hackathon placement and sad about missing "
                "the first-place target."
            ),
            "keyExcerpts": [
                (
                    "Our team placed in the hackathon, which made me happy and proud "
                    "of the result. I also felt sad about missing the first-position "
                    "target, and I kept thinking about whether more preparation and "
                    "effort could have changed the outcome for us."
                ),
            ],
        },
        "metrics": {
            "text": {
                "topics": ["achievement", "mixed emotions"],
                "keyPhrases": ["hackathon", "happy", "sad", "effort"],
            }
        },
        "templateInsights": [],
    }


def _rich_payload() -> dict:
    safety_note = "Solenne offers wellness reflections, not medical advice."
    return {
        "aiInsights": [
            {
                "title": "Pride alongside disappointment",
                "summary": (
                    "Your hackathon placement brought genuine pride, while missing the "
                    "first-place target left room for disappointment about the effort "
                    "your team invested."
                ),
                "moodLabel": "bittersweet",
                "dayThemes": ["achievement", "mixed emotions"],
                "suggestions": [
                    "Write down what your team did well.",
                    "Name one lesson you want to carry forward.",
                ],
                "reflectionQuestions": [
                    "Which part of the placement feels most meaningful?",
                    "What would enough effort look like next time?",
                ],
                "evidence": {
                    "reason": (
                        "Your journal connected the hackathon result with both happiness "
                        "and disappointment about the target."
                    ),
                    "metrics": {"sentimentValence": 0.2},
                },
                "confidence": 0.8,
                "safetyNote": safety_note,
            },
            {
                "title": "A learning thread in the result",
                "summary": (
                    "You recognized the achievement while also looking closely at effort, "
                    "expectations, and what reaching first position represented for you "
                    "after the hackathon."
                ),
                "moodLabel": "reflective",
                "dayThemes": ["learning", "expectations"],
                "suggestions": [
                    "Separate the outcome from what you learned.",
                    "Choose one improvement that feels realistic.",
                ],
                "reflectionQuestions": [
                    "What did this result teach you about your expectations?",
                    "Which improvement would matter most at another hackathon?",
                ],
                "evidence": {
                    "reason": (
                        "Your words linked the placement, the first-position goal, and "
                        "questions about how much effort was possible."
                    ),
                    "metrics": {"engagement": 0.6},
                },
                "confidence": 0.76,
                "safetyNote": safety_note,
            },
        ]
    }


def _saved_sparse_payload() -> dict:
    return {
        "aiInsights": [
            {
                "title": "Mixed Emotions",
                "summary": "You're feeling both happy and sad.",
                "moodLabel": "Bittersweet",
                "dayThemes": ["Emotional Balance"],
                "suggestions": ["Practice self-care"],
                "reflectionQuestions": ["What's causing your sadness?"],
                "evidence": {
                    "reason": (
                        "Your transcript mentions feeling both happy and sad, with a "
                        "relatively high overall valence and sentiment valence."
                    ),
                    "metrics": {
                        "overallValence": 0.16,
                        "sentimentValence": 0.2,
                    },
                },
                "confidence": 0.8,
                "safetyNote": (
                    "Remember, it's okay to feel multiple emotions at once."
                ),
            },
            {
                "title": "Recent Success",
                "summary": "You're happy about a recent achievement.",
                "moodLabel": "Proud",
                "dayThemes": ["Achievement"],
                "suggestions": ["Celebrate your win"],
                "reflectionQuestions": ["What did you learn?"],
                "evidence": {
                    "reason": (
                        "Your transcript mentions being happy about getting placed in "
                        "a hackathon, with a high engagement metric."
                    ),
                    "metrics": {"engagement": 0.61},
                },
                "confidence": 0.7,
                "safetyNote": (
                    "Solenne offers wellness reflections, not medical advice."
                ),
            },
        ]
    }


if __name__ == "__main__":
    unittest.main()
