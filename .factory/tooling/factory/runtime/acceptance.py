"""Shared, model-independent acceptance data validation. Does not execute checks."""

from __future__ import annotations

from factory.checks.contracts import CheckSpec
from factory.runtime.contracts import CheckResult
from factory.tasks.contracts import Criterion, Task
from factory.tasks.criteria import criteria_map as criteria_map
from factory.tasks.criteria import ensure as ensure
from factory.tasks.criteria import ids as ids
from factory.tasks.criteria import plan_criteria as plan_criteria


def check_plan(task: Task, available: dict[str, Criterion]) -> None:
    selected = ids(task.get("acceptance_ids"), "task acceptance_ids", empty=True)
    contributions = ids(
        task.get("contributes_to_acceptance_ids", []), "contributes_to_acceptance_ids", empty=True
    )
    ensure(
        selected <= set(available) and contributions <= set(available),
        "Unknown task acceptance criterion",
    )
    local = task.get("local_acceptance_criteria", [])
    local_ids = {"local:" + cid for cid in criteria_map(local)} if local else set()
    ensure(
        selected or (contributions and local_ids),
        "Missing task acceptance_ids or local contribution acceptance",
    )
    if contributions:
        if not (isinstance(task.get("parent_plan_ref"), str) and task["parent_plan_ref"].strip()):
            raise ValueError("Contribution needs parent plan provenance")
    selected |= local_ids
    checks = task["required_checks"]
    ensure(checks, "Missing required checks")
    known: set[str] = set()
    covered: set[str] = set()
    for c in checks:
        cid = c["id"]
        ensure(cid not in known, "Duplicate check ID")
        refs = set(c["criteria"])
        ensure(refs or c["category"] == "project", "Missing check criteria")
        ensure(len(refs) == len(c["criteria"]), "Duplicate check criteria")
        ensure(refs <= selected, "Check references unknown task criterion")
        known.add(cid)
        covered |= refs
    ensure(covered == selected, "Acceptance criterion has no required check")


def successful(check: CheckResult) -> bool:
    if check.get("kind") == "observation":
        return check.get("result") == "PASS" and bool(check.get("evidence"))
    return (
        type(check.get("exit_code")) is int
        and check["exit_code"] == 0
        and bool(check.get("command"))
        and bool(check.get("cwd"))
        and check.get("result", "PASS") == "PASS"
    )


def resolved_extra(check: CheckResult) -> bool:
    """A non-required check may be inconclusive, but never silently ignored."""
    resolution = check.get("resolution")
    if isinstance(resolution, dict) and resolution.get("disposition") == "not_run":
        if check.get("exit_code") is not None or check.get("result") != "NOT_RUN":
            return False
    return (
        check.get("category") == "additional"
        and isinstance(resolution, dict)
        and resolution.get("disposition") in {"out_of_scope", "invalid_check", "not_run"}
        and isinstance(resolution.get("reason"), str)
        and bool(resolution["reason"].strip())
    )


def verify_results(specifications: list[CheckSpec], checks: list[CheckResult]) -> None:
    expected = {c["id"]: c for c in specifications}
    actual = {}
    for check in checks:
        cid = check["id"]
        ensure(cid not in actual, "Duplicate result check ID")
        actual[cid] = check
        if cid in expected:
            spec = expected[cid]
            ensure(check.get("category") == spec["category"], "Required check category changed")
            ensure(check.get("kind") == spec["kind"], "Required check kind changed")
            ensure(
                ids(check.get("criteria"), "result criteria", empty=True) == set(spec["criteria"]),
                "Required check criteria changed",
            )
            ensure(check.get("method") == spec["method"], "Required check method changed")
            if not (
                successful(check)
                and isinstance(check.get("evidence"), str)
                and check["evidence"].strip()
            ):
                raise ValueError(f"Required check not passed: {cid}")
        else:
            ensure(check.get("category") == "additional", "Undeclared check must be additional")
            ensure(
                successful(check) or resolved_extra(check),
                "Additional failure needs explicit resolution",
            )
    missing = sorted(set(expected) - set(actual))
    ensure(not missing, "Missing required check results: " + ", ".join(missing))
