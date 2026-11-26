#!/usr/bin/env python3
"""Bind independent TaskReviewer evidence to the checked candidate and selected inputs."""

from __future__ import annotations

from collections.abc import Collection
from pathlib import Path
from typing import Annotated, Literal, NotRequired

from pydantic import ConfigDict, Field, TypeAdapter, ValidationError, with_config
from typing_extensions import TypedDict

from factory import file_reader
from factory.decompose.contracts import Text
from factory.decompose.staging.manifest import Sha256
from factory.decompose.staging.output_safety import (
    review_inputs,
    review_worker_materials,
)
from factory.gates.gate_contract import GateCheck, digest, evidence
from factory.paths import FACTORY_ROOT
from factory.project.contracts import Selection
from factory.project.profile_io import (
    freeze_materials,
    load_profile,
    sha,
)
from factory.project.project import configured_profile
from factory.validation import validation_message

REVIEW_CRITERIA = ["plan-coverage", "task-cohesion", "architecture", "verification"]


def policy_binding(config: str | Path, selected: dict[str, str] | None = None) -> str:
    policy = load_profile(configured_profile(config))
    core = {
        p.relative_to(FACTORY_ROOT).as_posix(): sha(file_reader.read_bytes(p))
        for p in sorted(review_inputs())
    }
    selections: list[Selection] = [dict(process="decompose", audience="coordinator", scope=None)]
    selections += [
        dict(process="decompose", audience="worker", role=r, scope=None)
        for r in ("task-decomposer", "task-reviewer")
    ]
    documents = freeze_materials(policy, policy["workspace"], selections)
    agents = Path(policy["workspace"]) / "AGENTS.md"
    agents_hash = sha(file_reader.read_bytes(agents)) if agents.exists() else None
    workers = review_worker_materials(config, selected or {})
    coordinator = {
        rel: sha(file_reader.read_bytes(FACTORY_ROOT / rel))
        for rel in (
            "gates/skills/decompose/gate.md",
            "skills/factory-decompose/SKILL.md",
            "skills/factory-decompose/references/output-contract.md",
            "contracts/common/agent-checkpoint.md",
            "contracts/common/project-policy.md",
        )
    }
    return digest(
        {
            "project": policy["hash"],
            "core": core,
            "documents": documents,
            "agents": agents_hash,
            "workers": workers,
            "coordinator": coordinator,
        }
    )


@with_config(ConfigDict(strict=True, extra="forbid"))
class ReviewIdentity(TypedDict):
    run_id: Text
    assignment_id: Text
    reviewer_id: Text
    role: Literal["task-reviewer"]


@with_config(ConfigDict(strict=True, extra="forbid"))
class ReviewRequest(ReviewIdentity):
    author_id: Text
    artifact_hash: Text
    policy_hash: Text
    task_ids: Annotated[list[Text], Field(min_length=1)]
    criteria: list[Text]
    source_lock_sha256: Sha256
    author_manifest: dict[Text, Sha256]
    repaired: bool
    profiles: NotRequired[dict[Literal["task-decomposer", "task-reviewer"], Text]]


@with_config(ConfigDict(strict=True, extra="forbid"))
class ReviewFinding(TypedDict):
    id: Text
    blocking: bool
    message: Text
    evidence: Annotated[list[Text], Field(min_length=1)]


@with_config(ConfigDict(strict=True, extra="forbid"))
class ReviewReport(ReviewIdentity):
    request_hash: Text
    verdict: Literal["APPROVE", "NEEDS_WORK", "BLOCKED"]
    criteria: list[GateCheck]
    findings: list[ReviewFinding]


REVIEW_REQUEST = TypeAdapter[ReviewRequest](ReviewRequest)
REVIEW_REPORT = TypeAdapter[ReviewReport](ReviewReport)


def validate_request(raw: object) -> ReviewRequest:
    try:
        request = REVIEW_REQUEST.validate_python(raw)
    except ValidationError as exc:
        raise ValueError(
            validation_message("Invalid review request", exc, REVIEW_REQUEST)
        ) from None
    if request["author_id"] == request["reviewer_id"]:
        raise ValueError("TaskReviewer must be independent of the author")
    if request["criteria"] != REVIEW_CRITERIA or len(set(request["task_ids"])) != len(
        request["task_ids"]
    ):
        raise ValueError("Invalid review coverage")
    return request


def review_record(
    raw_request: object,
    raw_report: object,
    artifacts: str,
    policy_hash: str,
    task_ids: Collection[str],
    reference: str | Path,
) -> GateCheck:
    try:
        request = validate_request(raw_request)
        if (request["artifact_hash"], request["policy_hash"], request["task_ids"]) != (
            artifacts,
            policy_hash,
            sorted(task_ids),
        ):
            raise ValueError("Review request is stale: rebind current tasks and repeat review")
        report = REVIEW_REPORT.validate_python(raw_report)
        if report["request_hash"] != digest(raw_request) or any(
            report[k] != request[k] for k in ("run_id", "assignment_id", "reviewer_id", "role")
        ):
            raise ValueError("TaskReviewer identity or request mismatch")
        records = report["criteria"]
        if len(records) != len(REVIEW_CRITERIA) or {c["id"] for c in records} != set(
            REVIEW_CRITERIA
        ):
            raise ValueError("Unknown/duplicate/missing review criteria")
        findings = report["findings"]
        if len({f["id"] for f in findings}) != len(findings):
            raise ValueError("Duplicate review findings")
        failed = (
            any(c["status"] == "FAIL" for c in records)
            or any(f["blocking"] for f in findings)
            or report["verdict"] == "NEEDS_WORK"
        )
        blocked = any(c["status"] == "BLOCKED" for c in records) or report["verdict"] == "BLOCKED"
        state = "FAIL" if failed else "BLOCKED" if blocked else "PASS"
        details = [c["id"] + ": " + c["message"] for c in records if c["status"] != "PASS"]
        details += [f["id"] + ": " + f["message"] for f in findings if f["blocking"]]
        return evidence(
            "task-review",
            state,
            "TaskReviewer: " + report["verdict"] + "; " + "; ".join(details),
            [str(reference)],
        )
    except ValidationError as exc:
        return evidence(
            "task-review",
            "BLOCKED",
            validation_message("Invalid TaskReviewer report", exc, REVIEW_REPORT),
            [str(reference)],
        )
    except (ValueError, KeyError, TypeError) as exc:
        return evidence("task-review", "BLOCKED", str(exc), [str(reference)])
