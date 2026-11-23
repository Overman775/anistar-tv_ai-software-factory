"""Plan revision normalization and permitted approval transitions."""

from __future__ import annotations

import re
from collections.abc import Mapping
from urllib.parse import unquote

from factory.planning.plan_document import (
    URL_RE,
    error,
    parse_plan_header,
    parse_revision,
    split_metadata_block,
)


def normalize_url(match: re.Match[str]) -> str:
    url = unquote(match.group(0)).rstrip("/.,")
    while url.endswith(")") and url.count(")") > url.count("("):
        url = url[:-1]
    return url


def _without_metadata(text: str, fields: set[str]) -> str:
    header, body = split_metadata_block(text)
    kept = []
    for line in header.splitlines(keepends=True):
        key, separator, _ = line.partition(":")
        if not separator or key not in fields:
            kept.append(line)
    return "".join(kept) + body


def semantic_normal_form(text: str) -> str:
    lines: list[str] = []
    for line in _without_metadata(text, {"revision", "status", "approved_revision"}).splitlines():
        if re.fullmatch(r"\s*\|?(?:\s*:?-{3,}:?\s*\|)+\s*", line):
            continue
        line = URL_RE.sub(normalize_url, line)
        line = re.sub(r"\s+", " ", line).strip()
        if line:
            lines.append(line)
    return "\n".join(lines)


def approval_error(metadata: Mapping[str, object], revision: int | None) -> dict[str, str] | None:
    status = metadata.get("status")
    approved = metadata.get("approved_revision")
    if status == "draft" and approved != "none":
        return error("APPROVAL_INVARIANT_INVALID", "Draft must use approved_revision: none")
    if status == "approved" and (
        metadata.get("plan_state") != "PLAN_READY" or revision is None or approved != str(revision)
    ):
        return error(
            "APPROVAL_INVARIANT_INVALID", "Approved plan needs PLAN_READY and matching revision"
        )
    return None


class PlanRevision:
    """A plan snapshot as submitted, including the exact text approved by its owner."""

    def __init__(self, text: str) -> None:
        self.text = text
        self.metadata, self._validated_metadata, self.metadata_errors = parse_plan_header(text)

    @property
    def number(self) -> int | None:
        return parse_revision(self.metadata.get("revision", ""))

    @property
    def approval_content(self) -> str:
        return _without_metadata(self.text, {"status", "approved_revision"})

    def transition_errors(
        self, previous: PlanRevision, *, change_kind: str, change_evidence: str
    ) -> list[dict[str, str]]:
        prior, current = previous._validated_metadata, self._validated_metadata
        if prior is None or current is None:
            return [
                error(
                    "TRANSITION_METADATA_INVALID",
                    "Cannot validate transition with invalid metadata",
                )
            ]
        errors: list[dict[str, str]] = []
        if prior["plan_id"] != current["plan_id"]:
            errors.append(error("PLAN_ID_CHANGED", "plan_id must remain stable across revisions"))
        previous_revision = parse_revision(prior["revision"])
        current_revision = parse_revision(current["revision"])
        if previous_revision is None or current_revision is None:
            errors.append(
                error("TRANSITION_METADATA_INVALID", "Both revisions must be positive integers")
            )
            return errors
        if prior_error := approval_error(prior, previous_revision):
            errors.append(
                error("TRANSITION_METADATA_INVALID", "Previous revision: " + prior_error["message"])
            )
        if current_error := approval_error(current, current_revision):
            errors.append(current_error)
        if change_kind not in {"auto", "semantic", "nonsemantic"}:
            errors.append(error("CHANGE_KIND_INVALID", "Unknown coordinator change classification"))
            return errors
        if change_kind != "auto" and not change_evidence.strip():
            errors.append(
                error(
                    "CHANGE_EVIDENCE_MISSING",
                    "Explicit classification requires coordinator evidence",
                )
            )
        semantic_changed = (
            semantic_normal_form(previous.text) != semantic_normal_form(self.text)
            if change_kind == "auto"
            else change_kind == "semantic"
        )
        if change_kind == "nonsemantic":
            # IDs are machine identity. Meaning remains the coordinator's responsibility.
            for pattern in (
                r"\bCAP-\d{2,}\b",
                r"\bAC-\d{2,}\b",
                r"\bD-\d{2,}\b",
                r"\bEXT-\d{2,}\b",
            ):
                if set(re.findall(pattern, previous.text)) != set(re.findall(pattern, self.text)):
                    errors.append(
                        error(
                            "NONSEMANTIC_IDENTITY_CHANGED",
                            "Nonsemantic edits must preserve referenced IDs",
                        )
                    )
            for key in ("plan_state", "source", "handoff_recommendation"):
                if prior[key] != current[key]:
                    errors.append(
                        error("NONSEMANTIC_IDENTITY_CHANGED", f"Nonsemantic edit changed {key}")
                    )

        if prior["status"] == "draft" and current["status"] == "approved":
            if previous.approval_content != self.approval_content:
                errors.append(
                    error("APPROVAL_CONTENT_CHANGED", "Approval must change only approval metadata")
                )

        if semantic_changed:
            if current_revision != previous_revision + 1:
                errors.append(
                    error("SEMANTIC_REVISION_INVALID", "Semantic change requires revision N+1")
                )
            if current["status"] != "draft" or current["approved_revision"] != "none":
                errors.append(
                    error("SEMANTIC_APPROVAL_NOT_RESET", "Semantic change must reset approval")
                )
        elif current_revision != previous_revision:
            errors.append(
                error("NONSEMANTIC_REVISION_CHANGED", "Non-semantic edit must keep revision")
            )

        if prior["status"] == "approved" and not semantic_changed and previous.text != self.text:
            errors.append(
                error("APPROVED_IMMUTABLE", "Approved durable snapshot must not be edited")
            )
        return errors


def validate_transition(
    previous_text: str,
    current_text: str,
    *,
    change_kind: str = "auto",
    change_evidence: str = "",
) -> list[dict[str, str]]:
    return PlanRevision(current_text).transition_errors(
        PlanRevision(previous_text), change_kind=change_kind, change_evidence=change_evidence
    )
