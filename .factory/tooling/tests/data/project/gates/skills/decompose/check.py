"""AniStar task metadata constraints; architectural correctness needs review."""

from __future__ import annotations

import json
import sys
from typing import Annotated, Literal

from pydantic import ConfigDict, Field, TypeAdapter, ValidationError, with_config
from typing_extensions import TypedDict


@with_config(ConfigDict(strict=True, extra="ignore"))
class TaskMetadata(TypedDict):
    # The factory supplies a richer task record. AniStar owns these fields.
    affected_layers: list[
        Literal["domain", "data", "presentation", "navigation", "di", "api", "tests"]
    ]
    estimate_max_hours: Annotated[float, Field(ge=0, le=16, allow_inf_nan=False)]


@with_config(ConfigDict(strict=True, extra="ignore"))
class GateInput(TypedDict):
    tasks: dict[str, object]


INPUT = TypeAdapter[GateInput](GateInput)
METADATA = TypeAdapter[TaskMetadata](TaskMetadata)


def validate(tasks: dict[str, object]) -> list[str]:
    errors = []
    for key, task in tasks.items():
        try:
            METADATA.validate_python(task)
        except ValidationError as exc:
            for issue in exc.errors(include_input=False, include_context=False, include_url=False):
                field = ".".join(map(str, issue["loc"]))
                errors.append(f"{key}: {field}: {issue['msg']}")
    return errors


if __name__ == "__main__":
    try:
        errors = validate(INPUT.validate_json(sys.stdin.read())["tasks"])
        status = "FAIL" if errors else "PASS"
    except ValidationError:
        errors = ["Invalid decomposition input: expected tasks keyed by ID"]
        status = "BLOCKED"
    print(
        json.dumps(
            {
                "status": status,
                "message": "; ".join(errors) or "AniStar task metadata passed",
                "evidence": ["stdin task metadata: affected_layers, estimate_max_hours"],
            },
            ensure_ascii=False,
        )
    )
    sys.exit({"PASS": 0, "FAIL": 1, "BLOCKED": 2}[status])
