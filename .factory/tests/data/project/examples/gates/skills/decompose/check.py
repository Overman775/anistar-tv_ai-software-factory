"""Example: require a task outcome; customize for real project requirements."""

from __future__ import annotations

import json
import sys
from typing import Annotated

from pydantic import ConfigDict, StringConstraints, TypeAdapter, ValidationError, with_config
from typing_extensions import TypedDict


@with_config(ConfigDict(strict=True, extra="ignore"))
class TaskOutcome(TypedDict):
    outcome: Annotated[str, StringConstraints(pattern=r"\S")]


@with_config(ConfigDict(strict=True, extra="ignore"))
class GateInput(TypedDict):
    tasks: dict[str, object]


INPUT = TypeAdapter[GateInput](GateInput)
OUTCOME = TypeAdapter[TaskOutcome](TaskOutcome)

if __name__ == "__main__":
    try:
        tasks = INPUT.validate_json(sys.stdin.read())["tasks"]
    except ValidationError:
        print(
            json.dumps(
                {"status": "BLOCKED", "message": "Invalid tasks input", "evidence": ["stdin"]}
            )
        )
        sys.exit(2)
    errors = []
    for key, task in tasks.items():
        try:
            OUTCOME.validate_python(task)
        except ValidationError:
            errors.append(key)
    print(
        json.dumps(
            {
                "status": "FAIL" if errors else "PASS",
                "message": "Missing outcomes: " + ", ".join(errors)
                if errors
                else "Project task outcomes passed",
                "evidence": ["stdin task outcomes"],
            }
        )
    )
    sys.exit(bool(errors))
