"""Transition gates: real runner receipts and independent review evidence."""

from __future__ import annotations

import sys
import unittest
from collections.abc import Callable
from typing import Any

import yaml

from factory_tooling.project.contracts import ProjectCheck, ProjectData
from factory_tooling.project.profile_io import load_profile
from factory_tooling.project.profile_rules import required_checks, validate
from factory_tooling.runtime.contracts import ContextNode, TaskSelection
from factory_tooling.runtime.transition_gates import evaluate
from factory_tooling.runtime.workflow_core import Invalid
from factory_tooling.runtime.workflow_graph import validate_graph
from tests.factory_tooling.runtime import test_workflow


def check(cid: str = "lint", code: int = 0) -> ProjectCheck:
    return {
        "id": cid,
        "level": "slice",
        "kind": "static",
        "method": "Fixture static check",
        "execution": {
            "argv": [sys.executable, "-c", f"raise SystemExit({code})"],
            "cwd": ".",
            "timeout_seconds": 10,
        },
    }


def policy(checks: list[ProjectCheck] | None = None) -> ProjectData:
    return {
        "id": "gates",
        "gates": [{"id": "work-ready", "at": ["implement.work"], "checks": checks or [check()]}],
    }


class GateTests(unittest.TestCase):
    def setUp(self) -> None:
        self.f = test_workflow.WorkflowTests()
        self.f.setUp()
        self.addCleanup(self.f.doCleanups)

    def install(self, data: ProjectData) -> None:
        f = self.f
        f.fixture_profile.write_text(yaml.safe_dump(data))
        f.config["_project"] = load_profile(f.fixture_profile)
        f.config["_files"].update(f.config["_project"]["files"])
        f.g["tasks"]["label"]["required_checks"] += required_checks(
            data, f.g["tasks"]["label"], final=True
        )

    def work_setup(self, code: int = 0) -> test_workflow.WorkflowTests:
        f = self.f
        self.install(policy([check(code=code)]))
        f.g["nodes"][0]["resources"] = ["project-checks"]
        f.init()
        f.start("write-label")
        return f

    def test_missing_receipt_blocks_work_and_next_stage_then_real_pass_opens_it(self) -> None:
        f = self.work_setup()
        with self.assertRaisesRegex(Invalid, "Missing required check"):
            f.ledger.finish("write-label", f.report("write-label", checks=[]))
        self.assertEqual("running", f.ledger.read()["nodes"]["write-label"]["status"])
        with self.assertRaisesRegex(Invalid, "Dependencies"):
            f.ledger.claim("verify-label")
        forged: dict[str, Any] = {
            **f.g["tasks"]["label"]["required_checks"][-1],
            "result": "PASS",
            "exit_code": 0,
            "command": ["fake"],
            "cwd": ".",
            "evidence": "claimed",
        }
        with self.assertRaisesRegex(Invalid, "receipt"):
            f.ledger.finish("write-label", f.report("write-label", checks=[forged]))
        receipt = f.ledger.run_check("write-label", "lint")
        f.ledger.finish("write-label", f.report("write-label", checks=[receipt]))
        report = f.ledger.read()["nodes"]["write-label"]["report"]
        self.assertEqual(
            ["factory-implement-work", "work-ready"], [g["gate_id"] for g in report["gate_results"]]
        )
        self.assertTrue(
            all(g["status"] == "PASS" and g["artifact_hash"] for g in report["gate_results"])
        )
        f.start("verify-label")
        # Early success cannot replace the final verification's own fresh receipt.
        with self.assertRaisesRegex(Invalid, "Missing required check"):
            f.ledger.finish("verify-label", f.report("verify-label"))
        final = f.report("verify-label")
        final["checks"].append(f.ledger.run_check("verify-label", "lint"))
        f.ledger.finish("verify-label", final)
        f.ledger.accept("accept-label")

    def test_failed_command_can_report_failure_but_cannot_release_next_stage(self) -> None:
        f = self.work_setup(code=1)
        failed = f.ledger.run_check("write-label", "lint")
        self.assertEqual("FAIL", failed["result"])
        with self.assertRaisesRegex(Invalid, "Failed/incomplete"):
            f.ledger.finish("write-label", f.report("write-label", checks=[failed]))
        f.ledger.finish(
            "write-label",
            f.report(
                "write-label", outcome="FAIL", checks=[failed], gate_results=[{"status": "PASS"}]
            ),
        )
        self.assertEqual("blocked", f.ledger.read()["nodes"]["write-label"]["status"])
        self.assertEqual(
            "FAIL", f.ledger.read()["nodes"]["write-label"]["report"]["gate_results"][0]["status"]
        )
        with self.assertRaisesRegex(Invalid, "Dependencies"):
            f.ledger.claim("verify-label")

    def test_work_gate_rejects_stale_receipt(self) -> None:
        f = self.work_setup()
        receipt = f.ledger.run_check("write-label", "lint")
        (f.root / "lib/example.dart").write_text("changed after checking")
        with self.assertRaisesRegex(Invalid, "invalidated"):
            f.ledger.finish("write-label", f.report("write-label", checks=[receipt]))

    def test_stage_command_gate_requires_reservation_at_graph_validation(self) -> None:
        f = self.f
        self.install(policy())
        with self.assertRaisesRegex(Invalid, "project-checks reservation"):
            validate_graph(f.g, f.config, f.root)

    def test_integrated_review_requires_criteria_before_approval_and_acceptance(self) -> None:
        f = self.f
        data: ProjectData = {
            "id": "review-policy",
            "gates": [
                {
                    "id": "review-ready",
                    "at": ["implement.review", "code-review.complete"],
                    "criteria": [
                        {"id": "API", "lens": "system-design", "question": "Contract preserved?"}
                    ],
                }
            ],
        }
        self.install(data)
        f.g["tasks"]["label"]["independent_review"] = True
        f.g["agents"]["judge"] = {"role": "judge", "profile": f.config["_roles"]["judge"][0]}
        f.g["nodes"].append(
            {
                "id": "review-label",
                "task": "label",
                "stage": "review",
                "agent": "judge",
                "depends_on": ["verify-label"],
                "owns": [],
                "resources": ["project-checks"],
            }
        )
        next(n for n in f.g["nodes"] if n["stage"] == "accept")["depends_on"] = ["review-label"]
        f.init()
        f.start("write-label")
        f.ledger.finish("write-label", f.report("write-label"))
        f.start("verify-label")
        f.ledger.finish("verify-label", f.report("verify-label"))
        f.start("review-label", "independent-judge")
        with self.assertRaisesRegex(Invalid, "Missing required review"):
            f.ledger.finish("review-label", f.report("review-label", verdict="APPROVE"))
        report = f.report(
            "review-label",
            verdict="APPROVE",
            review_checks=[
                {
                    "id": "API",
                    "result": "PASS",
                    "evidence": "Compared lib/example.dart with the declared contract",
                }
            ],
        )
        f.ledger.finish("review-label", report)
        f.ledger.accept("accept-label")
        self.assertEqual(
            "PASS", f.ledger.read()["nodes"]["review-label"]["report"]["gate_results"][0]["status"]
        )

    def test_schema_rejects_unsupported_boundaries_types_and_cross_boundary_dependency(
        self,
    ) -> None:
        mutations_188: list[Callable[[Any], object]] = [
            lambda d: d.update(checks=[]),
            lambda d: d["gates"][0].update(at=["planning.complete"]),
            lambda d: d["gates"][0].update(at=["implement.review"]),
            lambda d: d["gates"][0].update(checks=[]),
            lambda d: d["gates"][0]["checks"][0].update(level="final"),
            lambda d: d["gates"][0]["checks"][0].update(after=["elsewhere"]),
        ]
        for change in mutations_188:
            data = policy()
            change(data)
            with self.subTest(data=data), self.assertRaises(ValueError):
                validate(data)

    def test_review_no_unexplained_na_duplicates_or_unrun_criteria(self) -> None:
        data: ProjectData = {
            "id": "fixture",
            "gates": [
                {
                    "id": "review",
                    "at": ["implement.review"],
                    "criteria": [
                        {"id": "API", "lens": "system-design", "question": "Compatibility?"}
                    ],
                }
            ],
        }
        node: ContextNode = {"id": "review-task", "stage": "review"}
        task: TaskSelection = {"scope": ["api.py"]}
        for records in [
            [],
            [{"id": "API", "result": "NOT_APPLICABLE", "evidence": "outside"}],
            [{"id": "API", "result": "NOT_RUN", "evidence": "later"}],
            [{"id": "API", "result": "PASS", "evidence": "file"}] * 2,
        ]:
            with self.subTest(records=records), self.assertRaises(ValueError):
                evaluate(data, node, task, {"review_checks": records})
        result = evaluate(
            data,
            node,
            task,
            {
                "review_checks": [
                    {
                        "id": "API",
                        "result": "NOT_APPLICABLE",
                        "evidence": "No external consumers in scoped change",
                        "reason": "Internal-only contract",
                    }
                ]
            },
        )
        self.assertEqual("PASS", result[0]["status"])


if __name__ == "__main__":
    unittest.main()
