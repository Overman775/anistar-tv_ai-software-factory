#!/usr/bin/env python3
"""Causal integration scenarios for current-only Factory review protocol."""

from __future__ import annotations

import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from copy import deepcopy
from pathlib import Path
from typing import Any

from render_review_report import render_report
from review_protocol_schema import canonical_scope_hash, expected_gates, parse_diff

SCRIPTS = Path(__file__).resolve().parent
REPOSITORY_ROOT = SCRIPTS.parents[3]
VALIDATOR = SCRIPTS / "validate_review_protocol.py"
TOOL_RUNNER = SCRIPTS / "run_tool_checks.py"
IDENTITY_FIELDS = (
    "schema_version",
    "review_id",
    "mode",
    "base_sha",
    "head_sha",
    "scope_hash",
)


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def identity(manifest: dict[str, Any]) -> dict[str, Any]:
    return {field: manifest[field] for field in IDENTITY_FIELDS}


def source_evidence(path: str, line: int = 1, side: str = "new") -> dict[str, Any]:
    return {"kind": "source", "path": path, "line": line, "side": side}


def binary_evidence(path: str) -> dict[str, Any]:
    return {"kind": "binary", "path": path}


def command(exit_code: int = 0) -> dict[str, Any]:
    return {
        "argv": ["/usr/bin/true"],
        "cwd": ".",
        "exit_code": exit_code,
        "stdout_excerpt": "ok\n" if exit_code == 0 else "",
        "stderr_excerpt": "" if exit_code == 0 else "failed\n",
        "stdout_truncated": False,
        "stderr_truncated": False,
    }


class ProtocolFixture:
    def __init__(
        self,
        root: Path,
        *,
        mode: str = "feature",
        path: str = "lib/sample.dart",
        diff_kind: str = "addition",
    ) -> None:
        self.root = root
        self.path = path
        self.mode = mode
        self.diff_kind = diff_kind
        if mode == "feature":
            source = root / path
            source.parent.mkdir(parents=True, exist_ok=True)
            source.write_text("int value = 1;\n", encoding="utf-8")
            diff_file = None
            diff_sha = None
            base_sha = None
            source_sha256 = {
                path: hashlib.sha256(source.read_bytes()).hexdigest(),
            }
            self.evidence = source_evidence(path)
        else:
            diff = self._diff(path, diff_kind)
            diff_path = root / "review.diff"
            diff_path.write_text(diff, encoding="utf-8")
            diff_file = str(diff_path)
            diff_sha = hashlib.sha256(diff.encode("utf-8")).hexdigest()
            base_sha = "a" * 40
            source_sha256 = None
            if diff_kind == "deletion":
                self.evidence = source_evidence(path, side="old")
            elif diff_kind == "binary":
                self.evidence = binary_evidence(path)
            else:
                self.evidence = source_evidence(path)
        self.manifest = {
            "schema_version": "3",
            "review_id": f"review-{mode}-{diff_kind}",
            "mode": mode,
            "target": path,
            "base_sha": base_sha,
            "head_sha": "b" * 40,
            "scope_files": [path],
            "diff_file": diff_file,
            "diff_sha256": diff_sha,
            "source_sha256": source_sha256,
        }
        self.manifest["scope_hash"] = canonical_scope_hash(self.manifest)
        self.registry = expected_gates([path])
        self.tools = [self._tool(tool_id) for tool_id in ("static", "tests", "deps")]
        self.lenses = [self._lens(lens) for lens in self.registry]
        self.qa = {
            **identity(self.manifest),
            "code_verdict": "APPROVE",
            "semantic_gap": None,
            "severity_overrides": [],
            "manual_merges": [],
            "notes": [],
        }

    @staticmethod
    def _diff(path: str, kind: str) -> str:
        if kind == "deletion":
            return (
                f"diff --git a/{path} b/{path}\n"
                "deleted file mode 100644\n"
                f"--- a/{path}\n"
                "+++ /dev/null\n"
                "@@ -1 +0,0 @@\n"
                "-int oldValue = 1;\n"
            )
        if kind == "binary":
            return (
                f"diff --git a/{path} b/{path}\n"
                "new file mode 100644\n"
                f"Binary files /dev/null and b/{path} differ\n"
            )
        return (
            f"diff --git a/{path} b/{path}\n"
            "new file mode 100644\n"
            "--- /dev/null\n"
            f"+++ b/{path}\n"
            "@@ -0,0 +1 @@\n"
            "+int value = 1;\n"
        )

    def _tool(self, tool_id: str) -> dict[str, Any]:
        return {
            **identity(self.manifest),
            "tool_id": tool_id,
            "status": "PASS",
            "reason": None,
            "commands": [command()],
        }

    def _lens(self, lens: str) -> dict[str, Any]:
        return {
            **identity(self.manifest),
            "lens": lens,
            "done_signal": "COMPLETE",
            "gates": [
                {
                    "gate_id": gate_id,
                    "status": "PASS",
                    "evidence": [deepcopy(self.evidence)],
                }
                for gate_id in self.registry[lens]
            ],
            "findings": [],
        }

    def add_finding(
        self,
        lens: str = "runtime-safety",
        *,
        finding_id: str = "RUN-1",
        gate_id: str | None = None,
        severity: str = "medium",
        description: str = "Changed behavior can return stale data.",
        evidence: dict[str, Any] | None = None,
        rule_id: str | None = None,
    ) -> dict[str, Any]:
        lens_output = next(item for item in self.lenses if item["lens"] == lens)
        selected_gate = gate_id or self.registry[lens][0]
        next(item for item in lens_output["gates"] if item["gate_id"] == selected_gate)[
            "status"
        ] = "FINDING"
        selected_evidence = deepcopy(evidence or self.evidence)
        finding = {
            "finding_id": finding_id,
            "gate_id": selected_gate,
            "path": self.path,
            "line": (
                None if selected_evidence["kind"] == "binary" else selected_evidence["line"]
            ),
            "rule": "Preserve observable behavior",
            "description": description,
            "fix": "Handle current state before returning.",
            "severity": severity,
            "confidence": "high",
            "evidence": [selected_evidence],
        }
        if rule_id is not None:
            finding["rule_id"] = rule_id
        lens_output["findings"].append(finding)
        return finding

    def execute(self) -> tuple[subprocess.CompletedProcess[str], dict[str, Any], str]:
        manifest_path = self.root / "manifest.json"
        lens_paths = [self.root / f"lens-{index}.json" for index in range(len(self.lenses))]
        tool_paths = [self.root / f"tool-{index}.json" for index in range(len(self.tools))]
        qa_path = self.root / "qa.json"
        output_path = self.root / "result.json"
        report_path = self.root / "report.md"
        write_json(manifest_path, self.manifest)
        for path, value in zip(lens_paths, self.lenses):
            write_json(path, value)
        for path, value in zip(tool_paths, self.tools):
            write_json(path, value)
        write_json(qa_path, self.qa)
        argv = [
            sys.executable,
            str(VALIDATOR),
            "--manifest",
            str(manifest_path),
        ]
        for path in lens_paths:
            argv.extend(["--lens-output", str(path)])
        for path in tool_paths:
            argv.extend(["--tool-result", str(path)])
        argv.extend(
            [
                "--qa-output",
                str(qa_path),
                "--output",
                str(output_path),
                "--report-output",
                str(report_path),
            ]
        )
        completed = subprocess.run(
            argv,
            cwd=self.root,
            text=True,
            capture_output=True,
            check=False,
        )
        result = json.loads(output_path.read_text(encoding="utf-8"))
        report = report_path.read_text(encoding="utf-8")
        return completed, result, report


class CurrentProtocolScenarios(unittest.TestCase):
    def fixture(self, **kwargs: Any) -> tuple[tempfile.TemporaryDirectory[str], ProtocolFixture]:
        temp = tempfile.TemporaryDirectory()
        return temp, ProtocolFixture(Path(temp.name), **kwargs)

    def test_lens_lifecycle_contract_is_identity_bound_and_preserves_partial_truth(self) -> None:
        skill = (SCRIPTS.parent / "SKILL.md").read_text(encoding="utf-8")
        normalized = " ".join(skill.split())
        for token in (
            "`review_id + base_sha + head_sha + scope_hash + canonical lens`",
            "valid `COMPLETE` terminalizes lens",
            "retry only same `FAILED`/invalid lens once",
            "never restart healthy lenses",
            "partial `INCOMPLETE` without synthesized findings",
            "New identity uses fresh lenses",
            "QA remains parent-owned",
        ):
            self.assertIn(" ".join(token.split()), normalized)
        self.assertIn(
            ".agents/contracts/common/agent-checkpoint.md#same-run-role-continuation",
            skill,
        )

    def test_clean_feature_complete_approve(self) -> None:
        temp, fixture = self.fixture(path="docs/review.md")
        with temp:
            fixture.tools[0].update(
                status="NOT_APPLICABLE",
                reason="docs-only scope has no static command",
                commands=[],
            )
            fixture.tools[2].update(
                status="NOT_APPLICABLE",
                reason="scope has no dependency change",
                commands=[],
            )
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 0)
            self.assertEqual(result["pipeline_status"], "COMPLETE")
            self.assertEqual(result["code_verdict"], "APPROVE")
            self.assertEqual(result["tool_statuses"]["static"], "NOT_APPLICABLE")
            fixture.add_finding(severity="high")
            fixture.qa["code_verdict"] = "NEEDS_WORK"
            (fixture.root / fixture.path).write_text("int value = 2;\n", encoding="utf-8")
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 2)
            self.assertIn("source bytes changed", " ".join(result["errors"]))
            self.assertEqual(result["findings"], [])

    def test_finding_needs_work(self) -> None:
        temp, fixture = self.fixture()
        with temp:
            fixture.add_finding(severity="high")
            fixture.qa["code_verdict"] = "NEEDS_WORK"
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 0)
            self.assertEqual(result["code_verdict"], "NEEDS_WORK")
            self.assertEqual([item["finding_id"] for item in result["findings"]], ["RUN-1"])

    def test_qa_added_findings_validate_and_remain_partial_truth(self) -> None:
        temp, fixture = self.fixture()
        with temp:
            added = {
                "finding_id": "QA-1",
                "gate_id": fixture.registry["runtime-safety"][0],
                "path": fixture.path,
                "line": 1,
                "rule": "QA found defect",
                "description": "QA challenged lens PASS.",
                "fix": "Apply bounded correction.",
                "severity": "high",
                "confidence": "high",
                "evidence": [deepcopy(fixture.evidence)],
            }
            fixture.qa.update(code_verdict="NEEDS_WORK", added_findings=[added])
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 0)
            self.assertEqual(result["findings"][0]["found_by"], ["qa"])
            malformed = deepcopy(added)
            malformed.pop("fix")
            fixture.qa["added_findings"].append(malformed)
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 2)
            self.assertEqual([item["finding_id"] for item in result["findings"]], ["QA-1"])
            out_of_scope = deepcopy(added)
            out_of_scope["finding_id"] = "QA-2"
            out_of_scope["path"] = "outside.dart"
            out_of_scope["evidence"][0]["path"] = "outside.dart"
            fixture.qa["added_findings"] = [out_of_scope]
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 2)
            self.assertEqual(result["findings"], [])

    def test_qa_added_finding_id_collision_preserves_lens_finding(self) -> None:
        for rule_id in (None, "BLOCK-PRINT"):
            temp, fixture = self.fixture()
            with temp:
                lens_finding = fixture.add_finding(finding_id="RUN-1", rule_id=rule_id)
                fixture.qa.update(
                    code_verdict="NEEDS_WORK",
                    added_findings=[deepcopy(lens_finding)],
                )
                completed, result, _ = fixture.execute()
                self.assertEqual(completed.returncode, 2)
                self.assertEqual(result["pipeline_status"], "INCOMPLETE")
                self.assertEqual(
                    [item["finding_id"] for item in result["findings"]], ["RUN-1"]
                )
                self.assertIn("collides", " ".join(result["errors"]))

    def test_duplicate_qa_added_finding_id_preserves_first_addition(self) -> None:
        temp, fixture = self.fixture()
        with temp:
            added = {
                "finding_id": "QA-1",
                "gate_id": fixture.registry["runtime-safety"][0],
                "path": fixture.path,
                "line": 1,
                "rule": "QA found defect",
                "description": "QA challenged lens PASS.",
                "fix": "Apply bounded correction.",
                "severity": "high",
                "confidence": "high",
                "evidence": [deepcopy(fixture.evidence)],
            }
            fixture.qa.update(
                code_verdict="NEEDS_WORK",
                added_findings=[added, deepcopy(added)],
            )
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 2)
            self.assertEqual(result["pipeline_status"], "INCOMPLETE")
            self.assertEqual(
                [item["finding_id"] for item in result["findings"]], ["QA-1"]
            )

    def test_tool_failure_is_complete_evidence(self) -> None:
        temp, fixture = self.fixture()
        with temp:
            fixture.tools[1]["status"] = "FAIL"
            fixture.tools[1]["commands"] = [command(1)]
            for verdict in ("APPROVE", "RETHINK"):
                fixture.qa["code_verdict"] = verdict
                fixture.qa["semantic_gap"] = "blocked behavior" if verdict == "RETHINK" else None
                completed, result, report = fixture.execute()
                self.assertEqual(completed.returncode, 0)
                self.assertEqual(result["pipeline_status"], "COMPLETE")
                self.assertEqual(result["code_verdict"], "NEEDS_WORK")
                self.assertIsNone(result["semantic_gap"])
                self.assertEqual(result["tool_failures"], ["tests"])
                self.assertEqual(result["failing_commands"][0]["exit_code"], 1)
                self.assertEqual(result["failing_commands"][0]["stderr_excerpt"], "failed\n")
                self.assertIn("Failing commands", report)
                self.assertIn("/usr/bin/true", report)
                self.assertNotIn("Semantic gap", report)
            fixture.tools[1]["status"] = "PASS"
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 2)
            self.assertIn("contradicts exit codes", " ".join(result["errors"]))

    def test_branch_hunk_prefixes_update_line_counters(self) -> None:
        context = parse_diff(
            "diff --git a/lib/sample.dart b/lib/sample.dart\n"
            "--- a/lib/sample.dart\n"
            "+++ b/lib/sample.dart\n"
            "@@ -1,3 +1,3 @@\n"
            "---removed\n"
            "+++added\n"
            " unchanged\n"
            "-oldTail\n"
            "+newTail\n"
        )
        self.assertEqual(
            context["old"], {("lib/sample.dart", 1), ("lib/sample.dart", 3)}
        )
        self.assertEqual(
            context["new"], {("lib/sample.dart", 1), ("lib/sample.dart", 3)}
        )

    def test_not_run_makes_incomplete(self) -> None:
        temp, fixture = self.fixture()
        with temp:
            fixture.tools[1].update(status="NOT_RUN", reason="device unavailable", commands=[])
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 2)
            self.assertEqual(result["pipeline_status"], "INCOMPLETE")
            self.assertEqual(result["code_verdict"], "NEEDS_WORK")
            fixture.tools[1] = fixture._tool("tests")
            gate = fixture.lenses[1]["gates"][0]
            gate.update(status="NOT_RUN", reason="source unavailable")
            gate.pop("evidence")
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 2)
            self.assertIn("gate RUN-BEHAVIOR NOT_RUN", " ".join(result["errors"]))

    def test_malformed_lens_makes_incomplete(self) -> None:
        temp, fixture = self.fixture()
        with temp:
            del fixture.lenses[0]["done_signal"]
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 2)
            self.assertIn("done_signal", " ".join(result["errors"]))

    def test_missing_gate_makes_incomplete(self) -> None:
        temp, fixture = self.fixture()
        with temp:
            fixture.lenses[0]["gates"].pop()
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 2)
            self.assertIn("missing gates", " ".join(result["errors"]))
            fixture = ProtocolFixture(Path(temp.name) / "universal-na")
            for lens in fixture.lenses:
                for gate in lens["gates"]:
                    gate.update(
                        status="NOT_APPLICABLE",
                        reason="incorrect universal bypass",
                    )
                    gate.pop("evidence")
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 2)
            self.assertIn("universal gate", " ".join(result["errors"]))

    def test_out_of_scope_finding_is_excluded(self) -> None:
        temp, fixture = self.fixture()
        with temp:
            finding = fixture.add_finding()
            finding["path"] = "outside.dart"
            finding["evidence"][0]["path"] = "outside.dart"
            fixture.qa["code_verdict"] = "NEEDS_WORK"
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 2)
            self.assertEqual(result["findings"], [])

    def test_deletion_old_side_evidence(self) -> None:
        temp, fixture = self.fixture(mode="branch", path="lib/deleted.dart", diff_kind="deletion")
        with temp:
            fixture.add_finding(severity="high")
            fixture.qa["code_verdict"] = "NEEDS_WORK"
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 0)
            self.assertEqual(result["findings"][0]["evidence"][0]["side"], "old")

    def test_binary_evidence(self) -> None:
        temp, fixture = self.fixture(mode="branch", path="assets/new.png", diff_kind="binary")
        with temp:
            fixture.add_finding(severity="medium")
            fixture.qa["code_verdict"] = "NEEDS_WORK"
            completed, result, report = fixture.execute()
            self.assertEqual(completed.returncode, 0)
            self.assertIsNone(result["findings"][0]["line"])
            self.assertIn("assets/new.png:binary", report)
            text_fixture = ProtocolFixture(fixture.root / "text-feature")
            text_fixture.add_finding(evidence=binary_evidence(text_fixture.path))
            text_fixture.qa["code_verdict"] = "NEEDS_WORK"
            completed, result, _ = text_fixture.execute()
            self.assertEqual(completed.returncode, 2)
            self.assertEqual(result["findings"], [])

    def test_partial_report_preserves_valid_finding(self) -> None:
        temp, fixture = self.fixture()
        with temp:
            fixture.add_finding(severity="high")
            fixture.lenses[0]["gates"].pop()
            fixture.qa["code_verdict"] = "NEEDS_WORK"
            completed, result, report = fixture.execute()
            self.assertEqual(completed.returncode, 2)
            self.assertEqual(result["pipeline_status"], "INCOMPLETE")
            self.assertEqual([item["finding_id"] for item in result["findings"]], ["RUN-1"])
            self.assertIn("RUN-1", report)

    def test_branch_mode_happy_path(self) -> None:
        temp, fixture = self.fixture(mode="branch")
        with temp:
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 0)
            self.assertEqual(result["mode"], "branch")
            fixture.add_finding(severity="high")
            fixture.qa["code_verdict"] = "NEEDS_WORK"
            Path(fixture.manifest["diff_file"]).write_text(
                Path(fixture.manifest["diff_file"]).read_text(encoding="utf-8") + "\n",
                encoding="utf-8",
            )
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 2)
            self.assertIn("diff: sha256 mismatch", result["errors"])
            self.assertEqual(result["findings"], [])

    def test_pr_mode_happy_path(self) -> None:
        temp, fixture = self.fixture(mode="pr")
        with temp:
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 0)
            self.assertEqual(result["mode"], "pr")
            fixture.lenses[0]["base_sha"] = "c" * 40
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 2)
            self.assertIn("identity mismatch for base_sha", " ".join(result["errors"]))
            fixture.lenses[0]["base_sha"] = fixture.manifest["base_sha"]
            fixture.tools[0]["head_sha"] = "c" * 40
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 2)
            self.assertIn("identity mismatch for head_sha", " ".join(result["errors"]))

    def test_markdown_injection_is_escaped(self) -> None:
        temp, fixture = self.fixture()
        with temp:
            fixture.add_finding(
                description="impact\n### injected <script>alert(1)</script>",
            )
            fixture.qa["code_verdict"] = "NEEDS_WORK"
            completed, _, report = fixture.execute()
            self.assertEqual(completed.returncode, 0)
            self.assertNotIn("\n### injected", report)
            self.assertNotIn("<script>", report)
            self.assertIn("\\#\\#\\# injected", report)

    def test_two_same_line_free_form_findings_stay_distinct(self) -> None:
        temp, fixture = self.fixture()
        with temp:
            fixture.add_finding(finding_id="RUN-1", description="first defect")
            second = fixture.add_finding(
                lens="verification-quality",
                finding_id="VER-2",
                description="second defect",
            )
            second["evidence"].append(
                {"kind": "tool", "tool_id": "tests", "command_index": 0}
            )
            fixture.qa["code_verdict"] = "NEEDS_WORK"
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 0)
            self.assertEqual(
                {item["finding_id"] for item in result["findings"]},
                {"RUN-1", "VER-2"},
            )
            merge_finding = {
                "finding_id": "QA-1",
                "gate_id": fixture.registry["runtime-safety"][0],
                "path": fixture.path,
                "line": 1,
                "rule": "merged",
                "description": "merged impact",
                "fix": "merged fix",
                "severity": "medium",
                "confidence": "high",
                "evidence": [deepcopy(fixture.evidence)],
            }
            fixture.qa["manual_merges"] = [
                {
                    "source_ids": ["RUN-1", "VER-2"],
                    "reason": "same demonstrated defect",
                    "finding": merge_finding,
                }
            ]
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 0)
            self.assertEqual(len(result["findings"]), 1)
            merged = result["findings"][0]
            self.assertEqual(set(merged["source_ids"]), {"RUN-1", "VER-2"})
            self.assertEqual(
                set(merged["found_by"]),
                {"runtime-safety", "verification-quality"},
            )
            self.assertIn("tool", {item["kind"] for item in merged["evidence"]})
            for finding in fixture.lenses[1]["findings"]:
                finding["severity"] = "high"
            for finding in fixture.lenses[2]["findings"]:
                finding["severity"] = "high"
            fixture.qa["code_verdict"] = "APPROVE"
            fixture.qa["manual_merges"] = [
                {
                    "source_ids": ["RUN-1", "VER-2"],
                    "reason": "same defect",
                    "finding": merge_finding,
                }
            ]
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 2)
            self.assertEqual(result["code_verdict"], "NEEDS_WORK")
            self.assertEqual(
                {item["finding_id"] for item in result["findings"]},
                {"RUN-1", "VER-2"},
            )
            fixture.add_finding(finding_id="RUN-3", severity="high")
            merge_finding["finding_id"] = "RUN-3"
            merge_finding["severity"] = "high"
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 2)
            self.assertIn("collides", " ".join(result["errors"]))
            self.assertEqual(
                {item["finding_id"] for item in result["findings"]},
                {"RUN-1", "VER-2", "RUN-3"},
            )

    def test_real_parent_runner_to_validator_happy_path(self) -> None:
        temp, fixture = self.fixture()
        with temp:
            manifest_path = fixture.root / "runner-manifest.json"
            write_json(manifest_path, fixture.manifest)
            produced = []
            for tool_id in ("static", "tests", "deps"):
                output = fixture.root / f"runner-{tool_id}.json"
                argv = (
                    [sys.executable, "-c", "print('x' * 40000)"]
                    if tool_id == "static"
                    else ["/usr/bin/printf", tool_id]
                )
                completed = subprocess.run(
                    [
                        sys.executable,
                        str(TOOL_RUNNER),
                        "--manifest",
                        str(manifest_path),
                        "--tool-id",
                        tool_id,
                        "--command",
                        json.dumps({"argv": argv, "cwd": "."}),
                        "--output",
                        str(output),
                    ],
                    cwd=fixture.root,
                    text=True,
                    capture_output=True,
                    check=False,
                )
                self.assertEqual(completed.returncode, 0, completed.stderr)
                produced.append(json.loads(output.read_text(encoding="utf-8")))
            self.assertTrue(produced[0]["commands"][0]["stdout_truncated"])
            self.assertLessEqual(
                len(produced[0]["commands"][0]["stdout_excerpt"].encode("utf-8")),
                24 * 1024,
            )
            fixture.tools = produced
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 0)
            self.assertEqual(set(result["tool_statuses"].values()), {"PASS"})
            fail_output = fixture.root / "runner-tests-fail.json"
            failed = subprocess.run(
                [
                    sys.executable,
                    str(TOOL_RUNNER),
                    "--manifest",
                    str(manifest_path),
                    "--tool-id",
                    "tests",
                    "--command",
                    json.dumps({"argv": ["/usr/bin/false"], "cwd": "."}),
                    "--output",
                    str(fail_output),
                ],
                cwd=fixture.root,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(failed.returncode, 1)
            not_run_output = fixture.root / "runner-deps-not-run.json"
            not_run = subprocess.run(
                [
                    sys.executable,
                    str(TOOL_RUNNER),
                    "--manifest",
                    str(manifest_path),
                    "--tool-id",
                    "deps",
                    "--not-run-reason",
                    "not applicable in environment",
                    "--output",
                    str(not_run_output),
                ],
                cwd=fixture.root,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(not_run.returncode, 0)
            fixture.tools = [
                produced[0],
                json.loads(fail_output.read_text(encoding="utf-8")),
                json.loads(not_run_output.read_text(encoding="utf-8")),
            ]
            fixture.qa["code_verdict"] = "NEEDS_WORK"
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 2)
            self.assertEqual(result["tool_failures"], ["tests"])
            self.assertEqual(result["tool_statuses"]["deps"], "NOT_RUN")
            not_applicable_output = fixture.root / "runner-deps-na.json"
            not_applicable = subprocess.run(
                [
                    sys.executable,
                    str(TOOL_RUNNER),
                    "--manifest",
                    str(manifest_path),
                    "--tool-id",
                    "deps",
                    "--not-applicable-reason",
                    "scope has no dependency change",
                    "--output",
                    str(not_applicable_output),
                ],
                cwd=fixture.root,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(not_applicable.returncode, 0)
            fixture.tools[2] = json.loads(
                not_applicable_output.read_text(encoding="utf-8")
            )
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 0)
            self.assertEqual(result["pipeline_status"], "COMPLETE")
            self.assertEqual(result["tool_statuses"]["deps"], "NOT_APPLICABLE")

    def test_severity_override_requires_reason(self) -> None:
        temp, fixture = self.fixture()
        with temp:
            fixture.add_finding()
            fixture.qa["code_verdict"] = "NEEDS_WORK"
            fixture.qa["severity_overrides"] = [
                {"finding_id": "RUN-1", "severity": "high", "reason": ""}
            ]
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 2)
            self.assertEqual(result["findings"][0]["severity"], "medium")
            fixture.lenses[1]["findings"][0]["severity"] = "high"
            fixture.qa["review_id"] = "foreign-review"
            fixture.qa["severity_overrides"] = [
                {
                    "finding_id": "RUN-1",
                    "severity": "medium",
                    "reason": "foreign downgrade",
                }
            ]
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 2)
            self.assertEqual(result["findings"][0]["severity"], "high")
            self.assertNotIn("qa_severity_reason", result["findings"][0])

    def test_conditional_file_routing_is_mandatory(self) -> None:
        temp, fixture = self.fixture(path="lib/packages/features/demo/presentation/demo_widget.dart")
        with temp:
            runtime = next(item for item in fixture.lenses if item["lens"] == "runtime-safety")
            runtime["gates"] = [
                gate for gate in runtime["gates"] if gate["gate_id"] != "RUN-UI"
            ]
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 2)
            self.assertIn("RUN-UI", " ".join(result["errors"]))
            platform_paths = (
                "android/app/build.gradle.kts",
                "android/settings.gradle.kts",
                "android/gradle/libs.versions.toml",
                "android/gradle.properties",
                "pubspec.yaml",
            )
            for path in platform_paths:
                routed = expected_gates([path])
                self.assertIn("SYS-PLATFORM", routed["system-design"], path)
                self.assertIn("VER-PLATFORM", routed["verification-quality"], path)

    def test_anistar_domain_paths_route_to_owned_gates(self) -> None:
        cases = {
            "infrastructure/anistar/lib/src/html_anistar_client.dart": ("system-design", "SYS-CLIENT"),
            "lib/app/app_container.dart": ("system-design", "SYS-CLIENT"),
            "lib/packages/features/catalog/data/repositories/catalog_repository.dart": ("system-design", "SYS-DATA"),
            "test/packages/features/catalog/data/mapper_test.dart": ("system-design", "SYS-DATA"),
            "test/infrastructure/anistar/episode_dto_test.dart": ("system-design", "SYS-DATA"),
            "test/packages/features/catalog/repositories_test.dart": ("runtime-safety", "RUN-ASYNC"),
            "infrastructure/storage/lib/src/cookie_storage.dart": ("runtime-safety", "RUN-SESSION"),
            "lib/packages/features/player/presentation/player_bloc.dart": ("runtime-safety", "RUN-PLAYER"),
            "tool/e2e/media/fixture.m3u8": ("runtime-safety", "RUN-PLAYER"),
            "lib/packages/ui_kit/lib/src/focus/focus_scope.dart": ("runtime-safety", "RUN-UI"),
            "test/packages/ui_kit/focus_test.dart": ("verification-quality", "VER-UI"),
            "integration_test/support/remote_controls.dart": ("verification-quality", "VER-UI"),
            ".fvmrc": ("verification-quality", "VER-SDK"),
            "pubspec.lock": ("verification-quality", "VER-SDK"),
            "scripts/check.sh": ("verification-quality", "VER-SDK"),
            "tool/quality/verify_android_apk_test.py": ("verification-quality", "VER-PLATFORM"),
            "docs/adr/0009-single-anistar-client-and-dio.md": ("system-design", "SYS-CLIENT"),
            "docs/specs/06_tv_interaction.md": ("runtime-safety", "RUN-UI"),
        }
        for path, (lens, gate) in cases.items():
            with self.subTest(path=path):
                self.assertIn(gate, expected_gates([path])[lens])

    def test_factory_docs_and_tools_do_not_activate_application_domains(self) -> None:
        paths = [
            ".agents/contracts/common/session.md",
            ".agents/skills/factory-code-review/scripts/test_review_scripts.py",
            "AGENTS.md",
            "scripts/session_review.py",
        ]
        for path in paths:
            with self.subTest(path=path):
                routed = expected_gates([path])
                self.assertNotIn("RUN-UI", routed["runtime-safety"])
                self.assertNotIn("RUN-SESSION", routed["runtime-safety"])
                self.assertNotIn("RUN-PLAYER", routed["runtime-safety"])
                self.assertNotIn("SYS-CLIENT", routed["system-design"])

    def test_current_report_keeps_visual_pr_format_and_escaping(self) -> None:
        temp, fixture = self.fixture()
        with temp:
            fixture.add_finding()
            fixture.qa["code_verdict"] = "NEEDS_WORK"
            completed, result, rendered = fixture.execute()
            self.assertEqual(completed.returncode, 0)
            self.assertIn("## 🔎 Factory Review · 🚧 NEEDS\\_WORK", rendered)
            self.assertIn("- ✅ **Протокол:** `COMPLETE`", rendered)
            self.assertIn("🚧 **Мерж заблокирован:**", rendered)
            self.assertIn("### 🟡 Medium", rendered)
            self.assertIn("💥 **Влияние:**", rendered)
            self.assertIn("🛠 **Как исправить:**", rendered)
            self.assertIn("🧾 **Детали:**", rendered)
            self.assertIn("<summary>🧰 Внутренности ревью</summary>", rendered)

            result["pipeline_status"] = "INCOMPLETE"
            result["review_id"] = "<script>alert(1)</script>"
            report_path = fixture.root / "visual-report.md"
            render_report(report_path, result)
            rendered = report_path.read_text(encoding="utf-8")
            self.assertIn("⚠️ **Мерж заблокирован:** ревью неполное", rendered)
            self.assertNotIn("<script>", rendered)
            self.assertIn(r"\<script\>alert\(1\)\</script\>", rendered)


if __name__ == "__main__":
    unittest.main(verbosity=2)
