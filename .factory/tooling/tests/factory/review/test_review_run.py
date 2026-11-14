"""Behavioral regressions for standalone review planning and lifecycle."""

from __future__ import annotations

import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from collections.abc import Callable
from copy import deepcopy
from pathlib import Path
from typing import Any

from factory.paths import FACTORY_ROOT
from factory.project.profile_io import load_profile, snapshot
from factory.review.review_contracts import validate_manifest
from factory.review.review_plan import prepare, validate_plan
from tests.factory.review.fixture_protocol import ProtocolFixture, write_json

RUNNER = FACTORY_ROOT / "skills/factory-code-review/scripts/review_run.py"


class ReviewRunTests(unittest.TestCase):
    def fixture(self) -> ProtocolFixture:
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        return ProtocolFixture(Path(temp.name))

    def call(self, f: ProtocolFixture, *args: Any) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(RUNNER), *args], cwd=f.root, text=True, capture_output=True
        )

    def test_three_specializations_cover_intent_under_acceptance(self) -> None:
        f = self.fixture()
        names = {a["name"]: a["criteria"] for a in f.manifest["assignments"]}
        self.assertEqual(set(names), {"ArchitectureReviewer", "CodeReviewer", "AcceptanceReviewer"})
        self.assertIn("SYS-INTENT", names["AcceptanceReviewer"])
        self.assertNotIn("SYS-INTENT", names["ArchitectureReviewer"])
        f.manifest["assignments"][2]["criteria"].remove("SYS-INTENT")
        with self.assertRaisesRegex(ValueError, "assignments"):
            validate_plan(f.manifest)

    def test_run_assignment_is_accepted_by_context_entry_point(self) -> None:
        from factory.context.context import build
        from factory.project.profile_io import sha
        from factory.project.profile_rules import document_paths, select_rules
        from factory.runtime.workflow_config import load_config
        from tests.fixture_bundle import ROOT as fixture

        f = self.fixture()
        policy = load_profile(fixture / "project/project.yaml")
        paths = {"AGENTS.md"}
        for rule in select_rules(
            policy["data"], process="code-review", audience="worker", role="reviewer"
        ):
            if "file" not in rule:
                paths.update(document_paths(policy["data"], rule))
        content = "Accepted baseline documentation."
        f.manifest["project_policy"] = snapshot(
            policy,
            source="fixture baseline",
            documents={
                path: {"content": content, "sha256": sha(content.encode())} for path in paths
            },
        )
        f.rebind()
        request, run = f.root / "request.json", f.root / "run"
        write_json(request, f.manifest)
        created = self.call(f, "init", "--input", request, "--run", run)
        self.assertEqual(0, created.returncode, created.stderr)
        response = self.call(f, "assignment", "--id", "system-design", "--run", run)
        self.assertEqual(0, response.returncode, response.stderr)
        config = load_config(fixture / "factory.yaml")
        packet: dict[str, Any] = dict(
            build(
                config, f.root, "reviewer", "reviewer", "code-review", json.loads(response.stdout)
            )
        )
        self.assertEqual(f.manifest["target"], packet["source"]["target"])
        self.assertEqual("system-design", packet["lens"])

    def test_project_commands_and_criteria_extend_without_orchestrator_changes(self) -> None:
        f = self.fixture()
        profile = f.root / "project.yaml"
        profile.write_text("""id: fixture
rules: {}
gates:
- id: review-command
  at: [code-review.complete]
  checks:
  - id: custom-check
    level: slice
    kind: tests
    method: project check
    execution: {argv: [check], cwd: '.', timeout_seconds: 10, inputs: []}
- id: review-criteria
  at: [code-review.complete]
  criteria:
  - {id: CUSTOM, lens: runtime-safety, question: "Is the project invariant preserved?"}
""")
        f.manifest["project_policy"] = snapshot(load_profile(profile), source="fixture")
        m = prepare(f.manifest)
        self.assertIn("CUSTOM", m["assignments"][1]["criteria"])
        self.assertIn("custom-check", [c["id"] for c in m["checks"]])
        m["checks"] = [c for c in m["checks"] if c["id"] != "custom-check"]
        with self.assertRaisesRegex(ValueError, "mandatory commands"):
            validate_plan(m)

    def test_command_substitution_and_waiver_block(self) -> None:
        mutations_73: list[Callable[[Any], object]] = [
            lambda t: t["commands"][0].update(argv=["fake"]),
            lambda t: t.update(status="NOT_APPLICABLE", reason="skip", commands=[]),
        ]
        for mutate in mutations_73:
            f = self.fixture()
            mutate(f.tools[0])
            _, result, _ = f.execute()
            self.assertEqual("INCOMPLETE", result["pipeline_status"])

    def test_no_commands_valid_with_explanation(self) -> None:
        f = self.fixture()
        f.manifest["additional_checks"] = []
        f.tools = []
        f.rebind()
        _, result, _ = f.execute()
        self.assertEqual("COMPLETE", result["pipeline_status"], result["errors"])
        self.assertEqual({}, result["tool_statuses"])

    def test_unknown_requirements_do_not_erase_valid_findings(self) -> None:
        f = self.fixture()
        f.manifest["context"]["requirements"] = []
        f.manifest["context"]["limitations"] = ["Incident expected result unavailable"]
        f.rebind()
        f.add_finding(severity="high")
        f.qa["code_verdict"] = "NEEDS_WORK"
        _, result, _ = f.execute()
        self.assertEqual("INCOMPLETE", result["pipeline_status"])
        self.assertEqual(1, len(result["findings"]))
        self.assertIn("SYS-INTENT", " ".join(result["errors"]))

    def test_pr_body_is_required_but_may_be_empty(self) -> None:
        f = self.fixture()
        f.manifest["mode"] = "pr"
        f.manifest["context"]["pr"] = None
        with self.assertRaisesRegex(ValueError, "PR title/body"):
            prepare(f.manifest)

    def test_context_changes_invalidate_identity(self) -> None:
        f = self.fixture()
        f.manifest["context"]["sources"][0]["content"] = "Different task"
        self.assertIn("manifest: scope_hash mismatch", validate_manifest(f.manifest))

    def test_missing_requirement_has_no_fake_diff_location(self) -> None:
        f = self.fixture()
        content = (f.root / f.path).read_text()
        f.manifest["source_evidence"] = {
            f.path: {"content": content, "sha256": hashlib.sha256(content.encode()).hexdigest()}
        }
        f.rebind()
        finding = f.add_finding(lens="verification-quality", gate_id="SYS-INTENT", severity="high")
        finding.update(
            kind="missing-requirement",
            path=None,
            line=None,
            investigation="Inspected service and found no requested branch",
            evidence=[
                {"kind": "requirement", "requirement_id": "AC1"},
                {"kind": "inspection", "path": f.path, "line": 1},
            ],
        )
        f.qa["code_verdict"] = "NEEDS_WORK"
        _, result, report = f.execute()
        self.assertEqual("COMPLETE", result["pipeline_status"], result["errors"])
        self.assertIn("unimplemented requirement", report)
        finding["evidence"].pop()
        _, result, _ = f.execute()
        self.assertEqual("INCOMPLETE", result["pipeline_status"])

    def test_missing_requirement_accepts_omitted_location_with_source_evidence(self) -> None:
        f = self.fixture()
        finding = f.add_finding(lens="verification-quality", gate_id="SYS-INTENT", severity="high")
        finding.update(
            kind="missing-requirement",
            investigation="Inspected changed source and found no requested branch",
            evidence=[
                {"kind": "requirement", "requirement_id": "AC1"},
                {"kind": "source", "path": f.path, "line": 1, "side": "new"},
            ],
        )
        del finding["path"]
        del finding["line"]
        f.qa["code_verdict"] = "NEEDS_WORK"
        process, result, _ = f.execute()
        self.assertEqual(0, process.returncode, process.stderr)
        self.assertEqual("COMPLETE", result["pipeline_status"], result["errors"])
        self.assertNotIn("path", result["findings"][0])
        self.assertNotIn("line", result["findings"][0])

    def test_free_discovery_needs_no_registry_and_no_auto_merge(self) -> None:
        f = self.fixture()
        a = f.add_finding()
        a["gate_id"] = None
        b = deepcopy(a)
        b["finding_id"] = "RUN-2"
        f.lenses[1]["findings"].append(b)
        for gate in f.lenses[1]["gates"]:
            gate["status"] = "PASS"
        f.qa["code_verdict"] = "NEEDS_WORK"
        _, result, _ = f.execute()
        self.assertEqual("COMPLETE", result["pipeline_status"], result["errors"])
        self.assertEqual(2, len(result["findings"]))

    def test_lifecycle_runs_commands_preserves_results_and_rejects_drift(self) -> None:
        f = self.fixture()
        request = f.root / "request.json"
        write_json(request, f.manifest)
        run = f.root / "run"
        result = self.call(f, "init", "--input", str(request), "--run", str(run))
        self.assertEqual(0, result.returncode, result.stderr)
        for check in f.manifest["checks"]:
            result = self.call(f, "check", "--id", check["id"], "--run", str(run))
            self.assertEqual(0, result.returncode, result.stderr)
        for value in f.lenses:
            path = f.root / "out.json"
            path.write_text(json.dumps(value))
            result = self.call(
                f, "submit", "--id", value["lens"], "--input", str(path), "--run", str(run)
            )
            self.assertEqual(0, result.returncode, result.stderr)
        result = self.call(
            f, "submit", "--id", value["lens"], "--input", str(path), "--run", str(run)
        )
        self.assertNotEqual(0, result.returncode)
        qa = f.root / "qa.json"
        write_json(qa, f.qa)
        result = self.call(f, "finish", "--input", str(qa), "--run", str(run))
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual("COMPLETE", json.loads(result.stdout)["pipeline_status"])
        self.assertTrue((run / "final-1/report.md").is_file())
        (f.root / f.path).write_text("changed")
        result = self.call(f, "status", "--run", str(run))
        self.assertIn("drift", result.stderr)

    def test_recovery_limit_and_independent_run_directories(self) -> None:
        f = self.fixture()
        request = f.root / "request.json"
        write_json(request, f.manifest)
        for name in ["first", "second"]:
            result = self.call(f, "init", "--input", str(request), "--run", str(f.root / name))
            self.assertEqual(0, result.returncode, result.stderr)
        broken = f.root / "broken.json"
        write_json(broken, {"lens": "system-design", "done_signal": "FAILED"})
        for attempt in range(3):
            result = self.call(
                f,
                "submit",
                "--id",
                "system-design",
                "--input",
                str(broken),
                "--run",
                str(f.root / "first"),
            )
            self.assertEqual(result.returncode == 0, attempt < 2, result.stderr)
        self.assertEqual([], list((f.root / "second").glob("reviewer-*.json")))

    def test_prefix_related_check_ids_have_independent_lifecycle_and_budget(self) -> None:
        f = self.fixture()

        def check(
            identifier: str, argv: list[str], after: list[str] | None = None
        ) -> dict[str, Any]:
            return {
                "id": identifier,
                "method": "fixture command",
                "after": after or [],
                "execution": {"argv": argv, "cwd": ".", "timeout_seconds": 10},
            }

        f.manifest["additional_checks"] = [
            check("lint", [sys.executable, "-c", "pass"]),
            check("lint-1", [sys.executable, "-c", "pass"]),
            check("lint-extra", ["fixture-command-that-does-not-exist"]),
            check("dependent", [sys.executable, "-c", "pass"], ["lint"]),
        ]
        f.rebind()
        request, run = f.root / "request.json", f.root / "run"
        write_json(request, f.manifest)
        self.assertEqual(0, self.call(f, "init", "--input", request, "--run", run).returncode)
        for _ in range(2):
            result = self.call(f, "check", "--id", "lint-extra", "--run", run)
            self.assertEqual(0, result.returncode, result.stderr)
            self.assertEqual("BLOCKED", json.loads(result.stdout)["status"])
        exhausted = self.call(f, "check", "--id", "lint-extra", "--run", run)
        self.assertIn("recovery exhausted", exhausted.stderr)
        self.assertEqual(0, self.call(f, "check", "--id", "lint-1", "--run", run).returncode)
        status = json.loads(self.call(f, "status", "--run", run).stdout)
        self.assertEqual("PENDING", status["checks"]["lint"])
        self.assertEqual("PASS", status["checks"]["lint-1"])
        blocked = self.call(f, "check", "--id", "dependent", "--run", run)
        self.assertIn("dependency", blocked.stderr)
        self.assertEqual(0, self.call(f, "check", "--id", "lint", "--run", run).returncode)
        self.assertEqual(0, self.call(f, "check", "--id", "dependent", "--run", run).returncode)
        self.assertTrue((run / "check-lint-1.json").is_file())
        self.assertTrue((run / "check-lint-1-1.json").is_file())

    def test_command_dependency_and_mutating_command_cannot_complete(self) -> None:
        f = self.fixture()
        f.manifest["additional_checks"] = [
            {
                "id": "first",
                "method": "prepare evidence",
                "execution": {
                    "argv": [sys.executable, "-c", "pass"],
                    "cwd": ".",
                    "timeout_seconds": 10,
                },
            },
            {
                "id": "second",
                "method": "dependent evidence",
                "after": ["first"],
                "execution": {
                    "argv": [
                        sys.executable,
                        "-c",
                        "from pathlib import Path; Path('lib/sample.dart').write_text('mutated')",
                    ],
                    "cwd": ".",
                    "timeout_seconds": 10,
                },
            },
        ]
        f.rebind()
        request = f.root / "request.json"
        write_json(request, f.manifest)
        run = f.root / "run"
        self.assertEqual(
            0, self.call(f, "init", "--input", str(request), "--run", str(run)).returncode
        )
        result = self.call(f, "check", "--id", "second", "--run", str(run))
        self.assertIn("dependency", result.stderr)
        self.assertEqual(0, self.call(f, "check", "--id", "first", "--run", str(run)).returncode)
        result = self.call(f, "check", "--id", "second", "--run", str(run))
        self.assertIn("drift", result.stderr)
        self.assertTrue((run / "check-second-1.json").exists())

    def test_changed_core_definition_and_unknown_dependency_block(self) -> None:
        f = self.fixture()
        f.manifest["core_criteria"][0][2] = "Weakened question"
        with self.assertRaisesRegex(ValueError, "core criteria"):
            validate_plan(f.manifest)
        f.manifest["additional_checks"][0]["after"] = ["not-selected"]
        with self.assertRaisesRegex(ValueError, "dependency"):
            prepare(f.manifest)

    def test_malformed_command_result_preserves_other_findings(self) -> None:
        f = self.fixture()
        f.add_finding(severity="high")
        f.qa["code_verdict"] = "NEEDS_WORK"
        f.tools[0]["commands"] = [None]
        _, result, _ = f.execute()
        self.assertEqual("INCOMPLETE", result["pipeline_status"])
        self.assertEqual(1, len(result["findings"]))

    def test_retry_cannot_erase_valid_findings_from_incomplete_attempt(self) -> None:
        f = self.fixture()
        f.add_finding(severity="high")
        request = f.root / "request.json"
        write_json(request, f.manifest)
        run = f.root / "run"
        self.assertEqual(
            0, self.call(f, "init", "--input", str(request), "--run", str(run)).returncode
        )
        first = deepcopy(f.lenses[1])
        first["gates"].pop()
        out = f.root / "out.json"
        write_json(out, first)
        result = self.call(
            f, "submit", "--id", "runtime-safety", "--input", str(out), "--run", str(run)
        )
        self.assertEqual(0, result.returncode, result.stderr)
        second = deepcopy(f.lenses[1])
        second["findings"] = []
        out.write_text(json.dumps(second))
        result = self.call(
            f, "submit", "--id", "runtime-safety", "--input", str(out), "--run", str(run)
        )
        self.assertEqual(0, result.returncode, result.stderr)
        retained = json.loads((run / "reviewer-runtime-safety-2.json").read_text())
        self.assertEqual("RUN-1", retained["findings"][0]["finding_id"])
