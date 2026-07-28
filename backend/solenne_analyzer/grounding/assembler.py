from __future__ import annotations

from ..schemas import AiInsight
from .models import ClaimCard, GroundedInsightDraft, GroundingCatalog, ObservationFact


def assemble_insights(
    drafts: list[GroundedInsightDraft],
    facts: list[ObservationFact],
    retrieved_claims: list[ClaimCard],
    catalog: GroundingCatalog,
) -> list[AiInsight]:
    fact_by_id = {item.evidenceId: item for item in facts}
    claim_by_id = {item.claimCardId: item for item in retrieved_claims}
    output: list[AiInsight] = []
    for draft in drafts:
        selected_facts = [fact_by_id[item] for item in draft.observationFactIds]
        selected_claims = [claim_by_id[item] for item in draft.claimCardIds]
        allowed_suggestions = {
            suggestion_id
            for claim in selected_claims
            for suggestion_id in claim.allowedSuggestionIds
        }
        suggestions = [
            catalog.suggestion_by_id[item].text
            for item in draft.suggestionIds
            if item in allowed_suggestions
            and item in catalog.suggestion_by_id
            and catalog.suggestion_by_id[item].runtime_eligible
        ]
        references = [
            _reference(claim, catalog)
            for claim in selected_claims
        ][:2]
        status = "source_supported" if references else "user_data_only"
        output.append(
            AiInsight(
                title=draft.title,
                summary=draft.summary,
                moodLabel=draft.moodLabel,
                dayThemes=list(draft.dayThemes),
                suggestions=suggestions,
                reflectionQuestions=list(draft.reflectionQuestions),
                evidence={
                    "schemaVersion": 2,
                    "rationale": _rationale(selected_facts, selected_claims),
                    "userEvidence": [item.to_evidence() for item in selected_facts],
                    "externalReferences": references,
                    "verification": {
                        "status": status,
                        "method": "curated_claim_match" if references else "journal_observation",
                        "catalogVersion": catalog.catalogVersion,
                        "reason": None if references else "no_selected_reference",
                    },
                },
                confidence=draft.confidence,
                safetyNote=draft.safetyNote,
            )
        )
    return output


def _rationale(
    facts: list[ObservationFact],
    claims: list[ClaimCard],
) -> str:
    claim_types = {item.claimType for item in claims}
    values = list(
        dict.fromkeys(
            str(item.value).strip()
            for item in facts
            if item.kind in {"topic", "key_phrase"}
            and str(item.value).strip()
            and (
                not claim_types
                or any(claim_type in item.claimTypes for claim_type in claim_types)
            )
        )
    )
    if values:
        observed = _join_words(values[:3])
        reason = f"This appeared because your reflection included {observed}."
    else:
        reason = "This appeared because of the journal details cited below."
    if claims:
        return (
            f"{reason} The attached source offers general context only for the "
            "matched theme shown below; it does not determine what your individual "
            "experience means."
        )
    return (
        f"{reason} The reflection stays with your own words and leaves their "
        "personal meaning open to you."
    )


def _join_words(values: list[str]) -> str:
    if len(values) == 1:
        return values[0]
    return ", ".join(values[:-1]) + f" and {values[-1]}"


def _reference(claim: ClaimCard, catalog: GroundingCatalog) -> dict:
    source = catalog.source_by_id[claim.sourceId]
    return {
        "claimCardId": claim.claimCardId,
        "sourceId": source.sourceId,
        "title": source.title,
        "publisher": source.publisher,
        "year": source.year,
        "url": source.url,
        "doi": source.doi,
        "pmid": source.pmid,
        "matchedClaim": claim.displayClaim,
        "limitations": claim.limitations,
        "supportLevel": claim.supportLevel,
    }
