"""Context routing regressions across processes, stages and actual transports."""

from __future__ import annotations

import hashlib
import json
import subprocess
import sys
import unittest
from copy import deepcopy
from pathlib import Path
from typing import Any
from unittest.mock import patch

from factory.adapters.acpx_adapter import prepare_prompt
from factory.context import context
from factory.runtime.workflow_config import load_config
from factory.runtime.workflow_core import Invalid
from tests.factory.runtime import workflow_fixture

_TOOLS = Path(__file__).resolve().parents[3] / "bin"


class ContextTests(unittest.TestCase):
    def setUp(self) -> None:
        self.f = workflow_fixture.WorkflowFixture(self.addCleanup)

    def packet(
        self,
        role: str = "generalist",
        process: str = "implement",
        stage: str = "work",
        resources: list[str] | None = None,
        profile: str | None = None,
        **extra: Any,
    ) -> dict[str, Any]:
        assignment = dict(
            source=deepcopy(self.f.g["sources"]["request"]),
            task=deepcopy(self.f.g["tasks"]["label"]),
            node=dict(stage=stage, resources=resources or [], read=[]),
            **extra,
        )
        if process == "code-review":
            from factory.project.profile_io import sha, snapshot

            raw = (self.f.root / "AGENTS.md").read_bytes()
            assignment["project_policy"] = snapshot(
                self.f.config["_project"],
                source="fixture baseline",
                documents={"AGENTS.md": {"content": raw.decode(), "sha256": sha(raw)}},
            )
        return dict(
            context.build(
                self.f.config,
                self.f.root,
                profile or self.f.config["_defaults"][role],
                role,
                process,
                assignment,
            )
        )

    def names(self, packet: dict[str, Any]) -> set[str]:
        return {
            str(Path(i["path"]).relative_to(workflow_fixture.ROOT))
            for i in packet["instructions"]
            if Path(i["path"]).is_relative_to(workflow_fixture.ROOT)
        }

    def test_generalist_gets_review_contract_for_owned_unresolved_findings(self) -> None:
        contract = "contracts/common/review-findings.md"
        for owner, status, expected in [
            (None, None, False),
            ("write-label", "open", True),
            ("write-label", "ready", True),
            ("write-label", "fixed", False),
            ("different-writer", "open", False),
        ]:
            with self.subTest(owner=owner, status=status):
                findings = (
                    {
                        "REV-1": {
                            "owner_node_id": owner,
                            "owner_role": "generalist",
                            "status": status,
                        }
                    }
                    if owner is not None
                    else {}
                )
                packet = self.packet(node_id="write-label", review_findings=findings)
                self.assertEqual(expected, contract in self.names(packet))
                self.assertEqual(findings, packet["review_findings"])

        self.assertIn(contract, self.names(self.packet("judge", stage="verify")))
        self.assertIn(str(workflow_fixture.ROOT / contract), self.f.config["_files"])

    def test_review_assignment_keeps_specialization_and_captured_context(self) -> None:
        for name, lens in [
            ("ArchitectureReviewer", "system-design"),
            ("CodeReviewer", "runtime-safety"),
            ("AcceptanceReviewer", "verification-quality"),
        ]:
            captured: dict[str, Any] = {
                "sources": [{"id": "incident", "content": "Expected recovery"}],
                "requirements": [{"id": "AC1", "text": "Recover"}],
            }
            packet = self.packet(
                "reviewer",
                "code-review",
                name=name,
                lens=lens,
                context=captured,
                owned_gates={"SYS-INTENT": "Check intent"},
            )
            self.assertEqual(name, packet["name"])
            self.assertEqual(lens, packet["lens"])
            self.assertEqual(captured, packet["context"])
            self.assertEqual({"SYS-INTENT": "Check intent"}, packet["owned_gates"])
            self.assertIn("contracts/reviewer.md", self.names(packet))

    def test_gate_documents_are_role_scoped_not_whole_directory(self) -> None:
        owners = {"developer", "test-writer", "generalist", "judge", "reviewer"}
        for process, roles in context.PROCESS_ROLES.items():
            for role in roles:
                with self.subTest(process=process, role=role):
                    selected = {
                        p for p in self.names(self.packet(role, process)) if p.startswith("gates/")
                    }
                    expected = {"gates/common/verification-rules.md"}
                    if role in owners:
                        expected.add(f"gates/roles/{role}.md")
                    self.assertEqual(expected, selected)

    def test_role_gate_drift_blocks_existing_assignment(self) -> None:
        f = self.f
        file = f.config_file(lambda c: None)
        f.config = load_config(file)
        f.init()
        f.ledger.claim("write-label")
        (file.parent / "gates/roles/generalist.md").write_text("Weakened completion gate")
        with self.assertRaisesRegex(Invalid, "drift"):
            f.ledger.packet("write-label")

    def test_every_supported_role_receives_own_contract_without_coordinator(self) -> None:
        for process, roles in context.PROCESS_ROLES.items():
            for role in roles:
                with self.subTest(process=process, role=role):
                    packet = self.packet(role, process)
                    names = self.names(packet)
                    self.assertIn(f"roles/{role}.md", names)
                    self.assertIn(f"contracts/{role}.md", names)
                    self.assertIn("contracts/common/worker-rules.md", names)
                    self.assertIn("contracts/common/communication.md", names)
                    self.assertEqual(
                        len(packet["instructions"]),
                        len({i["path"] for i in packet["instructions"]}),
                    )
                    self.assertIn("adapters/worker/codex.md", names)
                    self.assertIn("adapters/worker/common.md", names)
                    self.assertEqual(
                        process == "implement", "adapters/worker/native-packet.md" in names
                    )
                    self.assertFalse(
                        names
                        & {
                            "workflow/router.md",
                            "workflow/orchestration.md",
                            "workflow/README.md",
                            "adapters/codex.md",
                            "contracts/common/agent-checkpoint.md",
                        }
                    )
                    self.assertFalse(any(name.endswith("/SKILL.md") for name in names))

    def test_commands_follow_reservation_not_role_alone(self) -> None:
        writing = self.names(self.packet())
        checking = self.names(self.packet(stage="verify", resources=["project-checks"]))
        self.assertNotIn("contracts/common/check-execution.md", writing)
        self.assertIn("contracts/common/check-execution.md", checking)
        self.assertIn("skills/factory-implement/references/project-checks.md", checking)
        self.assertIn("contracts/common/implement-result.md", writing)

    def test_principles_delivered_once_to_applicable_profiles_only(self) -> None:
        recipients: dict[str, Any] = {
            "coding-principles": {"developer", "generalist"},
            "testing-principles": {"test-writer", "generalist"},
            "review-principles": {"reviewer", "judge"},
        }
        for process, roles in context.PROCESS_ROLES.items():
            for role in roles:
                for profile in self.f.config["_roles"][role]:
                    with self.subTest(process=process, role=role, profile=profile):
                        packet = self.packet(role, process, profile=profile)
                        names = self.names(packet)
                        self.assertEqual(
                            self.f.config["profiles"][profile]["capabilities"],
                            packet["profile"]["capabilities"],
                        )
                        for name, owners in recipients.items():
                            relative = (
                                f"contracts/common/{name}.md"
                                if name != "verification-rules"
                                else "gates/common/verification-rules.md"
                            )
                            entries = [
                                i
                                for i in packet["instructions"]
                                if i["path"].endswith("/" + relative)
                            ]
                            self.assertEqual(int(role in owners), len(entries))
                            if entries:
                                self.assertEqual(
                                    (workflow_fixture.ROOT / relative).read_text(),
                                    entries[0]["content"],
                                )
                        for name in ["worker-rules", "verification-rules", "code-discovery"]:
                            relative = (
                                f"contracts/common/{name}.md"
                                if name != "verification-rules"
                                else "gates/common/verification-rules.md"
                            )
                            entries = [
                                i
                                for i in packet["instructions"]
                                if i["path"].endswith("/" + relative)
                            ]
                            self.assertEqual(1, len(entries))
                            self.assertEqual(
                                (workflow_fixture.ROOT / relative).read_text(),
                                entries[0]["content"],
                            )
                        self.assertEqual(
                            {f"roles/{role}.md"}, {n for n in names if n.startswith("roles/")}
                        )
                        self.assertEqual(
                            {f"contracts/{role}.md"},
                            {n for n in names if n.startswith("contracts/") and n.count("/") == 1},
                        )

    def test_verify_source_criteria_checks_and_permissions_survive(self) -> None:
        packet = self.packet("test-writer", stage="verify", resources=["project-checks"])
        self.assertEqual(self.f.g["sources"]["request"], packet["source"])
        self.assertEqual(self.f.g["tasks"]["label"], packet["task"])
        self.assertEqual(["project-checks"], packet["node"]["resources"])
        self.assertEqual(
            self.f.config["profiles"]["middle-test-writer"]["capabilities"],
            packet["profile"]["capabilities"],
        )

    def test_planning_and_decompose_do_not_inherit_implement_results(self) -> None:
        for role, process in [
            ("architect", "planning"),
            ("task-decomposer", "decompose"),
            ("task-reviewer", "decompose"),
        ]:
            packet = self.packet(role, process)
            names = self.names(packet)
            self.assertNotIn("contracts/common/implement-result.md", names)
            self.assertNotIn("contracts/common/review-findings.md", names)
            self.assertNotIn("contracts/common/check-execution.md", names)
        self.assertIn(
            "skills/factory-planning/references/plan-contract.md",
            self.names(self.packet("architect", "planning")),
        )
        self.assertIn(
            "skills/factory-decompose/references/generation-contract.md",
            self.names(self.packet("task-decomposer", "decompose")),
        )

    def test_standalone_and_integrated_review_have_separate_result_contracts(self) -> None:
        lens = self.names(self.packet("reviewer", "code-review"))
        integrated = self.names(self.packet("judge", stage="review", resources=["project-checks"]))
        schema = "skills/factory-code-review/references/lens-result.md"
        self.assertIn(schema, lens)
        self.assertNotIn(schema, integrated)
        self.assertIn("contracts/common/review-principles.md", lens & integrated)
        self.assertNotIn(
            "skills/factory-code-review/references/reviewer-prompts.md", lens | integrated
        )

    def test_actual_native_and_acp_share_semantic_packet(self) -> None:
        f = self.f
        f.require_fixture_review()
        f.init()
        f.ledger.claim("write-label")
        native = f.ledger.packet("write-label")
        # Both transports preserve the packet built for their own resolved profile.
        other = workflow_fixture.WorkflowFixture(self.addCleanup)
        other.fake_acp()
        other.init()
        other.ledger.claim("write-label")
        state = other.ledger.read()
        from factory.runtime.assignment import implement_packet

        expected = implement_packet(state, "write-label")
        prepared = prepare_prompt(other.ledger, "write-label")
        path = Path(prepared["prompt"])
        self.assertEqual(path.suffixes[-2:], [".packet", ".json"])
        self.assertEqual(prepared["prompt_argv"][-2:], ["--file", str(path)])
        self.assertEqual(expected, json.loads(path.read_bytes()))
        self.assertIn("adapters/worker/native-packet.md", self.names(native))
        self.assertNotIn("adapters/worker/native-packet.md", self.names(expected))
        self.assertIn("adapters/worker/common.md", self.names(expected))
        self.assertEqual(native["source"], expected["source"])
        self.assertEqual(native["task"], expected["task"])

    def test_unknown_process_role_and_profile_fail_closed(self) -> None:
        for role, process, profile in [
            ("architect", "implement", "architect"),
            ("developer", "planning", "developer"),
            ("generalist", "unknown", "generalist"),
            ("generalist", "implement", "developer"),
        ]:
            with self.subTest(role=role, process=process), self.assertRaises(ValueError):
                self.packet(role, process, profile=profile)

    def test_missing_project_document_blocks_packet(self) -> None:
        f = self.f
        f.g["nodes"][0]["read"] = ["missing.md"]
        f.init()
        f.ledger.claim("write-label")
        with self.assertRaisesRegex(Invalid, "Missing context file"):
            f.ledger.packet("write-label")

    def test_project_reading_is_included_with_provenance(self) -> None:
        f = self.f
        (f.root / "rules.md").write_text("Project-specific mandatory constraint")
        f.g["nodes"][0]["read"] = ["rules.md"]
        f.init()
        f.ledger.claim("write-label")
        packet = f.ledger.packet("write-label")
        item = next(i for i in packet["instructions"] if i["path"].endswith("/rules.md"))
        self.assertEqual("project", item["audience"])
        self.assertTrue(item["sha256"])
        self.assertEqual("Project-specific mandatory constraint", item["content"])

    def test_missing_worker_adapter_blocks_config(self) -> None:
        file = self.f.config_file(lambda c: c["adapters"]["codex"].pop("worker_instructions"))
        with self.assertRaises(Invalid):
            load_config(file)

    def test_worker_adapter_drift_blocks_existing_run(self) -> None:
        f = self.f
        file = f.config_file(lambda c: None)
        f.config = load_config(file)
        f.init()
        f.ledger.claim("write-label")
        (file.parent / "adapters/worker/codex.md").write_text("Changed worker permissions")
        with self.assertRaisesRegex(Invalid, "drift"):
            f.ledger.packet("write-label")

    def test_communication_drift_blocks_existing_assignment(self) -> None:
        f = self.f
        file = f.config_file(lambda c: None)
        f.config = load_config(file)
        f.init()
        f.ledger.claim("write-label")
        (file.parent / "contracts/common/communication.md").write_text(
            "Changed communication policy"
        )
        with self.assertRaisesRegex(Invalid, "drift"):
            f.ledger.packet("write-label")

    def test_shared_policy_drift_blocks_existing_assignment(self) -> None:
        for name in [
            "coding-principles",
            "testing-principles",
            "worker-rules",
            "verification-rules",
        ]:
            with self.subTest(policy=name):
                f = workflow_fixture.WorkflowFixture(self.addCleanup)
                file = f.config_file(lambda c: None)
                f.config = load_config(file)
                f.init()
                f.ledger.claim("write-label")
                (
                    file.parent
                    / (
                        f"contracts/common/{name}.md"
                        if name != "verification-rules"
                        else "gates/common/verification-rules.md"
                    )
                ).write_text("Changed policy")
                with self.assertRaisesRegex(Invalid, "drift"):
                    f.ledger.packet("write-label")

    def test_missing_testing_principles_blocks_context(self) -> None:
        f = self.f
        file = f.config_file(lambda c: None)
        (file.parent / "contracts/common/testing-principles.md").unlink()
        with self.assertRaisesRegex(ValueError, "Missing"):
            config = load_config(file)
            context.build(
                config,
                f.root,
                config["_defaults"]["generalist"],
                "generalist",
                "implement",
                dict(
                    source=f.g["sources"]["request"],
                    task=f.g["tasks"]["label"],
                    node=dict(stage="work", resources=[], read=[]),
                ),
            )

    def test_profile_cannot_grant_unavailable_command_stage(self) -> None:
        self.f.config["profiles"]["generalist"]["capabilities"]["commands"] = False
        with self.assertRaisesRegex(ValueError, "commands forbidden"):
            self.packet(stage="verify", resources=["project-checks"])

    def test_required_isolation_blocks_nonimplement_packet(self) -> None:
        self.f.config["profiles"]["architect"]["enforcement"] = "required"
        with self.assertRaisesRegex(ValueError, "BLOCKED_CAPABILITIES"):
            self.packet("architect", "planning")

    def test_shared_coordinator_rules_cannot_enter_worker_materials(self) -> None:
        root = Path(self.f.config["_path"]).parent.resolve()
        common = root / "adapters/common.md"
        with self.assertRaisesRegex(ValueError, "Coordinator instructions"):
            context._project_materials(
                self.f.config,
                root,
                root.parent,
                [".factory/adapters/common.md"],
                include_agents=False,
            )
        with patch.object(context, "selected_materials", return_value=[(common, {"id": "bad"})]):
            with self.assertRaisesRegex(ValueError, "Coordinator instructions"):
                self.packet()

    def test_orchestrator_material_cannot_enter_worker_packet(self) -> None:
        root = Path(self.f.config["_path"]).parent.resolve()
        for rel in ("roles/orchestrator.md", "contracts/orchestrator.md"):
            with self.subTest(path=rel):
                file = root / rel
                with self.assertRaisesRegex(ValueError, "Coordinator instructions"):
                    context._project_materials(
                        self.f.config,
                        root,
                        root.parent,
                        [".factory/" + rel],
                        include_agents=False,
                    )
                with patch.object(
                    context, "selected_materials", return_value=[(file, {"id": "bad"})]
                ):
                    with self.assertRaisesRegex(ValueError, "Coordinator instructions"):
                        self.packet()
                adapter = self.f.config["adapters"][
                    self.f.config["profiles"]["generalist"]["adapter"]
                ]
                original = adapter["worker_instructions"]
                adapter["worker_instructions"] = rel
                try:
                    with self.assertRaisesRegex(ValueError, "Coordinator instructions"):
                        self.packet()
                finally:
                    adapter["worker_instructions"] = original

    def test_coordinator_read_cannot_bypass_packet_routing(self) -> None:
        f = self.f
        (f.root / "SKILL.md").write_text("Unscoped coordinator procedure")
        f.g["nodes"][0]["read"] = ["SKILL.md"]
        f.init()
        f.ledger.claim("write-label")
        with self.assertRaisesRegex(Invalid, "Coordinator instructions"):
            f.ledger.packet("write-label")

    def test_native_packet_rejects_implement_skill_as_worker_instructions(self) -> None:
        normal = self.f
        normal.init()
        normal.ledger.claim("write-label")
        bootstrap = normal.ledger.prepare_packet("write-label")
        packet = json.loads((normal.root / bootstrap["path"]).read_text())
        adapter_name = normal.config["profiles"]["generalist"]["adapter"]
        worker_file = normal.config["adapters"][adapter_name]["worker_instructions"]
        worker_path = Path(normal.config["_path"]).parent / worker_file
        self.assertTrue(
            any(
                entry["reason"] == "worker environment" and Path(entry["path"]) == worker_path
                for entry in packet["instructions"]
            )
        )

        invalid = workflow_fixture.WorkflowFixture(self.addCleanup)
        config = invalid.config_file(
            lambda raw: raw["adapters"][adapter_name].update(
                worker_instructions="skills/factory-implement/SKILL.md"
            )
        )
        invalid.config = load_config(config)
        invalid.init()
        invalid.ledger.claim("write-label")
        with self.assertRaisesRegex(Invalid, "worker_instructions"):
            invalid.ledger.prepare_packet("write-label")
        self.assertNotIn("packet_file", invalid.ledger.read()["nodes"]["write-label"])

    def test_context_cli_keeps_nonimplement_process_out_of_ledger(self) -> None:
        f = self.f
        target = f.root / "assignment.json"
        target.write_text(
            json.dumps(
                dict(
                    source=f.g["sources"]["request"],
                    allowed_writes=[".factory/memory/staging/planning-plan.md"],
                    report_path=".factory/memory/staging/planning-plan.md",
                    read=[],
                )
            )
        )
        result = subprocess.run(
            [
                sys.executable,
                str(workflow_fixture.ROOT / "tooling/bin/context.py"),
                "--config",
                str(f.config_file(lambda c: None)),
                "--workspace",
                str(f.root),
                "--process",
                "planning",
                "--role",
                "architect",
                "--profile",
                "architect",
                str(target),
            ],
            text=True,
            capture_output=True,
        )
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual("planning", json.loads(result.stdout)["process"])
        self.assertFalse(f.ledger.path.exists())

    def test_each_instruction_records_reason_and_exact_content_hash(self) -> None:
        from factory.runtime.workflow_core import digest

        packet = self.packet()
        self.assertEqual(
            len(packet["instructions"]), len({i["path"] for i in packet["instructions"]})
        )
        for item in packet["instructions"]:
            self.assertTrue(item["reason"])
            self.assertEqual(digest(item["content"].encode()), item["sha256"])

    def test_workflow_dependencies_are_handed_off_as_data(self) -> None:
        f = self.f
        f.init()
        f.start("write-label")
        f.ledger.finish("write-label", f.report("write-label"))
        f.ledger.claim("verify-label")
        packet = f.ledger.packet("verify-label")
        self.assertEqual("done", packet["dependency_results"]["write-label"]["status"])
        self.assertEqual(
            "WRITES_READY", packet["dependency_results"]["write-label"]["report"]["stage_result"]
        )

    def test_new_assignment_has_full_packet_not_only_delta(self) -> None:
        f = self.f
        f.init()
        f.start("write-label")
        first = f.ledger.packet("write-label")
        f.ledger.finish("write-label", f.report("write-label"))
        f.ledger.claim("verify-label")
        second = f.ledger.packet("verify-label")
        self.assertNotEqual(first["dispatch_id"], second["dispatch_id"])
        self.assertTrue(self.names(first) <= self.names(second))

    def assignment(self, **node_fields: Any) -> dict[str, Any]:
        return dict(
            source=deepcopy(self.f.g["sources"]["request"]),
            task=deepcopy(self.f.g["tasks"]["label"]),
            node=dict(stage="work", resources=[], read=[], **node_fields),
        )

    def test_reader_uses_one_snapshot_for_content_and_hash(self) -> None:
        calls = []
        raw = "Правила\r\nSecond line\r\n".encode()

        def reader(file: Path) -> bytes:
            calls.append(file)
            return raw

        assignment = self.assignment()
        assignment["node"]["read"] = ["AGENTS.md", "./AGENTS.md"]
        packet = context.build(
            self.f.config,
            self.f.root,
            "generalist",
            "generalist",
            "implement",
            assignment,
            read_bytes=reader,
        )
        self.assertEqual(len(calls), len(set(calls)))
        for entry in packet["instructions"]:
            self.assertEqual(raw, entry["content"].encode("utf-8"))
            self.assertEqual(hashlib.sha256(raw).hexdigest(), entry["sha256"])
        self.assertEqual(len(calls), len(packet["instructions"]))
        self.assertNotIn("context_manifest", packet)

    def test_new_rule_selects_material_and_freezes_its_dependency(self) -> None:
        config_file = self.f.config_file(lambda c: None)
        relative = "contracts/common/custom-context.md"
        (config_file.parent / relative).write_text("Additional planning rule")
        rule = context.MaterialRule(
            (relative,), "additional planning policy", "planning", roles=frozenset({"architect"})
        )
        with patch.object(context, "STAGE_RULES", (*context.STAGE_RULES, rule)):
            config = load_config(config_file)
            self.assertIn(str((config_file.parent / relative).resolve()), config["_files"])
            planning = context.build(
                config,
                self.f.root,
                "architect",
                "architect",
                "planning",
                dict(source={"kind": "test"}),
            )
            entries = [i for i in planning["instructions"] if i["path"].endswith(relative)]
            self.assertEqual(1, len(entries))
            self.assertEqual(rule.reason, entries[0]["reason"])
            work = context.build(
                config, self.f.root, "generalist", "generalist", "implement", self.assignment()
            )
            self.assertFalse(any(i["path"].endswith(relative) for i in work["instructions"]))

    def test_malformed_selectors_and_resources_fail_as_validation_errors(self) -> None:
        for process, role, profile in [
            ([], "generalist", "generalist"),
            ("implement", {}, "generalist"),
            ("implement", "generalist", []),
        ]:
            with self.subTest(process=process, role=role, profile=profile):
                with self.assertRaises(ValueError):
                    context.build(
                        self.f.config, self.f.root, profile, role, process, self.assignment()
                    )
        for resources in [None, "project-checks", {"project-checks": True}, [1]]:
            assignment = self.assignment()
            assignment["node"]["resources"] = resources
            with self.subTest(resources=resources), self.assertRaisesRegex(ValueError, "resources"):
                context.build(
                    self.f.config, self.f.root, "generalist", "generalist", "implement", assignment
                )

    def test_invalid_project_paths_are_rejected_before_reading(self) -> None:
        link = self.f.root / "linked.md"
        link.symlink_to(self.f.root / "AGENTS.md")
        for relative in ["../AGENTS.md", str(self.f.root / "AGENTS.md"), "linked.md", 123]:
            assignment = self.assignment()
            assignment["node"]["read"] = [relative]
            with self.subTest(path=relative), self.assertRaises(ValueError):
                context.build(
                    self.f.config,
                    self.f.root,
                    "generalist",
                    "generalist",
                    "implement",
                    assignment,
                    read_bytes=lambda _: self.fail("Invalid paths must not be read"),
                )

    def test_node_read_overrides_assignment_read_including_empty_list(self) -> None:
        assignment = self.assignment()
        assignment["read"] = ["missing.md"]
        context.build(
            self.f.config, self.f.root, "generalist", "generalist", "implement", assignment
        )
        del assignment["node"]["read"]
        with self.assertRaisesRegex(ValueError, "Missing context file"):
            context.build(
                self.f.config, self.f.root, "generalist", "generalist", "implement", assignment
            )

    def test_invalid_utf8_reports_file_and_preserves_inputs(self) -> None:
        assignment = self.assignment()
        original = deepcopy(assignment)
        with self.assertRaisesRegex(ValueError, "Context file is not UTF-8:"):
            context.build(
                self.f.config,
                self.f.root,
                "generalist",
                "generalist",
                "implement",
                assignment,
                read_bytes=lambda _: b"\xff",
            )
        self.assertEqual(original, assignment)


if __name__ == "__main__":
    unittest.main()
