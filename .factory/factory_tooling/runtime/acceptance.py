"""Shared, model-independent acceptance data validation. Does not execute checks."""

from __future__ import annotations

import re
from typing import Annotated

from pydantic import ConfigDict, Field, TypeAdapter, ValidationError

from factory_tooling.runtime.contracts import (
    CheckResult,
    CheckSpec,
    Criterion,
    Nonblank,
    Task,
)
from factory_tooling.validation import validation_message

IDS = TypeAdapter[list[str]](list[Nonblank], config=ConfigDict(strict=True))
CRITERIA = TypeAdapter[list[Criterion]](
    Annotated[list[Criterion], Field(min_length=1)], config=ConfigDict(strict=True)
)


def ensure(condition: object, message: str) -> None:
    if not condition:
        raise ValueError(message)


def ids(value: object, label: str, *, empty: bool = False) -> set[str]:
    try:
        values = IDS.validate_python(value)
    except ValidationError as exc:
        raise ValueError(validation_message(f"Missing or invalid {label}", exc, IDS)) from None
    ensure(empty or values, f"Missing {label}")
    ensure(len(set(values)) == len(values), f"Duplicate {label}")
    return set(values)


def criteria_map(criteria: object) -> dict[str, Criterion]:
    try:
        entries = CRITERIA.validate_python(criteria)
    except ValidationError as exc:
        raise ValueError(
            validation_message("Missing or invalid acceptance criteria", exc, CRITERIA)
        ) from None
    result: dict[str, Criterion] = {}
    for criterion in entries:
        cid = criterion["id"]
        ensure(cid not in result, "Duplicate AC identity")
        result[cid] = criterion
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
