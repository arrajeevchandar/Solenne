from __future__ import annotations

import json
from datetime import date
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

from .models import (
    ApprovedSuggestion,
    ClaimCard,
    GroundingCatalog,
    ReviewApproval,
    SourceRecord,
)


CLAIM_TYPES = {
    "reflective_journaling",
    "rest_routines",
    "workload_breaks",
    "social_connection",
    "grounding_routines",
}
SUPPORT_LEVELS = {"strong", "moderate", "weak"}
STATUSES = {"draft", "approved", "inactive"}
FORBIDDEN_CONTENT_KEYS = {"abstract", "fullText", "full_text", "pdfText", "pdf_text"}


class CatalogError(ValueError):
    """Raised when the curated grounding catalog is missing or invalid."""


def load_catalog(path: Path) -> GroundingCatalog:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise CatalogError(f"Grounding catalog was not found at {path}.") from error
    except json.JSONDecodeError as error:
        raise CatalogError(f"Grounding catalog is not valid JSON: {error}.") from error
    errors, catalog = _validate_and_parse(raw)
    if errors or catalog is None:
        raise CatalogError("; ".join(errors))
    return catalog


def validate_catalog_file(path: Path) -> list[str]:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return [f"Catalog was not found at {path}."]
    except json.JSONDecodeError as error:
        return [f"Catalog is not valid JSON: {error}."]
    errors, _ = _validate_and_parse(raw)
    return errors


def catalog_report(catalog: GroundingCatalog) -> dict[str, Any]:
    return {
        "catalogVersion": catalog.catalogVersion,
        "sources": len(catalog.sources),
        "claimCards": len(catalog.claimCards),
        "eligibleClaimCards": sum(item.runtime_eligible for item in catalog.claimCards),
        "suggestions": len(catalog.suggestions),
        "eligibleSuggestions": sum(item.runtime_eligible for item in catalog.suggestions),
        "claimTypes": {
            claim_type: sum(item.claimType == claim_type for item in catalog.claimCards)
            for claim_type in sorted(CLAIM_TYPES)
        },
    }


def _validate_and_parse(raw: Any) -> tuple[list[str], GroundingCatalog | None]:
    errors: list[str] = []
    if not isinstance(raw, dict):
        return ["Catalog root must be an object."], None
    _find_forbidden_keys(raw, "catalog", errors)
    version = _required_text(raw, "catalogVersion", "catalog", errors, 80)
    source_items = _required_list(raw, "sources", "catalog", errors)
    claim_items = _required_list(raw, "claimCards", "catalog", errors)
    suggestion_items = _required_list(raw, "suggestions", "catalog", errors)

    sources: list[SourceRecord] = []
    source_ids: set[str] = set()
    for index, item in enumerate(source_items):
        label = f"sources[{index}]"
        if not isinstance(item, dict):
            errors.append(f"{label} must be an object.")
            continue
        source_id = _required_text(item, "sourceId", label, errors, 100)
        _unique(source_id, source_ids, f"Duplicate sourceId {source_id}.", errors)
        url = _required_text(item, "url", label, errors, 500)
        _validate_https(url, f"{label}.url", errors)
        year = item.get("year")
        if not isinstance(year, int) or not 1900 <= year <= 2100:
            errors.append(f"{label}.year must be an integer between 1900 and 2100.")
            year = 1900
        sources.append(
            SourceRecord(
                sourceId=source_id,
                title=_required_text(item, "title", label, errors, 240),
                publisher=_required_text(item, "publisher", label, errors, 160),
                year=year,
                url=url,
                doi=_optional_text(item.get("doi"), f"{label}.doi", errors, 160),
                pmid=_optional_text(item.get("pmid"), f"{label}.pmid", errors, 40),
                licenseUsageNote=_required_text(
                    item, "licenseUsageNote", label, errors, 300
                ),
            )
        )

    suggestions: list[ApprovedSuggestion] = []
    suggestion_ids: set[str] = set()
    for index, item in enumerate(suggestion_items):
        label = f"suggestions[{index}]"
        if not isinstance(item, dict):
            errors.append(f"{label} must be an object.")
            continue
        suggestion_id = _required_text(item, "suggestionId", label, errors, 100)
        _unique(
            suggestion_id,
            suggestion_ids,
            f"Duplicate suggestionId {suggestion_id}.",
            errors,
        )
        status = _status(item.get("status"), label, errors)
        approvals = _approvals(item.get("approvals"), label, errors)
        active = item.get("active", False)
        if not isinstance(active, bool):
            errors.append(f"{label}.active must be a boolean.")
            active = False
        _validate_approval_gate(status, active, approvals, label, errors)
        suggestions.append(
            ApprovedSuggestion(
                suggestionId=suggestion_id,
                text=_required_text(item, "text", label, errors, 180),
                tags=tuple(_text_list(item.get("tags"), f"{label}.tags", errors)),
                status=status,
                approvals=approvals,
                active=active,
            )
        )

    claims: list[ClaimCard] = []
    claim_ids: set[str] = set()
    for index, item in enumerate(claim_items):
        label = f"claimCards[{index}]"
        if not isinstance(item, dict):
            errors.append(f"{label} must be an object.")
            continue
        claim_id = _required_text(item, "claimCardId", label, errors, 100)
        _unique(claim_id, claim_ids, f"Duplicate claimCardId {claim_id}.", errors)
        source_id = _required_text(item, "sourceId", label, errors, 100)
        if source_id not in source_ids:
            errors.append(f"{label}.sourceId does not reference a catalog source.")
        claim_type = item.get("claimType")
        if claim_type not in CLAIM_TYPES:
            errors.append(f"{label}.claimType is not supported.")
            claim_type = "reflective_journaling"
        support = item.get("supportLevel")
        if support not in SUPPORT_LEVELS:
            errors.append(f"{label}.supportLevel is not supported.")
            support = "weak"
        status = _status(item.get("status"), label, errors)
        approvals = _approvals(item.get("approvals"), label, errors)
        active = item.get("active", False)
        if not isinstance(active, bool):
            errors.append(f"{label}.active must be a boolean.")
            active = False
        _validate_approval_gate(status, active, approvals, label, errors)
        allowed_ids = _text_list(
            item.get("allowedSuggestionIds"),
            f"{label}.allowedSuggestionIds",
            errors,
        )
        for suggestion_id in allowed_ids:
            if suggestion_id not in suggestion_ids:
                errors.append(
                    f"{label}.allowedSuggestionIds contains unknown id {suggestion_id}."
                )
        claims.append(
            ClaimCard(
                claimCardId=claim_id,
                sourceId=source_id,
                claimType=claim_type,
                displayClaim=_required_text(
                    item, "displayClaim", label, errors, 360
                ),
                limitations=_required_text(item, "limitations", label, errors, 360),
                tags=tuple(_text_list(item.get("tags"), f"{label}.tags", errors)),
                supportLevel=support,
                allowedSuggestionIds=tuple(allowed_ids),
                status=status,
                approvals=approvals,
                active=active,
            )
        )

    if errors:
        return errors, None
    return errors, GroundingCatalog(
        catalogVersion=version,
        sources=tuple(sources),
        claimCards=tuple(claims),
        suggestions=tuple(suggestions),
    )


def _find_forbidden_keys(value: Any, path: str, errors: list[str]) -> None:
    if isinstance(value, dict):
        for key, nested in value.items():
            if key in FORBIDDEN_CONTENT_KEYS:
                errors.append(f"{path}.{key} must not store copied source content.")
            _find_forbidden_keys(nested, f"{path}.{key}", errors)
    elif isinstance(value, list):
        for index, nested in enumerate(value):
            _find_forbidden_keys(nested, f"{path}[{index}]", errors)


def _required_list(raw: dict, key: str, label: str, errors: list[str]) -> list:
    value = raw.get(key)
    if not isinstance(value, list):
        errors.append(f"{label}.{key} must be an array.")
        return []
    return value


def _required_text(
    raw: dict, key: str, label: str, errors: list[str], max_len: int
) -> str:
    value = raw.get(key)
    if not isinstance(value, str) or not value.strip():
        errors.append(f"{label}.{key} must be a non-empty string.")
        return ""
    clean = " ".join(value.split())
    if len(clean) > max_len:
        errors.append(f"{label}.{key} must be at most {max_len} characters.")
    return clean


def _optional_text(value: Any, label: str, errors: list[str], max_len: int) -> str | None:
    if value is None:
        return None
    if not isinstance(value, str):
        errors.append(f"{label} must be a string or null.")
        return None
    clean = value.strip()
    if len(clean) > max_len:
        errors.append(f"{label} must be at most {max_len} characters.")
    return clean or None


def _text_list(value: Any, label: str, errors: list[str]) -> list[str]:
    if not isinstance(value, list):
        errors.append(f"{label} must be an array.")
        return []
    output: list[str] = []
    for item in value:
        if not isinstance(item, str) or not item.strip():
            errors.append(f"{label} may contain only non-empty strings.")
            continue
        output.append(item.strip())
    return output


def _status(value: Any, label: str, errors: list[str]) -> str:
    if value not in STATUSES:
        errors.append(f"{label}.status must be draft, approved, or inactive.")
        return "draft"
    return value


def _approvals(value: Any, label: str, errors: list[str]) -> tuple[ReviewApproval, ...]:
    if not isinstance(value, list):
        errors.append(f"{label}.approvals must be an array.")
        return ()
    approvals: list[ReviewApproval] = []
    for index, item in enumerate(value):
        item_label = f"{label}.approvals[{index}]"
        if not isinstance(item, dict):
            errors.append(f"{item_label} must be an object.")
            continue
        reviewer = _required_text(item, "reviewerId", item_label, errors, 100)
        reviewed_at = _required_text(item, "reviewedAt", item_label, errors, 40)
        try:
            date.fromisoformat(reviewed_at)
        except ValueError:
            errors.append(f"{item_label}.reviewedAt must use YYYY-MM-DD format.")
        approvals.append(ReviewApproval(reviewer, reviewed_at))
    return tuple(approvals)


def _validate_approval_gate(
    status: str,
    active: bool,
    approvals: tuple[ReviewApproval, ...],
    label: str,
    errors: list[str],
) -> None:
    if status == "approved" or active:
        reviewers = {item.reviewerId for item in approvals if item.reviewerId}
        if len(reviewers) < 2:
            errors.append(f"{label} needs two distinct reviewers before approval or activation.")
    if active and status != "approved":
        errors.append(f"{label} cannot be active unless status is approved.")


def _validate_https(url: str, label: str, errors: list[str]) -> None:
    parsed = urlparse(url)
    if parsed.scheme != "https" or not parsed.netloc or parsed.username or parsed.password:
        errors.append(f"{label} must be a canonical HTTPS URL without credentials.")


def _unique(value: str, seen: set[str], message: str, errors: list[str]) -> None:
    if not value:
        return
    if value in seen:
        errors.append(message)
    seen.add(value)
