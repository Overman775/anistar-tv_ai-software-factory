"""Compute and apply the same evidence obligations at dispatch and handoff."""

from factory.project.contracts import ProjectData
from factory.project.profile_rules import (
    boundary_gates,
    check_definition,
    project_checks,
    registered_check,
)
from factory.runtime.contracts import (
    CheckApprovalPolicy,
    CheckResult,
    Node,
    Report,
    State,
    agent_key,
)
from factory.runtime.contracts import FinishRequirements as FinishRequirements
from factory.runtime.reports import acceptance
from factory.runtime.workflow_core import acceptance_guard
from factory.tasks.contracts import Task


def requirements(
    profile: ProjectData, node: Node, task: Task, role: str | None
) -> FinishRequirements:
    stage = node["stage"]
    gates = boundary_gates(profile, "implement." + stage, task)
    all_checks = list(task["required_checks"])
    selected = node.get("required_check_ids")
    if selected is not None and role == "tester" and stage == "verify":
        declared = {check["id"] for check in all_checks}
        all_checks.extend(
            registered_check(profile, cid, task["scope"]) for cid in selected if cid not in declared
        )
        gates = [
            {**gate, "checks": [cid for cid in gate.get("checks", []) if cid in selected]}
            for gate in gates
        ]
    by_id = {c["id"]: c for c in all_checks}
    gated = {cid for gate in gates for cid in gate.get("checks", [])}
    full = stage == "verify" and selected is None
    verification_ids = {
        check["id"]
        for check in all_checks
        if (
            check.get("assessor") != "judge"
            if check["kind"] == "observation"
            else not check["execution"].get("outputs")
        )
    }
    required = gated | (verification_ids if full else set(selected or []))
    if selected is not None:
        acceptance.ensure(set(selected) <= set(by_id), "Unknown node required check")
    if role == "judge":
        required = {cid for cid in required if by_id[cid]["kind"] == "observation"}
        required.update(
            check["id"]
            for check in all_checks
            if check["kind"] == "observation" and check.get("assessor") == "judge"
        )
    commands = "project-checks" in node.get("resources", [])
    if selected is not None:
        acceptance.ids(selected, "node required_check_ids", empty=True)
        acceptance.ensure(stage not in {"accept", "explore"}, "Node cannot select checks")
        acceptance.ensure(required <= set(by_id), "Unknown node required check")
    allowed = [
        check
        for check in all_checks
        if (selected is None or check["id"] in required)
        and (
            (check["kind"] == "observation" and check.get("assessor") in {None, role})
            or (
                check["kind"] != "observation"
                and commands
                and (
                    (
                        role == "tester"
                        and check["kind"] != "codegen"
                        and not check["execution"].get("outputs")
                    )
                    or (
                        role in {"implementer", "doc-writer"}
                        and check["kind"] == "codegen"
                        and bool(check["execution"].get("outputs"))
                        and set(check["execution"]["outputs"]) <= set(node.get("owns", []))
                    )
                )
            )
        )
    ]
    for check in allowed:
        if role in {"implementer", "doc-writer"} and check["kind"] == "codegen":
            check_definition(registered_check(profile, check["id"], task["scope"]), check)
            acceptance.ensure(
                check["id"] in gated, "Code generation needs a registered producer boundary"
            )
    available = {check["id"] for check in allowed}
    acceptance.ensure(
        required <= available,
        "Required checks need project-checks reservation and exact output ownership",
    )
    approval_policies: dict[str, CheckApprovalPolicy] = {}
    for entry in project_checks(profile):
        if (
            role == "tester"
            and stage == "verify"
            and entry["id"] in available
            and (action := entry.get("approval_action"))
        ):
            approval_policies[entry["id"]] = {"action": action}
            if pattern := entry.get("approval_path_regex"):
                approval_policies[entry["id"]]["path_regex"] = pattern
        if entry["id"] in required:
            acceptance.ensure(
                set(entry.get("after", [])) <= available,
                "Missing registered prerequisites for check " + entry["id"],
            )
    for check in allowed:
        if check["kind"] == "observation":
            continue
        stages = check["execution"].get("stages", [])
        if stages:
            registered = {entry["id"] for entry in project_checks(profile)}
            acceptance.ensure(
                {check["id"], *stages} <= registered
                and set(stages) <= available
                and check["id"] not in stages
                and all(
                    stage_check["kind"] != "observation"
                    and not stage_check["execution"].get("stages")
                    and stage_check["execution"].get("mode") == "full"
                    and not stage_check["execution"].get("outputs")
                    for stage_check in (by_id[cid] for cid in stages)
                ),
                "Composite requires registered, assigned direct read-only stages declared full",
            )
    test_receipt = False
    kinds = ["static", "tests", "docs"] if full else []
    result: FinishRequirements = {
        "allowed_checks": allowed,
        "required_checks": [check for check in all_checks if check["id"] in required],
        "gates": gates,
        "evidence_kinds": kinds,
        "not_applicable_allowed": [
            kind
            for kind in kinds
            if (kind != "tests" or task["risk"] != "high")
            and not any(c["kind"] == kind for c in all_checks)
        ],
        "require_test_receipt": test_receipt,
        "require_approval": stage == "review",
        "require_writes_ready": role == "implementer"
        and bool(node.get("owns"))
        and not any(check["kind"] == "codegen" for check in allowed),
        "require_evidence": stage == "verify",
    }
    if approval_policies:
        result["approval_policies"] = approval_policies
    return result


def validate_selection(obligations: FinishRequirements, checks: list[CheckResult]) -> None:
    allowed = {check["id"] for check in obligations["allowed_checks"]}
    for check in checks:
        acceptance.ensure(
            (
                check.get("category") == "additional"
                and (check.get("kind") == "observation" or bool(obligations["evidence_kinds"]))
            )
            or check.get("id") in allowed,
            f"Check not assigned to this node: {check.get('id')}",
        )


def validate_tester_outcome(
    state: State, node: Node, obligations: FinishRequirements, report: Report
) -> None:
    if node["stage"] != "verify" or report["stage_result"] not in {"FAIL_CODE", "FAIL_TEST"}:
        return
    assigned = {
        check["id"] for check in obligations["required_checks"] if check["kind"] != "observation"
    }
    latest = {
        record["spec"]["id"]: record["status"]
        for record in state.get("executions", {}).values()
        if record["node_id"] == node["id"] and record["dispatch_id"] == report["dispatch_id"]
    }
    if not assigned or not all(latest.get(cid) == "PASS" for cid in assigned):
        return
    checks = report.get("checks", [])
    acceptance.ensure(
        acceptance.has_failed_observation(obligations["allowed_checks"], checks)
        or any(
            check.get("result") == "FAIL"
            and bool(check.get("evidence", "").strip())
            and latest.get(check["id"]) == "FAIL"
            for check in checks
        ),
        "Assigned commands passed. Return VERIFIED with coverage_notes for Judge, or include an assigned failed observation.",
    )


def validate_pass(obligations: FinishRequirements, report: Report) -> None:
    checks = report.get("checks", [])
    validate_selection(obligations, checks)
    required = obligations["required_checks"]
    required_ids = {check["id"] for check in required}
    acceptance.verify_results(
        required,
        [check for check in checks if check.get("id") in required_ids],
    )
    kinds = {c.get("kind") for c in checks if acceptance.successful(c)}
    reasons = report.get("not_applicable", {})
    acceptance.ensure(
        not obligations["evidence_kinds"]
        or set(reasons) <= set(obligations["not_applicable_allowed"]),
        "Not-applicable reason cannot replace assigned evidence",
    )
    for kind in obligations["evidence_kinds"]:
        if kind not in kinds:
            if kind not in obligations["not_applicable_allowed"]:
                raise ValueError(f"Missing {kind} receipt")
            reason = reasons.get(kind)
            if not (isinstance(reason, str) and reason.strip()):
                raise ValueError(f"Missing {kind} evidence or justified not_applicable reason")
    if obligations["require_test_receipt"]:
        acceptance.ensure(
            report.get("stage_result") != "WRITES_READY",
            "A required test receipt cannot be replaced by WRITES_READY",
        )
        test_ids = {c["id"] for c in obligations["allowed_checks"] if c["kind"] == "tests"}
        acceptance.ensure(
            any(c.get("id") in test_ids and acceptance.successful(c) for c in checks),
            "Missing required successful tests receipt",
        )
    if obligations["require_writes_ready"]:
        acceptance.ensure(
            report.get("stage_result") == "WRITES_READY",
            "Unlocked writer returns WRITES_READY, checks deferred",
        )
    if obligations["require_evidence"]:
        acceptance.ensure(checks, "Missing verification evidence")
    if obligations["require_approval"]:
        acceptance.ensure(report.get("verdict") == "APPROVE", "Missing independent APPROVE")


def for_node(state: State, node: Node) -> FinishRequirements:
    return acceptance_guard(
        requirements,
        state["config"]["_project"]["data"],
        node,
        state["graph"]["tasks"][node["task"]],
        state["graph"]["agents"][agent_key(node)]["role"],
    )
