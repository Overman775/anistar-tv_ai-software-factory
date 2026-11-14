"""Core transition definitions, shared by executors and the generated gate map."""

import argparse
import json
from collections.abc import Iterable
from typing import TypedDict

from factory.gates.gate_contract import GateResult
from factory.paths import FACTORY_ROOT

CORE: dict[str, tuple[str, str, str, list[str]]] = {
    "planning.complete": (
        "factory-planning",
        "Planning coordinator",
        "gates/skills/planning/gate.md",
        ["plan-contract", "plan-review", "approval"],
    ),
    "decompose.complete": (
        "factory-decompose",
        "Decompose assembler",
        "gates/skills/decompose/gate.md",
        ["source", "graph", "project-checks", "task-review"],
    ),
    "code-review.complete": (
        "factory-code-review",
        "Review protocol validator",
        "gates/skills/code-review/gate.md",
        ["review-protocol"],
    ),
}
for stage in ("explore", "work", "docs", "verify", "review", "accept"):
    CORE["implement." + stage] = (
        "factory-implement-" + stage,
        "Implement runtime",
        "gates/skills/implement.md",
        ["stage-contract"],
    )


class GateDefinition(TypedDict):
    id: str
    at: list[str]
    executor: str
    instructions: str
    requirements: list[str]


def definition(boundary: str) -> GateDefinition:
    key, owner, instructions, requirements = CORE[boundary]
    return {
        "id": key,
        "at": [boundary],
        "executor": owner,
        "instructions": instructions,
        "requirements": list(requirements),
    }


def core_result(
    boundary: str, subject: str, policy_hash: str, artifact_hash: str, records: Iterable[object]
) -> GateResult:
    from factory.gates.gate_contract import conclude

    item = definition(boundary)
    return conclude(
        item["id"], boundary, subject, policy_hash, artifact_hash, item["requirements"], records
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", default=str(FACTORY_ROOT / "factory.yaml"))
    args = parser.parse_args()
    from factory.project.profile_io import load_profile
    from factory.project.project import configured_profile

    policy = load_profile(configured_profile(args.config))
    rows = [definition(b) | {"owner": "factory"} for b in CORE]
    for gate in policy["data"].get("gates", []):
        rows.append(
            {
                "id": gate["id"],
                "at": gate["at"],
                "owner": "project",
                "executor": [definition(b)["executor"] for b in gate["at"]],
                "requirements": [c["id"] for c in gate.get("checks", gate.get("criteria", []))],
            }
        )
    print(json.dumps(rows, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
