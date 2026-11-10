"""Plan revision normalization and permitted approval transitions."""

from __future__ import annotations

import re
from urllib.parse import unquote

from factory_tooling.planning.plan_document import (
    URL_RE,
    error,
    parse_metadata,
    parse_revision,
)


def normalize_url(match: re.Match[str]) -> str:
    url = unquote(match.group(0)).rstrip("/.,")
    while url.endswith(")") and url.count(")") > url.count("("):
        url = url[:-1]
    return url


def semantic_normal_form(text: str) -> str:
    lines: list[str] = []
    for line in text.splitlines():
        if re.match(r"^(revision|status|approved_revision):", line):
            continue
        if re.fullmatch(r"\s*\|?(?:\s*:?-{3,}:?\s*\|)+\s*", line):
            continue
        line = URL_RE.sub(normalize_url, line)
        line = re.sub(r"\s+", " ", line).strip()
        if line:
            lines.append(line)
    return "\n".join(lines)


def validate_transition(
    previous_text: str,
    current_text: str,
    *,
    change_kind: str = "auto",
    change_evidence: str = "",
) -> list[dict[str, str]]:
    errors: list[dict[str, str]] = []
    previous, previous_errors = parse_metadata(previous_text)
    current, current_errors = parse_metadata(current_text)
    if previous_errors or current_errors:
        return [
            error("TRANSITION_METADATA_INVALID", "Cannot validate transition with invalid metadata")
        ]
    if previous["plan_id"] != current["plan_id"]:
        errors.append(error("PLAN_ID_CHANGED", "plan_id must remain stable across revisions"))
    previous_revision = parse_revision(previous["revision"])
    current_revision = parse_revision(current["revision"])
    if previous_revision is None or current_revision is None:
        errors.append(
            error("TRANSITION_METADATA_INVALID", "Both revisions must be positive integers")
        )
        return errors
    content_changed = semantic_normal_form(previous_text) != semantic_normal_form(current_text)
    if change_kind not in {"auto", "semantic", "nonsemantic"}:
        return [error("CHANGE_KIND_INVALID", "Unknown coordinator change classification")]
    if change_kind != "auto" and not change_evidence.strip():
        errors.append(
            error(
                "CHANGE_EVIDENCE_MISSING", "Explicit classification requires coordinator evidence"
            )
        )
    semantic_changed = content_changed if change_kind == "auto" else change_kind == "semantic"
    if change_kind == "nonsemantic":
        # IDs are machine identity. Meaning remains the coordinator's responsibility.
        for pattern in (r"\bCAP-\d{2,}\b", r"\bAC-\d{2,}\b", r"\bD-\d{2,}\b", r"\bEXT-\d{2,}\b"):
            if set(re.findall(pattern, previous_text)) != set(re.findall(pattern, current_text)):
                errors.append(
                    error(
                        "NONSEMANTIC_IDENTITY_CHANGED",
                        "Nonsemantic edits must preserve referenced IDs",
                    )
                )
        for key in ("plan_state", "source", "handoff_recommendation"):
            if previous[key] != current[key]:
                errors.append(
                    error("NONSEMANTIC_IDENTITY_CHANGED", f"Nonsemantic edit changed {key}")
                )

    def without_approval(text: str) -> str:
        return "".join(
            line
            for line in text.splitlines(keepends=True)
            if not re.match(r"^(status|approved_revision):", line)
        )

    if previous["status"] == "draft" and current["status"] == "approved":
        if without_approval(previous_text) != without_approval(current_text):
            errors.append(
                error("APPROVAL_CONTENT_CHANGED", "Approval must change only approval metadata")
            )

    approval_only = (
        not semantic_changed
        and previous["status"] == "draft"
        and current["status"] == "approved"
        and current_revision == previous_revision
    )
    if approval_only:
        return errors
    if semantic_changed:
        if current_revision != previous_revision + 1:
            errors.append(
                error("SEMANTIC_REVISION_INVALID", "Semantic change requires revision N+1")
            )
        if current.get("status") != "draft" or current.get("approved_revision") != "none":
            errors.append(
                error("SEMANTIC_APPROVAL_NOT_RESET", "Semantic change must reset approval")
            )
    elif current_revision != previous_revision:
        errors.append(error("NONSEMANTIC_REVISION_CHANGED", "Non-semantic edit must keep revision"))

    if previous["status"] == "approved" and not semantic_changed and previous_text != current_text:
        errors.append(error("APPROVED_IMMUTABLE", "Approved durable snapshot must not be edited"))
    return errors
