"""Shared, model-independent acceptance data validation. Does not execute checks."""

from __future__ import annotations

import re
from typing import Any, cast

from factory_tooling.runtime.command_contract import validate_execution
from factory_tooling.runtime.contracts import (
    Check,
    Criterion,
    Task,
)


def ensure(condition: object, message: str) -> None:
    if not condition:
        raise ValueError(message)


def ids(value: object, label: str, *, empty: bool = False) -> set[str]:
    if not isinstance(value, list) or (not empty and not value):
        raise ValueError(f"Missing {label}")
    if not (all(isinstance(x, str) and x.strip() for x in value)):
        raise ValueError(f"Invalid {label}")
    ensure(len(set(value)) == len(value), f"Duplicate {label}")
    return cast(set[str], set(value))


def criteria_map(criteria: Any) -> dict[str, Criterion]:
    if not (isinstance(criteria, list) and criteria):
        raise ValueError("Missing acceptance criteria")
    result: dict[str, Criterion] = {}
    for c in criteria:
        if not (isinstance(c, dict)):
            raise ValueError("Invalid acceptance criterion")
        cid = c.get("id")
        if not (isinstance(cid, str) and re.fullmatch("AC-\\d{2,}", cid)):
            raise ValueError("Invalid AC identity")
        ensure(cid not in result, "Duplicate AC identity")
        for field in ("applies_to", "requirement", "verification"):
            if not (isinstance(c.get(field), str) and c[field].strip()):
                raise ValueError(f"Missing AC {field}")
        result[cid] = cast(Criterion, c)
    return result


def plan_criteria(text: str) -> list[Criterion]:
    """Read the single canonical table; ignore prose references to AC IDs."""
    marker = "### Acceptance criteria"
    ensure(text.count(marker) == 1, "Missing/duplicate acceptance table")
    section = re.split(r"\n#{1,3} ", text.split(marker, 1)[1], maxsplit=1)[0]
    rows = [
        [c.strip() for c in line.strip().strip("|").split("|")]
        for line in section.splitlines()
        if line.strip().startswith("|")
    ]
    ensure(
        rows and rows[0] == ["ID", "Applicability", "Criterion", "Verification"],
        "Invalid acceptance table header",
    )
    criteria: list[Criterion] = []
    for row in rows[1:]:
        if all(re.fullmatch(r":?-{3,}:?", cell) for cell in row):
            continue
        ensure(len(row) == 4, "Invalid acceptance row")
        cid, applies, requirement, verification = row
        if not (applies == "global" or re.fullmatch("CAP-\\d{2,}(?:,\\s*CAP-\\d{2,})*", applies)):
            raise ValueError("Invalid acceptance applicability")
        criteria.append(
            dict(id=cid, applies_to=applies, requirement=requirement, verification=verification)
        )
    criteria_map(criteria)
    return criteria


def check_plan(task: Task, available: dict[str, Criterion]) -> dict[str, Check]:
    selected = ids(task.get("acceptance_ids"), "task acceptance_ids", empty=True)
    contributions = ids(
        task.get("contributes_to_acceptance_ids", []), "contributes_to_acceptance_ids", empty=True
    )
    ensure(
        selected <= set(available) and contributions <= set(available),
        "Unknown task acceptance criterion",
    )
    local = task.get("local_acceptance_criteria", [])
    if not (isinstance(local, list)):
        raise ValueError("Invalid local_acceptance_criteria")
    local_ids = {"local:" + cid for cid in criteria_map(local)} if local else set()
    ensure(
        selected or (contributions and local_ids),
        "Missing task acceptance_ids or local contribution acceptance",
    )
    if contributions:
        if not (isinstance(task.get("parent_plan_ref"), str) and task["parent_plan_ref"].strip()):
            raise ValueError("Contribution needs parent plan provenance")
    selected |= local_ids
    checks = task.get("required_checks")
    if not (isinstance(checks, list) and checks):
        raise ValueError("Missing required_checks")
    known, covered = {}, set()
    for c in checks:
        if not (isinstance(c, dict)):
            raise ValueError("Invalid required check")
        cid = c.get("id")
        if not (isinstance(cid, str) and re.fullmatch("[A-Za-z0-9][A-Za-z0-9_-]*", cid)):
            raise ValueError("Invalid check ID")
        ensure(cid not in known, "Duplicate check ID")
        ensure(c.get("category") in {"acceptance", "project"}, "Invalid required check category")
        ensure(
            c.get("kind") in {"tests", "static", "docs", "build", "codegen", "observation"},
            "Invalid required check kind",
        )
        refs = ids(c.get("criteria"), "check criteria", empty=c["category"] == "project")
        ensure(refs <= selected, "Check references unknown task criterion")
        if not (isinstance(c.get("method"), str) and c["method"].strip()):
            raise ValueError("Missing check method")
        if c["kind"] != "observation":
            validate_execution(c.get("execution"))
        known[cid] = c
        covered |= refs
    ensure(covered == selected, "Acceptance criterion has no required check")
    return known


def successful(check: Check) -> bool:
    if check.get("kind") == "observation":
        return check.get("result") == "PASS" and bool(check.get("evidence"))
    return (
        type(check.get("exit_code")) is int
        and check["exit_code"] == 0
        and bool(check.get("command"))
        and bool(check.get("cwd"))
        and check.get("result", "PASS") == "PASS"
    )


def resolved_extra(check: Check) -> bool:
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


def verify_results(task: Task, checks: list[Check]) -> None:
    if not (isinstance(checks, list)):
        raise ValueError("Invalid checks")
    expected = {c["id"]: c for c in task["required_checks"]}
    actual = {}
    for check in checks:
        if not (isinstance(check, dict)):
            raise ValueError("Invalid check result")
        cid = check.get("id")
        if not (isinstance(cid, str) and cid and (cid not in actual)):
            raise ValueError("Missing/duplicate result check ID")
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
