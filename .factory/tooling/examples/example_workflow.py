"""Publish a typed example proposal in the current checkout."""

from pathlib import Path

from factory.runtime.graph_inputs import ProposedGraph, propose


def proposal() -> ProposedGraph:
    return {
        "sources": {
            "request": {
                "text": "Correct the specified label; preserve behavior.",
                "acceptance": [
                    {
                        "id": "AC-01",
                        "applies_to": "global",
                        "requirement": "Specified label is shown without behavior change",
                        "verification": "Check the label and unchanged action",
                    }
                ],
            }
        },
        "agents": {
            "author": {"role": "implementer", "profile": "middle-implementer"},
            "tester": {"role": "tester", "profile": "tester"},
        },
        "tasks": {
            "label": {
                "slice": "ui-copy",
                "source": "request",
                "outcome": "Specified label is shown",
                "reason": "Local copy-only change with direct oracle",
                "risk": "low",
                "kind": "fix",
                "independent_review": False,
                "scope": ["lib/example.dart"],
                "depends_on": [],
                "acceptance_ids": ["AC-01"],
                "required_checks": [
                    {
                        "id": "behavior",
                        "category": "acceptance",
                        "criteria": ["AC-01"],
                        "method": "Direct behavior regression for the declared criteria",
                        "kind": "tests",
                        "execution": {
                            "argv": ["flutter", "test", "test/REPLACE_WITH_ACTUAL_TEST.dart"],
                            "cwd": ".",
                            "timeout_seconds": 600,
                        },
                    }
                ],
                "policy_decisions": {
                    "dart-changes": {
                        "reason": "Planned final "
                        "anistar-check "
                        "runs the "
                        "complete static "
                        "triplet on the "
                        "integrated "
                        "candidate; no "
                        "explicit early "
                        "static "
                        "requirement.",
                        "probability": 0.1,
                        "source": "agent:coordinator (illustrative estimate)",
                    },
                    "application-changes": {
                        "reason": "Example "
                        "assumes "
                        "application/Dart "
                        "behavior "
                        "changes; "
                        "replace "
                        "with "
                        "actual "
                        "scoped "
                        "evidence "
                        "before "
                        "use.",
                        "probability": 0.9,
                        "source": "agent:coordinator (illustrative estimate)",
                    },
                },
                "project_check_inputs": {},
            }
        },
        "nodes": [
            {
                "id": "write-label",
                "task": "label",
                "stage": "work",
                "agent": "author",
                "depends_on": [],
                "owns": ["lib/example.dart"],
                "resources": ["project-checks"],
            },
            {
                "id": "verify-label",
                "task": "label",
                "stage": "verify",
                "agent": "tester",
                "depends_on": ["write-label"],
                "owns": [],
                "resources": ["project-checks"],
            },
            {
                "id": "accept-label",
                "task": "label",
                "stage": "accept",
                "agent": None,
                "depends_on": ["verify-label"],
                "owns": [],
                "resources": [],
            },
        ],
    }


if __name__ == "__main__":
    print(propose(Path.cwd(), proposal()))
