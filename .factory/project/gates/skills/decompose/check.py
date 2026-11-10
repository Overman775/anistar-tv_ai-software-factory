"""AniStar task metadata constraints; architectural correctness needs review."""

from __future__ import annotations

import json
import sys
from typing import Any

LAYERS = {"domain", "data", "presentation", "navigation", "di", "api", "tests"}


def validate(tasks: dict[str, Any]) -> list[str]:
    errors = []
    for key, task in tasks.items():
        layers = task.get("affected_layers")
        if not isinstance(layers, list) or any(
            not isinstance(x, str) or x not in LAYERS for x in layers
        ):
            errors.append(f"{key}: affected_layers must list AniStar layers: {sorted(LAYERS)}")
        estimate = task.get("estimate_max_hours")
        if type(estimate) not in (int, float) or not 0 <= estimate <= 16:
            errors.append(
                f"{key}: estimated maximum must be within 0–16 hours; split oversized tasks"
            )
    return errors


if __name__ == "__main__":
    try:
        errors = validate(json.load(sys.stdin)["tasks"])
        status = "FAIL" if errors else "PASS"
    except (ValueError, KeyError, TypeError) as exc:
        errors = [f"Invalid decomposition input: {exc}"]
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
