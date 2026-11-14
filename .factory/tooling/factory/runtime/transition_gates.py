"""Pure evidence requirements for project supplements to workflow boundaries."""

from __future__ import annotations

from typing import NotRequired

from pydantic import ConfigDict, TypeAdapter, ValidationError, with_config
from typing_extensions import TypedDict

from factory.gates.catalog import CORE, core_result
from factory.gates.gate_contract import GateResult, GateStatus, conclude, digest, evidence
from factory.project.contracts import ProjectData
from factory.project.profile_rules import boundary_gates
from factory.runtime import acceptance
from factory.runtime.contracts import (
    ContextNode,
    Node,
    Report,
    ReviewCheck,
    State,
)
from factory.tasks.contracts import Task, TaskSelection
from factory.validation import validation_message

CORE_BOUNDARIES = set(CORE)
REVIEW_CHECKS = TypeAdapter[list[ReviewCheck]](list[ReviewCheck], config=ConfigDict(strict=True))


def evaluate(
    profile: ProjectData, node: Node | ContextNode, task: Task | TaskSelection, raw: object
) -> list[GateResult]:
    """Validate PASS evidence. Runtime validates command receipts separately.

    Core role/source/permission/acceptance gates cannot be overridden here.
    Failed/blocked reports use existing coordinator correction and retry policy.
    """
    report = raw if isinstance(raw, dict) else {}
    gates = boundary_gates(profile, "implement." + node["stage"], task)
    expected_checks = {cid for gate in gates for cid in gate.get("checks", [])}
    if expected_checks:
        specifications = [c for c in task.get("required_checks", []) if c["id"] in expected_checks]
        results = [c for c in report.get("checks", []) if c.get("id") in expected_checks]
        acceptance.verify_results(specifications, results)
    expected_criteria = {cid for gate in gates for cid in gate.get("criteria", [])}
    if expected_criteria or report.get("review_checks"):
        try:
            records = REVIEW_CHECKS.validate_python(report.get("review_checks", []))
        except ValidationError as exc:
            raise ValueError(
                validation_message("Invalid review_checks", exc, REVIEW_CHECKS)
            ) from None
        seen = set()
        for record in records:
            cid = record["id"]
            if cid not in expected_criteria or cid in seen:
                raise ValueError("Unknown/duplicate review criterion")
            seen.add(cid)
        acceptance.ensure(seen == expected_criteria, "Missing required review criteria")
    return [
        conclude(
            gate["id"],
            "implement." + node["stage"],
            str(report.get("run_id")) + ":" + node["id"] + ":" + str(report.get("dispatch_id")),
            digest(profile),
            digest(report.get("files", {})),
            gate.get("checks", gate.get("criteria", [])),
            [
                evidence(key, "PASS", "Runtime validated current evidence", [node["id"], key])
                for key in gate.get("checks", gate.get("criteria", []))
            ],
        )
        for gate in gates
    ]


@with_config(ConfigDict(strict=True, extra="forbid"))
class AcceptanceStageResult(TypedDict):
    outcome: GateStatus
    summary: str
    files: dict[str, str]
    dispatch_id: NotRequired[str]


def stage_result(state: State, node: Node, report: Report | AcceptanceStageResult) -> GateResult:
    return core_result(
        "implement." + node["stage"],
        state["run_id"] + ":" + node["id"] + ":" + str(report.get("dispatch_id", "coordinator")),
        digest(state["config"]["_files"]),
        digest(report.get("files", {})),
        [
            evidence(
                "stage-contract",
                report["outcome"],
                report["summary"],
                [node["id"], "runtime validation and retained report"],
            )
        ],
    )
