"""Acceptance criterion identifiers and canonical planning-table parsing."""

import re
from typing import Annotated

from pydantic import ConfigDict, Field, TypeAdapter, ValidationError

from factory.tasks.contracts import Criterion, Nonblank
from factory.validation import validation_message

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
