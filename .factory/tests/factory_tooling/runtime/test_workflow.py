from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from collections.abc import Callable
from copy import deepcopy
from pathlib import Path
from typing import Any
from unittest.mock import patch

from factory_tooling.adapters.acpx_adapter import (
    build_command,
    install_connection,
    prepare_prompt,
    run_operation,
)
from factory_tooling.runtime.contracts import State, agent_key
from factory_tooling.runtime.memory import read_task, resolve_evidence
from factory_tooling.runtime.workflow import Ledger
from factory_tooling.runtime.workflow_config import load_config
from factory_tooling.runtime.workflow_core import Invalid, digest, read_json, snapshot
from factory_tooling.runtime.workflow_graph import diagram, validate_graph
from factory_tooling.runtime.workflow_sources import lock_source
from tests.fixture_bundle import ROOT as ROOT

_TOOLS = Path(__file__).resolve().parents[3] / "tools"


class WorkflowTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="factory-workflow-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "lib").mkdir()
        (self.root / "lib/example.dart").write_text("before")
        (self.root / "AGENTS.md").write_text("Fixture workspace. No real external calls.")
        self.config = load_config(ROOT / "factory.yaml")
        from factory_tooling.project.profile_io import load_profile

        self.fixture_policy = "id: unit-fixture\n"
        self.fixture_profile = self.root / "fixture-project.yaml"
        self.fixture_profile.write_text(self.fixture_policy)
        self.config["_project"] = load_profile(self.fixture_profile)
        self.config["_files"].update(self.config["_project"]["files"])
        self.g = read_json(ROOT / "tools/example.workflow.json")
        self.g["tasks"]["label"].pop("policy_decisions", None)
        for node in self.g["nodes"]:
            if node["stage"] == "work":
                node["resources"] = []
        self.g["tasks"]["label"]["required_checks"] = [
            c for c in self.g["tasks"]["label"]["required_checks"] if c["category"] == "acceptance"
        ]
        self.g["tasks"]["label"]["required_checks"][0]["execution"] = {
            "argv": [sys.executable, "-c", "print('fixture check')"],
            "cwd": ".",
            "timeout_seconds": 10,
        }
        self.ledger = Ledger(self.root)

    def init(self) -> State:
        return self.ledger.init(self.g, self.config)

    def report(self, node: str, outcome: str = "PASS", **extra: Any) -> dict[str, Any]:
        s = self.ledger.read()
        n = next(n for n in s["graph"]["nodes"] if n["id"] == node)
        task = s["graph"]["tasks"][n["task"]]
        return {
            "run_id": s["run_id"],
            "dispatch_id": s["nodes"][node]["dispatch_id"],
            "node_id": node,
            "task_id": n["task"],
            "slice_id": task["slice"],
            "source_hash": s["graph"]["sources"][task["source"]]["hash"],
            "terminal": True,
            "outcome": outcome,
            "summary": "Fixture result",
            "files": snapshot(self.root, task["scope"]),
            "stage_result": "WRITES_READY" if n.get("owns") else "VERIFIED",
            "checks": (
                (
                    [self.ledger.run_check(node, task["required_checks"][0]["id"])]
                    if task["required_checks"][0]["kind"] != "observation"
                    else [
                        {
                            **task["required_checks"][0],
                            "result": "PASS",
                            "evidence": "fixture observation",
                        }
                    ]
                )
                if "project-checks" in n.get("resources", [])
                else []
            ),
            "not_applicable": {"static": "Fixture has no Dart tools", "docs": "Fixture only"},
            **extra,
        }

    def start(self, node: str, handle: str = "handle-author") -> None:
        self.ledger.claim(node)
        state = self.ledger.read()
        n = next(n for n in state["graph"]["nodes"] if n["id"] == node)
        profile = state["config"]["profiles"][state["graph"]["agents"][agent_key(n)]["profile"]]
        self.ledger.bind(
            node,
            handle,
            state["config"]["models"][profile["model"]]["id"]
            or "fixture-default"
            or "fixture-default",
        )

    def complete(self) -> None:
        self.start("write-label")
        self.ledger.finish("write-label", self.report("write-label"))
        self.start("verify-label")
        self.ledger.finish("verify-label", self.report("verify-label"))
        self.ledger.accept("accept-label")

    def config_file(self, mutate: Callable[[dict[str, Any]], object]) -> Path:
        import yaml

        raw = yaml.safe_load((ROOT / "factory.yaml").read_text())
        mutate(raw)
        # Use absolute existing canonical file paths via a fixture bundle copy.
        import shutil

        dest = self.root / "bundle"
        shutil.copytree(
            ROOT,
            dest,
            ignore=shutil.ignore_patterns("__pycache__", ".venv", ".mypy_cache", ".ruff_cache"),
            symlinks=True,
        )
        raw["project"] = "project/fixture.yaml"
        (dest / "project/fixture.yaml").write_text(self.fixture_policy)
        (dest / "factory.yaml").write_text(yaml.safe_dump(raw))
        return dest / "factory.yaml"

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

    def test_pinned_entry_rejects_changed_instructions_before_init(self) -> None:
        path = self.config_file(lambda c: None)
        graph = self.root / "graph.json"
        graph.write_text(json.dumps(self.g))
        snapshot = self.root / "config.json"
        command = [
            sys.executable,
            str(_TOOLS / "workflow.py"),
            "--workspace",
            str(self.root),
            "--config",
            str(path),
        ]
        result = subprocess.run(command + ["config"], capture_output=True, text=True, check=True)
        snapshot.write_text(result.stdout)
        init = command + ["init", str(graph), "--config-pin", str(snapshot)]
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
                command + ["read-instructions", str(snapshot), relative],
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(0, read.returncode)
            self.assertNotIn("changed\n", read.stdout)
            rejected = subprocess.run(init, capture_output=True, text=True)
            self.assertNotEqual(0, rejected.returncode, relative)
            self.assertIn("changed since snapshot", rejected.stderr)
            self.assertFalse(self.ledger.path.exists())
            file.write_text(original)
        result = subprocess.run(
            command + ["read-instructions", str(snapshot), "roles/orchestrator.md"],
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
        self.assertFalse(self.ledger.path.exists())
        self.assertNotIn("hash", self.g["sources"]["request"])

    def test_missing_execution_source_contract_rejects_config(self) -> None:
        path = self.config_file(lambda c: None)
        (path.parent / "skills/factory-implement/references/execution-source-contract.md").unlink()
        with self.assertRaisesRegex(Invalid, "Missing factory dependency"):
            load_config(path)

    def test_configuration_hashes_each_package_module_once_and_requires_known_modules(self) -> None:
        config = self.config_file(lambda c: None)
        module = config.parent / "factory_tooling/runtime/workflow.py"
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
        self.assertEqual(self.config["profiles"]["middle-test-writer-zcode"]["connection"], "zcode")
        adapter = str(ROOT / "adapters/acpx.md")
        self.assertIn(adapter, self.config["_files"])
        p = self.config_file(
            lambda c: c["profiles"]["developer"]["variants"]["middle-developer"].update(
                adapter="missing"
            )
        )
        with self.assertRaisesRegex(Invalid, "known adapter"):
            load_config(p)

    def test_acp_runtime_code_is_frozen_before_dispatch(self) -> None:
        path = self.config_file(lambda c: None)
        self.config = load_config(path)
        self.init()
        adapter = path.parent / "tools/acpx_adapter.py"
        self.assertIn(str(adapter.resolve()), self.config["_files"])
        adapter.write_text(adapter.read_text() + "\n# Changed transport implementation\n")
        before = self.ledger.read()
        with self.assertRaisesRegex(Invalid, "drift"):
            self.ledger.claim("write-label")
        self.assertEqual(before, self.ledger.read())

    def test_graph_uses_explicit_workspace_independent_of_cwd(self) -> None:
        foreign = self.root / "foreign"
        foreign.mkdir()
        (foreign / "lib").symlink_to(self.root / "lib", target_is_directory=True)
        (self.root / "checks").mkdir()
        (foreign / "checks").symlink_to(self.root / "checks", target_is_directory=True)
        self.g["tasks"]["label"]["required_checks"][0]["execution"]["cwd"] = "checks"
        with patch("factory_tooling.runtime.workflow.Path.cwd", return_value=foreign):
            validate_graph(self.g, self.config, self.root)
            self.init()
            self.ledger.claim("write-label")
        self.assertEqual("reserved", self.ledger.read()["nodes"]["write-label"]["status"])

    def test_workspace_symlink_and_hardlink_are_rejected_from_other_cwd(self) -> None:
        foreign = self.root / "foreign"
        foreign.mkdir()
        (self.root / "alias").symlink_to(self.root / "lib", target_is_directory=True)
        graph = deepcopy(self.g)
        graph["tasks"]["label"]["scope"] = ["alias/example.dart"]
        with patch("factory_tooling.runtime.workflow.Path.cwd", return_value=foreign):
            with self.assertRaisesRegex(Invalid, "Symlink"):
                validate_graph(graph, self.config, self.root)
        import os

        os.link(self.root / "lib/example.dart", self.root / "lib/linked.dart")
        with self.assertRaisesRegex(Invalid, "Hardlinked"):
            validate_graph(self.g, self.config, self.root)

    def test_duplicate_profile_transport_is_rejected(self) -> None:
        p = self.config_file(
            lambda c: c["profiles"]["developer"]["variants"]["middle-developer"].update(
                runner="native"
            )
        )
        with self.assertRaisesRegex(Invalid, "Unknown profile variant fields"):
            load_config(p)

    def test_malformed_capabilities_rejected(self) -> None:
        p = self.config_file(
            lambda c: c["profiles"]["developer"]["capabilities"].update(edit="false")
        )
        with self.assertRaisesRegex(Invalid, "boolean capabilities"):
            load_config(p)

    def test_strict_enforcement_blocks_before_dispatch(self) -> None:
        self.config["profiles"]["generalist"]["enforcement"] = "required"
        self.init()
        with self.assertRaisesRegex(Invalid, "BLOCKED_CAPABILITIES"):
            self.ledger.claim("write-label")
        self.assertEqual(self.ledger.read()["nodes"]["write-label"]["status"], "pending")

    def test_readonly_profile_cannot_claim_writer(self) -> None:
        self.config["profiles"]["generalist"]["capabilities"]["edit"] = False
        self.init()
        with self.assertRaisesRegex(Invalid, "forbids edits"):
            self.ledger.claim("write-label")

    def test_task_reviewer_repair_profile_cannot_write_product_scope(self) -> None:
        import yaml

        example = yaml.safe_load((ROOT / "factory.example.yaml").read_text())
        self.assertTrue(self.config["profiles"]["task-reviewer"]["capabilities"]["edit"])
        self.assertTrue(example["profiles"]["task-reviewer"]["capabilities"]["edit"])
        self.g["agents"]["author"] = {"role": "task-reviewer", "profile": "task-reviewer"}
        with self.assertRaisesRegex(Invalid, "Role cannot write product scope"):
            self.init()

    def test_packet_accepts_task_without_optional_dependencies(self) -> None:
        self.g["tasks"]["label"].pop("depends_on", None)
        self.init()
        self.ledger.claim("write-label")
        self.assertEqual({}, self.ledger.packet("write-label")["dependency_results"])

    def test_native_packet_includes_adapter_and_capabilities(self) -> None:
        self.init()
        self.ledger.claim("write-label")
        packet = self.ledger.packet("write-label")
        self.assertEqual(packet["profile"]["adapter"], "codex")
        self.assertEqual(packet["model"]["id"], "gpt-6.1-sol")
        self.assertTrue(any("Codex worker adapter" in f["content"] for f in packet["instructions"]))
        self.assertTrue(any("Generalist Contract" in f["content"] for f in packet["instructions"]))
        self.assertTrue(any("Fixture workspace" in f["content"] for f in packet["instructions"]))
        self.assertFalse(any(f["content"].startswith("# Router") for f in packet["instructions"]))

    def test_acp_packet_includes_adapter_and_policy(self) -> None:
        self.fake_acp()
        self.init()
        self.ledger.claim("write-label")
        result = prepare_prompt(self.ledger, "write-label")
        content = Path(result["prompt"]).read_text()
        self.assertIn("ACP worker adapter", content)
        self.assertNotIn("# Router", content)
        self.assertIn('"capabilities"', content)
        self.assertIn('"enforcement": "instructions"', content)

    def test_missing_router_is_rejected(self) -> None:
        for mutate in (lambda c: c.pop("router"), lambda c: c.update(router="missing.md")):
            with self.subTest(mutate=mutate):
                # config_file creates one copied bundle per test fixture.
                import shutil

                shutil.rmtree(self.root / "bundle", ignore_errors=True)
                path = self.config_file(mutate)
                with self.assertRaisesRegex(Invalid, "Missing router policy"):
                    load_config(path)

    def test_configured_router_reaches_dispatch_and_drift_blocks_it(self) -> None:
        path = self.config_file(lambda c: c.update(router="workflow/alternate-router.md"))
        policy = path.parent / "workflow/alternate-router.md"
        policy.write_text("Distinct router policy")
        self.config = load_config(path)
        self.init()
        self.ledger.claim("write-label")
        packet = self.ledger.packet("write-label")
        self.assertFalse(
            any(f["content"] == "Distinct router policy" for f in packet["instructions"])
        )
        policy.write_text("Changed router policy")
        with self.assertRaisesRegex(Invalid, "drift"):
            self.ledger.packet("write-label")

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
        other["agents"]["author"] = {"role": "developer", "profile": "middle-developer"}
        with self.assertRaisesRegex(Invalid, "one Generalist"):
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
            self.ledger.claim("verify-label")

    def test_source_drift_stops_writer(self) -> None:
        (self.root / "request.md").write_text("source")
        self.g["sources"]["request"] = {
            "path": "request.md",
            "acceptance": self.g["sources"]["request"]["acceptance"],
        }
        self.init()
        (self.root / "request.md").write_text("different source")
        with self.assertRaisesRegex(Invalid, "SOURCE_DRIFT"):
            self.ledger.claim("write-label")

    def test_unverified_model_cannot_bind(self) -> None:
        self.init()
        self.ledger.claim("write-label")
        with self.assertRaisesRegex(Invalid, "model differs"):
            self.ledger.bind("write-label", "h", "invented-model")

    def test_no_blind_redispatch(self) -> None:
        self.init()
        self.ledger.claim("write-label")
        self.ledger.unknown("write-label", "lost response")
        with self.assertRaisesRegex(Invalid, "Already dispatched"):
            self.ledger.claim("write-label")
        with self.assertRaisesRegex(Invalid, "Outstanding"):
            self.ledger.archive("cancelled", "cancel")

    def test_reconciled_result_does_not_repeat_side_effect(self) -> None:
        self.init()
        self.start("write-label")
        self.ledger.unknown("write-label", "lost response")
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
        with self.assertRaisesRegex(Invalid, "verification commands"):
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

    def test_history_survives_cleanup_and_unknown_file_is_preserved(self) -> None:
        self.init()
        self.complete()
        unknown = self.ledger.dir / "someone-elses-file.md"
        unknown.write_text("keep")
        history = Path(self.ledger.archive("completed", "done"))
        self.ledger.clean()
        self.assertTrue(history.exists())
        self.assertTrue(unknown.exists())
        self.assertFalse(self.ledger.path.exists())

    def test_memory_reads_task_from_the_requested_run_after_cleanup(self) -> None:
        archived_id = self.init()["run_id"]
        self.complete()
        saved_steps = self.ledger.read()["nodes"]
        archive = Path(self.ledger.archive("completed", "done"))
        self.ledger.clean()
        archive_bytes = archive.read_bytes()
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
        state["review_findings"] = {
            "label": {"F-1": {"status": "open"}, "F-2": {"status": "fixed"}}
        }
        self.ledger.save(state, "fixture_findings")
        active_bytes = self.ledger.path.read_bytes()

        active = read_task(self.root, "label", run_id=None)
        archived = read_task(self.root, "label", run_id=archived_id)
        self.assertEqual(active["run_id"], active_id)
        self.assertEqual(active["steps"]["write-label"]["report"]["summary"], "New run")
        self.assertEqual(active["open_findings"], {"F-1": {"status": "open"}})
        self.assertEqual(archived["run_id"], archived_id)
        self.assertEqual(archived["run_status"], "completed")
        self.assertEqual(archived, before_next_run)
        self.assertEqual(archived["open_findings"], {})
        self.assertEqual(self.ledger.path.read_bytes(), active_bytes)
        self.assertEqual(archive.read_bytes(), archive_bytes)

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

    def test_legacy_memory_evidence_resolution_is_safe(self) -> None:
        evidence = self.root / ".factory/memory/history/run-example/evidence.txt"
        evidence.parent.mkdir(parents=True)
        evidence.write_text("saved evidence", encoding="utf-8")
        legacy = ".ai-pipeline/history/run-example/evidence.txt"
        self.assertEqual(resolve_evidence(self.root, legacy).read_text(), "saved evidence")
        with self.assertRaises(Invalid):
            resolve_evidence(self.root, ".ai-pipeline/../outside")
        with self.assertRaises(Invalid):
            resolve_evidence(self.root, ".ai-pipeline/history/missing")
        evidence.unlink()
        evidence.symlink_to(self.root / "lib/example.dart")
        with self.assertRaises(Invalid):
            resolve_evidence(self.root, legacy)

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
        self.ledger.path.write_text("{")
        with self.assertRaisesRegex(Invalid, "Cannot read run"):
            read_task(self.root, "label", run_id=None)

    def test_cleanup_requires_saved_history(self) -> None:
        self.init()
        self.complete()
        history = Path(self.ledger.archive("completed", "done"))
        history.unlink()
        with self.assertRaisesRegex(Invalid, "History"):
            self.ledger.clean()
        self.assertTrue(self.ledger.path.exists())

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

    def require_fixture_review(self) -> None:
        self.g["tasks"]["label"]["independent_review"] = True
        self.g["agents"]["fixture-judge"] = {"role": "judge", "profile": "judge"}
        self.g["nodes"].append(
            {
                "id": "review-label",
                "task": "label",
                "stage": "review",
                "agent": "fixture-judge",
                "depends_on": ["verify-label"],
                "owns": [],
                "resources": ["project-checks"],
            }
        )
        next(n for n in self.g["nodes"] if n["id"] == "accept-label")["depends_on"] = [
            "review-label"
        ]

    def test_reserved_test_writer_must_submit_actual_tests_receipt(self) -> None:
        self.g["agents"]["author"] = {"role": "test-writer", "profile": "middle-test-writer"}
        self.g["nodes"][0]["resources"] = ["project-checks"]
        static = deepcopy(self.g["tasks"]["label"]["required_checks"][0])
        static.update(id="lint", kind="static")
        self.g["tasks"]["label"]["required_checks"].append(static)
        self.require_fixture_review()
        self.init()
        self.start("write-label")
        state = self.ledger.read()
        task = state["graph"]["tasks"]["label"]
        report: dict[str, Any] = {
            "run_id": state["run_id"],
            "dispatch_id": state["nodes"]["write-label"]["dispatch_id"],
            "node_id": "write-label",
            "task_id": "label",
            "slice_id": task["slice"],
            "source_hash": state["graph"]["sources"][task["source"]]["hash"],
            "terminal": True,
            "outcome": "PASS",
            "summary": "Tests written",
            "files": snapshot(self.root, task["scope"]),
            "stage_result": "VERIFIED",
            "checks": [self.ledger.run_check("write-label", "lint")],
        }
        with self.assertRaisesRegex(Invalid, "successful tests receipt"):
            self.ledger.finish("write-label", report)
        report["checks"].append(self.ledger.run_check("write-label", "behavior"))
        report["stage_result"] = "WRITES_READY"
        with self.assertRaisesRegex(Invalid, "TestWriter checks required"):
            self.ledger.finish("write-label", report)
        report["stage_result"] = "VERIFIED"
        self.ledger.finish("write-label", report)
        self.assertEqual(self.ledger.read()["nodes"]["write-label"]["status"], "done")

    def test_unreserved_test_writer_can_defer_checks(self) -> None:
        self.g["agents"]["author"] = {"role": "test-writer", "profile": "middle-test-writer"}
        self.require_fixture_review()
        self.init()
        self.start("write-label")
        self.ledger.finish("write-label", self.report("write-label"))
        self.assertEqual(self.ledger.read()["nodes"]["write-label"]["status"], "done")

    def test_blocked_reserved_test_writer_can_report_without_tests(self) -> None:
        self.g["agents"]["author"] = {"role": "test-writer", "profile": "middle-test-writer"}
        self.g["nodes"][0]["resources"] = ["project-checks"]
        self.require_fixture_review()
        self.init()
        self.start("write-label")
        report = self.report("write-label", "BLOCKED", checks=[])
        self.ledger.finish("write-label", report)
        self.assertEqual(self.ledger.read()["nodes"]["write-label"]["status"], "blocked")

    def parallel_graph(self) -> None:
        works = []
        for i in range(8):
            acp = i >= 4
            aid = f"worker{i}"
            self.g["agents"][aid] = {
                "role": "test-writer" if acp else "generalist",
                "profile": "middle-test-writer-zcode" if acp else "generalist",
            }
            scope = f"lib/file{i}.txt"
            self.g["tasks"]["label"]["scope"].append(scope)
            works.append(
                {
                    "id": aid,
                    "task": "label",
                    "stage": "work",
                    "agent": aid,
                    "depends_on": [],
                    "owns": [scope],
                    "resources": [],
                }
            )
        self.g["nodes"] = works + self.g["nodes"][1:]
        self.g["nodes"][-2]["depends_on"] = [w["id"] for w in works]
        self.require_fixture_review()

    def test_native_and_acp_capacity_queues_fourth_independently(self) -> None:
        self.parallel_graph()
        self.init()
        for i in [0, 1, 2, 4, 5, 6]:
            self.ledger.claim(f"worker{i}")
        for i in [3, 7]:
            with self.assertRaisesRegex(Invalid, "QUEUED_CAPACITY"):
                self.ledger.claim(f"worker{i}")
        self.ledger.unknown("worker0", "lost response")
        with self.assertRaisesRegex(Invalid, "QUEUED_CAPACITY"):
            self.ledger.claim("worker3")

    def test_overlapping_writers_blocked(self) -> None:
        self.parallel_graph()
        self.g["nodes"][1]["owns"] = self.g["nodes"][0]["owns"]
        self.init()
        self.ledger.claim("worker0")
        with self.assertRaisesRegex(Invalid, "QUEUED_OWNERSHIP"):
            self.ledger.claim("worker1")

    def test_native_session_cannot_be_reassigned_to_other_agent(self) -> None:
        self.parallel_graph()
        self.init()
        self.start("worker0", "shared")
        self.ledger.claim("worker1")
        with self.assertRaisesRegex(Invalid, "different logical agent"):
            self.ledger.bind("worker1", "shared", "gpt-6.1-sol")

    def fake_acp(self, code: int = 0) -> Path:
        binary = Path(sys.executable)
        self.transport_exit_code = code
        self.config["acpx"]["command"] = str(binary)
        self.config["acpx"]["connections"]["zcode"]["command"] = str(binary)
        self.g["agents"]["author"] = {"role": "test-writer", "profile": "middle-test-writer-zcode"}
        self.require_fixture_review()
        return binary

    def transport(self, argv: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
        # Keep real child-process/output behavior without requiring a POSIX shell.
        self.assertEqual(str(Path(sys.executable).resolve()), argv[0])
        script = f"print('fixture transport only'); raise SystemExit({self.transport_exit_code})"
        return subprocess.run([sys.executable, "-c", script, *argv[1:]], text=True, **kwargs)

    def test_registry_merge_preserves_other_settings(self) -> None:
        self.fake_acp()
        (self.root / ".acpxrc.json").write_text(
            json.dumps({"ttl": 47, "agents": {"other": {"argv": ["other"]}}})
        )
        install_connection(self.config, self.root, "zcode")
        current = read_json(self.root / ".acpxrc.json")
        self.assertEqual(current["ttl"], 47)
        self.assertIn("other", current["agents"])
        current["agents"]["zcode"] = {"argv": ["different"]}
        (self.root / ".acpxrc.json").write_text(json.dumps(current))
        with self.assertRaisesRegex(Invalid, "alias differs"):
            install_connection(self.config, self.root, "zcode")

    def test_connection_cannot_silently_ignore_mcp_or_environment_settings(self) -> None:
        for field in ("env", "mcpServers", "mcp_config"):
            # Validate each fresh serialized fixture, without adapter-derived keys.
            def mutate(c: dict[str, Any], field: str = field) -> None:
                c["acpx"]["connections"]["zcode"][field] = {}

            path = self.config_file(mutate)
            with (
                self.subTest(field=field),
                self.assertRaisesRegex(Invalid, "Unsupported connection field"),
            ):
                load_config(path)
            import shutil

            shutil.rmtree(path.parent)

    def test_connection_args_must_not_be_a_shell_string(self) -> None:
        path = self.config_file(
            lambda c: c["acpx"]["connections"]["zcode"].update(args="server --option")
        )
        with self.assertRaisesRegex(Invalid, "argv list"):
            load_config(path)

    def test_acp_command_preserves_provider_qualified_model_id(self) -> None:
        self.fake_acp()
        state = self.init()
        command = build_command(state, "write-label", "create")
        self.assertEqual(command[command.index("--model") + 1], r"builtin:zai-coding-plan\GLM-5.3")

    def test_prompt_contains_instruction_content_and_no_blanket_approval(self) -> None:
        self.fake_acp()
        self.init()
        self.ledger.claim("write-label")
        prepared = prepare_prompt(self.ledger, "write-label")
        self.assertIn("Test Writer Contract", Path(prepared["prompt"]).read_text())
        self.assertNotIn("--approve-all", prepared["prompt_argv"])
        self.assertIn("--non-interactive-permissions", prepared["prompt_argv"])

    def test_prompt_return_never_marks_node_passed(self) -> None:
        self.fake_acp()
        install_connection(self.config, self.root, "zcode")
        self.init()
        self.ledger.claim("write-label")
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

    def test_create_failure_is_unknown_and_cannot_be_recreated(self) -> None:
        self.fake_acp(code=2)
        install_connection(self.config, self.root, "zcode")
        self.init()
        self.ledger.claim("write-label")
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
        self.ledger.claim("verify-label")
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
        self.ledger.claim("write-label")
        old = run_operation(self.ledger, "write-label", "create", run=self.transport)["session"]
        self.ledger.resolve("write-label", "blocked", "fixture process exited, no backend session")
        self.ledger.replace_session(
            "author", "failed creation", "terminal verified", "no work done"
        )
        self.ledger.retry("write-label", "recovery", "creation failed", "terminal verified")
        self.ledger.claim("write-label")
        new = run_operation(self.ledger, "write-label", "create", run=self.transport)["session"]
        self.assertNotEqual(old, new)

    def test_stale_transport_completion_does_not_modify_new_attempt(self) -> None:
        self.fake_acp()
        install_connection(self.config, self.root, "zcode")
        self.init()
        self.ledger.claim("write-label")

        def old_call(*args: Any, **kwargs: Any) -> subprocess.CompletedProcess[str]:
            self.ledger.unknown("write-label", "transport outcome lost")
            self.ledger.retry("write-label", "recovery", "terminal confirmed", "fixture exited")
            self.ledger.claim("write-label")
            return subprocess.CompletedProcess([], 2)

        result = run_operation(self.ledger, "write-label", "create", run=old_call)
        self.assertTrue(result["stale"])
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
        from factory_tooling.context.context import factory_files

        for rel in factory_files(self.config) + [self.config["router"]]:
            destination = self.root / rel
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text((ROOT / rel).read_text())
        self.init()
        self.ledger.claim("write-label")
        result = prepare_prompt(self.ledger, "write-label")
        self.assertNotIn(
            "Distinct configured orchestration policy", Path(result["prompt"]).read_text()
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
                },
            )

    def external_source(self) -> dict[str, Any]:
        content = b"# External plan\nCorrect label; verify visible text.\n"
        (self.root / "external.md").write_bytes(content)
        return {
            "acceptance": self.g["sources"]["request"]["acceptance"],
            "path": "external.md",
            "kind": "approved_plan",
            "selected_scope": "correct label",
            "approval_evidence": "explicit_external_hash_approval",
            "external_approval": {
                "state": "approved",
                "source_path": "external.md",
                "content_sha256": digest(content),
                "selected_scope": "correct label",
                "approved_by": "user",
                "evidence_ref": "fixture-message-42",
            },
        }

    def test_external_approved_plan_init_and_reintake(self) -> None:
        self.g["sources"]["request"] = self.external_source()
        self.init()
        graph = deepcopy(self.ledger.read()["graph"])
        self.ledger.reintake(graph, "recheck", "fixture-message-42")
        self.ledger.claim("write-label")
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
        self.ledger.claim("write-label")

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

    def test_external_plan_drift_blocks_dispatch_and_reintake(self) -> None:
        self.g["sources"]["request"] = self.external_source()
        self.init()
        (self.root / "external.md").write_text("Changed after approval")
        with self.assertRaisesRegex(Invalid, "SOURCE_DRIFT"):
            self.ledger.claim("write-label")
        with self.assertRaisesRegex(Invalid, "does not match"):
            self.ledger.reintake(
                deepcopy(self.ledger.read()["graph"]), "new content", "generic continue"
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
        with self.assertRaisesRegex(Invalid, "unknown approval"):
            lock_source(self.root, source)

    def test_terminal_run_cannot_mutate_or_break_cleanup(self) -> None:
        self.init()
        self.complete()
        self.ledger.archive("completed", "done")
        before = self.ledger.path.read_bytes()
        with self.assertRaisesRegex(Invalid, "Terminal run"):
            self.ledger.retry("write-label", "tests", "attempt", "terminal")
        self.assertEqual(before, self.ledger.path.read_bytes())
        self.ledger.clean()

    def test_case_alias_writers_cannot_run_together(self) -> None:
        self.parallel_graph()
        self.g["nodes"][1]["owns"] = ["lib/FILE0.txt"]
        self.init()
        self.ledger.claim("worker0")
        with self.assertRaisesRegex(Invalid, "QUEUED_OWNERSHIP"):
            self.ledger.claim("worker1")

    def test_terminal_source_drift_report_is_recorded_as_blocked(self) -> None:
        (self.root / "request.md").write_text("original")
        self.g["sources"]["request"] = {
            "path": "request.md",
            "acceptance": self.g["sources"]["request"]["acceptance"],
        }
        self.init()
        self.start("write-label")
        (self.root / "request.md").write_text("changed")
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
        (self.root / "request.md").write_text("changed")
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
        commands = [{"kind": "tests", "cwd": ".", "command": "flutter test", "exit_code": 0}]
        with self.assertRaisesRegex(Invalid, "without project-checks"):
            self.ledger.finish("write-label", self.report("write-label", checks=commands))

    def batch(self) -> None:
        first = self.g["tasks"]["label"]
        self.g["tasks"]["second"] = {
            **deepcopy(first),
            "outcome": "Related next outcome",
            "depends_on": ["label"],
        }
        self.g["tasks"]["integrated"] = {
            **deepcopy(first),
            "outcome": "Both outcomes work together",
            "kind": "integration",
            "independent_review": True,
            "depends_on": ["label", "second"],
        }
        self.g["agents"]["integration-judge"] = {"role": "judge", "profile": "judge"}
        self.g["nodes"] += [
            {
                "id": "write-second",
                "task": "second",
                "stage": "work",
                "agent": "author",
                "depends_on": ["accept-label"],
                "owns": ["lib/example.dart"],
                "resources": [],
            },
            {
                "id": "verify-second",
                "task": "second",
                "stage": "verify",
                "agent": "author",
                "depends_on": ["write-second"],
                "owns": [],
                "resources": ["project-checks"],
            },
            {
                "id": "accept-second",
                "task": "second",
                "stage": "accept",
                "agent": None,
                "depends_on": ["verify-second"],
                "owns": [],
                "resources": [],
            },
            {
                "id": "verify-all",
                "task": "integrated",
                "stage": "verify",
                "agent": "integration-judge",
                "depends_on": ["accept-label", "accept-second"],
                "owns": [],
                "resources": ["project-checks"],
            },
            {
                "id": "accept-all",
                "task": "integrated",
                "stage": "accept",
                "agent": None,
                "depends_on": ["review-all"],
                "owns": [],
                "resources": [],
            },
        ]
        self.g["nodes"].append(
            {
                "id": "review-all",
                "task": "integrated",
                "stage": "review",
                "agent": "integration-judge",
                "depends_on": ["verify-all"],
                "owns": [],
                "resources": ["project-checks"],
            }
        )

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
        self.assertEqual(results["verify-label"]["report"]["checks"][0]["result"], "PASS")
        self.assertNotIn("files", results["write-label"]["report"])
        reference = results["write-label"]["report_ref"]
        stored = read_json(self.root / reference["path"])
        for key in reference["keys"]:
            stored = stored[key]
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
            packet["dependency_results"]["write-label"]["report"],
            self.ledger.read()["nodes"]["write-label"]["report"],
        )

    def test_dependency_projection_stops_at_indirect_task(self) -> None:
        from factory_tooling.runtime.assignment import dependency_results

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
        from factory_tooling.runtime.assignment import dependency_results

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
            self.ledger.claim("write-second")

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
        self.start("verify-all", "handle-integration-judge")
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
            self.start("verify-all", "handle-integration-judge")
            self.ledger.finish("verify-all", self.report("verify-all", "FAIL"))
            if attempt < allowed:
                self.ledger.retry("verify-all", "review", "Integration finding", "Worker stopped")
            else:
                before = self.ledger.path.read_bytes()
                with self.assertRaisesRegex(Invalid, "RETRY_BUDGET_EXHAUSTED"):
                    self.ledger.retry("verify-all", "review", "Still failing", "Worker stopped")
                self.assertEqual(before, self.ledger.path.read_bytes())
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
            "author": {"role": "developer", "profile": "middle-developer"},
            "tester": {"role": "test-writer", "profile": "middle-test-writer"},
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
