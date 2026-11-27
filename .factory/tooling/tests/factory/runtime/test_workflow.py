from __future__ import annotations

import json
import shutil
import subprocess
import sys
import time
import unittest
from contextlib import ExitStack
from copy import deepcopy
from pathlib import Path
from typing import IO, Any, Literal
from unittest.mock import Mock, patch

from factory.adapters.acpx_adapter import (
    build_command,
    install_connection,
    prepare_prompt,
    run_operation,
)
from factory.database.sqlite import sqlite_history_repository, sqlite_run_repository, workflow_db
from factory.runtime import teacher
from factory.runtime.contracts import FindingRecord
from factory.runtime.history import report_history
from factory.runtime.history.document import render
from factory.runtime.history.task_records import read_task, resolve_evidence
from factory.runtime.run_repository import ArchiveReference
from factory.runtime.scheduling.run_sessions import RunSessions
from factory.runtime.workflow import Ledger
from factory.runtime.workflow_config import load_config
from factory.runtime.workflow_core import Invalid, digest, read_json, snapshot
from factory.runtime.workflow_graph import diagram, validate_graph
from factory.runtime.workflow_sources import lock_source
from tests import CLI
from tests.factory.runtime.store_fixture import has_current, overwrite, record_bytes
from tests.factory.runtime.workflow_fixture import WorkflowFixture
from tests.fixture_bundle import ROOT as ROOT

_TOOLS = Path(__file__).resolve().parents[3] / "bin"


class WorkflowTests(unittest.TestCase, WorkflowFixture):
    def setUp(self) -> None:
        WorkflowFixture.__init__(self, self.addCleanup)

    def test_cli_diagram_renders_graph_and_status_identifies_current_dispatch(self) -> None:
        self.init()
        self.claim("write-label")
        argv = [*CLI, "workflow", "--workspace", str(self.root), "diagram"]
        default = subprocess.run(argv, capture_output=True, text=True, check=True)
        machine = subprocess.run([*argv, "--json"], capture_output=True, text=True, check=True)
        native = subprocess.run(
            [*argv, "--view", "pydantic", "--json"], capture_output=True, text=True, check=True
        )
        mermaid = json.loads(native.stdout)["result"]["mermaid"]
        self.assertIn("stateDiagram-v2", mermaid)
        self.assertIn("task_write-label --> task_verify-label", mermaid)
        state = self.ledger.read()
        self.assertTrue(default.stdout.startswith("sequenceDiagram\n"))
        self.assertEqual(
            json.loads(machine.stdout),
            {
                "ok": True,
                "result": {
                    "run_id": state["run_id"],
                    "mermaid": default.stdout.rstrip("\n") + "\n",
                },
            },
        )
        status = subprocess.check_output([*argv[:-1], "status"], text=True)
        dispatch = json.loads(status)["result"]["dispatches"]["write-label"]
        self.assertEqual("reserved", dispatch["status"])
        self.assertEqual(state["nodes"]["write-label"]["dispatch_id"], dispatch["dispatch_id"])

    def test_orchestrator_alias_is_optional_and_must_be_known(
        self,
    ) -> None:
        import yaml

        path = self.config_file(lambda c: c.pop("orchestrator", None))
        self.assertNotIn("orchestrator", load_config(path))
        raw = yaml.safe_load(path.read_text())
        raw["orchestrator"] = {"model": "missing"}
        path.write_text(yaml.safe_dump(raw))
        with self.assertRaisesRegex(Invalid, "orchestrator model"):
            load_config(path)

    def test_python_init_checks_supplied_config_pin_before_creating_run(self) -> None:
        from factory.runtime.workflow_config import instruction_pin

        pin = instruction_pin(self.config)
        for invalid in ("", "config.json", instruction_pin({**self.config, "_files": {}})):
            with (
                self.subTest(invalid=type(invalid)),
                self.assertRaisesRegex(Invalid, "changed since snapshot"),
            ):
                self.ledger.init(self.g, self.config, config_pin=invalid)
            self.assertFalse(self.ledger.runs.has_current(self.root))
        self.assertEqual(self.ledger.init(self.g, self.config, config_pin=pin)["status"], "active")

    def test_pinned_entry_rejects_changed_instructions_before_init(self) -> None:
        path = self.config_file(lambda c: None)
        from factory.runtime.graph_inputs import propose

        graph = propose(self.root, self.g)
        command = [
            *CLI,
            "workflow",
            "--workspace",
            str(self.root),
            "--config",
            str(path),
        ]
        result = subprocess.run(command + ["config"], capture_output=True, text=True, check=True)
        pin = result.stdout.strip()
        init = command + ["init", str(graph), "--config-pin", pin]
        for relative in (
            "skills/factory-implement/SKILL.md",
            "roles/orchestrator.md",
            "contracts/orchestrator.md",
            "workflow/README.md",
            "contracts/common/agent-checkpoint.md",
            "skills/factory-implement/references/execution-source-contract.md",
        ):
            file = path.parent / relative
            original = file.read_text()
            file.write_text(original + "\nchanged\n")
            read = subprocess.run(
                command + ["read-instructions", pin, relative],
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(0, read.returncode)
            self.assertNotIn("changed\n", read.stdout)
            rejected = subprocess.run(init, capture_output=True, text=True)
            self.assertNotEqual(0, rejected.returncode, relative)
            self.assertIn("changed since snapshot", rejected.stderr)
            self.assertFalse(has_current(self.ledger))
            file.write_text(original)
        result = subprocess.run(
            command + ["read-instructions", pin, "roles/orchestrator.md"],
            capture_output=True,
            text=True,
        )
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(
            (path.parent / "roles/orchestrator.md").read_text(),
            json.loads(result.stdout)["result"][0]["content"],
        )
        result = subprocess.run(init, capture_output=True, text=True)
        self.assertEqual(0, result.returncode, result.stderr)

    def test_init_rechecks_loaded_instruction_bytes(self) -> None:
        path = self.config_file(lambda c: None)
        self.config = load_config(path)
        file = path.parent / "roles/orchestrator.md"
        file.write_text(file.read_text() + "\nchanged\n")
        with self.assertRaisesRegex(Invalid, "drift"):
            self.init()
        self.assertFalse(has_current(self.ledger))
        self.assertNotIn("hash", self.g["sources"]["request"])

    def test_missing_execution_source_contract_rejects_config(self) -> None:
        path = self.config_file(lambda c: None)
        (path.parent / "skills/factory-implement/references/execution-source-contract.md").unlink()
        with self.assertRaisesRegex(Invalid, "Missing factory dependency"):
            load_config(path)

    def test_configuration_hashes_each_package_module_once_and_requires_known_modules(self) -> None:
        config = self.config_file(lambda c: None)
        module = config.parent / "tooling/factory/runtime/workflow.py"
        reads: list[Path] = []
        original = Path.read_bytes

        def observed(path: Path) -> bytes:
            reads.append(path)
            return original(path)

        with patch.object(Path, "read_bytes", observed):
            load_config(config)
        self.assertEqual(1, sum(path.resolve() == module.resolve() for path in reads))
        module.unlink()
        with self.assertRaisesRegex(Invalid, "Missing factory dependency"):
            load_config(config)

    def test_adapter_reference_resolves_and_is_frozen(self) -> None:
        self.assertEqual(self.config["profiles"]["middle-implementer-zcode"]["connection"], "zcode")
        adapter = str(ROOT / "adapters/acpx.md")
        self.assertIn(adapter, self.config["_files"])
        p = self.config_file(
            lambda c: c["agent_workers"]["implementer"]["variants"]["middle-implementer"].update(
                adapter="missing"
            )
        )
        with self.assertRaisesRegex(Invalid, "known adapter"):
            load_config(p)

    def test_acp_runtime_code_is_frozen_before_dispatch(self) -> None:
        path = self.config_file(lambda c: None)
        self.config = load_config(path)
        self.init()
        adapter = path.parent / "tooling/factory/adapters/acpx_adapter.py"
        self.assertIn(str(adapter.resolve()), self.config["_files"])
        adapter.write_text(adapter.read_text() + "\n# Changed transport implementation\n")
        before = self.ledger.read()
        with self.assertRaisesRegex(Invalid, "drift"):
            self.claim("write-label")
        self.assertEqual(before, self.ledger.read())

    def test_graph_uses_explicit_workspace_independent_of_cwd(self) -> None:
        foreign = self.root / "foreign"
        foreign.mkdir()
        (foreign / "lib").symlink_to(self.root / "lib", target_is_directory=True)
        (self.root / "checks").mkdir()
        (foreign / "checks").symlink_to(self.root / "checks", target_is_directory=True)
        self.g["tasks"]["label"]["required_checks"][0]["execution"]["cwd"] = "checks"
        with patch.object(Path, "cwd", return_value=foreign):
            validate_graph(self.g, self.config, self.root)
            self.init()
            self.claim("write-label")
        self.assertEqual("reserved", self.ledger.read()["nodes"]["write-label"]["status"])

    def test_scope_rejects_existing_directory_before_init_and_revision(self) -> None:
        graph = deepcopy(self.g)
        graph["tasks"]["label"]["scope"].append("lib")
        with self.assertRaisesRegex(Invalid, "Scope must contain real files: lib"):
            validate_graph(graph, self.config, self.root)
        with self.assertRaisesRegex(Invalid, "Scope must contain real files: lib"):
            self.ledger.init(graph, self.config)
        self.assertFalse(has_current(self.ledger))

        self.init()
        before = self.ledger.read()
        graph = deepcopy(before["graph"])
        graph["tasks"]["label"]["scope"].append("lib")
        with self.assertRaisesRegex(Invalid, "Scope must contain real files: lib"):
            self.ledger.revise(graph, "directory is not a file")
        self.assertEqual(before, self.ledger.read())

    def test_future_scope_file_and_directory_ownership_are_accepted(self) -> None:
        self.g["tasks"]["label"]["scope"].append("lib/future.txt")
        self.g["nodes"][0]["owns"] = ["lib"]
        validate_graph(self.g, self.config, self.root)
        self.init()
        self.claim("write-label")

    def test_workspace_symlink_and_hardlink_are_rejected_from_other_cwd(self) -> None:
        foreign = self.root / "foreign"
        foreign.mkdir()
        (self.root / "alias").symlink_to(self.root / "lib", target_is_directory=True)
        graph = deepcopy(self.g)
        graph["tasks"]["label"]["scope"] = ["alias/example.dart"]
        with patch.object(Path, "cwd", return_value=foreign):
            with self.assertRaisesRegex(Invalid, "Symlink"):
                validate_graph(graph, self.config, self.root)
        import os

        os.link(self.root / "lib/example.dart", self.root / "lib/linked.dart")
        with self.assertRaisesRegex(Invalid, "Hardlinked"):
            validate_graph(self.g, self.config, self.root)

    def test_duplicate_profile_transport_is_rejected(self) -> None:
        p = self.config_file(
            lambda c: c["agent_workers"]["implementer"]["variants"]["middle-implementer"].update(
                runner="native"
            )
        )
        with self.assertRaisesRegex(Invalid, r"agent_workers.*variants.*extra field"):
            load_config(p)

    def test_malformed_capabilities_rejected(self) -> None:
        p = self.config_file(
            lambda c: c["agent_workers"]["implementer"]["capabilities"].update(edit="false")
        )
        with self.assertRaisesRegex(Invalid, r"capabilities.edit: .*boolean"):
            load_config(p)

    def test_strict_enforcement_blocks_before_dispatch(self) -> None:
        self.config["profiles"]["implementer"]["enforcement"] = "required"
        self.init()
        with self.assertRaisesRegex(Invalid, "BLOCKED_CAPABILITIES"):
            self.claim("write-label")
        self.assertEqual(self.ledger.read()["nodes"]["write-label"]["status"], "pending")

    def test_readonly_profile_cannot_claim_writer(self) -> None:
        self.config["profiles"]["implementer"]["capabilities"]["edit"] = False
        self.init()
        with self.assertRaisesRegex(Invalid, "forbids edits"):
            self.claim("write-label")

    def test_task_reviewer_repair_profile_cannot_write_product_scope(self) -> None:
        import yaml

        example = yaml.safe_load((ROOT / "factory.example.yaml").read_text())
        self.assertTrue(self.config["profiles"]["task-reviewer"]["capabilities"]["edit"])
        self.assertTrue(example["agent_workers"]["task-reviewer"]["capabilities"]["edit"])
        self.g["agents"]["author"] = {"role": "task-reviewer", "profile": "task-reviewer"}
        with self.assertRaisesRegex(Invalid, "Role outside Implement workflow: task-reviewer"):
            self.init()

    def test_packet_accepts_task_without_optional_dependencies(self) -> None:
        self.g["tasks"]["label"].pop("depends_on", None)
        self.init()
        self.claim("write-label")
        self.assertEqual({}, self.ledger.packet("write-label")["dependency_results"])

    def test_native_packet_includes_adapter_and_capabilities(self) -> None:
        self.init()
        self.claim("write-label")
        packet = self.ledger.packet("write-label")
        run = self.ledger.read()["run_id"]
        self.assertEqual(packet, self.ledger.packet("write-label"))
        [saved] = [
            a
            for a in sqlite_history_repository.listing(self.root, run)
            if a["kind"] == "inline-packet"
        ]
        exported = self.root / "inline.md"
        sqlite_history_repository.export(self.root, run, str(saved["path"]), exported)
        self.assertEqual(render(packet), exported.read_bytes())
        self.assertEqual(
            packet,
            self.ledger.history.document(
                self.root, run, str(saved["path"]), str(saved["sha256"]), "inline-packet"
            ),
        )
        self.assertEqual(packet["profile"]["adapter"], "codex")
        self.assertEqual(
            packet["model"]["id"],
            self.config["models"][self.config["profiles"]["implementer"]["model"]]["id"],
        )
        self.assertTrue(any("Codex worker adapter" in f["content"] for f in packet["instructions"]))
        self.assertTrue(any("Implementer contract" in f["content"] for f in packet["instructions"]))
        self.assertTrue(any("Fixture workspace" in f["content"] for f in packet["instructions"]))
        self.assertFalse(any(f["content"].startswith("# Router") for f in packet["instructions"]))

    def test_acp_packet_includes_adapter_and_policy(self) -> None:
        self.fake_acp()
        self.init()
        self.claim("write-label")
        result = prepare_prompt(self.ledger, "write-label")
        content = Path(result["prompt"]).read_text(encoding="utf-8")
        self.assertIn("ACP worker adapter", content)
        self.assertNotIn("# Router", content)
        self.assertIn("- capabilities", content)
        self.assertIn("- enforcement = instructions", content)

    def test_missing_router_is_rejected(self) -> None:
        for mutate in (lambda c: c.pop("router"), lambda c: c.update(router="missing.md")):
            with self.subTest(mutate=mutate):
                # config_file creates one copied bundle per test fixture.
                import shutil

                shutil.rmtree(self.root / "bundle", ignore_errors=True)
                path = self.config_file(mutate)
                with self.assertRaisesRegex(Invalid, "router"):
                    load_config(path)

    def test_configured_router_is_accepted_coordinator_reading(self) -> None:
        path = self.config_file(lambda c: c.update(router="workflow/alternate-router.md"))
        policy = path.parent / "workflow/alternate-router.md"
        policy.write_text("Distinct router policy")
        self.config = load_config(path)
        self.init()
        self.claim("write-label")
        packet = self.ledger.packet("write-label")
        self.assertFalse(
            any(f["content"] == "Distinct router policy" for f in packet["instructions"])
        )
        policy.write_text("Changed router policy")
        self.assertEqual(packet, self.ledger.packet("write-label"))

    def test_active_coordinator_reads_accepted_factory_and_project_text(self) -> None:
        path = self.config_file(lambda c: c.update(router="workflow/alternate-router.txt"))
        policy = path.parent / "workflow/alternate-router.txt"
        policy.write_text("Accepted router")
        user = path.parent / "memory/USER.md"
        user.parent.mkdir(exist_ok=True)
        user.write_text("Accepted owner instructions", encoding="utf-8")
        self.config = load_config(path)
        self.init()
        policy.unlink()
        user.write_text("Replaced owner instructions", encoding="utf-8")
        (self.root / "AGENTS.md").write_text("Candidate instructions")
        command = [*CLI, "workflow", "--workspace", str(self.root)]
        for args, accepted in (
            (["read-instructions", "-", "workflow/alternate-router.txt"], "Accepted router"),
            (["read-project"], "Fixture workspace."),
        ):
            result = subprocess.run(command + args, capture_output=True, text=True, check=True)
            self.assertIn(accepted, result.stdout)
            self.assertNotIn("Candidate instructions", result.stdout)
            if args == ["read-project"]:
                self.assertEqual(1, result.stdout.count("Accepted owner instructions"))
                self.assertNotIn("Replaced owner instructions", result.stdout)

    def test_configuration_has_two_separate_caps(self) -> None:
        self.assertEqual(self.config["_limits"], {"native": 3, "acpx:zcode": 3})

    def test_cycle_and_duplicate_id_rejected(self) -> None:
        self.g["nodes"][0]["depends_on"] = ["accept-label"]
        with self.assertRaisesRegex(Invalid, "cycle"):
            validate_graph(self.g, self.config)
        self.g["nodes"][0]["depends_on"] = []
        self.g["nodes"].append(deepcopy(self.g["nodes"][0]))
        with self.assertRaisesRegex(Invalid, "Duplicate"):
            validate_graph(self.g, self.config)

    def test_solo_completion_and_explicit_review_requirement(self) -> None:
        self.init()
        self.complete()
        self.assertEqual("done", self.ledger.read()["nodes"]["accept-label"]["status"])
        required = deepcopy(self.g)
        required["tasks"]["label"]["independent_review"] = True
        with self.assertRaisesRegex(Invalid, "Missing final review"):
            validate_graph(required, self.config, self.root)
        other = deepcopy(self.g)
        other["agents"]["author"] = {"role": "implementer", "profile": "implementer"}
        validate_graph(other, self.config, self.root)

    def test_non_low_risk_needs_independent_review(self) -> None:
        self.g["tasks"]["label"]["risk"] = "moderate"
        with self.assertRaisesRegex(Invalid, "requires review"):
            self.init()

    def test_missing_verify_or_wrong_order_rejected(self) -> None:
        self.g["nodes"][1]["depends_on"] = []
        self.g["nodes"][2]["depends_on"] = ["write-label", "verify-label"]
        with self.assertRaisesRegex(Invalid, "follow all writers"):
            self.init()

    def test_dependency_blocks_early_dispatch(self) -> None:
        self.init()
        with self.assertRaisesRegex(Invalid, "Dependencies"):
            self.claim("verify-label")

    def test_source_path_edit_keeps_original_writer_source(self) -> None:
        (self.root / "request.md").write_text("source")
        self.g["sources"]["request"] = {
            "path": "request.md",
            "acceptance": self.g["sources"]["request"]["acceptance"],
        }
        self.init()
        (self.root / "request.md").write_text("different source")
        self.claim("write-label")
        self.assertEqual("source", self.ledger.packet("write-label")["source"]["snapshot"])

    def test_reintake_refreshes_source_also_used_as_reading(self) -> None:
        self.g["sources"]["request"]["path"] = "request.md"
        self.g["sources"]["request"].pop("text")
        self.g["nodes"][0]["read"] = ["request.md"]
        (self.root / "request.md").write_text("Original source")
        self.init()
        self.start("write-label")
        self.ledger.finish("write-label", self.report("write-label"))
        before = self.ledger.read()
        (self.root / "request.md").write_text("Authorized new source")
        self.ledger.reintake(before["graph"], "Revised requirement", "user message")
        after = self.ledger.read()
        self.assertEqual("pending", after["nodes"]["write-label"]["status"])
        self.assertEqual(before["run_id"], after["run_id"])
        self.claim("write-label")
        packet = self.ledger.packet("write-label")
        self.assertEqual("Authorized new source", packet["source"]["snapshot"])
        self.assertIn("Authorized new source", [i["content"] for i in packet["instructions"]])
        self.assertNotIn("Original source", [i["content"] for i in packet["instructions"]])

    def test_unverified_model_cannot_bind(self) -> None:
        self.init()
        self.claim("write-label")
        with self.assertRaisesRegex(Invalid, "model differs"):
            self.ledger.bind("write-label", "h", "invented-model")

    def test_no_blind_redispatch(self) -> None:
        self.init()
        self.claim("write-label")
        self.ledger.unknown("write-label", "lost response")
        with self.assertRaisesRegex(Invalid, "Already dispatched"):
            self.claim("write-label")
        with self.assertRaisesRegex(Invalid, "Outstanding"):
            self.ledger.archive("cancelled", "cancel")

    def test_reconciled_result_does_not_repeat_side_effect(self) -> None:
        self.init()
        self.start("write-label")
        self.ledger.unknown("write-label", "lost response")
        before = self.ledger.read()
        with self.assertRaisesRegex(Invalid, "evidence"):
            self.ledger.resolve("write-label", "running", " \t ")
        self.assertEqual(self.ledger.read(), before)
        self.ledger.resolve("write-label", "running", "runtime result recovered")
        self.ledger.finish("write-label", self.report("write-label"))
        self.assertEqual(self.ledger.read()["nodes"]["write-label"]["attempt"], 1)

    def test_report_identity_and_bytes_checked(self) -> None:
        self.init()
        self.start("write-label")
        with self.assertRaisesRegex(Invalid, "identity"):
            self.ledger.finish("write-label", self.report("write-label", dispatch_id="old"))
        with self.assertRaisesRegex(Invalid, "file evidence"):
            self.ledger.finish("write-label", self.report("write-label", files={}))

    def test_failed_checks_cannot_pass(self) -> None:
        self.init()
        self.start("write-label")
        self.ledger.finish("write-label", self.report("write-label"))
        self.start("verify-label")
        with self.assertRaisesRegex(Invalid, "Missing required check results"):
            self.ledger.finish("verify-label", self.report("verify-label", checks=[]))

    def test_acceptance_rejects_later_write(self) -> None:
        self.init()
        self.start("write-label")
        self.ledger.finish("write-label", self.report("write-label"))
        self.start("verify-label")
        self.ledger.finish("verify-label", self.report("verify-label"))
        (self.root / "lib/example.dart").write_text("changed later")
        with self.assertRaisesRegex(Invalid, "invalidated"):
            self.ledger.accept("accept-label")

    def test_retry_preserves_budget_and_invalidates_dependents(self) -> None:
        self.init()
        self.complete()
        self.ledger.retry("write-label", "tests", "real failing test", "writer terminal")
        self.assertEqual(self.ledger.read()["nodes"]["accept-label"]["status"], "pending")
        self.start("write-label")
        self.ledger.finish("write-label", self.report("write-label", "FAIL"))
        self.ledger.retry("write-label", "tests", "same issue", "writer terminal")
        self.ledger.replace_session(
            "author", "context unavailable", "terminal confirmed", "remaining failure"
        )
        self.start("write-label", "new-handle")
        self.ledger.finish("write-label", self.report("write-label", "FAIL"))
        with self.assertRaisesRegex(Invalid, "BUDGET"):
            self.ledger.retry("write-label", "tests", "same issue", "writer terminal")

    def test_completed_archive_consumes_each_result_once_even_after_manual_ack(self) -> None:
        self.init()
        self.complete()
        state = self.ledger.read()
        self.ledger.acknowledge_result("write-label", state["nodes"]["write-label"]["dispatch_id"])
        self.ledger.archive("completed", "done")
        self.ledger.archive("completed", "done")
        archived = self.ledger.read()
        expected = sorted(state["report_index"])
        self.assertEqual(expected, sorted(archived["processed_results"]))
        self.assertEqual(
            expected,
            sorted(
                e["dispatch_id"] for e in archived["events"] if e["event"] == "result_acknowledged"
            ),
        )

    def test_history_survives_cleanup_and_unknown_file_is_preserved(self) -> None:
        self.init()
        self.complete()
        unknown = self.ledger.dir / "someone-elses-file.md"
        unknown.write_text("keep")
        history = Path(self.ledger.archive("completed", "done"))
        self.ledger.clean()
        self.assertTrue(history.exists())
        self.assertTrue(unknown.exists())
        self.assertFalse(has_current(self.ledger))

    def test_archive_retry_after_interrupted_terminal_state_write(self) -> None:
        run_id = self.init()["run_id"]
        self.complete()
        with (
            patch(
                "factory.database.sqlite.sqlite_teacher_job_repository.insert_event",
                side_effect=OSError("interrupted"),
            ),
            self.assertRaisesRegex(OSError, "interrupted"),
        ):
            self.ledger.archive("completed", "done")
        self.assertEqual("active", self.ledger.read()["status"])
        with sqlite_history_repository.database(self.root) as db:
            self.assertEqual([], db.execute("SELECT run_id FROM closed_runs").fetchall())
        self.assertEqual([], teacher.pending(self.root))
        restarted = Ledger(self.root)
        path = restarted.archive("completed", "done")
        self.assertEqual(str(self.root.resolve() / workflow_db.DATABASE), path)
        reopened = Ledger(self.root)
        self.assertEqual(path, reopened.archive("completed", "done"))
        with self.assertRaisesRegex(Invalid, "Terminal history is immutable"):
            reopened.archive("completed", "changed summary")
        state = reopened.read()
        self.assertEqual([state["final_teacher_event"]], teacher.pending(self.root))
        event = teacher.read_event(self.root, state["final_teacher_event"])
        self.assertEqual((run_id, workflow_db.DATABASE), (event.incident, event.source))
        reopened.clean()
        with sqlite_history_repository.database(self.root) as db:
            self.assertEqual([(run_id,)], db.execute("SELECT run_id FROM closed_runs").fetchall())
        self.assertEqual("completed", read_task(self.root, "label", run_id=run_id)["run_status"])

    def test_archive_preserves_adapter_reference_on_close_and_retry(self) -> None:
        run_id = self.init()["run_id"]
        self.complete()
        archive = ArchiveReference(f"urn:run:{run_id}", f"archive://history/{run_id}")
        store = Mock(spec_set=sqlite_run_repository, wraps=sqlite_run_repository)
        store.reference.return_value = archive
        self.assertEqual(
            archive.location, Ledger(self.root, runs=store).archive("completed", "done")
        )
        store.reference.assert_called_once_with(self.ledger.root, run_id)
        state = self.ledger.read()
        self.assertEqual(archive.source, state["archive_path"])
        self.assertEqual(
            archive.source, teacher.read_event(self.root, state["final_teacher_event"]).source
        )
        store.reference.reset_mock()
        reopened = Ledger(self.root, runs=store)
        self.assertEqual(archive.location, reopened.archive("completed", "done"))
        store.reference.assert_called_once_with(reopened.root, run_id, stored_source=archive.source)
        store.commit_archive.assert_called_once()

    def test_memory_reads_task_from_the_requested_run_after_cleanup(self) -> None:
        archived_id = self.init()["run_id"]
        self.complete()
        saved_steps = self.ledger.read()["nodes"]
        self.ledger.archive("completed", "done")
        self.ledger.clean()
        archived_inventory = sqlite_history_repository.inventory(self.root, archived_id)
        before_next_run = read_task(self.root, "label", run_id=archived_id)
        self.assertEqual(before_next_run["run_id"], archived_id)
        self.assertEqual(before_next_run["run_status"], "completed")
        self.assertEqual(
            set(before_next_run["steps"]), {"write-label", "verify-label", "accept-label"}
        )
        for node_id in ("write-label", "verify-label"):
            step = before_next_run["steps"][node_id]
            self.assertEqual(step["status"], "done")
            self.assertEqual(step["dispatch_id"], saved_steps[node_id]["dispatch_id"])
            self.assertEqual(step["report"], saved_steps[node_id]["report"])
        self.assertEqual(before_next_run["steps"]["accept-label"]["status"], "done")

        active_id = self.init()["run_id"]
        self.start("write-label")
        self.ledger.finish("write-label", self.report("write-label", summary="New run"))
        state = self.ledger.read()
        finding: FindingRecord = {
            "id": "REV-1",
            "status": "open",
            "blocking": True,
            "owner_role": "implementer",
            "owner_node_id": "write-label",
            "summary": "Current run finding",
            "evidence": "Inspected change",
            "history": [],
        }
        state["review_findings"] = {
            "label": {
                "REV-1": {**finding, "id": "REV-1", "status": "open"},
                "REV-2": {**finding, "id": "REV-2", "status": "fixed"},
            }
        }
        self.ledger.save(state, "fixture_findings")
        active_bytes = record_bytes(self.ledger)

        active = read_task(self.root, "label", run_id=None)
        archived = read_task(self.root, "label", run_id=archived_id)
        self.assertEqual(active["run_id"], active_id)
        self.assertEqual(active["steps"]["write-label"]["report"]["summary"], "New run")
        self.assertEqual(list(active["open_findings"]), ["REV-1"])
        self.assertEqual(active["open_findings"]["REV-1"]["status"], "open")
        self.assertEqual(archived["run_id"], archived_id)
        self.assertEqual(archived["run_status"], "completed")
        self.assertEqual(archived, before_next_run)
        self.assertEqual(archived["open_findings"], {})
        self.assertEqual(record_bytes(self.ledger), active_bytes)
        self.assertEqual(
            sqlite_history_repository.inventory(self.root, archived_id), archived_inventory
        )

    def test_factory_ancestor_symlink_rejected_before_lock_or_read(self) -> None:
        outside = self.root / "outside"
        outside.mkdir()
        (self.root / ".factory").symlink_to(outside, target_is_directory=True)
        with self.assertRaisesRegex(Invalid, "Symlink"):
            with self.ledger.locked():
                pass
        self.assertFalse((outside / "memory").exists())
        with self.assertRaisesRegex(Invalid, "Symlink"):
            self.ledger.read()

    def test_memory_evidence_resolution_is_safe(self) -> None:
        evidence = self.root / ".factory/memory/history/run-example/evidence.txt"
        evidence.parent.mkdir(parents=True)
        evidence.write_text("saved evidence", encoding="utf-8")
        reference = ".factory/memory/history/run-example/evidence.txt"
        self.assertEqual(resolve_evidence(self.root, reference).read_text(), "saved evidence")
        with self.assertRaises(Invalid):
            resolve_evidence(self.root, ".factory/memory/../outside")
        with self.assertRaises(Invalid):
            resolve_evidence(self.root, ".factory/memory/history/missing")
        evidence.unlink()
        evidence.symlink_to(self.root / "lib/example.dart")
        with self.assertRaises(Invalid):
            resolve_evidence(self.root, reference)

    def test_memory_distinguishes_missing_run_task_and_invalid_state(self) -> None:
        with self.assertRaisesRegex(Invalid, "Run not found"):
            read_task(self.root, "label", run_id=None)
        self.init()
        with self.assertRaisesRegex(Invalid, "Unknown task"):
            read_task(self.root, "unknown", run_id=None)
        with self.assertRaisesRegex(Invalid, "single run ID"):
            read_task(self.root, "label", run_id="../other")
        with self.assertRaisesRegex(Invalid, "single run ID"):
            read_task(self.root, "label", run_id="run-\0")
        overwrite(self.ledger, {"status": "invalid"})
        with self.assertRaises(Invalid):
            read_task(self.root, "label", run_id=None)

    def test_cleanup_requires_saved_history(self) -> None:
        self.init()
        self.complete()
        ref = self.ledger.read()["nodes"]["write-label"]["report_ref"]
        self.ledger.archive("completed", "done")
        with sqlite_history_repository.database(self.root) as db:
            db.execute(
                "DELETE FROM artifacts WHERE run_id=? AND path=?", (ref["run_id"], ref["path"])
            )
        with self.assertRaisesRegex(Invalid, "Missing or changed artifact"):
            self.ledger.clean()
        self.assertTrue(has_current(self.ledger))

    def test_archive_failure_keeps_state(self) -> None:
        self.init()
        self.complete()
        (self.root / ".factory/memory/history").rename(self.root / "saved-history")
        (self.root / ".factory/memory/history").symlink_to(
            self.root / "lib", target_is_directory=True
        )
        with self.assertRaisesRegex(Invalid, "Symlink"):
            self.ledger.archive("completed", "done")
        self.assertEqual(self.ledger.read()["status"], "active")

    def test_graph_revision_preserves_locked_task(self) -> None:
        s = self.init()
        changed = deepcopy(s["graph"])
        changed["tasks"]["label"]["outcome"] = "different"
        with self.assertRaisesRegex(Invalid, "locked tasks"):
            self.ledger.revise(changed, "changed mind")

    def test_diagram_has_one_lifeline_per_agent(self) -> None:
        rendered = diagram(self.init())
        self.assertEqual(rendered.count("participant A1"), 1)
        self.assertIn("sequenceDiagram", rendered)
        self.assertIn("participant T as Teacher", rendered)
        self.assertLess(
            rendered.rindex(" acceptance"), rendered.index("O->>T: Final Teacher review (planned)")
        )

    def test_implementer_cannot_execute_tests_despite_resource_reservation(self) -> None:
        self.g["nodes"][0]["resources"] = ["project-checks"]
        self.init()
        self.start("write-label")
        with self.assertRaisesRegex(Invalid, "Unknown assigned command"):
            self.ledger.run_check("write-label", "behavior")
        self.ledger.finish("write-label", self.report("write-label", checks=[]))
        self.assertEqual(self.ledger.read()["nodes"]["write-label"]["status"], "done")

    def test_implementer_handoff_needs_no_verification_receipts(self) -> None:
        self.g["agents"]["author"] = {"role": "implementer", "profile": "implementer"}
        self.require_fixture_review()
        self.init()
        self.start("write-label")
        self.ledger.finish("write-label", self.report("write-label"))
        self.assertEqual(self.ledger.read()["nodes"]["write-label"]["status"], "done")

    def test_implementer_reports_required_observation(self) -> None:
        self.g["agents"]["author"] = {"role": "implementer", "profile": "implementer"}
        self.require_fixture_review()
        check = self.g["tasks"]["label"]["required_checks"][0]
        check["kind"] = "observation"
        check.pop("execution")
        self.g["nodes"][0]["required_check_ids"] = ["behavior"]
        self.init()
        self.start("write-label")
        report = self.report("write-label")
        with self.assertRaisesRegex(Invalid, "Missing required check results: behavior"):
            self.ledger.finish("write-label", report)
        report["checks"] = [{**check, "result": "PASS", "evidence": "Observed behavior"}]
        self.ledger.finish("write-label", report)
        self.assertEqual(self.ledger.read()["nodes"]["write-label"]["status"], "done")

    def test_blocked_implementer_can_report_without_test_receipts(self) -> None:
        self.g["agents"]["author"] = {"role": "implementer", "profile": "implementer"}
        self.g["nodes"][0]["resources"] = ["project-checks"]
        self.require_fixture_review()
        self.init()
        self.start("write-label")
        report = self.report("write-label", "BLOCKED", checks=[])
        self.ledger.finish("write-label", report)
        self.assertEqual(self.ledger.read()["nodes"]["write-label"]["status"], "blocked")

    def test_native_and_acp_capacity_queues_fourth_independently(self) -> None:
        self.parallel_graph()
        self.init()
        for i in [0, 1, 2, 4, 5, 6]:
            self.claim(f"worker{i}")
        for i in [3, 7]:
            with self.assertRaisesRegex(Invalid, "QUEUED_CAPACITY"):
                self.claim(f"worker{i}")
        self.ledger.unknown("worker0", "lost response")
        with self.assertRaisesRegex(Invalid, "QUEUED_CAPACITY"):
            self.claim("worker3")

    def test_overlapping_writers_blocked(self) -> None:
        self.parallel_graph()
        self.g["nodes"][1]["owns"] = self.g["nodes"][0]["owns"]
        self.init()
        self.claim("worker0")
        with self.assertRaisesRegex(Invalid, "QUEUED_OWNERSHIP"):
            self.claim("worker1")

    def test_native_session_cannot_be_reassigned_to_other_agent(self) -> None:
        self.parallel_graph()
        self.init()
        self.start("worker0", "shared")
        self.claim("worker1")
        with self.assertRaisesRegex(Invalid, "different logical agent"):
            self.ledger.bind("worker1", "shared", "gpt-6.1-sol")

    def test_requested_acp_name_belongs_to_one_agent_before_bind(self) -> None:
        state = self.init()
        sessions = RunSessions(state)
        name = sessions.acp_name("author")
        sessions.request_acp_creation("author")
        requested = deepcopy(state)
        with self.assertRaisesRegex(Invalid, "different agent or epoch"):
            sessions.bind("reviewer", name, "fixture-model", expected_model=None)
        self.assertEqual(state, requested)
        sessions.bind("author", name, "fixture-model", expected_model=None)
        self.assertEqual(state["handle_owners"][name], "author")

    def test_acp_request_rejects_shared_physical_session(self) -> None:
        state = self.init()
        sessions = RunSessions(state)
        name = sessions.acp_name("author")
        state["sessions"]["reviewer"] = {"handle": name, "model": "fixture-model"}
        before = deepcopy(state)
        with self.assertRaisesRegex(Invalid, "Physical session shared"):
            sessions.request_acp_creation("author")
        self.assertEqual(state, before)

    def transport(self, argv: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
        # Keep real child-process/output behavior without requiring a POSIX shell.
        self.assertEqual(str(Path(sys.executable).resolve()), argv[0])
        script = f"print('fixture transport only'); raise SystemExit({self.transport_exit_code})"
        return subprocess.run([sys.executable, "-c", script, *argv[1:]], text=True, **kwargs)

    def test_registry_merge_preserves_other_settings(self) -> None:
        self.fake_acp()
        target = self.root / ".acpxrc.json"
        original = json.dumps({"ttl": 47, "agents": {"other": {"argv": ["other"]}}})
        target.write_text(original)
        preview = install_connection(self.config, self.root, "zcode", dry_run=True)
        self.assertTrue(preview.pop("would_write"))
        self.assertFalse((self.root / ".factory/memory/state/acpx-setup.lock").exists())
        self.assertEqual(target.read_text(), original)
        self.assertEqual(install_connection(self.config, self.root, "zcode"), preview)
        self.assertFalse(
            install_connection(self.config, self.root, "zcode", dry_run=True)["would_write"]
        )
        current = read_json(self.root / ".acpxrc.json")
        self.assertEqual(current["ttl"], 47)
        self.assertIn("other", current["agents"])
        current["agents"]["zcode"] = {"argv": ["different"]}
        (self.root / ".acpxrc.json").write_text(json.dumps(current))
        for dry_run in (True, False):
            with self.subTest(dry_run=dry_run), self.assertRaisesRegex(Invalid, "alias differs"):
                install_connection(self.config, self.root, "zcode", dry_run=dry_run)

    def test_connection_cannot_silently_ignore_mcp_or_environment_settings(self) -> None:
        for field in ("env", "mcpServers", "mcp_config"):
            # Validate each fresh serialized fixture, without adapter-derived keys.
            def mutate(c: dict[str, Any], field: str = field) -> None:
                c["acpx"]["connections"]["zcode"][field] = {}

            path = self.config_file(mutate)
            with (
                self.subTest(field=field),
                self.assertRaisesRegex(Invalid, r"acpx.connections.\*.*extra field"),
            ):
                load_config(path)
            import shutil

            shutil.rmtree(path.parent)

    def test_connection_args_must_not_be_a_shell_string(self) -> None:
        path = self.config_file(
            lambda c: c["acpx"]["connections"]["zcode"].update(args="server --option")
        )
        with self.assertRaisesRegex(Invalid, r"args: .*list"):
            load_config(path)

    def test_acp_command_preserves_provider_qualified_model_id(self) -> None:
        self.fake_acp()
        state = self.init()
        command = build_command(state, "write-label", "create")
        self.assertEqual(command[command.index("--model") + 1], r"builtin:zai-coding-plan\GLM-5.3")

    def test_prompt_contains_instruction_content_and_no_blanket_approval(self) -> None:
        self.fake_acp()
        self.init()
        self.claim("write-label")
        prepared = prepare_prompt(self.ledger, "write-label")
        self.assertIn("Implementer contract", Path(prepared["prompt"]).read_text(encoding="utf-8"))
        self.assertNotIn("--approve-all", prepared["prompt_argv"])
        self.assertIn("--non-interactive-permissions", prepared["prompt_argv"])

    def test_approve_all_requires_explicit_choice_of_workspace(self) -> None:
        self.fake_acp()
        self.config["acpx"]["connections"]["zcode"]["permissions"] = "approve-all"
        install_connection(self.config, self.root, "zcode")
        self.init()
        self.claim("write-label")
        with self.assertRaisesRegex(Invalid, "requires an explicit execution.workspace"):
            prepare_prompt(self.ledger, "write-label")
        with self.assertRaisesRegex(Invalid, "requires an explicit execution.workspace"):
            run_operation(self.ledger, "write-label", "create", run=self.transport)
        self.assertNotIn("acp_created", self.ledger.read())

    def test_approve_all_allows_explicit_shared_workspace(self) -> None:
        self.fake_acp()
        self.config["acpx"]["connections"]["zcode"]["permissions"] = "approve-all"
        self.config["execution"]["workspace"] = "shared"
        self.init()
        self.claim("write-label")
        argv = prepare_prompt(self.ledger, "write-label")["prompt_argv"]
        self.assertIn("--approve-all", argv)
        self.assertEqual(argv[argv.index("--cwd") + 1], str(self.ledger.root))

    def test_acp_poll_outputs_survive_repeated_calls_and_archive(self) -> None:
        self._check_acp_poll_history("write-label")

    def test_acp_poll_history_with_long_node_id(self) -> None:
        node_id = "a" * 161
        self.g["nodes"][0]["id"] = node_id
        for node in self.g["nodes"]:
            node["depends_on"] = [
                node_id if dep == "write-label" else dep for dep in node["depends_on"]
            ]
        self._check_acp_poll_history(node_id)

    def _check_acp_poll_history(self, node_id: str) -> None:
        self.fake_acp()
        install_connection(self.config, self.root, "zcode")
        self.init()
        self.claim(node_id)
        responses = iter(("ready", "idle"))

        def poll(argv: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
            kwargs["stdout"].write(next(responses))
            return subprocess.CompletedProcess(argv, 0)

        results = [run_operation(self.ledger, node_id, "show", run=poll) for _ in range(2)]
        paths = [result["stdout"] for result in results]
        self.assertEqual(len(set(paths)), 2)
        self.assertEqual(
            [Path(path).read_text(encoding="utf-8") for path in paths], ["ready", "idle"]
        )
        events = [
            event
            for event in self.ledger.read()["events"]
            if event["event"] == "transport_returned"
        ]
        refs = [result["stdout_ref"] for result in results]
        self.assertEqual([event["stdout"] for event in events], refs)
        run = results[0]["run_id"]
        name = results[0]["session"]
        self.ledger.unknown(node_id, "poll complete")
        self.ledger.resolve(node_id, "blocked", "transport stopped")
        usage = {
            "cwd": str(self.ledger.root),
            "name": name,
            "acpxRecordId": "fixture-record",
            "acpSessionId": "fixture-session",
            "messages": ["private content"],
            "request_token_usage": {"request-1": {"input_tokens": 8, "output_tokens": 0}},
            "cumulative_cost": {"amount": 0.25, "currency": "USD"},
        }
        probe = Mock(return_value=subprocess.CompletedProcess([], 0, stdout=json.dumps(usage)))
        self.ledger.archive("cancelled", "poll history", probe=probe)
        self.ledger.archive("cancelled", "poll history", probe=probe)
        probe.assert_called_once()
        self.assertEqual(probe.call_args.kwargs["cwd"], str(self.ledger.root))
        self.ledger.clean()
        self.assertTrue(all(not Path(path).exists() for path in paths))
        restored = self.root / "restored"
        target = restored / workflow_db.DATABASE
        target.parent.mkdir(parents=True)
        shutil.copyfile(self.root / workflow_db.DATABASE, target)
        self.assertEqual(
            [sqlite_history_repository.member(restored, run, ref).decode() for ref in refs],
            ["ready", "idle"],
        )
        with workflow_db.database(restored) as db:
            self.assertEqual(
                db.execute(
                    "SELECT session_name, collection, cost_amount, cost_currency FROM acpx_sessions"
                ).fetchall(),
                [(name, "ok", 0.25, "USD")],
            )
            self.assertEqual(
                db.execute(
                    "SELECT request_id, input_tokens, output_tokens, thought_tokens FROM acpx_request_usage"
                ).fetchall(),
                [("request-1", 8, 0, None)],
            )
            self.assertEqual(
                db.execute("SELECT node_id,dispatch_id FROM acpx_attempts").fetchall(),
                [(node_id, results[0]["dispatch_id"])],
            )
        projection = sqlite_history_repository.member(
            restored, run, f".factory/memory/history/{run}/usage.acpx.json"
        )
        self.assertNotIn(b"private content", projection)

    def test_interrupted_transport_preserves_partial_output_and_excludes_live_archive(self) -> None:
        self.fake_acp()
        install_connection(self.config, self.root, "zcode")
        self.init()
        self.claim("write-label")

        def stop(argv: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
            kwargs["stderr"].write("partial diagnostic")
            self.ledger.unknown("write-label", "reconciling")
            self.ledger.resolve("write-label", "blocked", "stopped")
            with self.assertRaisesRegex(Invalid, "locked"):
                self.ledger.archive("cancelled", "stopped")
            raise OSError("process interrupted")

        with self.assertRaisesRegex(OSError, "process interrupted"):
            run_operation(self.ledger, "write-label", "show", run=stop)
        state = self.ledger.read()
        final = state["events"][-1]
        self.assertEqual(final["event"], "transport_interrupted")
        self.ledger.archive("cancelled", "stopped")
        self.ledger.clean()
        self.assertEqual(
            sqlite_history_repository.member(self.root, state["run_id"], final["stderr"]),
            b"partial diagnostic",
        )
        rows = sqlite_history_repository.listing(self.root, state["run_id"])
        self.assertTrue(
            any(
                row["path"] == final["stderr"]
                and row["dispatch_id"] == final["dispatch_id"]
                and row["kind"] == "stderr"
                for row in rows
            )
        )

    def test_archive_waits_for_acpx_writer_after_adapter_is_killed(self) -> None:
        self.fake_acp()
        install_connection(self.config, self.root, "zcode")
        state = self.init()
        self.claim("write-label")
        child = self.root / "writer.py"
        child.write_text(
            "import os, time\n"
            "from pathlib import Path\n"
            "os.write(1, b'early\\n')\n"
            "Path('ready').touch()\n"
            "deadline = time.monotonic() + 45\n"
            "while not Path('release').exists() and time.monotonic() < deadline:\n"
            "    time.sleep(0.02)\n"
            "os.write(1, b'late\\n')\n"
            "os.write(2, b'last diagnostic')\n",
            encoding="utf-8",
        )
        adapter = (
            "import subprocess, sys\n"
            "from factory.adapters.acpx_adapter import run_operation\n"
            "from factory.runtime.workflow import Ledger\n"
            "def run(argv, **kwargs):\n"
            "    return subprocess.run([sys.executable, 'writer.py'], **kwargs)\n"
            "run_operation(Ledger(sys.argv[1]), 'write-label', 'show', run=run)\n"
        )
        with subprocess.Popen(
            [sys.executable, "-c", adapter, str(self.root)], cwd=_TOOLS.parent
        ) as parent:
            try:
                deadline = time.monotonic() + 30
                while not (self.root / "ready").exists():
                    self.assertIsNone(parent.poll(), "Adapter exited before starting ACPX")
                    self.assertLess(time.monotonic(), deadline, "ACPX did not start")
                    time.sleep(0.02)
                parent.kill()
                parent.wait(timeout=10)
                self.ledger.unknown("write-label", "adapter exited")
                self.ledger.resolve("write-label", "blocked", "session reconciled")
                with self.assertRaisesRegex(Invalid, "locked by a writer"):
                    self.ledger.archive("cancelled", "stopped")
            finally:
                (self.root / "release").touch()
                if parent.poll() is None:
                    parent.kill()
        deadline = time.monotonic() + 15
        while True:
            try:
                self.ledger.archive("cancelled", "stopped")
                break
            except Invalid as exc:
                if "locked by a writer" not in str(exc) or time.monotonic() >= deadline:
                    raise
                time.sleep(0.02)
        self.ledger.clean()
        items = sqlite_history_repository.listing(self.root, state["run_id"])
        for kind, expected in (("stdout", b"early\nlate\n"), ("stderr", b"last diagnostic")):
            name = next(str(item["path"]) for item in items if item["kind"] == kind)
            self.assertEqual(
                sqlite_history_repository.member(self.root, state["run_id"], name), expected
            )

    def test_return_with_descendant_holding_stderr_keeps_evidence_pending(self) -> None:
        self.fake_acp()
        install_connection(self.config, self.root, "zcode")
        state = self.init()
        self.claim("write-label")
        with ExitStack() as children:

            def spawn(argv: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
                process = children.enter_context(
                    subprocess.Popen(
                        [
                            sys.executable,
                            "-c",
                            "import sys; sys.stdin.read(); sys.stderr.write('tail')",
                        ],
                        stdin=subprocess.PIPE,
                        stdout=subprocess.DEVNULL,
                        stderr=kwargs["stderr"],
                    )
                )
                assert process.stdin is not None
                children.callback(process.stdin.close)
                return subprocess.CompletedProcess(argv, 0)

            with self.assertRaisesRegex(Invalid, "locked by a writer"):
                run_operation(self.ledger, "write-label", "show", run=spawn)
            request = self.ledger.read()["events"][-1]
            self.assertEqual(request["event"], "transport_requested")
            self.ledger.unknown("write-label", "reconciling")
            self.ledger.resolve("write-label", "blocked", "session reconciled")
            with self.assertRaisesRegex(Invalid, "locked by a writer"):
                self.ledger.archive("cancelled", "stopped")
        self.ledger.archive("cancelled", "stopped")
        self.ledger.clean()
        self.assertEqual(
            sqlite_history_repository.member(self.root, state["run_id"], request["stderr"]), b"tail"
        )

    def test_late_create_failure_preserves_reconciled_dispatch(self) -> None:
        self.fake_acp()
        install_connection(self.config, self.root, "zcode")
        self.init()
        self.claim("write-label")

        def late_failure(argv: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
            kwargs["stderr"].write("late failure")
            self.ledger.unknown("write-label", "reconciling")
            with self.assertRaisesRegex(Invalid, "locked"):
                self.ledger.resolve("write-label", "blocked", "verified termination")
            return subprocess.CompletedProcess(argv, 2)

        result = run_operation(self.ledger, "write-label", "create", run=late_failure)
        self.assertEqual(result["exit_code"], 2)
        self.assertIn("session", result)
        self.assertNotIn("stale", result)
        self.assertEqual(self.ledger.read()["nodes"]["write-label"]["status"], "unknown")
        self.ledger.resolve("write-label", "blocked", "verified termination")
        self.assertEqual(self.ledger.read()["nodes"]["write-label"]["status"], "blocked")
        self.ledger.archive("cancelled", "stopped")
        self.ledger.clean()
        self.assertEqual(
            sqlite_history_repository.member(self.root, result["run_id"], result["stderr_ref"]),
            b"late failure",
        )

    def test_prompt_return_never_marks_node_passed(self) -> None:
        self.fake_acp()
        install_connection(self.config, self.root, "zcode")
        self.init()
        self.claim("write-label")
        prepared = prepare_prompt(self.ledger, "write-label")
        run_operation(self.ledger, "write-label", "create", run=self.transport)
        self.ledger.bind(
            "write-label",
            prepared["session"],
            self.config["models"]["glm-5-3"]["id"] or "fixture-default",
        )
        packet_path = Path(prepared["prompt"])
        frozen = packet_path.read_bytes()
        self.assertEqual(frozen, frozen.strip())
        packet_path.unlink()
        prepare_prompt(self.ledger, "write-label")
        self.assertEqual(frozen, packet_path.read_bytes())
        self.assertEqual(prepare_prompt(self.ledger, "write-label")["prompt"], str(packet_path))
        packet_path.write_bytes(frozen + b" ")
        with self.assertRaisesRegex(Invalid, "Packet digest mismatch"):
            run_operation(self.ledger, "write-label", "prompt", run=self.transport)
        packet_path.write_bytes(frozen)
        with self.ledger.locked():
            state = self.ledger.read()
            state["revision"] += 1
            self.ledger.save(state, "test_revision_changed")
        with self.assertRaisesRegex(Invalid, "Stale packet identity"):
            run_operation(self.ledger, "write-label", "prompt", run=self.transport)
        with self.ledger.locked():
            state = self.ledger.read()
            state["revision"] -= 1
            self.ledger.save(state, "test_revision_restored")

        def capture(argv: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
            self.assertEqual(argv[-2:], ["--file", str(packet_path)])
            read_file = (
                "import pathlib, sys; "
                "sys.stdout.buffer.write(pathlib.Path(sys.argv[-1]).read_bytes())"
            )
            return subprocess.run([argv[0], "-c", read_file, *argv[1:]], **kwargs)

        result = run_operation(self.ledger, "write-label", "prompt", run=capture)
        self.assertEqual(Path(result["stdout"]).read_bytes(), frozen)
        self.assertEqual(result["gate"], "NOT_EVALUATED")
        self.assertEqual(self.ledger.read()["nodes"]["write-label"]["status"], "running")
        with self.assertRaisesRegex(Invalid, "already submitted"):
            run_operation(self.ledger, "write-label", "prompt", run=self.transport)

    def run_opencode_prompt_with_effort(
        self, set_exit_code: int
    ) -> tuple[dict[str, Any], dict[str, Any], list[list[str]]]:
        def configure(raw: dict[str, Any]) -> None:
            raw["acpx"]["command"] = sys.executable
            raw["acpx"]["connections"]["opencode"] = {
                "command": sys.executable,
                "args": ["acp"],
                "max_parallel_agents": 1,
            }
            raw["adapters"]["opencode"] = {
                **raw["adapters"]["zcode"],
                "harness": "opencode",
                "connection": "opencode",
            }
            raw["models"]["openrouter-glm"] = {
                "id": "openrouter/z-ai/glm-5.3",
                "effort": "max",
            }
            raw["agent_workers"]["implementer"]["variants"]["implementer"].update(
                adapter="opencode", model="openrouter-glm"
            )

        self.config = load_config(self.config_file(configure))
        install_connection(self.config, self.root, "opencode")
        self.init()
        node = "write-label"
        self.claim(node)
        prepared = prepare_prompt(self.ledger, node)
        calls: list[list[str]] = []

        def fake_process(
            argv: list[str], *, cwd: Path, stdout: IO[str], stderr: IO[str], check: Literal[False]
        ) -> subprocess.CompletedProcess[str]:
            self.assertEqual(cwd, self.root.resolve())
            self.assertFalse(check)
            self.assertFalse(stdout.closed)
            self.assertFalse(stderr.closed)
            calls.append(argv)
            return subprocess.CompletedProcess(argv, set_exit_code if "set" in argv else 0)

        run_operation(self.ledger, node, "create", run=fake_process)
        self.ledger.bind(node, prepared["session"], "openrouter/z-ai/glm-5.3")
        calls.clear()
        result = run_operation(self.ledger, node, "prompt", run=fake_process)
        return prepared, result, calls

    def test_opencode_sets_effort_before_prompt_in_the_same_session(self) -> None:
        prepared, result, calls = self.run_opencode_prompt_with_effort(set_exit_code=0)
        session = prepared["session"]
        self.assertEqual(
            [argv[-6:] for argv in calls],
            [
                ["opencode", "set", "effort", "max", "-s", session],
                ["opencode", "prompt", "-s", session, "--file", prepared["prompt"]],
            ],
        )
        self.assertEqual(result["exit_code"], 0)
        self.assertEqual(self.ledger.read()["nodes"]["write-label"]["status"], "running")

    def test_opencode_effort_failure_skips_prompt_and_leaves_attempt_unknown(
        self,
    ) -> None:
        prepared, result, calls = self.run_opencode_prompt_with_effort(set_exit_code=9)
        self.assertEqual(
            [argv[-6:] for argv in calls],
            [["opencode", "set", "effort", "max", "-s", prepared["session"]]],
        )
        self.assertEqual(result["exit_code"], 9)
        self.assertEqual(self.ledger.read()["nodes"]["write-label"]["status"], "unknown")

    def test_create_failure_is_unknown_and_cannot_be_recreated(self) -> None:
        self.fake_acp(code=2)
        install_connection(self.config, self.root, "zcode")
        self.init()
        self.claim("write-label")
        run_operation(self.ledger, "write-label", "create", run=self.transport)
        self.assertEqual(self.ledger.read()["nodes"]["write-label"]["status"], "unknown")
        with self.assertRaises(Invalid):
            run_operation(self.ledger, "write-label", "create", run=self.transport)

    def test_argv_preserves_shell_metacharacters_as_one_argument(self) -> None:
        self.fake_acp()
        s = self.init()
        path = str(self.root / "prompt $(do-not-execute).md")
        argv = build_command(s, "write-label", "prompt", path)
        self.assertEqual(argv[-1], path)

    def test_noncanonical_and_symlink_ownership_rejected(self) -> None:
        self.g["nodes"][0]["owns"] = ["./lib/example.dart"]
        with self.assertRaisesRegex(Invalid, "Noncanonical"):
            self.init()
        (self.root / "alias").symlink_to(self.root / "lib", target_is_directory=True)
        with self.assertRaisesRegex(Invalid, "Symlink"):
            snapshot(self.root, ["alias/example.dart"])

    def test_source_hash_includes_selected_scope_and_normalizes_whitespace(self) -> None:
        a = lock_source(
            self.root,
            {
                "acceptance": self.g["sources"]["request"]["acceptance"],
                "text": "hello  \r\n",
                "selected_scope": "CAP-1",
            },
        )
        b = lock_source(
            self.root,
            {
                "acceptance": self.g["sources"]["request"]["acceptance"],
                "text": "hello\n",
                "selected_scope": "CAP-1",
            },
        )
        c = lock_source(
            self.root,
            {
                "acceptance": self.g["sources"]["request"]["acceptance"],
                "text": "hello\n",
                "selected_scope": "CAP-2",
            },
        )
        self.assertEqual(a["hash"], b["hash"])
        self.assertNotEqual(a["content_hash"], b["content_hash"])
        self.assertNotEqual(b["hash"], c["hash"])

    def test_prepared_source_hash_cannot_be_silently_relocked(self) -> None:
        self.g["sources"]["request"]["hash"] = "stale"
        with self.assertRaisesRegex(Invalid, "SOURCE_DRIFT"):
            self.init()

    def test_retired_physical_handle_cannot_be_rebound(self) -> None:
        self.init()
        self.start("write-label")
        self.ledger.finish("write-label", self.report("write-label"))
        self.ledger.replace_session("author", "new context", "old writer terminal", "handoff")
        self.claim("verify-label")
        with self.assertRaisesRegex(Invalid, "Retired physical"):
            self.ledger.bind("verify-label", "handle-author", "gpt-6.1-sol")

    def test_exhausted_failure_cannot_be_reopened_by_revision(self) -> None:
        self.init()
        self.start("write-label")
        self.ledger.finish("write-label", self.report("write-label", "FAIL"))
        for _ in range(2):
            self.ledger.retry("write-label", "tests", "same failure", "terminal")
            self.start("write-label")
            self.ledger.finish("write-label", self.report("write-label", "FAIL"))
        g = self.ledger.read()["graph"]
        g["nodes"][0]["read"] = ["AGENTS.md"]
        self.ledger.revise(g, "extra context")
        self.assertEqual(self.ledger.read()["nodes"]["write-label"]["status"], "blocked")
        with self.assertRaisesRegex(Invalid, "BUDGET"):
            self.ledger.retry("write-label", "tests", "same failure", "terminal")

    def test_revision_extends_files_and_invalidates_finished_verification(self) -> None:
        self.init()
        self.complete()
        g = self.ledger.read()["graph"]
        g["tasks"]["label"]["scope"].append("lib/new.txt")
        self.ledger.revise(g, "discovered related generated file")
        self.assertEqual(self.ledger.read()["nodes"]["verify-label"]["status"], "pending")

    def test_revision_can_add_independent_review_without_changing_outcome(self) -> None:
        self.init()
        self.complete()
        g = self.ledger.read()["graph"]
        g["tasks"]["label"].update({"risk": "moderate", "independent_review": True})
        g["agents"]["reviewer"] = {"role": "judge", "profile": "judge"}
        g["nodes"].append(
            {
                "id": "review-label",
                "task": "label",
                "stage": "review",
                "agent": "reviewer",
                "depends_on": ["verify-label"],
                "owns": [],
                "resources": ["project-checks"],
            }
        )
        g["nodes"][2]["depends_on"] = ["review-label"]
        self.ledger.revise(g, "new risk needs independent review")
        self.assertEqual(self.ledger.read()["nodes"]["accept-label"]["status"], "pending")

    def test_unbound_failed_creation_can_change_epoch_after_reconciliation(self) -> None:
        self.fake_acp(code=2)
        install_connection(self.config, self.root, "zcode")
        self.init()
        self.claim("write-label")
        old = run_operation(self.ledger, "write-label", "create", run=self.transport)["session"]
        self.ledger.resolve("write-label", "blocked", "fixture process exited, no backend session")
        self.ledger.replace_session(
            "author", "failed creation", "terminal verified", "no work done"
        )
        self.ledger.retry("write-label", "recovery", "creation failed", "terminal verified")
        self.claim("write-label")
        before = self.ledger.read()
        profile = self.config["profiles"]["middle-implementer-zcode"]
        model = self.config["models"][profile["model"]]["id"] or "fixture-model"
        with self.assertRaisesRegex(Invalid, "different agent or epoch"):
            self.ledger.bind("write-label", old, model)
        self.assertEqual(before, self.ledger.read())
        new = run_operation(self.ledger, "write-label", "create", run=self.transport)["session"]
        self.assertNotEqual(old, new)

    def test_stale_transport_completion_does_not_modify_new_attempt(self) -> None:
        self.fake_acp()
        install_connection(self.config, self.root, "zcode")
        self.init()
        self.claim("write-label")

        def old_call(*args: Any, **kwargs: Any) -> subprocess.CompletedProcess[str]:
            self.ledger.unknown("write-label", "transport outcome lost")
            with self.assertRaisesRegex(Invalid, "Resolve"):
                self.ledger.retry("write-label", "recovery", "terminal confirmed", "fixture exited")
            with self.assertRaisesRegex(Invalid, "locked"):
                self.ledger.resolve("write-label", "blocked", "backend session stopped")
            return subprocess.CompletedProcess([], 2)

        result = run_operation(self.ledger, "write-label", "create", run=old_call)
        self.assertEqual(result["exit_code"], 2)
        self.assertIn("session", result)
        self.assertNotIn("stale", result)
        saved = next(
            row
            for row in sqlite_history_repository.listing(self.root, result["run_id"])
            if row["path"] == result["stdout_ref"]
        )
        self.assertEqual(saved["dispatch_id"], result["dispatch_id"])
        self.assertEqual(self.ledger.read()["nodes"]["write-label"]["status"], "unknown")
        self.ledger.resolve("write-label", "blocked", "backend session confirmed stopped")
        self.ledger.retry("write-label", "recovery", "terminal confirmed", "fixture exited")
        self.claim("write-label")
        self.assertEqual(self.ledger.read()["nodes"]["write-label"]["status"], "reserved")

    def test_source_reintake_retains_failure_budget(self) -> None:
        self.init()
        self.start("write-label")
        self.ledger.finish("write-label", self.report("write-label", "FAIL"))
        self.ledger.retry("write-label", "tests", "bad assertion", "terminal")
        graph = self.ledger.read()["graph"]
        graph["sources"]["request"]["text"] = "User clarified expected label"
        self.ledger.reintake(graph, "clarification", "user message reference")
        self.assertEqual(self.ledger.read()["counters"]["label:tests"], 1)

    def test_terminal_history_cannot_be_overwritten(self) -> None:
        self.init()
        self.complete()
        self.ledger.archive("completed", "first")
        with self.assertRaisesRegex(Invalid, "immutable"):
            self.ledger.archive("completed", "rewritten")

    def test_alternate_policy_path_is_loaded_for_acp(self) -> None:
        self.fake_acp()
        policy = self.root / "alternate.md"
        policy.write_text("Distinct configured orchestration policy")
        # Config relative path must remain within its own root.
        original = self.config["_path"]
        self.config["_path"] = str(self.root / "factory.yaml")
        self.config["orchestration"] = "alternate.md"
        for p in [*self.config["profiles"].values(), *self.config["adapters"].values()]:
            for field, value in p.items():
                if field in (
                    "role",
                    "instructions",
                    "worker_instructions",
                    "contract",
                ) and isinstance(value, str):
                    destination = self.root / value
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    destination.write_text((Path(original).parent / value).read_text())
        from factory.context.context import factory_files

        for rel in factory_files(self.config) + [self.config["router"]]:
            destination = self.root / rel
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text((ROOT / rel).read_text())
        shutil.copytree(Path(original).parent / "graphs", self.root / "graphs")
        self.init()
        self.claim("write-label")
        result = prepare_prompt(self.ledger, "write-label")
        self.assertNotIn(
            "Distinct configured orchestration policy",
            Path(result["prompt"]).read_text(encoding="utf-8"),
        )

    def test_approved_plan_cannot_be_downgraded_to_direct_mode(self) -> None:
        (self.root / "plan.md").write_text("This is not an approved plan")
        with self.assertRaisesRegex(Invalid, "must agree"):
            lock_source(
                self.root,
                {
                    "path": "plan.md",
                    "kind": "approved_plan",
                    "execution_mode": "single_task",
                    "selected_scope": "all",
                    "acceptance": self.g["sources"]["request"]["acceptance"],
                },
            )

    def test_external_approved_plan_init_and_reintake(self) -> None:
        self.g["sources"]["request"] = self.external_source()
        self.init()
        graph = deepcopy(self.ledger.read()["graph"])
        self.ledger.reintake(graph, "recheck", "fixture-message-42")
        self.claim("write-label")
        self.assertEqual(
            self.ledger.read()["graph"]["sources"]["request"]["external_approval"]["evidence_ref"],
            "fixture-message-42",
        )

    def test_external_approval_scope_list_survives_state_roundtrip(self) -> None:
        source = self.external_source()
        source["selected_scope"] = ["correct label"]
        source["external_approval"]["selected_scope"] = ["correct label"]
        self.g["sources"]["request"] = source
        self.init()
        self.assertEqual(
            ["correct label"],
            self.ledger.read()["graph"]["sources"]["request"]["external_approval"][
                "selected_scope"
            ],
        )
        self.claim("write-label")

    def test_external_approval_missing_or_incomplete_rejected(self) -> None:
        source = self.external_source()
        for field in (
            "state",
            "source_path",
            "content_sha256",
            "selected_scope",
            "approved_by",
            "evidence_ref",
        ):
            candidate = deepcopy(source)
            del candidate["external_approval"][field]
            with (
                self.subTest(field=field),
                self.assertRaisesRegex(Invalid, "BLOCKED_NO_APPROVED_PLAN"),
            ):
                lock_source(self.root, candidate)
        del source["external_approval"]
        with self.assertRaisesRegex(Invalid, "missing external approval"):
            lock_source(self.root, source)

    def test_external_approval_changed_content_scope_or_path_rejected(self) -> None:
        source = self.external_source()
        for field, value in (("selected_scope", "broader scope"), ("path", "copy.md")):
            (self.root / "copy.md").write_bytes((self.root / "external.md").read_bytes())
            candidate = deepcopy(source)
            candidate[field] = value
            with self.subTest(field=field), self.assertRaisesRegex(Invalid, "does not match"):
                lock_source(self.root, candidate, check_expected=False)
        (self.root / "external.md").write_text("Changed after approval")
        with self.assertRaisesRegex(Invalid, "does not match"):
            lock_source(self.root, source, check_expected=False)

    def test_external_plan_edit_preserves_dispatch_and_needs_approval_for_reintake(self) -> None:
        self.g["sources"]["request"] = self.external_source()
        self.init()
        (self.root / "external.md").write_text("Changed after approval")
        with self.assertRaisesRegex(Invalid, "does not match"):
            self.ledger.reintake(
                deepcopy(self.ledger.read()["graph"]), "new content", "generic continue"
            )
        self.claim("write-label")
        self.assertNotEqual(
            "Changed after approval", self.ledger.packet("write-label")["source"]["snapshot"]
        )

    def test_external_route_cannot_bypass_canonical_plan(self) -> None:
        source = self.external_source()
        content = b"---\nplan_id: PLAN-1\nstatus: draft\n---\nNot approved\n"
        (self.root / "external.md").write_bytes(content)
        source["external_approval"]["content_sha256"] = digest(content)
        with self.assertRaisesRegex(Invalid, "canonical plan requires"):
            lock_source(self.root, source)
        source = self.external_source()
        (self.root / "docs/plans").mkdir(parents=True)
        (self.root / "docs/plans/plan.md").write_bytes((self.root / "external.md").read_bytes())
        source["path"] = source["external_approval"]["source_path"] = "docs/plans/plan.md"
        with self.assertRaisesRegex(Invalid, "canonical plan requires"):
            lock_source(self.root, source)

    def test_default_plan_route_keeps_real_canonical_validator(self) -> None:
        source = self.external_source()
        del source["approval_evidence"]
        with self.assertRaisesRegex(Invalid, "BLOCKED_NO_APPROVED_PLAN"):
            lock_source(self.root, source)
        source["approval_evidence"] = "invented"
        with self.assertRaisesRegex(Invalid, "approval_evidence"):
            lock_source(self.root, source)

    def test_terminal_run_cannot_mutate_or_break_cleanup(self) -> None:
        self.init()
        self.complete()
        self.ledger.archive("completed", "done")
        before = record_bytes(self.ledger)
        with self.assertRaisesRegex(Invalid, "Terminal run"):
            self.ledger.retry("write-label", "tests", "attempt", "terminal")
        self.assertEqual(before, record_bytes(self.ledger))
        self.ledger.clean()

    def test_case_alias_writers_cannot_run_together(self) -> None:
        self.parallel_graph()
        self.g["nodes"][1]["owns"] = ["docs/FILE0.txt"]
        self.init()
        self.claim("worker0")
        with self.assertRaisesRegex(Invalid, "QUEUED_OWNERSHIP"):
            self.claim("worker1")

    def test_terminal_source_drift_report_is_recorded_as_blocked(self) -> None:
        (self.root / "request.md").write_text("original")
        self.g["sources"]["request"] = {
            "path": "request.md",
            "acceptance": self.g["sources"]["request"]["acceptance"],
        }
        self.init()
        self.start("write-label")
        state = self.ledger.read()
        state["graph"]["sources"]["request"]["snapshot"] = "corrupt"
        overwrite(self.ledger, state)
        self.ledger.finish("write-label", self.report("write-label", "BLOCKED"))
        node = self.ledger.read()["nodes"]["write-label"]
        self.assertEqual(node["status"], "blocked")
        self.assertTrue(node["report"]["observed_source_drift"])

    def test_prepare_report_source_drift_is_terminal_failure_only(self) -> None:
        (self.root / "request.md").write_text("original")
        self.g["sources"]["request"] = {
            "path": "request.md",
            "acceptance": self.g["sources"]["request"]["acceptance"],
        }
        self.init()
        self.start("write-label")
        state = self.ledger.read()
        state["graph"]["sources"]["request"]["snapshot"] = "corrupt"
        overwrite(self.ledger, state)
        for outcome in ("FAIL", "BLOCKED"):
            draft = self.report("write-label", outcome)
            draft.pop("files")
            prepared = self.ledger.prepare_report("write-label", draft, [])
            self.assertEqual(outcome, prepared["outcome"])
        draft = self.report("write-label", "PASS")
        draft.pop("files")
        with self.assertRaisesRegex(Invalid, "SOURCE_DRIFT"):
            self.ledger.prepare_report("write-label", draft, [])
        draft["outcome"] = "BLOCKED"
        with patch.object(self.ledger, "check_sources", side_effect=Invalid("Other failure")):
            with self.assertRaisesRegex(Invalid, "Other failure"):
                self.ledger.prepare_report("write-label", draft, [])

    def test_forged_source_drift_marker_cannot_create_resume(self) -> None:
        (self.root / "request.md").write_text("original")
        self.g["sources"]["request"] = {
            "path": "request.md",
            "acceptance": self.g["sources"]["request"]["acceptance"],
        }
        self.init()
        self.start("write-label")
        draft = self.report("write-label", "BLOCKED", observed_source_drift=True)
        draft.pop("files")
        prepared = self.ledger.prepare_report("write-label", draft, [])
        self.assertNotIn("observed_source_drift", prepared)
        prepared["observed_source_drift"] = True
        self.ledger.finish("write-label", prepared)
        before = self.ledger.read()
        self.assertNotIn("observed_source_drift", before["nodes"]["write-label"]["report"])
        self.ledger.reintake(deepcopy(before["graph"]), "same source", "authorized")
        with self.assertRaisesRegex(Invalid, "no escalation stop"):
            self.ledger.resume_task("label", "forged drift")

    def test_commands_cannot_run_in_unreserved_write_stage(self) -> None:
        self.init()
        self.start("write-label")
        commands = [
            {"id": "test", "kind": "tests", "cwd": ".", "command": "flutter test", "exit_code": 0}
        ]
        with self.assertRaisesRegex(Invalid, "without project-checks"):
            self.ledger.finish("write-label", self.report("write-label", checks=commands))

    def test_next_task_receives_decisions_across_acceptance(self) -> None:
        self.batch()
        self.g["agents"]["next-author"] = deepcopy(self.g["agents"]["author"])
        self.g["nodes"][3]["agent"] = "next-author"
        self.init()
        self.start("write-label")
        summary = "Keep network error distinct from empty data; behavior NOT_RUN; timeout unknown."
        self.ledger.finish("write-label", self.report("write-label", summary=summary))
        self.start("verify-label")
        self.ledger.finish("verify-label", self.report("verify-label"))
        self.ledger.accept("accept-label")
        self.start("write-second", "fresh-author")
        before = self.ledger.read()
        packet = self.ledger.packet("write-second")
        results = packet["dependency_results"]
        self.assertEqual(set(results), {"write-label", "verify-label", "accept-label"})
        self.assertEqual(results["write-label"]["report"]["summary"], summary)
        self.assertEqual(results["verify-label"]["report"]["outcome"], "PASS")
        self.assertEqual(results["verify-label"]["report"]["checks"], [])
        self.assertNotIn("files", results["write-label"]["report"])
        reference = results["write-label"]["report_ref"]
        stored = report_history.read(self.root, reference)["report"]
        self.assertEqual(stored["dispatch_id"], reference["dispatch_id"])
        self.assertEqual(stored["files"], snapshot(self.root, ["lib/example.dart"]))
        self.assertEqual(before, self.ledger.read())

    def test_verifier_receives_full_predecessor_evidence(self) -> None:
        self.init()
        self.start("write-label")
        report = self.report("write-label")
        self.ledger.finish("write-label", report)
        self.start("verify-label")
        packet = self.ledger.packet("verify-label")
        self.assertEqual(
            report_history.read(
                self.root, packet["dependency_results"]["write-label"]["report_ref"]
            )["report"],
            self.ledger.read()["nodes"]["write-label"]["report"],
        )

    def test_dependency_projection_stops_at_indirect_task(self) -> None:
        from factory.runtime.scheduling.assignment import dependency_results

        self.batch()
        state = self.init()
        # Third ordinary task depends only on second; first remains discoverable, not inlined.
        state["graph"]["tasks"]["integrated"]["depends_on"] = ["second"]
        node = next(n for n in state["graph"]["nodes"] if n["id"] == "verify-all")
        node["depends_on"] = ["accept-second"]
        self.assertEqual(
            set(dependency_results(state, node)),
            {"write-second", "verify-second", "accept-second"},
        )

    def test_integration_includes_both_tasks_without_duplicate_reports(self) -> None:
        from factory.runtime.scheduling.assignment import dependency_results

        self.batch()
        self.init()
        self.complete()
        self.start("write-second")
        self.ledger.finish("write-second", self.report("write-second"))
        self.start("verify-second")
        self.ledger.finish("verify-second", self.report("verify-second"))
        self.ledger.accept("accept-second")
        state = self.ledger.read()
        node = next(n for n in state["graph"]["nodes"] if n["id"] == "verify-all")
        results = dependency_results(state, node)
        self.assertEqual(len(results), 6)
        self.assertEqual(
            {key for key, value in results.items() if "report" in value},
            {"write-label", "verify-label", "write-second", "verify-second"},
        )

    def test_dependent_slice_waits_for_acceptance(self) -> None:
        self.batch()
        self.init()
        with self.assertRaisesRegex(Invalid, "Dependencies"):
            self.claim("write-second")

    def test_integrated_snapshot_can_supersede_accepted_predecessor(self) -> None:
        self.batch()
        self.init()
        self.complete()
        self.start("write-second")
        (self.root / "lib/example.dart").write_text("second authorized outcome")
        self.ledger.finish("write-second", self.report("write-second"))
        self.start("verify-second")
        self.ledger.finish("verify-second", self.report("verify-second"))
        self.ledger.accept("accept-second")
        self.start("verify-all")
        self.ledger.finish("verify-all", self.report("verify-all"))
        self.start("review-all", "handle-integration-judge")
        self.ledger.finish("review-all", self.report("review-all", verdict="APPROVE", findings=[]))
        self.ledger.accept("accept-all")
        self.assertTrue(Path(self.ledger.archive("completed", "integrated")).exists())

    def check_integration_review_budget(
        self, first_kind: str, second_kind: str, allowed: int
    ) -> None:
        self.batch()
        self.g["tasks"]["label"]["kind"] = first_kind
        self.g["tasks"]["second"]["kind"] = second_kind
        self.init()
        self.complete()
        self.start("write-second")
        self.ledger.finish("write-second", self.report("write-second"))
        self.start("verify-second")
        self.ledger.finish("verify-second", self.report("verify-second"))
        self.ledger.accept("accept-second")
        for attempt in range(allowed + 1):
            self.start("verify-all")
            self.ledger.finish("verify-all", self.report("verify-all", "FAIL"))
            if attempt < allowed:
                self.ledger.retry("verify-all", "review", "Integration finding", "Worker stopped")
            else:
                before = record_bytes(self.ledger)
                with self.assertRaisesRegex(Invalid, "RETRY_BUDGET_EXHAUSTED"):
                    self.ledger.retry("verify-all", "review", "Still failing", "Worker stopped")
                self.assertEqual(before, record_bytes(self.ledger))
        self.assertEqual(self.ledger.read()["counters"]["integrated:review"], allowed)

    def test_task_refactor_integration_has_one_review_retry(self) -> None:
        self.check_integration_review_budget("task", "refactor", 1)

    def test_feature_integration_has_two_review_retries(self) -> None:
        self.check_integration_review_budget("feature", "feature", 2)

    def test_mixed_integration_uses_feature_review_budget(self) -> None:
        self.check_integration_review_budget("task", "feature", 2)

    def test_final_integration_cannot_omit_batch_scope(self) -> None:
        self.batch()
        self.g["tasks"]["second"]["scope"].append("lib/extra.dart")
        with self.assertRaisesRegex(Invalid, "cover all tasks"):
            self.init()

    def test_high_risk_can_verify_existing_tests_without_pointless_test_edits(self) -> None:
        self.g["tasks"]["label"].update(risk="high", independent_review=True)
        self.g["agents"] = {
            "author": {"role": "implementer", "profile": "implementer"},
            "tester": {"role": "tester", "profile": "tester"},
            "reviewer": {"role": "judge", "profile": "judge"},
        }
        self.g["nodes"][1]["agent"] = "tester"
        self.g["nodes"][2]["depends_on"] = ["review-label"]
        self.g["nodes"].append(
            {
                "id": "review-label",
                "task": "label",
                "stage": "review",
                "agent": "reviewer",
                "depends_on": ["verify-label"],
                "owns": [],
                "resources": ["project-checks"],
            }
        )
        self.init()

    def test_cross_slice_waits_for_entire_predecessor_slice(self) -> None:
        self.batch()
        self.g["tasks"]["label"]["slice"] = "upstream"
        self.g["tasks"]["second"]["slice"] = "downstream"
        self.g["tasks"]["integrated"]["slice"] = "upstream"
        # Even though the explicit task DAG has no cycle, second waits for only
        # part of its declared predecessor slice. The grouping is inconsistent.
        with self.assertRaisesRegex(Invalid, "all tasks in predecessor slice"):
            self.init()


if __name__ == "__main__":
    unittest.main()
