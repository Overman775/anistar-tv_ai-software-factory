"""Publish a typed example proposal in the current checkout."""

from pathlib import Path

from factory.runtime.graph_inputs import ProposedGraph, propose


def proposal() -> ProposedGraph:
    return {
        "sources": {
            "request": {
                "text": "Example only: add a playback preference. Save it, "
                "restore it and apply it to playback; verify "
                "UI-to-storage-to-playback behavior. Do not change "
                "authentication or network trust.",
                "acceptance": [
                    {
                        "id": "AC-01",
                        "applies_to": "global",
                        "requirement": "Preference is applied to playback",
                        "verification": "Verify UI-to-playback behavior",
                    },
                    {
                        "id": "AC-02",
                        "applies_to": "global",
                        "requirement": "Preference survives restart",
                        "verification": "Save, restart and restore",
                    },
                ],
            }
        },
        "agents": {
            "implementer": {"role": "implementer", "profile": "middle-implementer"},
            "tester": {"role": "tester", "profile": "tester"},
            "reviewer": {"role": "judge", "profile": "judge"},
        },
        "tasks": {
            "preference": {
                "slice": "save-and-apply-preference",
                "source": "request",
                "outcome": "A preference persists and controls playback consistently",
                "reason": "Crosses UI, persistence and playback lifecycle; "
                "separate verification and independent review "
                "required",
                "risk": "high",
                "kind": "feature",
                "independent_review": True,
                "scope": [
                    "lib/example_preference.dart",
                    "test/example_preference_test.dart",
                    "docs/example_preference.md",
                ],
                "depends_on": [],
                "acceptance_ids": ["AC-01", "AC-02"],
                "required_checks": [
                    {
                        "id": "behavior",
                        "category": "acceptance",
                        "criteria": ["AC-01", "AC-02"],
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
                        "reason": "Planned "
                        "final "
                        "anistar-check "
                        "runs the "
                        "complete "
                        "static "
                        "triplet on "
                        "the "
                        "integrated "
                        "candidate; "
                        "no explicit "
                        "early "
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
                "id": "implement",
                "task": "preference",
                "stage": "work",
                "agent": "implementer",
                "depends_on": [],
                "owns": [
                    "lib/example_preference.dart",
                    "test/example_preference_test.dart",
                    "docs/example_preference.md",
                ],
                "resources": [],
            },
            {
                "id": "verify",
                "task": "preference",
                "stage": "verify",
                "agent": "tester",
                "depends_on": ["implement"],
                "owns": [],
                "resources": ["project-checks"],
            },
            {
                "id": "review",
                "task": "preference",
                "stage": "review",
                "agent": "reviewer",
                "depends_on": ["verify"],
                "owns": [],
                "resources": ["project-checks"],
            },
            {
                "id": "accept",
                "task": "preference",
                "stage": "accept",
                "agent": None,
                "depends_on": ["review"],
                "owns": [],
                "resources": [],
            },
        ],
    }


if __name__ == "__main__":
    print(propose(Path.cwd(), proposal()))
