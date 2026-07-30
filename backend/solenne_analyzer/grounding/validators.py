from __future__ import annotations

import json
import re
from typing import Any

from ..schemas import AiInsight, clamp
from .models import ClaimCard, GroundedInsightDraft, GroundingCatalog, ObservationFact


BLOCKED_PERSONAL_PHRASES = {
    "you have depression",
    "you are depressed",
    "you have anxiety",
    "you are anxious",
    "you are stressed",
    "indicates depression",
    "indicates anxiety",
    "indicates stress",
    "clinical",
    "diagnosis",
    "diagnose",
    "disorder",
    "treatment",
    "prescribe",
    "medication",
    "pathology",
    "caused by",
    "because of your",
    "means that you",
    "than usual",
    "your baseline",
    "compared with your",
    "compared to your",
    "over the last week",
    "this week your",
    "analytical mindset",
    "reflective mindset",
    "your mindset",
    "your personality",
    "personality trait",
    "hidden intention",
}
BLOCKED_RESEARCH_PHRASES = {
    "research shows",
    "research suggests",
    "studies show",
    "studies suggest",
    "evidence shows",
    "evidence suggests",
    "according to research",
    "scientifically proven",
}
ALLOWED_EVIDENCE_PATHS = {
    "nlp.topics",
    "nlp.keyPhrases",
    "transcript.wordCount",
    "transcript.confidence",
    "transcript.text",
    "durationSeconds",
}
MIN_SUBSTANTIVE_NARRATIVE_WORDS = 30
MIN_DETAILED_SUMMARY_WORDS = 35
MAX_DETAILED_SUMMARY_WORDS = 75
MAX_GROUNDED_DRAFTS = 5
THIRD_PERSON_SUBJECT_PHRASES = {
    "a student",
    "the student",
    "the user",
    "the speaker",
    "the person",
    "the journal owner",
}
NARRATIVE_STOP_WORDS = {
    "about",
    "after",
    "again",
    "also",
    "because",
    "could",
    "feel",
    "feeling",
    "felt",
    "from",
    "have",
    "journal",
    "reflection",
    "that",
    "there",
    "this",
    "today",
    "what",
    "when",
    "with",
    "would",
    "your",
    "youre",
}


def parse_grounded_drafts_json(content: str) -> list[GroundedInsightDraft]:
    payload = json.loads(content)
    raw_items = payload.get("drafts") if isinstance(payload, dict) else None
    if not isinstance(raw_items, list) or not raw_items:
        raise ValueError("Grounded response must include a non-empty drafts list.")
    drafts: list[GroundedInsightDraft] = []
    for index, item in enumerate(raw_items[:MAX_GROUNDED_DRAFTS]):
        if not isinstance(item, dict):
            raise ValueError(f"drafts[{index}] must be an object.")
        summary = _text(item.get("summary"), f"drafts[{index}].summary", 600)
        draft = GroundedInsightDraft(
            title=_text(item.get("title"), f"drafts[{index}].title", 80),
            summary=summary,
            moodLabel=_text(item.get("moodLabel"), f"drafts[{index}].moodLabel", 48),
            dayThemes=tuple(_text_list(item.get("dayThemes"), 5, 48)),
            reflectionQuestions=tuple(
                _text_list(item.get("reflectionQuestions"), 4, 140)
            ),
            observationFactIds=tuple(
                _id_list(item.get("observationFactIds"), "observationFactIds")
            ),
            claimCardIds=tuple(_id_list(item.get("claimCardIds"), "claimCardIds")),
            suggestionIds=tuple(_id_list(item.get("suggestionIds"), "suggestionIds")),
            confidence=clamp(float(item.get("confidence", 0.0)), 0.0, 1.0),
            safetyNote=_text(item.get("safetyNote"), f"drafts[{index}].safetyNote", 260),
        )
        _reject_language(draft)
        drafts.append(draft)
    return drafts


def sanitize_draft_references(
    drafts: list[GroundedInsightDraft],
    facts: list[ObservationFact],
    retrieved_claims: list[ClaimCard],
    catalog: GroundingCatalog,
) -> list[GroundedInsightDraft]:
    """Drop invalid IDs and repair claim/fact links instead of failing the whole run."""
    fact_ids = {item.evidenceId for item in facts}
    fact_by_id = {item.evidenceId: item for item in facts}
    claim_by_id = {item.claimCardId: item for item in retrieved_claims}
    cleaned: list[GroundedInsightDraft] = []
    for draft in drafts:
        observation_ids = [item for item in draft.observationFactIds if item in fact_ids]
        claim_ids: list[str] = []
        for claim_id in draft.claimCardIds:
            claim = claim_by_id.get(claim_id)
            if claim is None:
                continue
            selected_facts = [fact_by_id[item] for item in observation_ids]
            if any(claim.claimType in fact.claimTypes for fact in selected_facts):
                claim_ids.append(claim_id)
                continue
            match = next(
                (fact for fact in facts if claim.claimType in fact.claimTypes),
                None,
            )
            if match is None:
                continue
            if match.evidenceId not in observation_ids:
                observation_ids.append(match.evidenceId)
            claim_ids.append(claim_id)

        if not observation_ids:
            fallback = next(
                (fact for fact in facts if fact.kind in {"topic", "key_phrase"}),
                facts[0] if facts else None,
            )
            if fallback is None:
                raise ValueError("Cannot sanitize drafts without observation facts.")
            observation_ids = [fallback.evidenceId]

        allowed_suggestions = {
            suggestion_id
            for claim_id in claim_ids
            for suggestion_id in claim_by_id[claim_id].allowedSuggestionIds
            if (
                (suggestion := catalog.suggestion_by_id.get(suggestion_id)) is not None
                and suggestion.runtime_eligible
            )
        }
        suggestion_ids = [
            item for item in draft.suggestionIds if item in allowed_suggestions
        ]
        cleaned.append(
            GroundedInsightDraft(
                title=draft.title,
                summary=draft.summary,
                moodLabel=draft.moodLabel,
                dayThemes=draft.dayThemes,
                reflectionQuestions=draft.reflectionQuestions,
                observationFactIds=tuple(dict.fromkeys(observation_ids)),
                claimCardIds=tuple(dict.fromkeys(claim_ids)),
                suggestionIds=tuple(dict.fromkeys(suggestion_ids)),
                confidence=draft.confidence,
                safetyNote=draft.safetyNote,
            )
        )
    return cleaned


def validate_draft_references(
    drafts: list[GroundedInsightDraft],
    facts: list[ObservationFact],
    retrieved_claims: list[ClaimCard],
    catalog: GroundingCatalog,
) -> None:
    fact_ids = {item.evidenceId for item in facts}
    claim_ids = {item.claimCardId for item in retrieved_claims}
    eligible_suggestions = {
        suggestion_id
        for claim in retrieved_claims
        for suggestion_id in claim.allowedSuggestionIds
        if (
            (suggestion := catalog.suggestion_by_id.get(suggestion_id)) is not None
            and suggestion.runtime_eligible
        )
    }
    for index, draft in enumerate(drafts):
        if not draft.observationFactIds:
            raise ValueError(f"drafts[{index}] must reference at least one observation fact.")
        unknown_facts = set(draft.observationFactIds) - fact_ids
        if unknown_facts:
            raise ValueError(f"drafts[{index}] fabricated observation IDs: {sorted(unknown_facts)}")
        unknown_claims = set(draft.claimCardIds) - claim_ids
        if unknown_claims:
            raise ValueError(f"drafts[{index}] fabricated claim IDs: {sorted(unknown_claims)}")
        unknown_suggestions = set(draft.suggestionIds) - eligible_suggestions
        if unknown_suggestions:
            raise ValueError(
                f"drafts[{index}] used unapproved suggestion IDs: {sorted(unknown_suggestions)}"
            )
        if draft.suggestionIds and not draft.claimCardIds:
            raise ValueError(f"drafts[{index}] cannot use suggestions without an approved claim.")
        selected_facts = [item for item in facts if item.evidenceId in draft.observationFactIds]
        for claim_id in draft.claimCardIds:
            claim = next(item for item in retrieved_claims if item.claimCardId == claim_id)
            if not any(claim.claimType in fact.claimTypes for fact in selected_facts):
                raise ValueError(
                    f"drafts[{index}] did not cite a transcript fact that triggered {claim_id}."
                )


def validate_draft_quality(
    drafts: list[GroundedInsightDraft],
    retrieved_claims: list[ClaimCard],
    catalog: GroundingCatalog,
    journal_narrative: dict[str, Any],
) -> None:
    """Reject valid JSON that is too sparse for a substantive journal entry."""
    for index, draft in enumerate(drafts):
        if not _uses_direct_address(draft.summary):
            raise ValueError(
                f"drafts[{index}].summary must address the journal owner directly "
                "with you or your."
            )
        if len(_words(draft.summary)) > MAX_DETAILED_SUMMARY_WORDS:
            raise ValueError(
                f"drafts[{index}].summary must contain no more than "
                f"{MAX_DETAILED_SUMMARY_WORDS} words."
            )

    paraphrase = str(journal_narrative.get("paraphrase") or "")
    excerpts = " ".join(
        str(item)
        for item in (journal_narrative.get("keyExcerpts") or [])
        if str(item).strip()
    )
    # A fragmentary recording should not be padded with invented detail.
    if (
        max(len(_words(paraphrase)), len(_words(excerpts)))
        < MIN_SUBSTANTIVE_NARRATIVE_WORDS
    ):
        return

    claim_by_id = {item.claimCardId: item for item in retrieved_claims}
    narrative_anchors = {
        word
        for word in _words(f"{paraphrase} {excerpts}")
        if len(word) >= 4 and word not in NARRATIVE_STOP_WORDS
    }
    expected_anchors = min(2, len(narrative_anchors))
    available_theme_values = [
        *list(journal_narrative.get("topics") or []),
        *list(journal_narrative.get("keyPhrases") or []),
    ]
    expected_themes = min(
        2,
        _distinct_text_count([str(item) for item in available_theme_values]),
    )
    seen_titles: set[str] = set()
    for index, draft in enumerate(drafts):
        if len(_words(draft.summary)) < MIN_DETAILED_SUMMARY_WORDS:
            raise ValueError(
                f"drafts[{index}].summary is too brief for the supplied journal; "
                f"connect 2 to 4 concrete narrative details in "
                f"{MIN_DETAILED_SUMMARY_WORDS} or more words."
            )
        summary_anchors = set(_words(draft.summary)) & narrative_anchors
        if len(summary_anchors) < expected_anchors:
            raise ValueError(
                f"drafts[{index}].summary must name at least {expected_anchors} "
                "concrete journal details."
            )
        if _distinct_text_count(list(draft.dayThemes)) < expected_themes:
            raise ValueError(
                f"drafts[{index}] must include at least {expected_themes} "
                "distinct concise day themes."
            )
        if _distinct_text_count(list(draft.reflectionQuestions)) < 2:
            raise ValueError(
                f"drafts[{index}] must include at least two distinct "
                "reflection questions."
            )

        title_key = " ".join(_words(draft.title))
        if title_key in seen_titles:
            raise ValueError("Grounded drafts must cover distinct, non-duplicate ideas.")
        seen_titles.add(title_key)

        eligible_suggestions = {
            suggestion_id
            for claim_id in draft.claimCardIds
            if (claim := claim_by_id.get(claim_id)) is not None
            for suggestion_id in claim.allowedSuggestionIds
            if (
                (suggestion := catalog.suggestion_by_id.get(suggestion_id)) is not None
                and suggestion.runtime_eligible
            )
        }
        expected_suggestions = min(2, len(eligible_suggestions))
        if len(set(draft.suggestionIds)) < expected_suggestions:
            raise ValueError(
                f"drafts[{index}] must select {expected_suggestions} approved "
                "suggestion IDs available for its claims."
            )


def validate_assembled_insights(
    insights: list[AiInsight],
    facts: list[ObservationFact],
    catalog: GroundingCatalog,
) -> None:
    fact_by_id = {item.evidenceId: item for item in facts}
    for index, insight in enumerate(insights):
        _reject_ai_insight_language(insight)
        if not _uses_direct_address(insight.summary):
            raise ValueError(
                f"insight[{index}].summary must address the journal owner directly "
                "with you or your."
            )
        evidence = insight.evidence
        if evidence.get("schemaVersion") != 2:
            raise ValueError(f"insight[{index}] is missing evidence schemaVersion 2.")
        user_evidence = evidence.get("userEvidence")
        references = evidence.get("externalReferences")
        verification = evidence.get("verification")
        rationale = evidence.get("rationale")
        if not isinstance(user_evidence, list) or not isinstance(references, list):
            raise ValueError(f"insight[{index}] evidence arrays are invalid.")
        if not isinstance(verification, dict):
            raise ValueError(f"insight[{index}] verification is invalid.")
        if not isinstance(rationale, str) or not rationale.strip():
            raise ValueError(f"insight[{index}] evidence rationale is invalid.")
        for item in user_evidence:
            if not isinstance(item, dict):
                raise ValueError(f"insight[{index}] contains invalid user evidence.")
            fact = fact_by_id.get(item.get("evidenceId"))
            if fact is None:
                raise ValueError(f"insight[{index}] contains unknown evidence.")
            if item.get("sourcePath") not in ALLOWED_EVIDENCE_PATHS:
                raise ValueError(f"insight[{index}] uses a prohibited evidence path.")
            if item.get("value") != fact.value:
                raise ValueError(f"insight[{index}] altered an observation value.")
        for item in references:
            if not isinstance(item, dict):
                raise ValueError(f"insight[{index}] contains an invalid reference.")
            claim = catalog.claim_by_id.get(item.get("claimCardId"))
            source = catalog.source_by_id.get(item.get("sourceId"))
            if claim is None or source is None or not claim.runtime_eligible:
                raise ValueError(f"insight[{index}] references an unapproved catalog item.")
            expected = {
                "title": source.title,
                "publisher": source.publisher,
                "year": source.year,
                "url": source.url,
                "matchedClaim": claim.displayClaim,
                "limitations": claim.limitations,
                "supportLevel": claim.supportLevel,
            }
            if any(item.get(key) != value for key, value in expected.items()):
                raise ValueError(f"insight[{index}] altered catalog source metadata.")
        status = verification.get("status")
        if status == "source_supported" and not references:
            raise ValueError(f"insight[{index}] claims source support without a reference.")
        if status not in {"source_supported", "user_data_only", "fallback"}:
            raise ValueError(f"insight[{index}] has an unsupported verification status.")


def validate_grounded_user_language(insight: AiInsight) -> None:
    """Apply grounded wording rules before an insight receives evidence-v2 labeling."""
    _reject_ai_insight_language(insight)
    if not _uses_direct_address(insight.summary):
        raise ValueError(
            "Grounded insight summary must address the journal owner directly "
            "with you or your."
        )


def _reject_language(draft: GroundedInsightDraft) -> None:
    text = " ".join(
        [
            draft.title,
            draft.summary,
            draft.moodLabel,
            *draft.dayThemes,
            *draft.reflectionQuestions,
            draft.safetyNote,
        ]
    ).lower()
    blocked = BLOCKED_PERSONAL_PHRASES | BLOCKED_RESEARCH_PHRASES
    if any(phrase in text for phrase in blocked):
        raise ValueError("Grounded draft contains unsupported or clinical language.")


def _reject_ai_insight_language(insight: AiInsight) -> None:
    text = " ".join(
        [
            insight.title,
            insight.summary,
            insight.moodLabel,
            *insight.dayThemes,
            *insight.suggestions,
            *insight.reflectionQuestions,
            insight.safetyNote,
        ]
    ).lower()
    blocked = BLOCKED_PERSONAL_PHRASES | BLOCKED_RESEARCH_PHRASES
    if any(phrase in text for phrase in blocked):
        raise ValueError("Assembled insight contains unsupported or clinical language.")


def _uses_direct_address(value: str) -> bool:
    lowered = " ".join(value.lower().replace("’", "'").split())
    if any(phrase in lowered for phrase in THIRD_PERSON_SUBJECT_PHRASES):
        return False
    return bool(
        re.search(
            r"\b(?:you|your|yours|yourself|you're|you've|you'll|you'd)\b",
            lowered,
        )
    )


def _text(value: Any, label: str, max_len: int) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{label} must be a non-empty string.")
    clean = " ".join(value.split())
    if len(clean) <= max_len:
        return clean
    shortened = clean[:max_len].rstrip()
    return shortened.rsplit(" ", 1)[0] if " " in shortened else shortened


def _text_list(value: Any, max_items: int, max_len: int) -> list[str]:
    if not isinstance(value, list):
        raise ValueError("Grounded text lists must be arrays.")
    return [
        _text(item, "grounded list item", max_len)
        for item in value
        if isinstance(item, str) and item.strip()
    ][:max_items]


def _id_list(value: Any, label: str) -> list[str]:
    if not isinstance(value, list):
        raise ValueError(f"{label} must be an array.")
    output = [item.strip() for item in value if isinstance(item, str) and item.strip()]
    if len(output) != len(value):
        raise ValueError(f"{label} may contain only non-empty strings.")
    return list(dict.fromkeys(output))


def _words(value: str) -> list[str]:
    return re.findall(r"[a-z0-9']+", value.lower())


def _distinct_text_count(values: list[str]) -> int:
    return len(
        {
            clean
            for value in values
            if (clean := " ".join(_words(value)))
        }
    )
