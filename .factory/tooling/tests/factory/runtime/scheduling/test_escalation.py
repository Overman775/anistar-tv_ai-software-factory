"""End-to-end ledger corrections; fixture commands only, no model calls."""

from __future__ import annotations

import json
import subprocess
import unittest
from collections.abc import Callable
from copy import deepcopy
from pathlib import Path
from typing import Any
from unittest.mock import Mock, patch

from factory.adapters.acpx_adapter import prepare_prompt
from factory.database.port import DatabaseBackend
from factory.database.provider import use_database
from factory.runtime.contracts import agent_key
from factory.runtime.graph_inputs import PROPOSAL, propose
from factory.runtime.history.document import render
from factory.runtime.scheduling import escalation
from factory.runtime.scheduling.assignment import validate_packet
from factory.runtime.workflow_config import load_config
from factory.runtime.workflow_core import Invalid
from tests import CLI
from tests.factory.runtime import workflow_fixture
from tests.factory.runtime.store_fixture import overwrite

ROOT = workflow_fixture.ROOT


class EscalationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.f = workflow_fixture.WorkflowFixture(self.addCleanup)
        self.f.g["agents"]["author"] = dict(role="implementer", profile="middle-implementer")
        self.f.config["_defaults"]["implementer"] = "middle-implementer"
        self.f.require_fixture_review()

    def batch(self) -> None:
        f = self.f
        f.batch()
        f.g["nodes"].append(
            dict(
                id="review-second",
                task="second",
                stage="review",
                agent="fixture-judge",
                depends_on=["verify-second"],
                owns=[],
                resources=["project-checks"],
            )
        )
        next(n for n in f.g["nodes"] if n["id"] == "accept-second")["depends_on"] = [
            "review-second"
        ]

    def fail_verification(
        self, role_result: str = "FAIL", outcome: str = "FAIL", start: bool = True
    ) -> dict[str, str]:
        f = self.f
        if start:
            state = f.ledger.read()
            agent = next(agent_key(n) for n in state["graph"]["nodes"] if n["id"] == "write-label")
            session = state["sessions"].get(agent)
            handle = (
                session["handle"] if session else "writer-" + str(len(state.get("corrections", [])))
            )
            f.start("write-label", handle)
            f.ledger.finish("write-label", f.report("write-label"))
            s = f.ledger.read()
            agent = agent_key(s["graph"]["nodes"][0])
            handle = s["sessions"][agent]["handle"]
            f.start("verify-label")
        f.ledger.finish(
            "verify-label",
            f.report("verify-label", outcome=outcome, stage_result=role_result, checks=[]),
        )
        s = f.ledger.read()
        return dict(
            author_dispatch_id=s["nodes"]["write-label"]["dispatch_id"],
            evidence_node="verify-label",
            evidence_dispatch_id=s["nodes"]["verify-label"]["dispatch_id"],
            cause="tests",
            kind="quality" if outcome == "FAIL" else "requirements",
            reason="Confirmed failing behavior; next approach documented",
            terminal_evidence="Both turns returned terminal; no process remains",
            handoff="Keep AC-01. Failure log and rejected hypothesis in evidence; inspect current files.",
        )

    def test_profiles_keep_one_task_budget_and_stop_after_senior_failure(self) -> None:
        f = self.f
        f.init()
        for expected in ["senior-implementer", "senior-implementer"]:
            decision = f.ledger.correct("write-label", self.fail_verification())
            self.assertEqual(expected, decision["to_profile"])
            s = f.ledger.read()
            self.assertEqual("pending", s["nodes"]["write-label"]["status"])
            self.assertEqual(
                f.g["tasks"]["label"]["required_checks"],
                s["graph"]["tasks"]["label"]["required_checks"],
            )
        result = f.ledger.correct("write-label", self.fail_verification())
        self.assertEqual("human", result["decision"])
        self.assertEqual(2, f.ledger.read()["counters"]["label:tests"])
        self.assertEqual(0, result["budget_remaining"])
        with self.assertRaisesRegex(Invalid, "Budget exhausted"):
            f.ledger.resume_task("label", "try again")

    def test_timeline_preserves_repeated_decisions_and_their_original_dispatches(self) -> None:
        f = self.f
        run = f.init()["run_id"]
        expected = []
        for decision in ("escalate", "retry", "human"):
            request = self.fail_verification()
            record = f.ledger.correct("write-label", request)
            f.ledger.correct("write-label", request)
            expected.append(
                {
                    "factory.node.id": "write-label",
                    "factory.dispatch.id": request["author_dispatch_id"],
                    "factory.correction.evidence_node": "verify-label",
                    "factory.correction.evidence_dispatch": request["evidence_dispatch_id"],
                    "factory.correction.cause": "tests",
                    "factory.correction.from_profile": record["from_profile"],
                    "factory.correction.to_profile": record["to_profile"],
                    "factory.correction.decision": decision,
                }
            )
        for archived in (False, True):
            if archived:
                f.ledger.archive("cancelled", "Fixture")
                f.ledger.clean()
            reply = subprocess.run(
                [
                    *CLI,
                    "telemetry",
                    "show",
                    "--workspace",
                    str(f.root),
                    "--run",
                    run,
                ],
                capture_output=True,
                text=True,
                check=True,
            )
            root = json.loads(reply.stdout)["observations"][0]
            self.assertEqual(
                [
                    e["attributes"]
                    for e in root["events"]
                    if e["name"] == "factory.run.correction_decided"
                ],
                expected,
            )
            self.assertNotIn(request["handoff"], reply.stdout)

    def test_replay_and_conflicting_diagnosis_cannot_spend_again(self) -> None:
        f = self.f
        f.init()
        request = self.fail_verification()
        other = Mock(spec_set=DatabaseBackend)
        other.history.stored_evidence.side_effect = AssertionError("read from another backend")
        with use_database(other):
            first = f.ledger.correct("write-label", request)
        before = f.ledger.read()
        self.assertEqual(first, f.ledger.correct("write-label", request))
        self.assertEqual(before, f.ledger.read())
        changed = dict(request, cause="review")
        with self.assertRaisesRegex(Invalid, "Conflicting"):
            f.ledger.correct("write-label", changed)

    def test_revision_retries_failed_tests_after_diagnosed_implementer_repair(self) -> None:
        f = self.f
        f.g["agents"].update(
            tester=dict(role="tester", profile="tester"),
            diagnostician=dict(role="bug-hunter", profile="bug-hunter"),
        )
        f.g["tasks"]["label"]["scope"].append("lib/example_test.dart")
        f.g["nodes"].extend(
            [
                dict(
                    id="test-label",
                    task="label",
                    stage="verify",
                    agent="tester",
                    depends_on=[],
                    owns=[],
                    required_check_ids=["behavior"],
                    resources=["project-checks"],
                ),
                dict(
                    id="diagnose-label",
                    task="label",
                    stage="explore",
                    agent="diagnostician",
                    depends_on=[],
                    owns=[],
                    resources=[],
                ),
            ]
        )
        f.g["nodes"][0].update(depends_on=["test-label", "diagnose-label"], resources=[])
        f.init()
        f.start("test-label", "tester")
        failed = f.report("test-label", "FAIL", stage_result="FAIL_TEST", checks=[])
        f.ledger.finish("test-label", failed)
        f.start("diagnose-label", "diagnostician")
        diagnosis = f.report(
            "diagnose-label",
            stage_result="ROOT_CAUSE_FOUND",
            role_material=[
                {
                    "kind": "reproduction",
                    "observation": "The fixture label differs from the assertion",
                    "paths": ["lib/example.dart"],
                },
                {
                    "kind": "cause",
                    "observation": "The current label constant differs from the source",
                    "paths": ["lib/example.dart"],
                },
            ],
        )
        f.ledger.finish("diagnose-label", diagnosis)

        graph = f.ledger.read()["graph"]
        nodes = {node["id"]: node for node in graph["nodes"]}
        nodes["write-label"]["depends_on"] = ["diagnose-label"]
        nodes["test-label"]["depends_on"] = ["write-label"]
        nodes["verify-label"]["depends_on"] = ["test-label"]
        reason = "BugHunter traced the failing assertion to the production label"
        retry = ("test-label", failed["dispatch_id"], "diagnose-label", "write-label")
        before = f.ledger.read()
        production = f.root / "lib/example.dart"
        production.write_text("edited too early")
        with self.assertRaisesRegex(Invalid, "Test retry evidence is stale"):
            f.ledger.revise(graph, reason, retry_tests=retry)
        production.write_text("before")
        with (
            patch("factory.database.sqlite.workflow_db.save", side_effect=OSError("disk full")),
            self.assertRaisesRegex(OSError, "disk full"),
        ):
            f.ledger.revise(graph, reason, retry_tests=retry)
        self.assertEqual(before, f.ledger.read())

        proposal = propose(f.root, PROPOSAL.validate_python(graph))
        result = subprocess.run(
            [
                *CLI,
                "workflow",
                "--workspace",
                str(f.root),
                "revise",
                proposal,
                reason,
                "--retry-tests",
                *retry,
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(0, result.returncode, result.stderr)
        revised = f.ledger.read()
        self.assertEqual({"label:tests": 1}, revised["counters"])
        self.assertEqual(
            diagnosis["dispatch_id"], revised["events"][-1]["test_retry"]["diagnosis_dispatch"]
        )
        self.assertNotIn("corrections", revised)
        with self.assertRaisesRegex(Invalid, "current blocked test dispatch"):
            f.ledger.revise(graph, reason, retry_tests=retry)
        without_repair = deepcopy(graph)
        candidate = {node["id"]: node for node in without_repair["nodes"]}
        candidate["test-label"]["depends_on"] = []
        candidate["verify-label"]["depends_on"] = ["test-label", "write-label"]
        with self.assertRaisesRegex(Invalid, "Keep the Implementer repair dependency"):
            f.ledger.revise(without_repair, "try to remove the repair prerequisite")
        self.assertEqual(revised, f.ledger.read())

        with self.assertRaisesRegex(Invalid, "Dependencies not complete"):
            f.claim("test-label")
        f.start("write-label")
        production.write_text("after")
        f.ledger.finish("write-label", f.report("write-label", stage_result="WRITES_READY"))
        f.start("test-label", "tester")
        with self.assertRaisesRegex(Invalid, "Stale report identity"):
            f.ledger.finish("test-label", failed)
        passed = f.report("test-label", stage_result="PASS")
        f.ledger.finish("test-label", passed)
        final = f.ledger.read()
        self.assertEqual({"label:tests": 1}, final["counters"])
        self.assertEqual("done", final["nodes"]["test-label"]["status"])
        self.assertIn(failed["dispatch_id"], final["report_index"])
        self.assertIn(passed["dispatch_id"], final["report_index"])
        self.assertIn("verify-label", f.ledger.next_actions()["runnable"])

    def test_failed_save_leaves_original_state_and_retry_is_safe(self) -> None:
        f = self.f
        f.init()
        request = self.fail_verification()
        before = f.ledger.read()
        with patch("factory.database.sqlite.workflow_db.save", side_effect=OSError("disk full")):
            with self.assertRaises(OSError):
                f.ledger.correct("write-label", request)
        self.assertEqual(before, f.ledger.read())
        self.assertEqual("escalate", f.ledger.correct("write-label", request)["decision"])
        self.assertEqual(1, f.ledger.read()["counters"]["label:tests"])

    def test_worker_gets_task_history_not_routing_policy_in_native_and_acp(self) -> None:
        f = self.f
        f.g["agents"]["author"] = dict(role="implementer", profile="middle-implementer-zcode")
        f.config["_defaults"]["implementer"] = "middle-implementer-zcode"
        f.init()
        decision = f.ledger.correct("write-label", self.fail_verification("FAIL_TEST"))
        self.assertEqual("senior-implementer", decision["to_profile"])
        f.claim("write-label")
        s = f.ledger.read()
        packet = f.ledger.packet("write-label")
        self.assertNotIn("escalation", packet["profile"])
        self.assertNotIn("runner", packet["profile"])
        self.assertEqual(1, len(packet["correction"]["history"]))
        self.assertEqual(1, packet["correction"]["remaining_retries"]["tests"])
        self.assertEqual(s["graph"]["sources"]["request"], packet["source"])
        # Model an ACP reservation with identical scoped correction context.
        s["graph"]["agents"][agent_key(s["graph"]["nodes"][0])]["profile"] = (
            "middle-implementer-zcode"
        )
        s["nodes"]["write-label"]["profile"] = "middle-implementer-zcode"
        with patch.object(f.ledger, "read", return_value=s):
            prepared = prepare_prompt(f.ledger, "write-label")
        ref = s["nodes"]["write-label"]["packet_file"]
        envelope = validate_packet(
            f.ledger.history.document(f.root, ref["run_id"], ref["path"], ref["sha256"], "packet")
        )
        self.assertEqual(Path(prepared["prompt"]).read_bytes(), render(envelope))
        self.assertEqual(packet["correction"], envelope["correction"])
        self.assertNotIn("escalation", envelope["profile"])

    def test_old_handle_and_wrong_model_rejected_after_escalation(self) -> None:
        f = self.f
        f.init()
        request = self.fail_verification()
        old = f.ledger.read()["sessions"]["author"]["handle"]
        f.ledger.correct("write-label", request)
        f.claim("write-label")
        with self.assertRaisesRegex(Invalid, "different logical agent"):
            f.ledger.bind("write-label", old, "gpt-6.1-terra")
        with self.assertRaisesRegex(Invalid, "Actual model differs"):
            f.ledger.bind("write-label", "new", "gpt-6.1-terra")
        f.ledger.bind("write-label", "new", "gpt-6.1-sol")

    def test_code_and_test_failures_route_to_same_implementer(self) -> None:
        f = self.f
        f.g["agents"]["author"] = dict(role="implementer", profile="middle-implementer")
        f.init()
        request = self.fail_verification("FAIL_CODE")
        result = f.ledger.correct("write-label", request)
        self.assertEqual("senior-implementer", result["to_profile"])

    def test_blocker_does_not_raise_model_or_count_quality_failure(self) -> None:
        f = self.f
        f.init()
        request = self.fail_verification("BLOCKED_TOOL_ERROR", "BLOCKED")
        request["kind"] = "environment"
        result = f.ledger.correct("write-label", request)
        self.assertEqual("blocked", result["decision"])
        self.assertEqual(0, result["failure_count"])
        self.assertEqual({}, f.ledger.read()["counters"])
        with self.assertRaisesRegex(Invalid, "Task stopped"):
            f.ledger.retry("write-label", "recovery", "fix", "stopped")
        f.ledger.resume_task("label", "Actual tool restored; coordinator verified")
        self.assertEqual({"label:recovery": 1}, f.ledger.read()["counters"])
        f.claim("write-label")
        self.assertIn(
            "Actual tool restored",
            f.ledger.packet("write-label")["correction"]["blocker_resolutions"][0]["evidence"],
        )

    def test_environment_resume_uses_recovery_even_after_quality_budget_exhausted(self) -> None:

        f = self.f
        f.init()
        request = self.fail_verification("BLOCKED_TOOL_ERROR", "BLOCKED")
        request["kind"] = "environment"
        state = f.ledger.read()
        state["counters"]["label:tests"] = 2
        overwrite(f.ledger, state)
        result = f.ledger.correct("write-label", request)
        self.assertEqual("recovery", result["budget_cause"])
        self.assertFalse(f.ledger.read()["escalation_stops"]["label"]["budget_exhausted"])
        f.ledger.resume_task("label", "Environment restored and tool checked")
        self.assertEqual({"label:tests": 2, "label:recovery": 1}, f.ledger.read()["counters"])
        self.assertEqual("pending", f.ledger.read()["nodes"]["write-label"]["status"])

    def test_source_drift_reintake_requires_explicit_budgeted_resume_and_keeps_history(
        self,
    ) -> None:
        f = self.f
        (f.root / "task.md").write_text("Initial authorized request")
        f.g["sources"]["request"].pop("text")
        f.g["sources"]["request"]["path"] = "task.md"
        f.init()
        f.start("write-label")
        (f.root / "task.md").write_text("Changed authorized request")
        state = f.ledger.read()
        state["graph"]["sources"]["request"]["snapshot"] = "corrupt"
        overwrite(f.ledger, state)
        draft = f.report("write-label", "BLOCKED")
        draft.pop("files")
        report = f.ledger.prepare_report("write-label", draft, [])
        f.ledger.finish("write-label", report)
        before = f.ledger.read()
        self.assertTrue(before["nodes"]["write-label"]["report"]["observed_source_drift"])
        f.ledger.reintake(deepcopy(before["graph"]), "User clarified source", "user-message-42")
        state = f.ledger.read()
        self.assertEqual(before["nodes"]["write-label"], state["nodes"]["write-label"])
        self.assertEqual(before["counters"], state["counters"])
        with self.assertRaisesRegex(Invalid, "Already dispatched|Task stopped"):
            f.claim("write-label")
        f.ledger.resume_task("label", "New source authorized and no worker remains")
        state = f.ledger.read()
        self.assertEqual({"label:recovery": 1}, state["counters"])
        self.assertEqual("pending", state["nodes"]["write-label"]["status"])
        intake = next(e for e in state["events"] if e["event"] == "source_reintake")
        self.assertEqual(before["nodes"], intake["previous_nodes"])
        f.claim("write-label")
        self.assertIn(
            "New source authorized",
            f.ledger.packet("write-label")["correction"]["blocker_resolutions"][0]["evidence"],
        )

    def test_reintake_does_not_create_recovery_for_quality_failure(self) -> None:
        f = self.f
        f.init()
        self.fail_verification()
        before = f.ledger.read()
        graph = deepcopy(before["graph"])
        graph["sources"]["request"]["text"] = "Updated request"
        f.ledger.reintake(graph, "Clarification", "message-43")
        with self.assertRaisesRegex(Invalid, "no escalation stop"):
            f.ledger.resume_task("label", "Attempt free retry")
        with self.assertRaisesRegex(Invalid, "Use correct"):
            f.ledger.retry("verify-label", "recovery", "Try stale failure", "stopped")

    def test_complexity_cannot_promote_before_a_quality_failure(self) -> None:
        f = self.f
        f.init()
        request = self.fail_verification("BLOCKED", "BLOCKED")
        with self.assertRaisesRegex(Invalid, "kind: Input should be"):
            f.ledger.correct("write-label", {**request, "kind": "complexity"})
        self.assertEqual({}, f.ledger.read()["counters"])

    def test_wr_ready_cannot_trigger_escalation(self) -> None:
        f = self.f
        f.init()
        f.start("write-label")
        f.ledger.finish("write-label", f.report("write-label"))
        s = f.ledger.read()
        dispatch = s["nodes"]["write-label"]["dispatch_id"]
        request = dict(
            author_dispatch_id=dispatch,
            evidence_node="write-label",
            evidence_dispatch_id=dispatch,
            cause="tests",
            kind="quality",
            reason="guess",
            terminal_evidence="stopped",
            handoff="facts",
        )
        with self.assertRaisesRegex(Invalid, "failed/blocked"):
            f.ledger.correct("write-label", request)

    def test_senior_retries_same_session_below_threshold(self) -> None:
        f = self.f
        f.init()
        f.ledger.correct("write-label", self.fail_verification())
        request = self.fail_verification()
        session = deepcopy(f.ledger.read()["sessions"])
        result = f.ledger.correct("write-label", request)
        self.assertEqual("retry", result["decision"])
        self.assertEqual(session, f.ledger.read()["sessions"])

    def test_stale_report_and_unknown_state_are_not_retry_signals(self) -> None:
        f = self.f
        f.init()
        request = self.fail_verification()
        before = f.ledger.read()
        (f.root / "lib/example.dart").write_text("changed after verification")
        with self.assertRaisesRegex(Invalid, "evidence is stale"):
            f.ledger.correct("write-label", request)
        self.assertEqual(before, f.ledger.read())

    def test_plain_retry_cannot_bypass_profile_policy(self) -> None:
        f = self.f
        f.init()
        self.fail_verification()
        with self.assertRaisesRegex(Invalid, "Use correct"):
            f.ledger.retry("write-label", "tests", "again", "stopped")
        with self.assertRaisesRegex(Invalid, "Use correct"):
            f.ledger.retry("write-label", "recovery", "again", "stopped")

    def test_static_failure_uses_static_quality_budget(self) -> None:
        f = self.f
        f.init()
        request = self.fail_verification("BLOCKED_STATIC_FAILURE", "BLOCKED")
        request.update(kind="quality", cause="static")
        self.assertEqual("escalate", f.ledger.correct("write-label", request)["decision"])
        self.assertEqual({"label:static": 1}, f.ledger.read()["counters"])

    def test_human_resume_opens_work_and_spends_remaining_budget_once(self) -> None:
        f = self.f
        f.init()
        f.ledger.correct("write-label", self.fail_verification())
        request = self.fail_verification("BLOCKED", "BLOCKED")
        self.assertEqual("blocked", f.ledger.correct("write-label", request)["decision"])
        f.ledger.resume_task("label", "Human supplied missing implementation decision")
        self.assertEqual({"label:tests": 2}, f.ledger.read()["counters"])
        self.assertEqual("pending", f.ledger.read()["nodes"]["write-label"]["status"])
        before = f.ledger.read()
        with self.assertRaisesRegex(Invalid, "no escalation stop"):
            f.ledger.resume_task("label", "replay")
        self.assertEqual(before, f.ledger.read())

    def test_exhausted_recovery_keeps_blocker_and_state(self) -> None:
        f = self.f
        f.init()
        for attempt in range(2):
            request = self.fail_verification("BLOCKED_TOOL_ERROR", "BLOCKED")
            request["kind"] = "environment"
            f.ledger.correct("write-label", request)
            if attempt == 0:
                old_stop = f.ledger.next_actions()["task_stops"]["label"]["stop_id"]
                f.ledger.resume_task("label", "Environment restored", stop_id=old_stop)
        before = f.ledger.read()
        self.assertNotEqual(old_stop, f.ledger.next_actions()["task_stops"]["label"]["stop_id"])
        with self.assertRaisesRegex(Invalid, "decision is stale"):
            f.ledger.resume_task("label", "Environment restored", stop_id=old_stop)
        with self.assertRaisesRegex(Invalid, "Budget exhausted"):
            f.ledger.resume_task("label", "Still unavailable")
        self.assertEqual(before, f.ledger.read())

    def test_task_rejects_independent_product_authors(self) -> None:
        f = self.f
        f.g["agents"]["sibling"] = dict(role="implementer", profile="middle-implementer")
        extra = deepcopy(f.g["nodes"][0])
        extra.update(id="write-sibling", agent="sibling")
        f.g["nodes"].append(extra)
        f.g["nodes"][1]["depends_on"].append("write-sibling")
        with self.assertRaisesRegex(Invalid, "at most one product author"):
            f.init()

    def test_task_history_is_scoped_and_old_profile_cannot_be_reintroduced(self) -> None:
        f = self.f
        f.init()
        f.ledger.correct("write-label", self.fail_verification())
        s = f.ledger.read()
        other = deepcopy(s)
        other["graph"]["tasks"]["other"] = deepcopy(other["graph"]["tasks"]["label"])
        self.assertEqual([], escalation.worker_context(other, "other")["history"])
        graph = deepcopy(s["graph"])
        graph["agents"]["new"] = {"role": "implementer", "profile": "junior-implementer"}
        graph["nodes"][0]["agent"] = "new"
        with self.assertRaisesRegex(Invalid, "Correction agent mismatch"):
            f.ledger.revise(graph, "attempt to start over")

    def test_config_rejects_cycles_role_changes_bad_defaults_and_boolean_limits(self) -> None:
        mutations: list[Callable[[Any], object]] = [
            lambda c: c["profiles"]["senior-implementer"]["escalation"].update(
                to="junior-implementer"
            ),
            lambda c: c["profiles"]["junior-implementer"]["escalation"].update(to="tester"),
            lambda c: c["routing"]["defaults"].update({"roles/implementer.md": "tester"}),
            lambda c: c["execution"]["retry_budgets"].update(tests=True),
        ]
        for mutate in mutations:
            raw = deepcopy(self.f.config)
            mutate(raw)
            with self.subTest(mutate=mutate), self.assertRaises(ValueError):
                escalation.configure(raw)

    def test_switch_does_not_change_shared_agent_profile_for_other_tasks(self) -> None:
        f = self.f
        self.batch()
        f.init()
        f.ledger.correct("write-label", self.fail_verification())
        s = f.ledger.read()
        second = next(n for n in s["graph"]["nodes"] if n["id"] == "write-second")
        self.assertEqual("author", second["agent"])
        self.assertEqual("middle-implementer", s["graph"]["agents"]["author"]["profile"])
        self.assertEqual([], escalation.worker_context(s, "second")["history"])
        self.assertNotIn("second:tests", s["counters"])

    def test_complexity_cannot_disguise_environment_blocker(self) -> None:
        f = self.f
        f.init()
        request = self.fail_verification("BLOCKED_TOOL_ERROR", "BLOCKED")
        request["kind"] = "quality"
        with self.assertRaisesRegex(Invalid, "real blocker"):
            f.ledger.correct("write-label", request)

    def test_independent_reviewer_findings_and_gates_survive_correction(self) -> None:
        f = self.f
        f.g["tasks"]["label"].update(independent_review=True, risk="moderate", kind="feature")
        f.g["agents"]["reviewer"] = dict(role="judge", profile="judge")
        f.g["nodes"] = [n for n in f.g["nodes"] if n["id"] != "review-label"]
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
        f.start("write-label")
        f.ledger.finish("write-label", f.report("write-label"))
        f.start("verify-label")
        f.ledger.finish("verify-label", f.report("verify-label"))
        f.start("review-label", "independent-reviewer")
        finding = dict(
            id="REV-1",
            status="open",
            blocking=True,
            owner_role="implementer",
            summary="Incorrect label",
            evidence="Reproduction",
        )
        f.ledger.finish(
            "review-label",
            f.report(
                "review-label",
                "FAIL",
                stage_result="NEEDS_WORK",
                verdict="NEEDS_WORK",
                findings=[finding],
            ),
        )
        before = f.ledger.read()
        request = dict(
            author_dispatch_id=before["nodes"]["write-label"]["dispatch_id"],
            evidence_node="review-label",
            evidence_dispatch_id=before["nodes"]["review-label"]["dispatch_id"],
            cause="review",
            kind="quality",
            reason="Verified code defect",
            terminal_evidence="All stopped",
            handoff="REV-1 stays open",
        )
        f.ledger.correct("write-label", request)
        after = f.ledger.read()
        self.assertEqual(before["review_findings"], after["review_findings"])
        self.assertEqual(before["graph"]["tasks"], after["graph"]["tasks"])
        self.assertEqual("pending", after["nodes"]["review-label"]["status"])
        self.assertEqual(
            before["graph"]["agents"]["reviewer"], after["graph"]["agents"]["reviewer"]
        )
        f.claim("write-label")
        packet = f.ledger.packet("write-label")
        self.assertEqual("open", packet["review_findings"]["REV-1"]["status"])

    def test_other_active_assignment_blocks_correction_without_mutation(self) -> None:
        f = self.f
        self.batch()
        f.g["tasks"]["second"]["depends_on"] = []
        f.g["tasks"]["second"]["scope"] = ["lib/second.dart"]
        (f.root / "lib/second.dart").write_text("second")
        f.g["tasks"]["integrated"]["scope"].append("lib/second.dart")
        n = next(n for n in f.g["nodes"] if n["id"] == "write-second")
        n["depends_on"] = []
        n["owns"] = ["lib/second.dart"]
        f.init()
        request = self.fail_verification()
        f.claim("write-second")
        before = f.ledger.read()
        with self.assertRaisesRegex(Invalid, "Quiesce"):
            f.ledger.correct("write-label", request)
        self.assertEqual(before, f.ledger.read())
        f.ledger.unknown("write-second", "lost response")
        before = f.ledger.read()
        with self.assertRaisesRegex(Invalid, "Quiesce"):
            f.ledger.correct("write-label", request)
        self.assertEqual(before, f.ledger.read())

    def test_explicit_replacement_handoff_is_task_scoped(self) -> None:
        f = self.f
        self.batch()
        f.init()
        self.fail_verification()
        before = f.ledger.read()
        with self.assertRaisesRegex(Invalid, "Multi-task"):
            f.ledger.replace_session("author", "new context", "stopped", "unsplit private history")
        self.assertEqual(before, f.ledger.read())
        f.ledger.replace_session(
            "author",
            "new context",
            "stopped",
            {"label": "label only", "second": "second only"},
        )
        s = f.ledger.read()
        self.assertEqual(
            [{"agent": "author", "handoff": "label only"}],
            escalation.worker_context(s, "label")["session_handoffs"],
        )
        self.assertEqual(
            [{"agent": "author", "handoff": "second only"}],
            escalation.worker_context(s, "second")["session_handoffs"],
        )

    def test_same_profile_sibling_assignments_advance_without_deadlock(self) -> None:
        f = self.f
        f.g["agents"]["checker"] = dict(role="tester", profile="tester")
        f.g["nodes"][1]["agent"] = "checker"
        f.init()
        f.start("write-label", "author")
        f.ledger.finish("write-label", f.report("write-label"))
        f.start("verify-label", "checker")
        request = self.fail_verification(start=False)
        result = f.ledger.correct("write-label", request)
        s = f.ledger.read()
        self.assertEqual({"author"}, set(result["agents"]))
        self.assertNotEqual(s["graph"]["nodes"][0]["agent"], s["graph"]["nodes"][1]["agent"])
        f.start("write-label", "new-author")
        f.ledger.finish("write-label", f.report("write-label"))
        f.start("verify-label", "checker")
        f.ledger.finish("verify-label", f.report("verify-label"))
        f.start("review-label", "fixture-judge")
        f.ledger.finish("review-label", f.report("review-label", verdict="APPROVE", findings=[]))
        f.ledger.accept("accept-label")

    def test_backend_default_cannot_silently_change_model_in_existing_session(self) -> None:
        f = self.f
        f.g["agents"]["author"] = dict(role="implementer", profile="middle-implementer-zcode")
        f.config["_defaults"]["implementer"] = "middle-implementer-zcode"
        f.config["models"][f.config["profiles"]["middle-implementer-zcode"]["model"]]["id"] = None
        again = deepcopy(f.g["nodes"][0])
        again.update(id="write-again", depends_on=["write-label"])
        f.g["nodes"].append(again)
        f.g["nodes"][1]["depends_on"] = ["write-again"]
        f.init()
        f.start("write-label", "acp-default")
        f.ledger.finish("write-label", f.report("write-label"))
        f.claim("write-again")
        with self.assertRaisesRegex(Invalid, "Effective model changed"):
            f.ledger.bind("write-again", "acp-default", "different-default")
        f.ledger.bind("write-again", "acp-default", "fixture-default")

    def test_yaml_example_loads_full_catalog_and_defaults(self) -> None:
        c = load_config(ROOT / "factory.example.yaml")
        self.assertNotIn("roles", c)
        self.assertEqual("middle-implementer", c["_defaults"]["implementer"])
        self.assertEqual("pi", c["profiles"]["middle-implementer-pi"]["connection"])
        self.assertEqual(r"builtin:zai-coding-plan\GLM-5.3", c["models"]["glm-5-3"]["id"])
        self.assertNotIn("zcode", c["models"])
        self.assertEqual("glm-5-3", c["profiles"]["middle-implementer-zcode"]["model"])

    def test_configuration_graph_and_state_have_no_schema_versions(self) -> None:
        f = self.f
        self.assertNotIn("version", f.config)
        self.assertNotIn("version", f.g)
        f.init()
        self.assertNotIn("version", f.ledger.read())


if __name__ == "__main__":
    unittest.main()
