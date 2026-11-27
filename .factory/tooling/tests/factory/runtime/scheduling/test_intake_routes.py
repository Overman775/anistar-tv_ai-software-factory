"""Exercise the task classifier, direct intake and dispatch on isolated checkout copies."""

import json
import subprocess
import unittest
from copy import deepcopy
from pathlib import Path
from typing import Any

from factory.runtime import graph_inputs
from factory.runtime.workflow_config import load_config
from factory.runtime.workflow_core import Invalid
from tests import CLI
from tests.factory.runtime.workflow_fixture import WorkflowFixture


class TaskRouteTests(unittest.TestCase):
    def test_explicit_public_writer_needs_judge_without_optional_write_scope(self) -> None:
        f = WorkflowFixture(self.addCleanup)
        f.fixture_policy += "public_contracts:\n  lib/example.dart: [guide.md]\n"
        config = load_config(f.config_file(lambda c: c["execution"].update(workspace="shared")))
        task = f.g["tasks"]["label"]
        task["risk"], task["independent_review"] = "low", False
        task.pop("write_scope", None)
        task["scope"].append("guide.md")
        next(n for n in f.g["nodes"] if n.get("owns"))["owns"].append("guide.md")
        with self.assertRaisesRegex(Invalid, "Missing final review after verification"):
            f.ledger.init(f.g, config)
        f.require_fixture_review()
        self.assertIn("review-label", f.ledger.init(f.g, config)["nodes"])

    def test_judge_observation_stays_with_review_and_green_tester_can_report_gap(self) -> None:
        f = WorkflowFixture(self.addCleanup)
        task = f.g["tasks"]["label"]
        observation = {
            "id": "owner-assessment",
            "kind": "observation",
            "category": "acceptance",
            "method": "Assess owner criterion",
            "criteria": task["acceptance_ids"],
            "assessor": "judge",
        }
        task["required_checks"].append(observation)
        with self.assertRaisesRegex(Invalid, "Missing final review"):
            f.init()
        f.require_fixture_review()
        f.init()
        f.start("write-label")
        f.ledger.finish("write-label", f.report("write-label"))
        f.start("verify-label")
        packet = f.ledger.packet("verify-label")
        self.assertIn("prepare-report", packet["report_command"])
        self.assertNotIn(observation, packet["finish_requirements"]["allowed_checks"])
        report = f.report("verify-label", coverage_notes=["Only the registered examples ran."])
        failed = {**report, "outcome": "FAIL", "stage_result": "FAIL_CODE"}
        draft = {k: v for k, v in failed.items() if k != "files"}
        with self.assertRaisesRegex(Invalid, "Assigned commands passed"):
            f.ledger.prepare_report("verify-label", draft, [])
        with self.assertRaisesRegex(Invalid, "Assigned commands passed"):
            f.ledger.finish("verify-label", failed)
        f.ledger.finish("verify-label", report)
        f.start("review-label")
        review = f.ledger.packet("review-label")
        self.assertIn(observation, review["finish_requirements"]["required_checks"])
        delivered = review["dependency_results"]
        self.assertNotIn("coverage_notes", delivered["verify-label"]["report"])
        self.assertNotIn("Fixture result", str(delivered["write-label"]["report"]))
        self.assertEqual(
            report["coverage_notes"],
            f.ledger.read()["nodes"]["verify-label"]["report"]["coverage_notes"],
        )
        self.assertIn("report_ref", delivered["verify-label"])
        judged = f.report("review-label", verdict="APPROVE")
        with self.assertRaisesRegex(Invalid, "Missing required check"):
            f.ledger.finish("review-label", judged)
        judged["checks"] = [{**observation, "result": "PASS", "evidence": "Independent assessment"}]
        f.ledger.finish("review-label", judged)
        f.ledger.accept("accept-label")

    def test_roles_and_owner_minimum_at_public_entry(self) -> None:
        scenarios = [
            ("feature", "feature", "moderate", None, False, "implementer", True),
            ("bug", "fix", "low", None, False, "implementer", False),
            ("refactor", "refactor", "high", None, False, "implementer", True),
            ("small", "task", "low", None, False, "implementer", False),
            ("small-owner", "task", "low", None, True, "implementer", True),
            ("research", "task", "low", "research", False, "code-explorer", False),
            ("diagnose", "fix", "low", "diagnosis", False, "bug-hunter", False),
            ("docs", "docs", "low", None, False, "doc-writer", False),
            ("public", "task", "low", None, False, "implementer", True),
        ]
        for case, kind, risk, inquiry, owner, first, judged in scenarios:
            with self.subTest(case=case):
                f = WorkflowFixture(self.addCleanup)
                if case in {"public", "research"}:
                    f.fixture_policy += "public_contracts:\n  lib/example.dart: [guide.md]\n"
                config = f.config_file(lambda c: c["execution"].update(workspace="shared"))
                graph = deepcopy(f.g)
                graph.update(agents={}, nodes=[])
                task = graph["tasks"]["label"]
                task.update(kind=kind, risk=risk, reason=case)
                if inquiry:
                    task["inquiry"] = inquiry
                else:
                    task["write_scope"] = list(task["scope"])
                if owner:
                    task["owner_review_ref"] = "owner-message-7"
                proposal = graph_inputs.propose(
                    f.root, graph_inputs.PROPOSAL.validate_python(graph)
                )

                def run(*args: str, f: WorkflowFixture = f, config: Path = config) -> Any:
                    command = [
                        *CLI,
                        "workflow",
                        "--workspace",
                        str(f.root),
                        "--config",
                        str(config),
                        *args,
                        "--json",
                    ]
                    result = subprocess.run(command, text=True, capture_output=True)
                    self.assertEqual(0, result.returncode, result.stdout + result.stderr)
                    return json.loads(result.stdout)["result"]

                preview = run("validate", proposal)
                run("init", proposal)
                status = run("status")
                roles = [first, "tester", *(["judge"] if judged else [])]
                self.assertEqual(roles, status["task_routes"]["label"]["roles"])
                self.assertEqual(risk, status["task_routes"]["label"]["risk"])
                self.assertEqual(case, status["task_routes"]["label"]["reason"])
                [node] = status["runnable"]
                self.assertIn(node, preview)
                ticket = status["assignment_tickets"][node]
                claim = run("claim", node, "--ticket", ticket)
                self.assertIn(claim["delivery"]["action"], {"spawn", "prepare_acp"})
                self.assertEqual(first, f.ledger.read()["nodes"][node]["role"])
                if owner:
                    f.ledger.bind(
                        node,
                        handle="same-author",
                        model=str(
                            f.ledger.read()["config"]["models"][claim["profile"]["model"]]["id"]
                        ),
                    )
                    f.ledger.finish(node, f.report(node, outcome="FAIL", stage_result="FAIL_CODE"))
                    revised = deepcopy(f.ledger.read()["graph"])
                    revised["tasks"]["label"].pop("owner_review_ref")
                    with self.assertRaises(Invalid):
                        f.ledger.revise(revised, "Remove owner request")
                    self.assertEqual(
                        "owner-message-7", run("status")["task_routes"]["label"]["owner_review_ref"]
                    )
