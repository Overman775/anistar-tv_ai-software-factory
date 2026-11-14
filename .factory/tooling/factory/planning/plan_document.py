"""Canonical plan vocabulary and Markdown parsing primitives."""

from __future__ import annotations

import re
from typing import Annotated, Literal

from pydantic import ConfigDict, StringConstraints, TypeAdapter, ValidationError, with_config
from typing_extensions import TypedDict


@with_config(ConfigDict(strict=True, extra="forbid"))
class PlanMetadata(TypedDict):
    plan_id: Annotated[str, StringConstraints(pattern=r"^[a-z0-9]+(?:-[a-z0-9]+)*$")]
    revision: str
    plan_state: Literal["PLAN_READY"]
    status: Literal["draft", "approved"]
    approved_revision: str
    source: Literal["request", "spec", "local", "mixed"]
    handoff_recommendation: Literal["direct", "decompose", "either"]


METADATA = TypeAdapter[PlanMetadata](PlanMetadata)
REQUIRED_METADATA = tuple(PlanMetadata.__annotations__)

METADATA_ERRORS = {
    "plan_id": "PLAN_ID_INVALID",
    "plan_state": "PLAN_STATE_INVALID",
    "status": "STATUS_INVALID",
    "source": "SOURCE_INVALID",
    "handoff_recommendation": "HANDOFF_INVALID",
}


def parse_revision(value: str) -> int | None:
    """Return a positive revision, or None for invalid metadata."""
    try:
        revision = int(value)
    except ValueError:
        return None
    return revision if revision > 0 else None


REQUIRED_HEADINGS = (
    "## What changes",
    "## How it works",
    "## Solution structure",
    "## Key decisions",
    "## Unknowns and boundaries",
    "## Readiness and verification",
    "## Handoff",
)


PLAN_STATES = {"PLAN_READY"}


API_EVIDENCE_TYPES = {
    "backend_api",
    "platform_plugin_api",
    "storage",
    "local_contract",
    "external_contract",
    "none",
}


SOURCES = {"request", "spec", "local", "mixed"}


HANDOFFS = {"direct", "decompose", "either"}


CONTINUATIONS = {
    "awaiting user choice",
    "pre-authorized direct execution",
    "pre-authorized decomposition",
    "plan only",
}


PREAUTHORIZED_CONTINUATIONS = {
    "pre-authorized direct execution",
    "pre-authorized decomposition",
}


PLAN_ID_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


DECISION_ID_RE = re.compile(r"^D-\d{2,}$")


DECISION_REFERENCE_RE = re.compile(r"\bD-\d{2,}\b")


EXTERNAL_ID_RE = re.compile(r"\bEXT-\d{2,}\b")


CAPABILITY_RE = re.compile(r"\bCAP-\d{2,}\b")


URL_RE = re.compile(r"https?://[^\s|<>]+")


NO_MATERIAL_DECISIONS = "- No significant decisions."


EMPTY_VALUES = {"", "-", "—", "none", "null", "n/a"}


FORBIDDEN_METADATA = {
    "publication_id",
    "question_budget_total",
    "question_budget_remaining",
    "question_batches_used",
    "current_question_batch",
    "estimate",
    "task_count",
}


def error(code: str, message: str) -> dict[str, str]:
    return {"code": code, "message": message}


def parse_metadata(text: str) -> tuple[dict[str, str], list[dict[str, str]]]:
    metadata: dict[str, str] = {}
    errors: list[dict[str, str]] = []
    prefix = text.split("\n## ", 1)[0]
    for line in prefix.splitlines():
        match = re.match(r"^([a-z][a-z0-9_]*):\s*(.*?)\s*$", line)
        if not match:
            continue
        key, value = match.groups()
        if key in metadata:
            errors.append(error("METADATA_DUPLICATE", f"Duplicate metadata: {key}"))
        metadata[key] = value

    try:
        METADATA.validate_python(metadata)
    except ValidationError as exc:
        for issue in exc.errors(include_input=False, include_context=False, include_url=False):
            key = str(issue["loc"][0])
            if issue["type"] == "missing":
                errors.append(error("METADATA_MISSING", f"Missing metadata: {key}"))
            elif issue["type"] == "extra_forbidden":
                code = "FORBIDDEN_METADATA" if key in FORBIDDEN_METADATA else "METADATA_EXTRA"
                errors.append(error(code, f"Metadata is not canonical: {key}"))
            else:
                errors.append(
                    error(METADATA_ERRORS.get(key, "METADATA_INVALID"), f"{key}: {issue['msg']}")
                )
    return metadata, errors


def extract_section(text: str, heading: str) -> str:
    start = text.find(heading)
    if start < 0:
        return ""
    start += len(heading)
    end = text.find("\n## ", start)
    return text[start:] if end < 0 else text[start:end]


def declared_capabilities(text: str) -> set[str]:
    return set(
        re.findall(
            r"(?m)^\s*[-*]\s+(CAP-\d{2,})\s+[—-]\s+\S",
            extract_section(text, "## What changes"),
        )
    )


def split_row(line: str) -> list[str]:
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def is_separator(cells: list[str]) -> bool:
    return bool(cells) and all(re.fullmatch(r":?-{3,}:?", cell) for cell in cells)


def table_after_header(section: str, header_marker: str) -> tuple[list[str], list[list[str]]]:
    lines = section.splitlines()
    for index, line in enumerate(lines):
        if not line.lstrip().startswith("|"):
            continue
        header = split_row(line)
        if header_marker not in header:
            continue
        rows: list[list[str]] = []
        for candidate in lines[index + 1 :]:
            if not candidate.lstrip().startswith("|"):
                if rows:
                    break
                continue
            cells = split_row(candidate)
            if is_separator(cells):
                continue
            rows.append(cells)
        return header, rows
    return [], []


def validate_applicability(
    value: str,
    known_capabilities: set[str],
    *,
    invalid_code: str,
    unknown_code: str,
    subject: str,
) -> list[dict[str, str]]:
    if value == "global":
        return []
    capabilities = CAPABILITY_RE.findall(value)
    residue = CAPABILITY_RE.sub("", value)
    residue = re.sub(r"[,\s]+", "", residue)
    if not capabilities or residue:
        return [error(invalid_code, f"{subject} must use comma-separated CAP IDs or global")]
    unknown = set(capabilities) - known_capabilities
    if unknown:
        return [
            error(unknown_code, f"{subject} references undeclared capabilities: {sorted(unknown)}")
        ]
    return []
