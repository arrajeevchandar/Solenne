from __future__ import annotations

from collections import Counter

from .models import ClaimCard, GroundingCatalog, ObservationFact


def retrieve_claims(
    facts: list[ObservationFact],
    catalog: GroundingCatalog,
    *,
    limit: int = 2,
) -> list[ClaimCard]:
    # Count how many transcript facts point at each claim type. A type backed by several
    # facts (e.g. a cluster of emotion words) is a stronger, more relevant match than one
    # riding on a single incidental keyword, so it should be preferred.
    type_signal: Counter[str] = Counter(
        claim_type
        for fact in facts
        if fact.kind in {"topic", "key_phrase"}
        for claim_type in fact.claimTypes
    )
    eligible_types = set(type_signal)
    ranked = [
        claim
        for claim in catalog.claimCards
        if claim.runtime_eligible and claim.claimType in eligible_types
    ]
    ranked.sort(
        key=lambda claim: (
            0 if claim.supportLevel == "strong" else 1,
            -type_signal[claim.claimType],
            claim.claimType,
            claim.claimCardId,
        )
    )
    selected: list[ClaimCard] = []
    seen_types: set[str] = set()
    for claim in ranked:
        if claim.claimType in seen_types:
            continue
        selected.append(claim)
        seen_types.add(claim.claimType)
        if len(selected) >= limit:
            break
    return selected
