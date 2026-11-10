"""Pure evidence requirements for project supplements to workflow boundaries."""

from __future__ import annotations

from factory_tooling.gates.catalog import CORE, core_result
from factory_tooling.gates.gate_contract import GateResult, conclude, digest, evidence
from factory_tooling.project.contracts import ProjectData
from factory_tooling.project.profile_rules import boundary_gates
from factory_tooling.runtime import acceptance
from factory_tooling.runtime.contracts import (
    Node,
    Report,
    State,
    Task,
)

CORE_BOUNDARIES = set(CORE)


def evaluate(profile: ProjectData, node: Node, task: Task, report: Report) -> list[GateResult]:
    """Validate PASS evidence. Runtime validates command receipts separately.

    Core role/source/permission/acceptance gates cannot be overridden here.
    Failed/blocked reports use existing coordinator correction and retry policy.
    """
    gates = boundary_gates(profile, "implement." + node["stage"], task)
    expected_checks = {cid for gate in gates for cid in gate.get("checks", [])}
    if expected_checks:
        specifications = [c for c in task["required_checks"] if c["id"] in expected_checks]
        results = [c for c in report.get("checks", []) if c.get("id") in expected_checks]
        acceptance.verify_results({"required_checks": specifications}, results)
    expected_criteria = {cid for gate in gates for cid in gate.get("criteria", [])}
    if expected_criteria or report.get("review_checks"):
        records = report.get("review_checks", [])
        if not (isinstance(records, list)):
            raise ValueError("Invalid review_checks")
        seen = set()
        for record in records:
            if not (isinstance(record, dict)):
                raise ValueError("Invalid review check")
            cid = record.get("id")
            if not (isinstance(cid, str) and cid in expected_criteria and (cid not in seen)):
                raise ValueError("Unknown/duplicate review criterion")
            seen.add(cid)
            acceptance.ensure(
                record.get("result") in {"PASS", "NOT_APPLICABLE"}, "Review criterion not passed"
            )
            if not (isinstance(record.get("evidence"), str) and record["evidence"].strip()):
                raise ValueError("Review criterion needs evidence")
            if record["result"] == "NOT_APPLICABLE":
                if not (isinstance(record.get("reason"), str) and record["reason"].strip()):
                    raise ValueError("Review criterion needs applicability reason")
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


def stage_result(state: State, node: Node, report: Report) -> GateResult:
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
