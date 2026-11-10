"""Node-scoped initial choices and correction authorization."""

from __future__ import annotations

import json
import subprocess
import sys
import unittest
from collections.abc import Mapping
from copy import deepcopy
from pathlib import Path
from typing import Any

import yaml

from factory_tooling.adapters.acpx_adapter import install_connection, prepare_prompt, run_operation
from factory_tooling.project.profile_io import load_profile
from factory_tooling.runtime.assignment import implement_packet
from factory_tooling.runtime.workflow_config import validate_profile_decisions
from factory_tooling.runtime.workflow_core import Invalid
from factory_tooling.runtime.workflow_graph import validate_profile_selections
from tests.factory_tooling.runtime import test_escalation


class ProfileSelectionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.e = test_escalation.EscalationTests()
        self.e.setUp()
        self.addCleanup(self.e.doCleanups)
        self.f = self.e.f
        self.options = [
            "junior-developer",
            "middle-developer",
            "senior-developer",
            "no-eligible-profile",
        ]
        definition: dict[str, Any] = {
            "id": "initial-developer-profile",
            "type": "choice",
            "question": "Which profile?",
            "choices": [{"value": x, "description": x} for x in self.options],
        }
        self.f.fixture_profile.write_text(
            yaml.safe_dump({"id": "unit-fixture", "decisions": [definition]})
        )
        self.f.config["_project"] = load_profile(self.f.fixture_profile)
        self.f.config["_files"].update(self.f.config["_project"]["files"])
        for profile in self.f.config["profiles"].values():
            if profile["role"] == "roles/developer.md":
                profile["initial_profile_decision"] = definition["id"]
        for node in self.f.g["nodes"]:
            if node.get("agent") == "author":
                node["profile_selection"] = self.selection(node, "junior-developer")

    def selection(self, node: Mapping[str, Any], choice: str) -> dict[str, Any]:
        return {
            "task_id": node["task"],
            "node_id": node["id"],
            "decision_id": "initial-developer-profile",
            "answer": {
                "choice": choice,
                "probabilities": {x: 0.7 if x == choice else 0.1 for x in self.options},
                "confidence": 0.6,
                "source": "agent:coordinator",
                "reason": "Bounded work with clear checks",
            },
        }

    def test_definition_catalog_and_invalid_assignment(self) -> None:
        validate_profile_decisions(self.f.config)
        broken = deepcopy(self.f.config)
        broken_definition: Any = broken["_project"]["data"]["decisions"][0]
        broken_definition["choices"].pop()
        with self.assertRaises(Invalid):
            validate_profile_decisions(broken)
        for key, value in [("task_id", "other"), ("node_id", "other"), ("decision_id", "other")]:
            graph = deepcopy(self.f.g)
            graph["nodes"][0]["profile_selection"][key] = value
            with self.subTest(key=key), self.assertRaises(Invalid):
                self.f.ledger.init(graph, self.f.config)
        graph = deepcopy(self.f.g)
        graph["nodes"][0]["profile_selection"] = self.selection(
            graph["nodes"][0], "no-eligible-profile"
        )
        with self.assertRaises(Invalid):
            self.f.ledger.init(graph, self.f.config)

    def test_predispatch_change_and_reservation_guard(self) -> None:
        self.f.init()
        graph = deepcopy(self.f.ledger.read()["graph"])
        graph["agents"]["replacement"] = {"role": "developer", "profile": "middle-developer"}
        node = graph["nodes"][0]
        node["agent"] = "replacement"
        node["profile_selection"] = self.selection(node, "middle-developer")
        self.f.ledger.revise(graph, "Assignment requires independent local design")
        self.f.ledger.claim(node["id"])
        packet = implement_packet(self.f.ledger.read(), node["id"])
        self.assertNotIn("profile_selection", packet["node"])
        state = self.f.ledger.read()
        profile = state["config"]["profiles"][state["nodes"][node["id"]]["profile"]]
        model = state["config"]["models"][profile["model"]]["id"] or "fixture-default"
        self.f.ledger.bind(node["id"], "writer", model)
        self.f.ledger.finish(node["id"], self.f.report(node["id"]))
        changed = deepcopy(self.f.ledger.read()["graph"])
        changed["agents"]["another"] = {"role": "developer", "profile": "senior-developer"}
        changed["nodes"][0]["agent"] = "another"
        changed["nodes"][0]["profile_selection"] = self.selection(
            changed["nodes"][0], "senior-developer"
        )
        with self.assertRaisesRegex(Invalid, "Started assignments require correct"):
            self.f.ledger.revise(changed, "Cannot replace completed work")

    def test_reintake_keeps_corrected_answer_under_previous_policy(self) -> None:
        self.f.init()
        self.f.ledger.correct("write-label", self.e.fail_verification())
        before = self.f.ledger.read()
        original = deepcopy(before["graph"]["nodes"][0]["profile_selection"])
        policy = yaml.safe_load(self.f.fixture_profile.read_text())
        policy["decisions"][0]["min_confidence"] = 0.9
        self.f.fixture_profile.write_text(yaml.safe_dump(policy))
        self.f.ledger.reintake(deepcopy(before["graph"]), "Policy changed", "authorized")
        after = self.f.ledger.read()
        self.assertEqual(original, after["graph"]["nodes"][0]["profile_selection"])
        validate_profile_selections(
            after["graph"], after["config"], after["corrections"], after["events"]
        )
        wrong_fresh = deepcopy(after["graph"])
        wrong_fresh["nodes"][0]["profile_selection"]["answer"]["probabilities"] = {
            x: 1.0 if x == "junior-developer" else 0.0 for x in self.options
        }
        wrong_fresh["nodes"][0]["profile_selection"]["answer"]["confidence"] = 1.0
        with self.assertRaises(Invalid):
            self.f.ledger.reintake(wrong_fresh, "Fresh but wrong profile", "authorized")
        fresh = deepcopy(after["graph"])
        for node in fresh["nodes"]:
            if node.get("profile_selection") and node["task"] == "label":
                node["profile_selection"] = self.selection(node, "middle-developer")
                node["profile_selection"]["answer"]["probabilities"] = {
                    x: 1.0 if x == "middle-developer" else 0.0 for x in self.options
                }
                node["profile_selection"]["answer"]["confidence"] = 1.0
        self.f.ledger.reintake(fresh, "Fresh assessment", "authorized")
        rollback = deepcopy(self.f.ledger.read()["graph"])
        rollback["nodes"][0]["profile_selection"] = original
        with self.assertRaises(Invalid):
            self.f.ledger.reintake(rollback, "Attempt historical rollback", "authorized")

    def test_native_packet_and_acp_submit_omit_selection(self) -> None:
        self.f.init()
        self.f.ledger.claim("write-label")
        meta = self.f.ledger.prepare_packet("write-label")
        bootstrap = {
            key: meta[key]
            for key in (
                "node_id",
                "path",
                "sha256",
                "run_id",
                "dispatch_id",
                "source_hash",
                "revision",
            )
        }
        chunk = self.f.ledger.read_packet("write-label", bootstrap, 1)
        self.assertNotIn("profile_selection", chunk["content"])

    def test_acp_submit_omits_selection(self) -> None:
        profile = self.f.config["profiles"]["junior-developer"]
        alternate = self.f.config["profiles"]["middle-test-writer-zcode"]
        for key in ("runner", "harness", "connection", "worker_instructions", "model"):
            profile[key] = alternate[key]
        self.f.config["acpx"]["command"] = sys.executable
        self.f.config["acpx"]["connections"]["zcode"]["command"] = sys.executable
        self.f.init()
        install_connection(self.f.config, self.f.root, "zcode")
        self.f.ledger.claim("write-label")
        prepared = prepare_prompt(self.f.ledger, "write-label")
        packet = json.loads(Path(prepared["prompt"]).read_text())
        self.assertNotIn("profile_selection", packet["node"])
        model = self.f.config["models"][profile["model"]]["id"] or "fixture-default"
        self.f.ledger.bind("write-label", prepared["session"], model)

        def invoke(argv: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
            return subprocess.CompletedProcess(argv, 0)

        run_operation(self.f.ledger, "write-label", "prompt", run=invoke)

    def test_reason_only_revision_preserves_completed_writer(self) -> None:
        self.f.init()
        self.f.start("write-label")
        self.f.ledger.finish("write-label", self.f.report("write-label"))
        graph = deepcopy(self.f.ledger.read()["graph"])
        graph["nodes"][0]["profile_selection"]["answer"]["reason"] = "Updated evidence"
        self.f.ledger.revise(graph, "Refresh assessment")
        self.assertEqual("done", self.f.ledger.read()["nodes"]["write-label"]["status"])

    def test_revision_preserves_old_agent_and_reintake_needs_real_change(self) -> None:
        self.f.init()
        graph = deepcopy(self.f.ledger.read()["graph"])
        graph["agents"]["replacement"] = {"role": "developer", "profile": "middle-developer"}
        for node in graph["nodes"]:
            if node.get("agent") == "author":
                node["agent"] = "replacement"
                node["profile_selection"] = self.selection(node, "middle-developer")
        del graph["agents"]["author"]
        with self.assertRaisesRegex(Invalid, "Keep previous logical agent"):
            self.f.ledger.revise(deepcopy(graph), "Changed assessment")
        graph["agents"]["author"] = {"role": "developer", "profile": "junior-developer"}
        with self.assertRaisesRegex(Invalid, "requires revise"):
            self.f.ledger.reintake(graph, "Unchanged source", "authorized")

    def test_correction_authorizes_only_reassigned_nodes(self) -> None:
        self.f.init()
        request = self.e.fail_verification()
        record = self.f.ledger.correct("write-label", request)
        self.assertIn("write-label", record["reassigned_nodes"])
        state = self.f.ledger.read()
        validate_profile_selections(state["graph"], state["config"], state["corrections"])
        graph = deepcopy(state["graph"])
        other = next(n for n in graph["nodes"] if n["id"] == "review-label")
        other["agent"] = next(n for n in graph["nodes"] if n["id"] == "write-label")["agent"]
        other["profile_selection"] = self.selection(other, "junior-developer")
        with self.assertRaises(Invalid):
            validate_profile_selections(graph, state["config"], state["corrections"])
        self.assertEqual(record, self.f.ledger.correct("write-label", request))
