from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from solenne_analyzer.ai.validators import crisis_language_present
from solenne_analyzer.config import AnalyzerConfig
from solenne_analyzer.grounding.assembler import assemble_insights
from solenne_analyzer.grounding.catalog import (
    catalog_report,
    load_catalog,
    validate_catalog_file,
)
from solenne_analyzer.grounding.models import GroundedInsightDraft
from solenne_analyzer.grounding.generator import (
    _response_formats,
    build_grounding_context,
)
from solenne_analyzer.grounding.observations import (
    build_journal_narrative,
    build_observation_facts,
)
from solenne_analyzer.grounding.retriever import retrieve_claims
from solenne_analyzer.grounding.runtime import generate_grounded_insights
from solenne_analyzer.grounding.validators import (
    parse_grounded_drafts_json,
    validate_assembled_insights,
    validate_draft_references,
)
from solenne_analyzer.main import build_parser
from solenne_analyzer.schemas import AnalysisResult, LlmDiagnostics


FIXTURES = Path(__file__).parent / "fixtures"


class CatalogTests(unittest.TestCase):
    def test_repository_catalog_is_valid_and_runtime_eligible(self):
        path = (
            Path(__file__).parents[1]
            / "solenne_analyzer"
            / "grounding"
            / "catalog.json"
        )
        self.assertEqual(validate_catalog_file(path), [])
        report = catalog_report(load_catalog(path))
        self.assertGreaterEqual(report["sources"], 20)
        self.assertLessEqual(report["sources"], 30)
        self.assertGreaterEqual(report["eligibleClaimCards"], 1)
        self.assertGreaterEqual(report["eligibleSuggestions"], 1)

    def test_catalog_rejects_duplicate_ids_and_single_reviewer_approval(self):
        payload = _catalog_payload()
        payload["sources"].append(dict(payload["sources"][0]))
        payload["claimCards"][0].update(
            {
                "status": "approved",
                "active": True,
                "approvals": [
                    {"reviewerId": "reviewer-a", "reviewedAt": "2026-07-17"}
                ],
            }
        )
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "catalog.json"
            path.write_text(json.dumps(payload), encoding="utf-8")
            errors = validate_catalog_file(path)
        self.assertTrue(any("Duplicate sourceId" in item for item in errors))
        self.assertTrue(any("two distinct reviewers" in item for item in errors))

    def test_catalog_rejects_non_https_and_copied_abstract(self):
        payload = _catalog_payload()
        payload["sources"][0]["url"] = "http://example.com/source"
        payload["sources"][0]["abstract"] = "Copied source content"
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "catalog.json"
            path.write_text(json.dumps(payload), encoding="utf-8")
            errors = validate_catalog_file(path)
        self.assertTrue(any("HTTPS" in item for item in errors))
        self.assertTrue(any("copied source content" in item for item in errors))

    def test_llama_models_only_request_json_object_format(self):
        # Groq Llama models reject json_schema (HTTP 400); we must not send it to them.
        formats = _response_formats("llama-3.3-70b-versatile")
        self.assertEqual([item["type"] for item in formats], ["json_object"])

    def test_structured_output_models_still_offer_json_schema(self):
        formats = _response_formats("openai/gpt-oss-20b")
        self.assertEqual(
            [item["type"] for item in formats], ["json_schema", "json_object"]
        )

    def test_cli_exposes_catalog_and_selected_reprocess_commands(self):
        parser = build_parser()
        catalog_args = parser.parse_args(["catalog", "validate"])
        reprocess_args = parser.parse_args(
            [
                "reprocess",
                "--user-id",
                "user-1",
                "--journal-id",
                "journal-1",
            ]
        )
        self.assertEqual(catalog_args.catalog_command, "validate")
        self.assertEqual(reprocess_args.user_id, "user-1")
        self.assertEqual(reprocess_args.journal_id, "journal-1")


class ObservationAndAssemblyTests(unittest.TestCase):
    def test_observations_use_transcript_fields_only_for_claim_matching(self):
        result = _analysis_result(topics=["work"], phrases=["deadline"])
        result.voice.energyMean = 999
        result.facial.valence = -1
        result.fused.overallValence = -1
        result.nlp.stressScore = 1

        facts = build_observation_facts(result, min_confidence=0.45)

        self.assertTrue(any(item.claimTypes for item in facts))
        self.assertTrue(
            all(
                item.sourcePath
                in {
                    "nlp.topics",
                    "nlp.keyPhrases",
                    "transcript.wordCount",
                    "transcript.confidence",
                    "transcript.text",
                    "durationSeconds",
                }
                for item in facts
            )
        )

    def test_emotion_cluster_routes_to_reflective_journaling(self):
        result = _analysis_result(topics=["hackathon"], phrases=[])
        result.transcript.text = (
            "I'm feeling happy and I'm feeling sad about the hackathon result."
        )
        result.nlp.paraphrase = "I feel happy and sad about the hackathon."

        facts = build_observation_facts(result, min_confidence=0.45)
        reflective = [
            item for item in facts if "reflective_journaling" in item.claimTypes
        ]
        self.assertTrue(reflective)
        self.assertEqual(
            {str(item.value) for item in reflective}, {"happy", "sad"}
        )

    def test_single_emotion_word_does_not_route_to_reflective_journaling(self):
        result = _analysis_result(topics=["work"], phrases=["deadline"])
        result.transcript.text = "I felt happy that I finished the work deadline."
        result.nlp.paraphrase = "I finished a work deadline."

        facts = build_observation_facts(result, min_confidence=0.45)
        self.assertFalse(
            any("reflective_journaling" in item.claimTypes for item in facts)
        )

    def test_retriever_prefers_stronger_signal_type(self):
        with tempfile.TemporaryDirectory() as temp:
            catalog = load_catalog(
                _write_catalog(Path(temp), _catalog_payload_all_types())
            )
        result = _analysis_result(topics=["hackathon"], phrases=[])
        result.transcript.text = (
            "I'm feeling happy, sad, and proud but also disappointed about the hackathon."
        )
        result.nlp.paraphrase = "Mixed happy, sad, proud, disappointed feelings."
        facts = build_observation_facts(result, min_confidence=0.45)
        claims = retrieve_claims(facts, catalog, limit=1)
        self.assertEqual(claims[0].claimType, "reflective_journaling")

    def test_low_transcript_confidence_cannot_trigger_claims(self):
        result = _analysis_result(topics=["work"], phrases=["deadline"])
        result.transcript.confidence = 0.2
        facts = build_observation_facts(result, min_confidence=0.45)
        self.assertFalse(any(item.claimTypes for item in facts))

    def test_grounding_context_includes_journal_narrative_and_claims(self):
        with tempfile.TemporaryDirectory() as temp:
            path = _write_catalog(Path(temp), _catalog_payload())
            catalog = load_catalog(path)
        result = _analysis_result(topics=["work"], phrases=["deadline"])
        result.nlp.paraphrase = "I talked about a deadline at work and feeling tired."
        result.transcript.text = (
            "Today was busy. I had a deadline at work and felt tired after staying up late."
        )
        facts = build_observation_facts(result, min_confidence=0.45)
        claims = retrieve_claims(facts, catalog)
        context = build_grounding_context(
            facts,
            claims,
            build_journal_narrative(result),
        )
        self.assertIn("deadline", context["journalNarrative"]["paraphrase"])
        self.assertTrue(context["journalNarrative"]["keyExcerpts"])
        self.assertEqual(context["journalNarrative"]["topics"], ["work"])
        self.assertTrue(context["availableClaimCards"])
        self.assertIn("displayClaim", context["availableClaimCards"][0])
        self.assertTrue(
            any(
                item.kind == "key_phrase" and item.value == "tired"
                for item in facts
            )
        )

    def test_server_injects_exact_claim_and_approved_suggestion(self):
        with tempfile.TemporaryDirectory() as temp:
            path = _write_catalog(Path(temp), _catalog_payload())
            catalog = load_catalog(path)
        result = _analysis_result(topics=["work"], phrases=["deadline"])
        facts = build_observation_facts(result, min_confidence=0.45)
        claims = retrieve_claims(facts, catalog)
        draft = GroundedInsightDraft(
            title="A demanding task",
            summary="Work and a deadline were present in this reflection.",
            moodLabel="reflective",
            dayThemes=("work",),
            reflectionQuestions=("What part of the task needs the clearest boundary?",),
            observationFactIds=(
                next(item.evidenceId for item in facts if item.kind == "topic"),
            ),
            claimCardIds=(claims[0].claimCardId,),
            suggestionIds=("suggest_break",),
            confidence=0.8,
            safetyNote="Solenne offers wellness reflections, not medical advice.",
        )
        validate_draft_references([draft], facts, claims, catalog)
        insights = assemble_insights([draft], facts, claims, catalog)
        validate_assembled_insights(insights, facts, catalog)
        reference = insights[0].evidence["externalReferences"][0]
        self.assertEqual(reference["matchedClaim"], catalog.claimCards[0].displayClaim)
        self.assertEqual(insights[0].suggestions, ["Take one short pause away from the task."])


class GroundingRuntimeTests(unittest.TestCase):
    def test_enforce_runtime_generates_source_supported_evidence(self):
        with tempfile.TemporaryDirectory() as temp:
            path = _write_catalog(Path(temp), _catalog_payload())
            config = AnalyzerConfig(
                enable_llm_insights=True,
                groq_api_key="test-key",
                grounding_mode="enforce",
                grounding_catalog_path=path,
            )
            calls = []

            def fake_generate(facts, claims, _config, revision_feedback=None, **_kwargs):
                calls.append(revision_feedback)
                return [
                    GroundedInsightDraft(
                        title="Work was present",
                        summary="Work and a deadline were present in this reflection.",
                        moodLabel="reflective",
                        dayThemes=("work",),
                        reflectionQuestions=("What deserves a clear stopping point?",),
                        observationFactIds=(
                            next(item.evidenceId for item in facts if item.kind == "topic"),
                        ),
                        claimCardIds=(claims[0].claimCardId,),
                        suggestionIds=("suggest_break",),
                        confidence=0.8,
                        safetyNote="Solenne offers wellness reflections, not medical advice.",
                    )
                ], LlmDiagnostics(status="complete", provider="groq", model="test")

            with patch(
                "solenne_analyzer.grounding.runtime.generate_grounded_drafts",
                fake_generate,
            ):
                insights, diagnostics, provider = generate_grounded_insights(
                    _analysis_result(topics=["work"], phrases=["deadline"]),
                    config,
                )
        self.assertEqual(provider, "groq_grounded")
        self.assertEqual(diagnostics.grounding["status"], "source_supported")
        self.assertEqual(
            insights[0].evidence["verification"]["status"], "source_supported"
        )
        self.assertEqual(calls, [None])

    def test_validation_failure_retries_once_then_falls_back(self):
        with tempfile.TemporaryDirectory() as temp:
            path = _write_catalog(Path(temp), _catalog_payload())
            config = AnalyzerConfig(
                enable_llm_insights=True,
                groq_api_key="test-key",
                grounding_mode="enforce",
                grounding_catalog_path=path,
            )
            calls = 0

            def fake_generate(*_args, **_kwargs):
                nonlocal calls
                calls += 1
                return [
                    GroundedInsightDraft(
                        title="Unsupported",
                        summary="You have depression after this deadline.",
                        moodLabel="reflective",
                        observationFactIds=(
                            next(
                                item.evidenceId
                                for item in build_observation_facts(
                                    _analysis_result(topics=["work"], phrases=["deadline"]),
                                    min_confidence=0.45,
                                )
                                if item.kind == "topic"
                            ),
                        ),
                        confidence=0.5,
                        safetyNote="Solenne offers wellness reflections, not medical advice.",
                    )
                ], LlmDiagnostics(status="complete", provider="groq", model="test")

            with patch(
                "solenne_analyzer.grounding.runtime.generate_grounded_drafts",
                fake_generate,
            ):
                insights, diagnostics, provider = generate_grounded_insights(
                    _analysis_result(topics=["work"], phrases=["deadline"]),
                    config,
                )
        # The LLM ran but produced only invalid drafts. Because a curated claim still
        # matched the transcript, the deterministic grounded fallback assembles a
        # source-supported card rather than dropping the evidence entirely.
        self.assertEqual(calls, 2)
        self.assertEqual(provider, "grounded_template")
        self.assertEqual(diagnostics.grounding["status"], "source_supported")
        self.assertEqual(
            insights[0].evidence["verification"]["status"], "source_supported"
        )
        self.assertTrue(insights[0].evidence["externalReferences"])

    def test_deterministic_fallback_keeps_sources_when_llm_returns_empty(self):
        with tempfile.TemporaryDirectory() as temp:
            path = _write_catalog(Path(temp), _catalog_payload())
            config = AnalyzerConfig(
                enable_llm_insights=True,
                groq_api_key="test-key",
                grounding_mode="enforce",
                grounding_catalog_path=path,
            )

            def fake_generate(*_args, **_kwargs):
                # Groq reachable but returns no usable drafts (small-model failure).
                return [], LlmDiagnostics(
                    status="failed",
                    provider="groq",
                    model="test",
                    failureReason="drafts[0].summary must be a non-empty string.",
                )

            with patch(
                "solenne_analyzer.grounding.runtime.generate_grounded_drafts",
                fake_generate,
            ):
                insights, diagnostics, provider = generate_grounded_insights(
                    _analysis_result(topics=["work"], phrases=["deadline"]),
                    config,
                )
        self.assertEqual(provider, "grounded_template")
        self.assertEqual(diagnostics.grounding["status"], "source_supported")
        reference = insights[0].evidence["externalReferences"][0]
        self.assertEqual(reference["sourceId"], "source-work")
        self.assertEqual(
            insights[0].evidence["verification"]["method"], "curated_claim_match"
        )

    def test_crisis_language_bypasses_generator(self):
        config = AnalyzerConfig(
            enable_llm_insights=True,
            groq_api_key="test-key",
            grounding_mode="enforce",
        )
        result = _analysis_result(topics=["work"], phrases=["deadline"])
        result.transcript.text = "I want to hurt myself."
        with patch(
            "solenne_analyzer.grounding.runtime.generate_grounded_drafts"
        ) as generate:
            insights, diagnostics, provider = generate_grounded_insights(result, config)
        generate.assert_not_called()
        self.assertEqual(provider, "safety")
        self.assertEqual(diagnostics.grounding["reason"], "safety_bypass")
        self.assertEqual(insights[0].suggestions, [])

    def test_missing_catalog_returns_safe_fallback_without_failing_analysis(self):
        config = AnalyzerConfig(
            enable_llm_insights=True,
            groq_api_key="test-key",
            grounding_mode="enforce",
            grounding_catalog_path=Path("/definitely/missing/catalog.json"),
        )
        insights, diagnostics, provider = generate_grounded_insights(
            _analysis_result(topics=["work"], phrases=["deadline"]),
            config,
        )
        self.assertEqual(provider, "grounded_template")
        self.assertEqual(diagnostics.grounding["reason"], "catalog_unavailable")
        self.assertEqual(insights[0].evidence["externalReferences"], [])

    def test_missing_groq_key_returns_user_evidence_without_fake_citation(self):
        with tempfile.TemporaryDirectory() as temp:
            path = _write_catalog(Path(temp), _catalog_payload())
            config = AnalyzerConfig(
                enable_llm_insights=True,
                groq_api_key=None,
                grounding_mode="enforce",
                grounding_catalog_path=path,
            )
            insights, diagnostics, provider = generate_grounded_insights(
                _analysis_result(topics=["work"], phrases=["deadline"]),
                config,
            )
        self.assertEqual(provider, "grounded_template")
        self.assertEqual(diagnostics.grounding["reason"], "llm_unavailable")
        self.assertEqual(insights[0].evidence["externalReferences"], [])


class GoldenEvaluationTests(unittest.TestCase):
    def test_thirty_deterministic_grounding_cases(self):
        cases = json.loads(
            (FIXTURES / "grounding_golden_cases.json").read_text(encoding="utf-8")
        )
        self.assertEqual(len(cases), 30)
        with tempfile.TemporaryDirectory() as temp:
            catalog = load_catalog(_write_catalog(Path(temp), _catalog_payload_all_types()))
            for case in cases:
                with self.subTest(case=case["id"]):
                    if case["category"] == "blocked_language":
                        payload = _draft_json(case["summary"])
                        with self.assertRaises(ValueError):
                            parse_grounded_drafts_json(json.dumps(payload))
                        continue
                    if case["category"] == "safety":
                        self.assertTrue(crisis_language_present(case["text"]))
                        continue
                    result = _analysis_result(
                        topics=case["topics"], phrases=case["keyPhrases"]
                    )
                    result.transcript.text = case["text"]
                    result.transcript.confidence = case["transcriptConfidence"]
                    facts = build_observation_facts(result, min_confidence=0.45)
                    claims = retrieve_claims(facts, catalog)
                    if case["category"] == "source_supported":
                        self.assertTrue(claims)
                    else:
                        self.assertEqual(claims, [])


def _analysis_result(*, topics: list[str], phrases: list[str]) -> AnalysisResult:
    result = AnalysisResult(runId="journal-1", sourceVideo="journal.mp4")
    result.durationSeconds = 90
    result.transcript.text = (
        "Today I reflected on work and a deadline, and I tried to name what mattered."
    )
    result.transcript.wordCount = 14
    result.transcript.confidence = 0.9
    result.nlp.topics = topics
    result.nlp.keyPhrases = phrases
    result.nlp.confidence = 0.9
    return result


def _catalog_payload() -> dict:
    approvals = [
        {"reviewerId": "reviewer-a", "reviewedAt": "2026-07-16"},
        {"reviewerId": "reviewer-b", "reviewedAt": "2026-07-17"},
    ]
    return {
        "catalogVersion": "test-v1",
        "sources": [
            {
                "sourceId": "source-work",
                "title": "Reviewed work-break source",
                "publisher": "Test publisher",
                "year": 2024,
                "url": "https://example.org/work-breaks",
                "doi": None,
                "pmid": None,
                "licenseUsageNote": "Test metadata only.",
            }
        ],
        "suggestions": [
            {
                "suggestionId": "suggest_break",
                "text": "Take one short pause away from the task.",
                "tags": ["work"],
                "status": "approved",
                "approvals": approvals,
                "active": True,
            }
        ],
        "claimCards": [
            {
                "claimCardId": "claim-work",
                "sourceId": "source-work",
                "claimType": "workload_breaks",
                "displayClaim": "Work-break research studies brief pauses and recovery.",
                "limitations": "General context only; effects vary by person and task.",
                "tags": ["work", "study"],
                "supportLevel": "moderate",
                "allowedSuggestionIds": ["suggest_break"],
                "status": "approved",
                "approvals": approvals,
                "active": True,
            }
        ],
    }


def _catalog_payload_all_types() -> dict:
    payload = _catalog_payload()
    approvals = payload["claimCards"][0]["approvals"]
    types = [
        "reflective_journaling",
        "rest_routines",
        "workload_breaks",
        "social_connection",
        "grounding_routines",
    ]
    payload["sources"] = []
    payload["claimCards"] = []
    for claim_type in types:
        payload["sources"].append(
            {
                "sourceId": f"source-{claim_type}",
                "title": f"Source for {claim_type}",
                "publisher": "Test publisher",
                "year": 2024,
                "url": f"https://example.org/{claim_type}",
                "doi": None,
                "pmid": None,
                "licenseUsageNote": "Test metadata only.",
            }
        )
        payload["claimCards"].append(
            {
                "claimCardId": f"claim-{claim_type}",
                "sourceId": f"source-{claim_type}",
                "claimType": claim_type,
                "displayClaim": f"Reviewed context for {claim_type}.",
                "limitations": "General context only.",
                "tags": [claim_type],
                "supportLevel": "moderate",
                "allowedSuggestionIds": ["suggest_break"],
                "status": "approved",
                "approvals": approvals,
                "active": True,
            }
        )
    return payload


def _write_catalog(directory: Path, payload: dict) -> Path:
    path = directory / "catalog.json"
    path.write_text(json.dumps(payload), encoding="utf-8")
    return path


def _draft_json(summary: str) -> dict:
    return {
        "drafts": [
            {
                "title": "Reflection",
                "summary": summary,
                "moodLabel": "reflective",
                "dayThemes": [],
                "reflectionQuestions": [],
                "observationFactIds": ["fact-1"],
                "claimCardIds": [],
                "suggestionIds": [],
                "confidence": 0.5,
                "safetyNote": "Solenne offers wellness reflections, not medical advice.",
            }
        ]
    }


if __name__ == "__main__":
    unittest.main()
