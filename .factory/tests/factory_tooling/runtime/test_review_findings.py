"""Review history through the real ledger, including retries and session changes."""

from __future__ import annotations

import json
import sys
import unittest
from copy import deepcopy
from pathlib import Path
from typing import Any

from factory_tooling.adapters.acpx_adapter import prepare_prompt
from factory_tooling.runtime import review_findings
from factory_tooling.runtime.contracts import agent_key
from factory_tooling.runtime.workflow_core import Invalid, atomic_json, snapshot
from tests.factory_tooling.runtime import test_workflow

_TOOLS = Path(__file__).resolve().parents[3] / "tools"


class ReviewFindingTests(unittest.TestCase):
    def setUp(self) -> None:
        self.f = f = test_workflow.WorkflowTests()
        f.setUp()
        self.addCleanup(f.doCleanups)
        f.g["tasks"]["label"].update(independent_review=True, risk="moderate", kind="feature")
        f.g["agents"]["reviewer"] = dict(role="judge", profile="judge")
        f.g["nodes"].append(
            dict(
                id="review-label",
                task="label",
                stage="review",
                agent="reviewer",
                depends_on=["verify-label"],
                owns=[],
                resources=["project-checks"],
            )
        )
        f.g["nodes"][2]["depends_on"] = ["review-label"]
        f.init()
        self.finding = dict(
            id="REV-1",
            status="open",
            blocking=True,
            owner_role="generalist",
            summary="Incorrect label",
            evidence="Reproduction",
        )

    def work(self, updates: list[dict[str, Any]] | None = None) -> None:
        f = self.f
        f.start("write-label")
        f.ledger.finish("write-label", f.report("write-label", finding_updates=updates or []))
        f.start("verify-label")
        f.ledger.finish("verify-label", f.report("verify-label"))

    def review(
        self,
        findings: list[dict[str, Any]],
        outcome: str = "FAIL",
        verdict: str = "NEEDS_WORK",
        handle: str = "reviewer-session",
    ) -> None:
        f = self.f
        f.start("review-label", handle)
        f.ledger.finish(
            "review-label", f.report("review-label", outcome, findings=findings, verdict=verdict)
        )

    def discovered(self) -> None:
        self.work()
        self.review([self.finding])

    def retry_work(self, ready: bool = True) -> None:
        self.f.ledger.retry("write-label", "review", "Correct finding", "All workers stopped")
        self.work([dict(id="REV-1", status="ready", evidence="Changed label")] if ready else [])

    def test_full_lifecycle_accept_and_history(self) -> None:
        self.discovered()
        self.retry_work()
        self.review(
            [dict(id="REV-1", status="fixed", evidence="Verified corrected label")],
            "PASS",
            "APPROVE",
        )
        self.f.ledger.accept("accept-label")
        item = self.f.ledger.read()["review_findings"]["label"]["REV-1"]
        self.assertEqual(["open", "ready", "fixed"], [x["status"] for x in item["history"]])
        self.f.ledger.archive("completed", "done")
        self.f.ledger.clean()

    def test_omission_in_next_report_does_not_close_finding(self) -> None:
        self.discovered()
        self.retry_work(False)
        with self.assertRaisesRegex(Invalid, "omitted"):
            self.review([], "PASS", "APPROVE")
        self.assertEqual(
            "open", self.f.ledger.read()["review_findings"]["label"]["REV-1"]["status"]
        )

    def test_ready_is_not_closed(self) -> None:
        self.discovered()
        self.retry_work()
        with self.assertRaisesRegex(Invalid, "omitted"):
            self.review([], "PASS", "APPROVE")

    def test_author_cannot_self_close(self) -> None:
        self.discovered()
        f = self.f
        f.ledger.retry("write-label", "review", "fix", "stopped")
        f.start("write-label")
        with self.assertRaisesRegex(Invalid, "cannot close"):
            f.ledger.finish(
                "write-label",
                f.report(
                    "write-label",
                    finding_updates=[dict(id="REV-1", status="fixed", evidence="trust me")],
                ),
            )

    def test_reviewer_cannot_skip_fix_handoff(self) -> None:
        self.discovered()
        self.retry_work(False)
        with self.assertRaisesRegex(Invalid, "handed off"):
            self.review([dict(id="REV-1", status="fixed", evidence="fixed")], "PASS", "APPROVE")

    def test_dismissal_requires_evidence(self) -> None:
        self.discovered()
        self.retry_work(False)
        with self.assertRaisesRegex(Invalid, "needs evidence"):
            self.review([dict(id="REV-1", status="dismissed")], "PASS", "APPROVE")

    def test_reasoned_dismissal_is_allowed(self) -> None:
        self.discovered()
        self.retry_work(False)
        self.review(
            [
                dict(
                    id="REV-1",
                    status="dismissed",
                    evidence="Requirement explicitly allows this label",
                )
            ],
            "PASS",
            "APPROVE",
        )
        self.f.ledger.accept("accept-label")

    def test_cannot_lower_severity(self) -> None:
        self.discovered()
        self.retry_work(False)
        with self.assertRaisesRegex(Invalid, "severity"):
            self.review(
                [dict(id="REV-1", status="dismissed", blocking=False, evidence="skip")],
                "PASS",
                "APPROVE",
            )

    def test_session_change_preserves_packet_findings(self) -> None:
        self.discovered()
        f = self.f
        f.ledger.replace_session("author", "replace", "stopped", "REV-1 open")
        f.ledger.replace_session("reviewer", "replace", "stopped", "REV-1 open")
        f.ledger.retry("write-label", "review", "Correct finding", "All workers stopped")
        f.start("write-label", "new-author")
        correction = f.ledger.packet("write-label")
        self.assertEqual("open", correction["review_findings"]["REV-1"]["status"])
        self.assertIn(
            "review-findings.md", {Path(item["path"]).name for item in correction["instructions"]}
        )
        f.ledger.finish(
            "write-label",
            f.report(
                "write-label",
                finding_updates=[dict(id="REV-1", status="ready", evidence="Changed")],
            ),
        )
        f.start("verify-label", "new-author")
        verification = f.ledger.packet("verify-label")
        self.assertNotIn(
            "review-findings.md", {Path(item["path"]).name for item in verification["instructions"]}
        )
        f.ledger.finish("verify-label", f.report("verify-label"))
        f.ledger.claim("review-label")
        packet = f.ledger.packet("review-label")
        self.assertEqual("ready", packet["review_findings"]["REV-1"]["status"])
        self.assertNotIn("history", packet["review_findings"]["REV-1"])
        self.assertIn(
            "review-findings.md", {Path(item["path"]).name for item in packet["instructions"]}
        )
        f.ledger.bind("review-label", "new-reviewer", "gpt-6.1-sol")
        with self.assertRaisesRegex(Invalid, "omitted"):
            f.ledger.finish(
                "review-label", f.report("review-label", verdict="APPROVE", findings=[])
            )

    def test_revision_preserves_findings(self) -> None:
        self.discovered()
        f = self.f
        g = deepcopy(f.ledger.read()["graph"])
        g["tasks"]["label"]["reason"] = "Expanded diagnosis"
        f.ledger.revise(g, "diagnosis")
        self.assertEqual("open", f.ledger.read()["review_findings"]["label"]["REV-1"]["status"])

    def test_contradictory_report_rejected(self) -> None:
        f = self.f
        f.start("write-label")
        for fields in [
            dict(stage_result="FAIL_CODE"),
            dict(stage_result="BLOCKED_TOOL_ERROR"),
            dict(verdict="NEEDS_WORK"),
        ]:
            with self.subTest(fields=fields), self.assertRaisesRegex(Invalid, "Contradictory"):
                f.ledger.finish("write-label", f.report("write-label", **fields))

    def test_duplicate_id_rejected_even_on_failed_review(self) -> None:
        self.work()
        with self.assertRaisesRegex(Invalid, "duplicate"):
            self.review([self.finding, self.finding])

    def test_closed_resolution_is_bound_to_files_source_and_revision(self) -> None:
        self.discovered()
        self.retry_work()
        self.review([dict(id="REV-1", status="fixed", evidence="checked")], "PASS", "APPROVE")
        f = self.f
        s = f.ledger.read()
        files = snapshot(f.root, s["graph"]["tasks"]["label"]["scope"])
        source = s["graph"]["sources"]["request"]["hash"]
        for changed_files, changed_source, revision in [
            (dict(files, extra="changed"), source, s["revision"]),
            (files, "new-source", s["revision"]),
            (files, source, s["revision"] + 1),
        ]:
            changed = deepcopy(s)
            changed["revision"] = revision
            with self.assertRaisesRegex(ValueError, "Stale"):
                review_findings.gate(changed, "label", changed_files, changed_source)

    def test_reintake_retains_open_findings(self) -> None:
        self.discovered()
        f = self.f
        g = deepcopy(f.ledger.read()["graph"])
        g["sources"]["request"]["text"] = "Updated authorized label request"
        f.ledger.reintake(g, "changed source", "user request")
        self.assertEqual("open", f.ledger.read()["review_findings"]["label"]["REV-1"]["status"])

    def test_new_finding_cannot_arrive_already_closed(self) -> None:
        self.work()
        self.finding["status"] = "fixed"
        with self.assertRaisesRegex(Invalid, "start open"):
            self.review([self.finding], "PASS", "APPROVE")

    def test_reopened_finding_is_not_lost(self) -> None:
        self.discovered()
        self.retry_work()
        self.review([dict(id="REV-1", status="fixed", evidence="checked")], "PASS", "APPROVE")
        f = self.f
        f.ledger.retry("review-label", "review", "regression found", "stopped")
        self.review([dict(id="REV-1", status="open", evidence="reproduces again")])
        self.assertEqual("open", f.ledger.read()["review_findings"]["label"]["REV-1"]["status"])

    def test_acp_packet_gets_task_findings_without_history(self) -> None:
        self.discovered()
        other = test_workflow.WorkflowTests()
        other.setUp()
        self.addCleanup(other.doCleanups)
        other.fake_acp()
        other.init()
        state = other.ledger.read()
        state["review_findings"] = deepcopy(self.f.ledger.read()["review_findings"])
        state["review_findings"]["unrelated-task"] = {"REV-99": {"secret": "not needed"}}
        atomic_json(other.ledger.path, state)
        other.ledger.claim("write-label")
        prompt = Path(prepare_prompt(other.ledger, "write-label")["prompt"]).read_text()
        envelope = json.loads(prompt)
        self.assertEqual(["REV-1"], list(envelope["review_findings"]))
        self.assertNotIn("history", envelope["review_findings"]["REV-1"])
        self.assertIn("Review findings in Implement", prompt)

    def test_nonblocking_note_does_not_block(self) -> None:
        self.work()
        self.finding["blocking"] = False
        self.review([self.finding], "PASS", "APPROVE")
        self.f.ledger.accept("accept-label")


class IntegrationFindingTests(unittest.TestCase):
    def setUp(self) -> None:
        self.f = f = test_workflow.WorkflowTests()
        f.setUp()
        self.addCleanup(f.doCleanups)
        f.batch()
        f.g["agents"]["reviewer"] = dict(role="judge", profile="judge")
        for tid in ["label", "second", "integrated"]:
            f.g["tasks"][tid].update(independent_review=True, risk="moderate")
        f.g["nodes"].append(
            dict(
                id="review-label",
                task="label",
                stage="review",
                agent="reviewer",
                depends_on=["verify-label"],
                owns=[],
                resources=["project-checks"],
            )
        )
        f.g["nodes"][2]["depends_on"] = ["review-label"]
        final_verify = next(n for n in f.g["nodes"] if n["id"] == "verify-all")
        final_verify["agent"] = "reviewer"
        f.g["nodes"].append(
            dict(
                id="review-second",
                task="second",
                stage="review",
                agent="reviewer",
                depends_on=["verify-second"],
                owns=[],
                resources=["project-checks"],
            )
        )
        next(n for n in f.g["nodes"] if n["id"] == "accept-second")["depends_on"] = [
            "review-second"
        ]
        next(n for n in f.g["nodes"] if n["id"] == "review-all")["agent"] = "reviewer"

    def first(self, findings: list[dict[str, Any]] | None = None, ready: bool = False) -> None:
        f = self.f
        f.start("write-label", self.author_handle())
        updates = (
            [dict(id="REV-1", status="ready", evidence="Author corrected original defect")]
            if ready
            else []
        )
        f.ledger.finish("write-label", f.report("write-label", finding_updates=updates))
        f.start("verify-label", self.author_handle())
        f.ledger.finish("verify-label", f.report("verify-label"))
        self.review("review-label", findings or [])
        f.ledger.accept("accept-label")

    def author_handle(self) -> str:
        f = self.f
        state = f.ledger.read()
        node = next(n for n in state["graph"]["nodes"] if n["id"] == "write-label")
        return (
            state["sessions"].get(agent_key(node), {}).get("handle", agent_key(node) + "-session")
        )

    def second(self, content: str = "Final authorized outcome") -> None:
        f = self.f
        f.start("write-second", self.author_handle())
        (f.root / "lib/example.dart").write_text(content)
        f.ledger.finish("write-second", f.report("write-second"))
        f.start("verify-second", self.author_handle())
        f.ledger.finish("verify-second", f.report("verify-second"))
        self.review("review-second", [])
        f.ledger.accept("accept-second")

    def verify_all(
        self, outcome: str = "PASS", findings: list[dict[str, Any]] | None = None
    ) -> None:
        f = self.f
        f.start("verify-all", "independent-reviewer")
        f.ledger.finish("verify-all", f.report("verify-all", outcome, findings=findings or []))

    def review(self, node: str, findings: list[dict[str, Any]], outcome: str = "PASS") -> None:
        f = self.f
        f.start(node, "independent-reviewer")
        f.ledger.finish(
            node,
            f.report(
                node,
                outcome,
                findings=findings,
                verdict="APPROVE" if outcome == "PASS" else "NEEDS_WORK",
            ),
        )

    def finding(self, task: str = "label", owner: str = "write-label") -> dict[str, Any]:
        role = self.f.g["agents"]["author"]["role"]
        return dict(
            task_id=task,
            id="REV-1",
            status="open",
            blocking=True,
            owner_role=role,
            owner_node_id=owner,
            summary="Integration regression",
            evidence="Current failing scenario",
        )

    def test_final_judge_runs_all_gates_then_reviews_same_session(self) -> None:
        f = self.f
        for kind in ["static", "build"]:
            spec = deepcopy(f.g["tasks"]["integrated"]["required_checks"][0])
            spec.update(id="final-" + kind, kind=kind, category="project", criteria=[])
            f.g["tasks"]["integrated"]["required_checks"].append(spec)
        f.init()
        self.first()
        self.second()
        f.start("verify-all", "independent-reviewer")
        report = f.report("verify-all")
        report["checks"] += [
            f.ledger.run_check("verify-all", "final-" + kind) for kind in ["static", "build"]
        ]
        f.ledger.finish("verify-all", report)
        self.review("review-all", [])
        f.ledger.accept("accept-all")
        f.ledger.archive("completed", "Judge checked tests static and build")
        state = f.ledger.read()
        self.assertEqual({"tests", "static", "build"}, {c["kind"] for c in report["checks"]})
        self.assertEqual(
            state["nodes"]["verify-all"]["handle"], state["nodes"]["review-all"]["handle"]
        )
        self.assertNotEqual(
            state["nodes"]["write-label"]["handle"], state["nodes"]["review-all"]["handle"]
        )

    def test_final_review_refreshes_prior_closure_after_later_shared_file_write(self) -> None:
        f = self.f
        f.init()
        f.start("write-label")
        f.ledger.finish("write-label", f.report("write-label"))
        f.start("verify-label")
        f.ledger.finish("verify-label", f.report("verify-label"))
        self.review("review-label", [self.finding()], "FAIL")
        f.ledger.retry("write-label", "review", "Fix original finding", "All workers terminal")
        self.first([dict(id="REV-1", status="fixed", evidence="Slice recheck")], ready=True)
        prior = f.ledger.read()["review_findings"]["label"]["REV-1"]["reviewed"]
        self.second()
        self.verify_all()
        state = f.ledger.read()
        with self.assertRaisesRegex(ValueError, "Stale"):
            review_findings.gate(
                state,
                "label",
                snapshot(f.root, state["graph"]["tasks"]["label"]["scope"]),
                state["graph"]["sources"]["request"]["hash"],
            )
        f.ledger.claim("review-all")
        packet = f.ledger.packet("review-all")
        self.assertEqual("label", packet["review_findings"]["label:REV-1"]["task_id"])
        self.assertEqual("REV-1", packet["review_findings"]["label:REV-1"]["id"])
        self.assertNotIn("history", packet["review_findings"]["label:REV-1"])
        self.assertEqual("label", packet["integration_owners"]["write-label"]["task_id"])
        self.assertEqual("generalist", packet["integration_owners"]["write-label"]["role"])
        self.assertEqual(["lib/example.dart"], packet["integration_owners"]["write-label"]["owns"])
        self.assertEqual({"label", "second"}, set(packet["integration_tasks"]))
        f.ledger.bind("review-all", "independent-reviewer", "gpt-6.1-sol")
        with self.assertRaisesRegex(Invalid, "omitted"):
            f.ledger.finish("review-all", f.report("review-all", verdict="APPROVE", findings=[]))
        f.ledger.finish(
            "review-all",
            f.report(
                "review-all",
                verdict="APPROVE",
                findings=[
                    dict(
                        task_id="label",
                        id="REV-1",
                        status="fixed",
                        evidence="Independent final byte recheck",
                    )
                ],
            ),
        )
        f.ledger.accept("accept-all")
        f.ledger.archive("completed", "Integration rechecked original finding")
        item = f.ledger.read()["review_findings"]["label"]["REV-1"]
        self.assertEqual(prior, item["history"][-2])
        self.assertNotEqual(prior["files"], item["reviewed"]["files"])
        self.assertEqual("integrated", item["reviewed"]["review_task_id"])
        (f.root / "lib/example.dart").write_text("Later regression")
        with self.assertRaisesRegex(ValueError, "Stale"):
            review_findings.gate(
                f.ledger.read(),
                "label",
                snapshot(f.root, state["graph"]["tasks"]["label"]["scope"]),
                state["graph"]["sources"]["request"]["hash"],
            )

    def test_integration_findings_are_task_qualified_and_owner_is_explicit(self) -> None:
        f = self.f
        f.init()
        self.first()
        self.second()
        self.verify_all()
        f.ledger.claim("review-all")
        f.ledger.bind("review-all", "independent-reviewer", "gpt-6.1-sol")
        bad = self.finding()
        bad.pop("owner_node_id")
        with self.assertRaisesRegex(Invalid, "requires owner_node_id"):
            f.ledger.finish(
                "review-all", f.report("review-all", "FAIL", verdict="NEEDS_WORK", findings=[bad])
            )
        bad = self.finding(owner="write-second")
        with self.assertRaisesRegex(Invalid, "owner_node_id"):
            f.ledger.finish(
                "review-all", f.report("review-all", "FAIL", verdict="NEEDS_WORK", findings=[bad])
            )
        findings = [self.finding(), self.finding("second", "write-second")]
        f.ledger.finish(
            "review-all", f.report("review-all", "FAIL", verdict="NEEDS_WORK", findings=findings)
        )
        state = f.ledger.read()
        self.assertEqual(
            {"label:REV-1", "second:REV-1"}, set(review_findings.view(state, "integrated"))
        )
        self.assertEqual("open", state["review_findings"]["label"]["REV-1"]["status"])
        self.assertEqual("open", state["review_findings"]["second"]["REV-1"]["status"])

    def test_failed_integration_verification_routes_to_predecessor_then_rechecks(self) -> None:
        f = self.f
        f.g["agents"]["author"] = dict(role="developer", profile="middle-developer")
        f.config["profiles"]["middle-developer"]["escalation"] = {
            "to": "senior-developer",
            "after_failed_attempts": 2,
        }
        f.g["tasks"]["integrated"]["required_checks"][0]["execution"]["argv"] = [
            sys.executable,
            "-c",
            "from pathlib import Path; raise SystemExit(0 if Path('lib/example.dart').read_text() == 'Final corrected shared result' else 1)",
        ]
        f.init()
        self.first()
        self.second()
        self.verify_all("FAIL", [self.finding()])
        state = f.ledger.read()
        request = dict(
            author_dispatch_id=state["nodes"]["write-label"]["dispatch_id"],
            evidence_node="verify-all",
            evidence_dispatch_id=state["nodes"]["verify-all"]["dispatch_id"],
            cause="review",
            kind="quality",
            reason="Judge reproduced predecessor defect",
            terminal_evidence="All tasks terminal",
            handoff="label:REV-1 remains open",
        )
        self.assertEqual("retry", f.ledger.correct("write-label", request)["decision"])
        state = f.ledger.read()
        self.assertEqual({"label:review": 1}, state["counters"])
        self.assertTrue(all(v["status"] == "pending" for v in state["nodes"].values()))
        self.first([dict(id="REV-1", status="fixed", evidence="Slice recheck")], ready=True)
        # A real project fixture is repaired; the declared gate remains unchanged.
        # The initial command uses a project input that the author may repair.
        self.second("Final corrected shared result")
        self.verify_all()
        self.review(
            "review-all",
            [dict(task_id="label", id="REV-1", status="fixed", evidence="Final regression gone")],
        )
        f.ledger.accept("accept-all")
        f.ledger.archive("completed", "Corrected integration finding")
        self.assertEqual(
            ["open", "ready", "fixed", "fixed"],
            [e["status"] for e in f.ledger.read()["review_findings"]["label"]["REV-1"]["history"]],
        )

    def test_cross_source_integration_correction_checks_exact_owner_and_fresh_bytes(self) -> None:
        f = self.f
        f.g["agents"]["author"] = dict(role="developer", profile="middle-developer")
        f.config["profiles"]["middle-developer"]["escalation"] = {
            "to": "senior-developer",
            "after_failed_attempts": 2,
        }
        f.g["sources"]["other"] = deepcopy(f.g["sources"]["request"])
        f.g["sources"]["other"]["text"] = "Independent integration source"
        task = f.g["tasks"]["integrated"]
        task["source"] = "other"
        task["acceptance_ids"].append("request:AC-01")
        task["required_checks"][0]["criteria"].append("request:AC-01")
        f.init()
        self.first()
        self.second()
        self.verify_all("FAIL", [self.finding()])
        state = f.ledger.read()
        request = dict(
            author_dispatch_id=state["nodes"]["write-second"]["dispatch_id"],
            evidence_node="verify-all",
            evidence_dispatch_id=state["nodes"]["verify-all"]["dispatch_id"],
            cause="tests",
            kind="quality",
            reason="Integration failure",
            terminal_evidence="All terminal",
            handoff="Correct task-qualified finding",
        )
        with self.assertRaisesRegex(Invalid, "assigned to this author"):
            f.ledger.correct("write-second", request)
        self.assertEqual(state, f.ledger.read())
        request["author_dispatch_id"] = state["nodes"]["write-label"]["dispatch_id"]
        original = (f.root / "lib/example.dart").read_text()
        (f.root / "lib/example.dart").write_text("Changed after integration failure")
        with self.assertRaisesRegex(Invalid, "evidence is stale"):
            f.ledger.correct("write-label", request)
        self.assertEqual(state, f.ledger.read())
        (f.root / "lib/example.dart").write_text(original)
        self.assertEqual("retry", f.ledger.correct("write-label", request)["decision"])
        item = f.ledger.read()["review_findings"]["label"]["REV-1"]
        self.assertEqual(
            state["graph"]["sources"]["request"]["hash"], item["reviewed"]["source_hash"]
        )
        self.assertNotEqual(
            state["graph"]["sources"]["other"]["hash"], item["reviewed"]["source_hash"]
        )

    def test_judge_verify_cannot_close_findings_or_use_writer_session(self) -> None:
        f = self.f
        f.init()
        self.first()
        self.second()
        f.ledger.claim("verify-all")
        with self.assertRaisesRegex(Invalid, "different logical agent"):
            f.ledger.bind("verify-all", self.author_handle(), "gpt-6.1-sol")
        f.ledger.bind("verify-all", "independent-reviewer", "gpt-6.1-sol")
        closed = self.finding()
        closed["status"] = "dismissed"
        with self.assertRaisesRegex(Invalid, "closure requires review"):
            f.ledger.finish("verify-all", f.report("verify-all", findings=[closed]))


if __name__ == "__main__":
    unittest.main()
