"""End-to-end ledger corrections; fixture commands only, no model calls."""

from __future__ import annotations

import json
import unittest
from collections.abc import Callable
from copy import deepcopy
from pathlib import Path
from typing import Any
from unittest.mock import patch

from factory.adapters.acpx_adapter import prepare_prompt
from factory.runtime import escalation
from factory.runtime.contracts import agent_key
from factory.runtime.workflow_config import load_config
from factory.runtime.workflow_core import Invalid
from tests.factory.runtime import workflow_fixture

_TOOLS = Path(__file__).resolve().parents[3] / "bin"


ROOT = workflow_fixture.ROOT


class EscalationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.f = workflow_fixture.WorkflowFixture(self.addCleanup)
        self.f.g["agents"]["author"] = dict(role="developer", profile="middle-developer")
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
            f.start("verify-label", handle)
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
        for expected in ["senior-developer", "senior-developer"]:
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

    def test_replay_and_conflicting_diagnosis_cannot_spend_again(self) -> None:
        f = self.f
        f.init()
        request = self.fail_verification()
        first = f.ledger.correct("write-label", request)
        before = f.ledger.read()
        self.assertEqual(first, f.ledger.correct("write-label", request))
        self.assertEqual(before, f.ledger.read())
        changed = dict(request, cause="review")
        with self.assertRaisesRegex(Invalid, "Conflicting"):
            f.ledger.correct("write-label", changed)

    def test_failed_save_leaves_original_state_and_retry_is_safe(self) -> None:
        f = self.f
        f.init()
        request = self.fail_verification()
        before = f.ledger.read()
        with patch("factory.runtime.workflow.atomic_json", side_effect=OSError("disk full")):
            with self.assertRaises(OSError):
                f.ledger.correct("write-label", request)
        self.assertEqual(before, f.ledger.read())
        self.assertEqual("escalate", f.ledger.correct("write-label", request)["decision"])
        self.assertEqual(1, f.ledger.read()["counters"]["label:tests"])

    def test_worker_gets_task_history_not_routing_policy_in_native_and_acp(self) -> None:
        f = self.f
        f.g["agents"]["author"] = dict(role="test-writer", profile="middle-test-writer-zcode")
        f.config["_defaults"]["test-writer"] = "middle-test-writer-zcode"
        f.init()
        decision = f.ledger.correct("write-label", self.fail_verification("FAIL_TEST"))
        self.assertEqual("senior-test-writer", decision["to_profile"])
        f.ledger.claim("write-label")
        s = f.ledger.read()
        packet = f.ledger.packet("write-label")
        self.assertNotIn("escalation", packet["profile"])
        self.assertNotIn("runner", packet["profile"])
        self.assertEqual(1, len(packet["correction"]["history"]))
        self.assertEqual(1, packet["correction"]["remaining_retries"]["tests"])
        self.assertEqual(s["graph"]["sources"]["request"], packet["source"])
        # Model an ACP reservation with identical scoped correction context.
        s["graph"]["agents"][agent_key(s["graph"]["nodes"][0])]["profile"] = (
            "middle-test-writer-zcode"
        )
        s["nodes"]["write-label"]["profile"] = "middle-test-writer-zcode"
        with patch.object(f.ledger, "read", return_value=s):
            prepared = prepare_prompt(f.ledger, "write-label")
        prompt = Path(prepared["prompt"]).read_text()
        envelope = json.loads(prompt)
        self.assertEqual(packet["correction"], envelope["correction"])
        self.assertNotIn("escalation", envelope["profile"])

    def test_old_handle_and_wrong_model_rejected_after_escalation(self) -> None:
        f = self.f
        f.init()
        request = self.fail_verification()
        old = f.ledger.read()["sessions"]["author"]["handle"]
        f.ledger.correct("write-label", request)
        f.ledger.claim("write-label")
        with self.assertRaisesRegex(Invalid, "different logical agent"):
            f.ledger.bind("write-label", old, "gpt-6.1-terra")
        with self.assertRaisesRegex(Invalid, "Actual model differs"):
            f.ledger.bind("write-label", "new", "gpt-6.1-terra")
        f.ledger.bind("write-label", "new", "gpt-6.1-sol")

    def test_fail_code_is_not_a_testwriter_failure(self) -> None:
        f = self.f
        f.g["agents"]["author"] = dict(role="test-writer", profile="middle-test-writer")
        f.init()
        request = self.fail_verification("FAIL_CODE")
        before = f.ledger.read()
        with self.assertRaisesRegex(Invalid, "belongs to Developer"):
            f.ledger.correct("write-label", request)
        self.assertEqual(before, f.ledger.read())

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
        f.ledger.claim("write-label")
        self.assertIn(
            "Actual tool restored",
            f.ledger.packet("write-label")["correction"]["blocker_resolutions"][0]["evidence"],
        )

    def test_environment_resume_uses_recovery_even_after_quality_budget_exhausted(self) -> None:
        from factory.runtime.workflow_core import atomic_json

        f = self.f
        f.init()
        request = self.fail_verification("BLOCKED_TOOL_ERROR", "BLOCKED")
        request["kind"] = "environment"
        state = f.ledger.read()
        state["counters"]["label:tests"] = 2
        atomic_json(f.ledger.path, state)
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
            f.ledger.claim("write-label")
        f.ledger.resume_task("label", "New source authorized and no worker remains")
        state = f.ledger.read()
        self.assertEqual({"label:recovery": 1}, state["counters"])
        self.assertEqual("pending", state["nodes"]["write-label"]["status"])
        intake = next(e for e in state["events"] if e["event"] == "source_reintake")
        self.assertEqual(before["nodes"], intake["previous_nodes"])
        f.ledger.claim("write-label")
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
                f.ledger.resume_task("label", "Environment restored")
        before = f.ledger.read()
        with self.assertRaisesRegex(Invalid, "Budget exhausted"):
            f.ledger.resume_task("label", "Still unavailable")
        self.assertEqual(before, f.ledger.read())

    def test_independent_failed_siblings_are_diagnosed_separately(self) -> None:
        f = self.f
        f.g["agents"]["sibling"] = dict(role="developer", profile="middle-developer")
        extra = deepcopy(f.g["nodes"][0])
        extra.update(id="write-sibling", agent="sibling")
        f.g["nodes"].append(extra)
        f.g["nodes"][1]["depends_on"].append("write-sibling")
        f.init()
        requests: dict[str, Any] = {}
        for node in ["write-label", "write-sibling"]:
            f.start(node, node)
            f.ledger.finish(node, f.report(node, "FAIL", stage_result="FAIL_CODE", checks=[]))
            dispatch = f.ledger.read()["nodes"][node]["dispatch_id"]
            requests[node] = dict(
                author_dispatch_id=dispatch,
                evidence_node=node,
                evidence_dispatch_id=dispatch,
                cause="tests",
                kind="quality",
                reason="Confirmed defect",
                terminal_evidence="Stopped",
                handoff="Inspect defect",
            )
        f.ledger.correct("write-label", requests["write-label"])
        self.assertEqual(
            "middle-developer", f.ledger.read()["graph"]["agents"]["sibling"]["profile"]
        )
        self.assertEqual(
            "escalate", f.ledger.correct("write-sibling", requests["write-sibling"])["decision"]
        )
        self.assertEqual({"label:tests": 2}, f.ledger.read()["counters"])

    def test_task_history_is_scoped_and_old_profile_cannot_be_reintroduced(self) -> None:
        f = self.f
        f.init()
        f.ledger.correct("write-label", self.fail_verification())
        s = f.ledger.read()
        other = deepcopy(s)
        other["graph"]["tasks"]["other"] = deepcopy(other["graph"]["tasks"]["label"])
        self.assertEqual([], escalation.worker_context(other, "other")["history"])
        graph = deepcopy(s["graph"])
        graph["agents"]["new"] = {"role": "developer", "profile": "junior-developer"}
        graph["nodes"][0]["agent"] = "new"
        with self.assertRaisesRegex(Invalid, "Correction agent mismatch"):
            f.ledger.revise(graph, "attempt to start over")

    def test_config_rejects_cycles_role_changes_bad_defaults_and_boolean_limits(self) -> None:
        mutations: list[Callable[[Any], object]] = [
            lambda c: c["profiles"]["senior-developer"]["escalation"].update(to="junior-developer"),
            lambda c: c["profiles"]["junior-developer"]["escalation"].update(
                to="senior-test-writer"
            ),
            lambda c: c["routing"]["defaults"].update({"roles/developer.md": "generalist"}),
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
        self.assertEqual("middle-developer", s["graph"]["agents"]["author"]["profile"])
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
            owner_role="developer",
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
        f.ledger.claim("write-label")
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
        f.ledger.claim("write-second")
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
            json.dumps({"label": "label only", "second": "second only"}),
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
        f.g["agents"]["checker"] = dict(role="developer", profile="middle-developer")
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
        f.g["agents"]["author"] = dict(role="test-writer", profile="middle-test-writer-zcode")
        f.config["_defaults"]["test-writer"] = "middle-test-writer-zcode"
        f.config["models"][f.config["profiles"]["middle-test-writer-zcode"]["model"]]["id"] = None
        f.init()
        f.start("write-label", "acp-default")
        f.ledger.finish("write-label", f.report("write-label"))
        f.ledger.claim("verify-label")
        with self.assertRaisesRegex(Invalid, "Effective model changed"):
            f.ledger.bind("verify-label", "acp-default", "different-default")
        f.ledger.bind("verify-label", "acp-default", "fixture-default")

    def test_yaml_example_loads_full_catalog_and_defaults(self) -> None:
        c = load_config(ROOT / "factory.example.yaml")
        self.assertNotIn("roles", c)
        self.assertEqual("middle-developer", c["_defaults"]["developer"])
        self.assertEqual("pi", c["profiles"]["middle-test-writer-pi"]["connection"])
        self.assertEqual(r"builtin:zai-coding-plan\GLM-5.3", c["models"]["glm-5-3"]["id"])
        self.assertNotIn("zcode", c["models"])
        self.assertEqual("glm-5-3", c["profiles"]["middle-test-writer-zcode"]["model"])

    def test_configuration_graph_and_state_have_no_schema_versions(self) -> None:
        f = self.f
        self.assertNotIn("version", f.config)
        self.assertNotIn("version", f.g)
        f.init()
        self.assertNotIn("version", f.ledger.read())


if __name__ == "__main__":
    unittest.main()
