"""Acceptance regressions through the real ledger, with real fixture command execution."""

from __future__ import annotations

import unittest
from copy import deepcopy
from pathlib import Path
from typing import Any

from factory_tooling.runtime.acceptance import plan_criteria
from factory_tooling.runtime.workflow_core import Invalid
from factory_tooling.runtime.workflow_graph import validate_graph
from factory_tooling.runtime.workflow_sources import lock_source
from tests.factory_tooling.runtime import test_workflow

_TOOLS = Path(__file__).resolve().parents[3] / "tools"


class AcceptanceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.fixture = test_workflow.WorkflowTests()
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)

    def verifying(self) -> tuple[test_workflow.WorkflowTests, dict[str, Any]]:
        f = self.fixture
        f.init()
        f.start("write-label")
        f.ledger.finish("write-label", f.report("write-label"))
        f.start("verify-label")
        return f, f.report("verify-label")

    def test_task_guard_blocks_each_weakened_obligation(self) -> None:
        from copy import deepcopy

        from factory_tooling.runtime.workflow import preserve_task_guards
        from tests.factory_tooling.runtime import test_workflow

        fixture = test_workflow.WorkflowTests()
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        before = fixture.g["tasks"]["label"]
        before["independent_review"] = True
        before["risk"] = "high"
        changes: tuple[tuple[str, object, str], ...] = (
            ("required_checks", [], "required checks"),
            ("scope", [], "verification scope"),
            ("risk", "low", "risk assessment"),
            ("independent_review", False, "independent review"),
        )
        for key, value, message in changes:
            after = deepcopy(before)
            after[key] = value
            with self.subTest(key=key), self.assertRaisesRegex(Invalid, message):
                preserve_task_guards(before, after)

    def test_unassigned_criterion_blocks_graph(self) -> None:
        f = self.fixture
        c = deepcopy(f.g["sources"]["request"]["acceptance"][0])
        c["id"] = "AC-02"
        f.g["sources"]["request"]["acceptance"].append(c)
        with self.assertRaisesRegex(Invalid, "Unassigned"):
            f.init()

    def test_canonical_plan_criteria_are_verified_against_actual_source(self) -> None:
        from tests.factory_tooling.planning import test_validate_plan as module

        plan = module.PLAN.replace("status: draft", "status: approved").replace(
            "approved_revision: none", "approved_revision: 1"
        )
        f = self.fixture
        (f.root / "plan.md").write_text(plan)
        src: dict[str, Any] = dict(
            path="plan.md",
            kind="approved_plan",
            selected_scope="all",
            acceptance=plan_criteria(plan),
        )
        locked = lock_source(f.root, src)
        self.assertEqual("AC-01", locked["acceptance"][0]["id"])
        src["acceptance"][0]["requirement"] = "Weaker invented behavior"
        with self.assertRaisesRegex(Invalid, "differs from approved plan"):
            lock_source(f.root, src)

    def test_explicit_partial_scope_retains_unselected_criteria_without_claiming_pass(self) -> None:
        f = self.fixture
        src = f.g["sources"]["request"]
        c = deepcopy(src["acceptance"][0])
        c["id"] = "AC-02"
        src["acceptance"].append(c)
        src.update(selected_scope="label only", selected_acceptance_ids=["AC-01"])
        f.init()
        f.complete()
        self.assertEqual(2, len(f.ledger.read()["graph"]["sources"]["request"]["acceptance"]))

    def test_integration_rechecks_other_sources_without_colliding_ac_ids(self) -> None:
        f = self.fixture
        f.batch()
        f.g["sources"]["other"] = deepcopy(f.g["sources"]["request"])
        f.g["tasks"]["second"]["source"] = "other"
        with self.assertRaisesRegex(Invalid, "Integration must recheck"):
            validate_graph(f.g, f.config)
        task = f.g["tasks"]["integrated"]
        task["acceptance_ids"].append("other:AC-01")
        task["required_checks"][0]["criteria"].append("other:AC-01")
        validate_graph(f.g, f.config)

    def test_preparatory_task_keeps_local_and_parent_acceptance_distinct(self) -> None:
        f = self.fixture
        (f.root / "task.md").write_text(
            "- **Acceptance criteria:** —\nLocal goal: prepare the fixture.\n"
        )
        source = dict(
            path="task.md",
            kind="factory_decompose_task",
            acceptance=f.g["sources"]["request"]["acceptance"],
        )
        with self.assertRaisesRegex(Invalid, "local acceptance"):
            lock_source(f.root, source)
        source.update(acceptance_origin="task_local", parent_plan_ref="plan/CAP-01")
        self.assertEqual("task_local", lock_source(f.root, source)["acceptance_origin"])

    def test_functional_contributor_accepts_local_goal_before_parent_closer(self) -> None:
        f = self.fixture
        f.batch()
        task = f.g["tasks"]["label"]
        task.update(
            acceptance_ids=[],
            contributes_to_acceptance_ids=["AC-01"],
            parent_plan_ref="plan/CAP-01",
            local_acceptance_criteria=[
                dict(
                    id="AC-01",
                    applies_to="global",
                    requirement="Producer emits the local contract",
                    verification="Producer contract fixture",
                )
            ],
        )
        task["required_checks"][0]["criteria"] = ["local:AC-01"]
        f.init()
        f.complete()
        f.start("write-second")
        f.ledger.finish("write-second", f.report("write-second"))
        f.start("verify-second")
        f.ledger.finish("verify-second", f.report("verify-second"))
        f.ledger.accept("accept-second")
        f.start("verify-all", "integration-judge")
        f.ledger.finish("verify-all", f.report("verify-all"))
        f.start("review-all", "integration-judge")
        f.ledger.finish("review-all", f.report("review-all", verdict="APPROVE", findings=[]))
        f.ledger.accept("accept-all")
        f.ledger.archive("completed", "Local contributor then parent closer")
        state = f.ledger.read()
        self.assertEqual([], state["graph"]["tasks"]["label"]["acceptance_ids"])
        self.assertEqual(
            ["local:AC-01"], state["nodes"]["verify-label"]["report"]["checks"][0]["criteria"]
        )
        self.assertEqual(["AC-01"], state["nodes"]["verify-all"]["report"]["checks"][0]["criteria"])

    def test_local_and_parent_check_ids_do_not_alias(self) -> None:
        f = self.fixture
        task = f.g["tasks"]["label"]
        task["local_acceptance_criteria"] = [
            dict(
                id="AC-01",
                applies_to="global",
                requirement="Local contract",
                verification="Fixture",
            )
        ]
        with self.assertRaisesRegex(Invalid, "no required check"):
            f.init()
        task["required_checks"][0]["criteria"].append("local:AC-01")
        f.init()
        f.complete()

    def test_contributor_needs_local_checks_known_parent_and_provenance(self) -> None:
        f = self.fixture
        base = deepcopy(f.g["tasks"]["label"])
        invalid_inputs: list[tuple[dict[str, Any], str]] = [
            (
                dict(acceptance_ids=[], contributes_to_acceptance_ids=["AC-01"]),
                "local contribution",
            ),
            (
                dict(contributes_to_acceptance_ids=["AC-99"], parent_plan_ref="plan/CAP-01"),
                "Unknown",
            ),
            (dict(contributes_to_acceptance_ids=["AC-01"]), "provenance"),
        ]
        for fields, expected in invalid_inputs:
            f.g["tasks"]["label"] = {**deepcopy(base), **fields}
            with self.subTest(fields=fields), self.assertRaisesRegex(Invalid, expected):
                f.init()

    def test_criterion_without_check_blocks_graph(self) -> None:
        f = self.fixture
        f.g["tasks"]["label"]["required_checks"][0].update(category="project", criteria=[])
        with self.assertRaisesRegex(Invalid, "no required check"):
            f.init()

    def test_missing_required_result_blocks_even_with_other_green_tests(self) -> None:
        f, report = self.verifying()
        report["checks"][0].update(id="unrelated", category="additional")
        with self.assertRaisesRegex(Invalid, "Missing required check"):
            f.ledger.finish("verify-label", report)

    def test_required_cannot_be_downgraded_to_additional(self) -> None:
        f, report = self.verifying()
        report["checks"][0].update(
            category="additional", resolution={"disposition": "out_of_scope", "reason": "skip"}
        )
        with self.assertRaisesRegex(Invalid, "category changed"):
            f.ledger.finish("verify-label", report)

    def test_result_cannot_claim_other_criteria_or_method(self) -> None:
        f, report = self.verifying()
        for field, value in [
            ("criteria", ["AC-99"]),
            ("method", "unrelated test"),
            ("evidence", ""),
        ]:
            modified = deepcopy(report)
            modified["checks"][0][field] = value
            with self.subTest(field=field), self.assertRaises(Invalid):
                f.ledger.finish("verify-label", modified)

    def test_additional_pass_is_allowed_without_plan_revision(self) -> None:
        f, report = self.verifying()
        report["checks"].append(
            dict(
                id="edge",
                category="additional",
                kind="tests",
                command="edge-test",
                cwd=".",
                exit_code=0,
                evidence="edge log",
            )
        )
        f.ledger.finish("verify-label", report)
        f.ledger.accept("accept-label")

    def test_additional_failure_requires_resolution(self) -> None:
        f, report = self.verifying()
        extra = dict(
            id="edge", category="additional", kind="tests", command="probe", cwd=".", exit_code=1
        )
        report["checks"].append(extra)
        with self.assertRaises(Invalid):
            f.ledger.finish("verify-label", report)
        extra["resolution"] = {
            "disposition": "not_run",
            "reason": "Cannot rename an actual failure",
        }
        with self.assertRaises(Invalid):
            f.ledger.finish("verify-label", report)
        extra["resolution"] = {
            "disposition": "invalid_check",
            "reason": "Probe used a nonexistent fixture; mandatory checks remain valid",
        }
        f.ledger.finish("verify-label", report)
        f.ledger.accept("accept-label")

    def test_additional_failure_cannot_hide_blocking_finding(self) -> None:
        f, report = self.verifying()
        report["findings"] = [dict(id="REV-01", blocking=True, status="open", summary="Regression")]
        with self.assertRaisesRegex(Invalid, "blocking finding"):
            f.ledger.finish("verify-label", report)

    def test_required_project_gate_cannot_be_replaced_by_acceptance_tests(self) -> None:
        f = self.fixture
        f.g["tasks"]["label"]["required_checks"].append(
            dict(
                id="project-static",
                category="project",
                kind="static",
                criteria=[],
                method="Project static gate",
                execution=deepcopy(f.g["tasks"]["label"]["required_checks"][0]["execution"]),
            )
        )
        f, report = self.verifying()
        with self.assertRaisesRegex(Invalid, "Missing required check"):
            f.ledger.finish("verify-label", report)
        report["checks"].append(f.ledger.run_check("verify-label", "project-static"))
        f.ledger.finish("verify-label", report)
        f.ledger.accept("accept-label")

    def test_revision_may_add_but_not_remove_required_checks(self) -> None:
        f = self.fixture
        f.init()
        g = deepcopy(f.ledger.read()["graph"])
        g["tasks"]["label"]["required_checks"].append(
            dict(
                id="extra-project",
                category="project",
                kind="static",
                criteria=[],
                method="Extra project gate",
                execution=deepcopy(f.g["tasks"]["label"]["required_checks"][0]["execution"]),
            )
        )
        f.ledger.revise(g, "Additional applicable gate")
        del g["tasks"]["label"]["required_checks"][1]
        with self.assertRaisesRegex(Invalid, "weaken required checks"):
            f.ledger.revise(g, "Drop gate")

    def test_observation_can_confirm_criterion_without_fake_shell_command(self) -> None:
        self.fixture.g["tasks"]["label"]["required_checks"][0]["kind"] = "observation"
        f, report = self.verifying()
        command = report["checks"][0]
        report["checks"] = [
            {
                **command,
                "kind": "observation",
                "command": None,
                "exit_code": None,
                "result": "PASS",
                "evidence": "screenshots with comparison notes",
            },
            {
                **command,
                "id": "regression",
                "category": "additional",
                "kind": "tests",
                "command": "fixture",
                "cwd": ".",
                "exit_code": 0,
            },
        ]
        f.ledger.finish("verify-label", report)
        f.ledger.accept("accept-label")

    def test_required_observation_without_evidence_cannot_finish_verify(self) -> None:
        self.fixture.g["tasks"]["label"]["required_checks"][0]["kind"] = "observation"
        f, report = self.verifying()
        report["checks"][0].update(kind="observation", result="PASS", evidence="")
        with self.assertRaisesRegex(Invalid, "Failed/incomplete command evidence"):
            f.ledger.finish("verify-label", report)


if __name__ == "__main__":
    unittest.main()
