import json
import unittest
from unittest.mock import patch

from solenne_analyzer.ai.groq_client import (
    _chat_completion,
    _response_formats,
    generate_groq_insights,
)
from solenne_analyzer.ai.prompts import build_user_prompt
from solenne_analyzer.config import AnalyzerConfig


class GroqClientTest(unittest.TestCase):
    def test_llama_uses_json_object_without_unsupported_schema_attempt(self):
        self.assertEqual(
            _response_formats("llama-3.3-70b-versatile"),
            [{"type": "json_object"}],
        )

    def test_structured_output_model_keeps_json_schema_fallback(self):
        formats = _response_formats("openai/gpt-oss-20b")

        self.assertEqual(formats[0]["type"], "json_schema")
        self.assertEqual(formats[1], {"type": "json_object"})

    def test_substantive_prompt_requests_rich_distinct_cards(self):
        prompt = build_user_prompt(_substantive_context())

        self.assertIn("Return 2 distinct insight cards", prompt)
        self.assertIn("specific 15-to-70-word summary", prompt)
        self.assertIn("at least 2 distinct concise day themes", prompt)
        self.assertIn("at least 2 gentle, practical suggestions", prompt)
        self.assertIn("at least 2 open-ended reflection questions", prompt)
        self.assertIn("evidence.reason", prompt)

    def test_short_entry_prompt_allows_one_focused_card(self):
        context = {
            "transcript": {
                "wordCount": 20,
                "paraphrase": "I felt tired after class and wanted to rest.",
                "keyExcerpts": ["I felt tired after class and wanted to rest."],
            }
        }

        prompt = build_user_prompt(context)

        self.assertIn("One focused card is acceptable", prompt)
        self.assertNotIn("Return 2 distinct insight cards", prompt)

    def test_revision_prompt_includes_quality_feedback(self):
        prompt = build_user_prompt(
            _substantive_context(),
            revision_feedback="card 1 needs two suggestions",
        )

        self.assertIn("previous response was structurally valid", prompt)
        self.assertIn("card 1 needs two suggestions", prompt)

    def test_sparse_substantive_response_gets_one_revision_retry(self):
        with patch(
            "solenne_analyzer.ai.groq_client._chat_completion",
            side_effect=[_sparse_response(), _rich_response()],
        ) as completion:
            insights, diagnostics = generate_groq_insights(
                _substantive_context(),
                _config(),
                token_estimate=300,
            )

        self.assertEqual(diagnostics.status, "complete")
        self.assertEqual(len(insights), 2)
        self.assertEqual(completion.call_count, 2)
        self.assertIsNone(
            completion.call_args_list[0].kwargs["revision_feedback"]
        )
        feedback = completion.call_args_list[1].kwargs["revision_feedback"]
        self.assertIn("summary must contain at least 15 words", feedback)
        self.assertIn("at least 2 distinct suggestions", feedback)

    def test_sparse_response_is_retried_only_once(self):
        with patch(
            "solenne_analyzer.ai.groq_client._chat_completion",
            return_value=_sparse_response(),
        ) as completion:
            insights, diagnostics = generate_groq_insights(
                _substantive_context(),
                _config(),
                token_estimate=300,
            )

        self.assertEqual(insights, [])
        self.assertEqual(diagnostics.status, "failed")
        self.assertEqual(completion.call_count, 2)
        self.assertIn("summary must contain at least 15 words", diagnostics.failureReason)

    def test_structured_model_stops_after_one_quality_revision(self):
        config = _config()
        config = AnalyzerConfig(
            enable_llm_insights=config.enable_llm_insights,
            groq_api_key=config.groq_api_key,
            groq_model="openai/gpt-oss-20b",
        )
        with patch(
            "solenne_analyzer.ai.groq_client._chat_completion",
            return_value=_sparse_response(),
        ) as completion:
            insights, diagnostics = generate_groq_insights(
                _substantive_context(),
                config,
                token_estimate=300,
            )

        self.assertEqual(insights, [])
        self.assertEqual(diagnostics.status, "failed")
        self.assertEqual(completion.call_count, 2)

    def test_structured_model_does_not_try_a_third_format_after_bad_revision(self):
        config = AnalyzerConfig(
            enable_llm_insights=True,
            groq_api_key="test-key",
            groq_model="openai/gpt-oss-20b",
        )
        with patch(
            "solenne_analyzer.ai.groq_client._chat_completion",
            side_effect=[_sparse_response(), "{not-json", _rich_response()],
        ) as completion:
            insights, diagnostics = generate_groq_insights(
                _substantive_context(),
                config,
                token_estimate=300,
            )

        self.assertEqual(insights, [])
        self.assertEqual(diagnostics.status, "failed")
        self.assertEqual(completion.call_count, 2)

    def test_low_signal_response_does_not_require_revision(self):
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
        with patch(
            "solenne_analyzer.ai.groq_client._chat_completion",
            return_value=_short_entry_response(),
        ) as completion:
            insights, diagnostics = generate_groq_insights(
                context,
                _config(),
                token_estimate=50,
            )

        self.assertEqual(diagnostics.status, "complete")
        self.assertEqual(len(insights), 1)
        completion.assert_called_once()

    def test_finish_reason_length_is_rejected(self):
        response = _FakeResponse(
            {
                "choices": [
                    {
                        "finish_reason": "length",
                        "message": {"content": _rich_response()},
                    }
                ]
            }
        )
        with patch(
            "solenne_analyzer.ai.groq_client.httpx.Client",
            return_value=_FakeClient(response),
        ):
            with self.assertRaisesRegex(ValueError, "output token limit"):
                _chat_completion(
                    _substantive_context(),
                    _config(),
                    {"type": "json_object"},
                )


class _FakeResponse:
    def __init__(self, payload: dict) -> None:
        self._payload = payload

    def raise_for_status(self) -> None:
        return None

    def json(self) -> dict:
        return self._payload


class _FakeClient:
    def __init__(self, response: _FakeResponse) -> None:
        self.response = response

    def __enter__(self):
        return self

    def __exit__(self, *_args) -> None:
        return None

    def post(self, *_args, **_kwargs) -> _FakeResponse:
        return self.response


def _config() -> AnalyzerConfig:
    return AnalyzerConfig(
        enable_llm_insights=True,
        groq_api_key="test-key",
        groq_model="llama-3.3-70b-versatile",
    )


def _substantive_context() -> dict:
    return {
        "transcript": {
            "wordCount": 78,
            "paraphrase": (
                "I felt happy about our hackathon placement but sad about missing "
                "the first position."
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


def _sparse_response() -> str:
    return json.dumps(
        {
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
                            "Your transcript mentions feeling both happy and sad, with "
                            "a relatively high overall valence and sentiment valence."
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
                            "Your transcript mentions being happy about getting placed "
                            "in a hackathon, with a high engagement metric."
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
    )


def _rich_response() -> str:
    safety_note = "Solenne offers wellness reflections, not medical advice."
    return json.dumps(
        {
            "aiInsights": [
                {
                    "title": "Pride alongside disappointment",
                    "summary": (
                        "Your hackathon placement brought genuine pride, while missing "
                        "the first-position target left disappointment about the effort "
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
                            "Your journal connected the hackathon result with happiness "
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
                        "You recognized the achievement while examining effort, "
                        "expectations, and what reaching first position represented "
                        "for you after the hackathon."
                    ),
                    "moodLabel": "reflective",
                    "dayThemes": ["learning", "expectations"],
                    "suggestions": [
                        "Separate the outcome from what you learned.",
                        "Choose one improvement that feels realistic.",
                    ],
                    "reflectionQuestions": [
                        "What did this result teach you about expectations?",
                        "Which improvement would matter most next time?",
                    ],
                    "evidence": {
                        "reason": (
                            "Your words linked the placement, the first-position goal, "
                            "and questions about how much effort was possible."
                        ),
                        "metrics": {"engagement": 0.6},
                    },
                    "confidence": 0.76,
                    "safetyNote": safety_note,
                },
            ]
        }
    )


def _short_entry_response() -> str:
    payload = json.loads(_sparse_response())
    payload["aiInsights"] = payload["aiInsights"][:1]
    return json.dumps(payload)


if __name__ == "__main__":
    unittest.main()
