"""Specialists retain only evidence from their bound assignments."""

import json
import subprocess
import unittest
from typing import Any

from factory.runtime import graph_inputs
from factory.runtime.workflow_core import Invalid
from tests import CLI
from tests.factory.runtime.workflow_fixture import WorkflowFixture


class SpecialistTests(unittest.TestCase):
    def setUp(self) -> None:
        self.f = WorkflowFixture(self.addCleanup)
        self.config = self.f.config_file(lambda c: c["execution"].update(workspace="shared"))
        self.f.g.update(nodes=[], agents={})

    def run_cli(self, group: str, *args: str, ok: bool = True) -> Any:
        result = subprocess.run(
            [
                *CLI,
                group,
                "--workspace",
                str(self.f.root),
                "--config",
                str(self.config),
                *args,
                "--json",
            ],
            text=True,
            capture_output=True,
        )
        self.assertEqual(ok, result.returncode == 0, result.stdout + result.stderr)
        response = json.loads(result.stdout)
        return response["result"] if ok else response["error"]

    def start(self, node: str) -> str:
        plan = graph_inputs.propose(self.f.root, graph_inputs.PROPOSAL.validate_python(self.f.g))
        self.run_cli("workflow", "init", plan)
        self.f.start(node)
        return self.f.ledger.read()["nodes"][node]["dispatch_id"]

    def test_diagnosis_receipt_returns_to_original_investigation(self) -> None:
        f = self.f
        f.g["tasks"]["label"]["inquiry"] = "diagnosis"
        node = "explore-label"
        ticket = self.start(node)
        args = ["workflow", "note", node, "--dispatch", ticket]
        for reference, kind, description in [
            ("setup", "reproduction", "First label read immediately after restart is stale"),
            ("cache", "observation", "Fixture always misses the cache, so this read bypasses it"),
        ]:
            self.run_cli(
                *args,
                "--request",
                reference,
                "--kind",
                kind,
                "--observation",
                description,
                "--path",
                "lib/example.dart",
            )
        resumed = self.run_cli(*args)
        self.assertEqual(["setup", "cache"], [r["request_id"] for r in resumed["records"]])
        self.assertEqual(
            f.ledger.read()["graph"]["sources"]["request"]["hash"], resumed["source_hash"]
        )
        with self.assertRaisesRegex(Invalid, "confirmed cause evidence"):
            f.ledger.finish(node, f.report(node, stage_result="ROOT_CAUSE_FOUND"))
        self.run_cli(
            *args,
            "--request",
            "trace",
            "--kind",
            "request-check",
            "--observation",
            "Verify the failing branch with behavior",
            "--check",
            "behavior",
            "--path",
            "lib/example.dart",
        )
        auth = ("workflow", "authorize-check", node, "--dispatch", ticket, "--request", "trace")
        check_node = self.run_cli(*auth)["tester_node"]
        self.assertEqual(check_node, self.run_cli(*auth)["tester_node"])
        self.assertIn(check_node, self.run_cli("workflow", "status")["runnable"])
        f.start(check_node)
        check_ticket = f.ledger.read()["nodes"][check_node]["dispatch_id"]
        actual = self.run_cli(
            "checks",
            "run",
            check_node,
            "behavior",
            "--dispatch",
            check_ticket,
            "--request",
            "trace-check",
        )
        f.ledger.finish(check_node, f.report(check_node, checks=[actual]))
        state = self.run_cli(*args)
        self.assertEqual(ticket, state["dispatch_id"])
        self.assertEqual(
            [actual["execution_id"]], state["requested_verification"][check_node]["receipts"]
        )
        self.assertEqual("running", f.ledger.read()["nodes"][node]["status"])
        self.run_cli(
            *args,
            "--request",
            "cause",
            "--kind",
            "cause",
            "--observation",
            "Trace and source identify the stale label literal",
            "--path",
            "lib/example.dart",
            "--receipt",
            actual["execution_id"],
        )
        f.ledger.finish(node, f.report(node, stage_result="ROOT_CAUSE_FOUND"))
        self.assertEqual(1, len(f.ledger.read()["executions"]))
        self.assertEqual(["verify-label"], self.run_cli("workflow", "status")["runnable"])

    def test_diagnosis_can_return_a_named_blocker(self) -> None:
        f = self.f
        f.g["tasks"]["label"]["inquiry"] = "diagnosis"
        node = "explore-label"
        self.start(node)
        report = f.report(
            node,
            "BLOCKED",
            stage_result="BLOCKED_USER_INPUT",
            evidence="Need the exact deployment revision to distinguish two observed versions",
        )
        f.ledger.finish(node, report)
        self.assertEqual(report["evidence"], f.ledger.read()["nodes"][node]["report"]["evidence"])

    def test_implementer_owns_the_accompanying_readme(self) -> None:
        f = self.f
        task = f.g["tasks"]["label"]
        task["scope"].append("README.md")
        task["write_scope"] = list(task["scope"])
        node = "work-label"
        self.start(node)
        (f.root / "README.md").write_text("Use the renamed label.\n")
        (f.root / "lib/example.dart").write_text("Updated label")
        f.ledger.finish(
            node,
            f.report(
                node,
                write_result={
                    "code": ["lib/example.dart"],
                    "tests": ["behavior"],
                    "docs": ["README.md"],
                },
            ),
        )
        status = self.run_cli("workflow", "status")
        self.assertEqual(["verify-label"], status["runnable"])
        self.assertNotIn("doc-writer", status["task_routes"]["label"]["roles"])

    def test_docs_resume_and_verify_both_documents_and_links(self) -> None:
        f = self.f
        docs = ["api.md", "guide.md"]
        for path in docs:
            (f.root / path).write_text("Old documentation")
        f.g["tasks"]["label"].update(kind="docs", scope=docs, write_scope=docs)
        node = "docs-label"
        ticket = self.start(node)
        (f.root / "api.md").write_text("# Service API\n\nVersion two.\n")
        (f.root / "guide.md").write_text("See [API](api.md#wrong).\n")
        args = ["workflow", "note", node, "--dispatch", ticket]
        paths = ["--path", docs[0], "--path", docs[1]]
        self.run_cli(
            *args,
            "--request",
            "draft",
            "--kind",
            "documents",
            "--observation",
            "Updated API and guide",
            *paths,
        )
        resumed = self.run_cli(*args)
        self.assertEqual(docs, resumed["missing_document_reviews"])
        self.assertEqual(docs, resumed["scope"])
        with self.assertRaisesRegex(Invalid, "reference review"):
            f.ledger.finish(node, f.report(node, stage_result="DOCS_UPDATED"))
        args_check = [
            *args,
            "--request",
            "review",
            "--kind",
            "document-review",
            "--observation",
            "Compared signatures and checked referenced headings",
            *paths,
        ]
        self.assertIn("Broken document anchor", str(self.run_cli(*args_check, ok=False)))
        (f.root / "guide.md").write_text("See [API](api.md#service-api).\n")
        self.run_cli(
            *args,
            "--request",
            "correction",
            "--kind",
            "documents",
            "--observation",
            "Fixed API heading reference",
            "--path",
            "guide.md",
        )
        checked = self.run_cli(*args_check)
        self.assertEqual({"api.md"}, set(checked["links"]))
        self.assertEqual(checked, self.run_cli(*args_check))
        f.ledger.finish(node, f.report(node, stage_result="DOCS_UPDATED"))
        self.assertEqual("done", f.ledger.read()["nodes"][node]["status"])
