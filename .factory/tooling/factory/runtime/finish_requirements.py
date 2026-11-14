"""Compute and apply the same evidence obligations at dispatch and handoff."""

from factory.project.contracts import ProjectData
from factory.project.profile_rules import boundary_gates, project_checks
from factory.runtime import acceptance
from factory.runtime.contracts import CheckResult, Node, Report
from factory.runtime.contracts import FinishRequirements as FinishRequirements
from factory.tasks.contracts import Task


def requirements(
    profile: ProjectData, node: Node, task: Task, role: str | None
) -> FinishRequirements:
    stage = node["stage"]
    gates = boundary_gates(profile, "implement." + stage, task)
    all_checks = task["required_checks"]
    by_id = {c["id"]: c for c in all_checks}
    gated = {cid for gate in gates for cid in gate.get("checks", [])}
    selected = node.get("required_check_ids")
    full = stage == "verify" and selected is None
    verification_ids = {
        check["id"]
        for check in all_checks
        if check["kind"] == "observation" or not check["execution"].get("outputs")
    }
    required = gated | (verification_ids if full else set(selected or []))
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
            check["kind"] == "observation"
            or (
                commands and set(check["execution"].get("outputs", [])) <= set(node.get("owns", []))
            )
        )
    ]
    available = {check["id"] for check in allowed}
    acceptance.ensure(
        required <= available,
        "Required checks need project-checks reservation and exact output ownership",
    )
    for registered_check in project_checks(profile):
        if registered_check["id"] in required:
            acceptance.ensure(
                set(registered_check.get("after", [])) <= available,
                "Missing registered prerequisites for check " + registered_check["id"],
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
    test_receipt = stage == "work" and role == "test-writer" and commands
    if test_receipt:
        acceptance.ensure(
            any(c["kind"] == "tests" for c in allowed),
            "TestWriter needs an assigned tests receipt before dispatch",
        )
    kinds = ["static", "tests", "docs"] if full else []
    return {
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
        "require_writes_ready": bool(node.get("owns")) and not commands,
        "require_evidence": stage in {"verify", "review"},
    }


def validate_selection(obligations: FinishRequirements, checks: list[CheckResult]) -> None:
    allowed = {check["id"] for check in obligations["allowed_checks"]}
    for check in checks:
        acceptance.ensure(
            check.get("category") == "additional" or check.get("id") in allowed,
            f"Check not assigned to this node: {check.get('id')}",
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
            report.get("stage_result") != "WRITES_READY", "TestWriter checks required"
        )
        test_ids = {c["id"] for c in obligations["allowed_checks"] if c["kind"] == "tests"}
        acceptance.ensure(
            any(c.get("id") in test_ids and acceptance.successful(c) for c in checks),
            "TestWriter needs a successful tests receipt",
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
