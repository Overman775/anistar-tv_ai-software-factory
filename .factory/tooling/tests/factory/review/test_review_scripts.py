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

from factory.review.render_review_report import render_report
from factory.review.review_contracts import canonical_scope_hash
from factory.review.review_diff import parse_diff
from factory.review.review_evidence import validate_evidence
from tests.factory.review.fixture_protocol import (
    SCRIPTS,
    TOOL_RUNNER,
    ProtocolFixture,
    binary_evidence,
    command,
    expected_gates,
    identity,
    source_evidence,
    write_json,
)


class CurrentProtocolScenarios(unittest.TestCase):
    def fixture(self, **kwargs: Any) -> tuple[tempfile.TemporaryDirectory[str], ProtocolFixture]:
        temp = tempfile.TemporaryDirectory()
        return temp, ProtocolFixture(Path(temp.name), **kwargs)

    def test_lens_lifecycle_contract_is_identity_bound_and_preserves_partial_truth(self) -> None:
        skill = (SCRIPTS.parents[2] / "skills/factory-code-review/SKILL.md").read_text(
            encoding="utf-8"
        )
        normalized = " ".join(skill.split())
        for token in (
            "`review_id + base_sha + head_sha + scope_hash + canonical lens`",
            "valid COMPLETE terminalizes that assignment",
            "Retry only same FAILED/invalid assignment once",
            "never restart healthy assignments",
            "Partial INCOMPLETE preserves valid findings without synthesized missing conclusions",
            "New identity uses fresh assignments",
            "QA remains coordinator-owned",
        ):
            self.assertIn(" ".join(token.split()), normalized)
        self.assertIn(
            ".factory/contracts/common/agent-checkpoint.md#same-run-role-continuation",
            skill,
        )

    def test_clean_feature_complete_approve(self) -> None:
        temp, fixture = self.fixture(path="docs/review.md")
        with temp:
            fixture.tools = [fixture.tools[1]]
            fixture.manifest["additional_checks"] = [fixture.manifest["additional_checks"][1]]
            fixture.rebind()
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 0)
            self.assertEqual(result["pipeline_status"], "COMPLETE")
            self.assertEqual(result["code_verdict"], "APPROVE")
            self.assertNotIn("static", result["tool_statuses"])
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
            added: dict[str, Any] = {
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
        for rule_id in (None,):
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
                self.assertEqual([item["finding_id"] for item in result["findings"]], ["RUN-1"])
                self.assertIn("collides", " ".join(result["errors"]))

    def test_duplicate_qa_added_finding_id_preserves_first_addition(self) -> None:
        temp, fixture = self.fixture()
        with temp:
            added: dict[str, Any] = {
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
            self.assertEqual([item["finding_id"] for item in result["findings"]], ["QA-1"])

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

    def test_execution_blocker_keeps_review_incomplete_with_or_without_failure(self) -> None:
        temp, fixture = self.fixture()
        with temp:
            blocked = command(0) | {"exit_code": None, "error": "TimeoutExpired"}
            for failed in (False, True):
                with self.subTest(failed=failed):
                    fixture.tools[1]["status"] = "FAIL" if failed else "BLOCKED"
                    fixture.tools[1]["commands"] = ([command(1)] if failed else []) + [blocked]
                    completed, result, report = fixture.execute()
                    self.assertEqual(2, completed.returncode)
                    self.assertEqual("INCOMPLETE", result["pipeline_status"])
                    self.assertEqual("NEEDS_WORK", result["code_verdict"])
                    self.assertEqual(["tests"] if failed else [], result["tool_failures"])
                    self.assertEqual(2 if failed else 1, len(result["failing_commands"]))
                    self.assertIn("TimeoutExpired", report)

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
        self.assertEqual(context["old"], {("lib/sample.dart", 1), ("lib/sample.dart", 3)})
        self.assertEqual(context["new"], {("lib/sample.dart", 1), ("lib/sample.dart", 3)})

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
            second["evidence"].append({"kind": "tool", "tool_id": "tests", "command_index": 0})
            fixture.qa["code_verdict"] = "NEEDS_WORK"
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 0)
            self.assertEqual(
                {item["finding_id"] for item in result["findings"]},
                {"RUN-1", "VER-2"},
            )
            merge_finding: dict[str, Any] = {
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

    def test_invalid_manual_merge_ids_preserve_valid_high_findings_in_cli(self) -> None:
        temp, fixture = self.fixture()
        with temp:
            fixture.add_finding(finding_id="RUN-1", severity="high")
            fixture.add_finding(finding_id="RUN-2", severity="high")
            fixture.qa["code_verdict"] = "NEEDS_WORK"
            for sources, candidate_id in (([{}, {}], "QA-1"), (["RUN-1", "RUN-2"], {})):
                with self.subTest(sources=sources, candidate_id=candidate_id):
                    fixture.qa["manual_merges"] = [
                        {
                            "source_ids": sources,
                            "reason": "same issue",
                            "finding": {"finding_id": candidate_id},
                        }
                    ]
                    completed, result, _ = fixture.execute()
                    self.assertEqual(2, completed.returncode, completed.stderr)
                    self.assertNotIn("Traceback", completed.stderr)
                    self.assertEqual("INCOMPLETE", result["pipeline_status"])
                    self.assertEqual(
                        {"RUN-1", "RUN-2"}, {item["finding_id"] for item in result["findings"]}
                    )
                    self.assertTrue(all(item["severity"] == "high" for item in result["findings"]))

    def test_malformed_qa_and_merge_evidence_keep_high_findings(self) -> None:
        temp, fixture = self.fixture()
        with temp:
            source = fixture.add_finding(finding_id="RUN-1", severity="high")
            fixture.add_finding(finding_id="RUN-2", severity="high")
            fixture.qa["code_verdict"] = "NEEDS_WORK"
            base = deepcopy(fixture.qa)
            malformed_evidence = (
                {"kind": "source", "path": fixture.path, "line": 1, "side": {}},
                {"kind": "tool", "tool_id": {}, "command_index": 0},
                {"kind": "requirement", "requirement_id": {}},
                {"kind": "inspection", "path": {}, "line": 1},
            )
            mutations: list[tuple[str, Any]] = [
                ("code_verdict", {}),
                ("severity_overrides", [{"finding_id": {}, "severity": "high", "reason": "x"}]),
                ("severity_overrides", [{"finding_id": "RUN-1", "severity": {}, "reason": "x"}]),
                ("added_findings", [{"gate_id": {}}]),
                ("merge_gate_id", {}),
                ("merge_confidence", {}),
            ] + [("merge_evidence", [entry]) for entry in malformed_evidence]
            for key, invalid in mutations:
                with self.subTest(field=key, value=invalid):
                    fixture.qa = deepcopy(base)
                    if key.startswith("merge_"):
                        candidate = deepcopy(source)
                        candidate["finding_id"] = "QA-1"
                        candidate[key.removeprefix("merge_")] = invalid
                        fixture.qa["manual_merges"] = [
                            {
                                "source_ids": ["RUN-1", "RUN-2"],
                                "reason": "same issue",
                                "finding": candidate,
                            }
                        ]
                    else:
                        fixture.qa[key] = invalid
                    completed, result, _ = fixture.execute()
                    self.assertEqual(2, completed.returncode, completed.stderr)
                    self.assertNotIn("Traceback", completed.stderr)
                    self.assertEqual("INCOMPLETE", result["pipeline_status"])
                    self.assertEqual(
                        {"RUN-1", "RUN-2"}, {item["finding_id"] for item in result["findings"]}
                    )
                    self.assertTrue(all(item["severity"] == "high" for item in result["findings"]))

    def test_real_parent_runner_to_validator_happy_path(self) -> None:
        temp, fixture = self.fixture()
        with temp:
            for check in fixture.manifest["additional_checks"]:
                check["execution"]["argv"] = [sys.executable, "-c", "print('x' * 40000)"]
            fixture.rebind()
            manifest_path = fixture.root / "runner-manifest.json"
            write_json(manifest_path, fixture.manifest)
            produced = []
            for tool_id in ("static", "tests", "deps"):
                output = fixture.root / f"runner-{tool_id}.json"
                completed = subprocess.run(
                    [
                        sys.executable,
                        str(TOOL_RUNNER),
                        "--manifest",
                        str(manifest_path),
                        "--tool-id",
                        tool_id,
                        "--output",
                        str(output),
                    ],
                    cwd=fixture.root,
                    text=True,
                    capture_output=True,
                )
                self.assertEqual(completed.returncode, 0, completed.stderr)
                produced.append(json.loads(output.read_text()))
            self.assertTrue(produced[0]["commands"][0]["stdout_truncated"])
            fixture.tools = produced
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 0, result["errors"])
            for extra in [
                ["--command", '{"argv":["/usr/bin/false"],"cwd":"."}'],
                ["--not-applicable-reason", "skip"],
            ]:
                completed = subprocess.run(
                    [
                        sys.executable,
                        str(TOOL_RUNNER),
                        "--manifest",
                        str(manifest_path),
                        "--tool-id",
                        "tests",
                        *extra,
                    ],
                    cwd=fixture.root,
                    text=True,
                    capture_output=True,
                )
                self.assertEqual(completed.returncode, 2)

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

    def test_qa_dismissal_preserves_original_and_allows_approve(self) -> None:
        temp, fixture = self.fixture()
        with temp:
            original = deepcopy(fixture.add_finding(severity="high"))
            fixture.qa["dismissals"] = [
                {
                    "finding_id": "RUN-1",
                    "reason": "The changed guard rejects the alleged stale state. <script>\n### hidden",
                    "evidence": [deepcopy(fixture.evidence)],
                }
            ]
            completed, result, report = fixture.execute()
            self.assertEqual(completed.returncode, 0, completed.stderr)
            self.assertEqual(result["code_verdict"], "APPROVE")
            self.assertEqual(result["findings"], [])
            decision = result["dismissed_findings"][0]
            self.assertEqual(decision["dismissed_by"], "qa")
            self.assertEqual(
                decision["finding"],
                {
                    **original,
                    "source_ids": ["RUN-1"],
                    "found_by": ["runtime-safety"],
                },
            )
            self.assertEqual(decision["evidence"], [fixture.evidence])
            self.assertIn("QA dismissed findings", report)
            self.assertIn("RUN-1", report)
            self.assertIn("Original severity:** `high`", report)
            self.assertNotIn("<script>", report)
            self.assertNotIn("\n### hidden", report)

    def test_invalid_dismissal_cannot_erase_high_finding(self) -> None:
        invalid: list[dict[str, Any]] = [
            {"reason": "", "evidence": [source_evidence("lib/sample.dart")]},
            {"reason": "   ", "evidence": [source_evidence("lib/sample.dart")]},
            {"reason": "unsupported claim", "evidence": []},
            {
                "reason": "unsupported claim",
                "evidence": [{"kind": "note", "path": "lib/sample.dart"}],
            },
            {"reason": "wrong line", "evidence": [source_evidence("lib/sample.dart", 99)]},
            {"reason": "outside scope", "evidence": [source_evidence("other.dart")]},
            {
                "reason": "generic passing tool",
                "evidence": [{"kind": "tool", "tool_id": "tests", "command_index": 0}],
            },
            {
                "reason": "missing command",
                "evidence": [
                    source_evidence("lib/sample.dart"),
                    {"kind": "tool", "tool_id": "tests", "command_index": 99},
                ],
            },
        ]
        for fields in invalid:
            with self.subTest(fields=fields):
                temp, fixture = self.fixture()
                with temp:
                    fixture.add_finding(severity="high")
                    fixture.qa["dismissals"] = [{"finding_id": "RUN-1", **fields}]
                    completed, result, _ = fixture.execute()
                    self.assertEqual(completed.returncode, 2)
                    self.assertEqual(result["code_verdict"], "NEEDS_WORK")
                    self.assertEqual(result["dismissed_findings"], [])
                    self.assertEqual([item["finding_id"] for item in result["findings"]], ["RUN-1"])

    def test_dismissal_ids_and_identity_must_be_unambiguous(self) -> None:
        for variant in ("unknown", "repeated", "foreign", "not-list", "malformed"):
            with self.subTest(variant=variant):
                temp, fixture = self.fixture()
                with temp:
                    fixture.add_finding(severity="high")
                    decision: dict[str, Any] = {
                        "finding_id": "RUN-1",
                        "reason": "guard disproves claim",
                        "evidence": [deepcopy(fixture.evidence)],
                    }
                    fixture.qa["dismissals"] = [decision]
                    if variant == "unknown":
                        decision["finding_id"] = "RUN-404"
                    elif variant == "repeated":
                        fixture.qa["dismissals"].append(deepcopy(decision))
                    elif variant == "foreign":
                        fixture.qa["head_sha"] = "c" * 40
                    elif variant == "not-list":
                        fixture.qa["dismissals"] = decision
                    else:
                        fixture.qa["dismissals"] = [{"finding_id": []}, None]
                    completed, result, _ = fixture.execute()
                    self.assertEqual(completed.returncode, 2, completed.stderr)
                    self.assertEqual(result["dismissed_findings"], [])
                    self.assertEqual(result["findings"][0]["severity"], "high")

    def test_dismissal_cannot_remove_other_finding_or_tool_blocker(self) -> None:
        temp, fixture = self.fixture()
        with temp:
            fixture.add_finding(severity="high")
            fixture.add_finding(lens="verification-quality", finding_id="VER-1", severity="high")
            fixture.qa["dismissals"] = [
                {
                    "finding_id": "RUN-1",
                    "reason": "guard disproves claim",
                    "evidence": [deepcopy(fixture.evidence)],
                }
            ]
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 2)
            self.assertEqual([item["finding_id"] for item in result["findings"]], ["VER-1"])
            self.assertEqual(result["code_verdict"], "NEEDS_WORK")
            fixture.qa["dismissals"].append(
                {
                    "finding_id": "VER-1",
                    "reason": "same counterexample",
                    "evidence": [deepcopy(fixture.evidence)],
                }
            )
            fixture.tools[1]["commands"] = [command(1)]
            fixture.tools[1]["status"] = "FAIL"
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 0)
            self.assertEqual(result["findings"], [])
            self.assertEqual(len(result["dismissed_findings"]), 2)
            self.assertEqual(result["tool_failures"], ["tests"])
            self.assertEqual(result["code_verdict"], "NEEDS_WORK")

    def test_dismissal_precedes_merges_without_reusing_source_ids(self) -> None:
        temp, fixture = self.fixture()
        with temp:
            source = fixture.add_finding(severity="high")
            fixture.add_finding(finding_id="RUN-2", severity="high")
            fixture.add_finding(lens="verification-quality", finding_id="VER-1", severity="high")
            fixture.qa["dismissals"] = [
                {
                    "finding_id": "RUN-1",
                    "reason": "guard disproves claim",
                    "evidence": [deepcopy(fixture.evidence)],
                }
            ]
            fixture.qa["manual_merges"] = [
                {
                    "source_ids": ["RUN-2", "VER-1"],
                    "reason": "same defect",
                    "finding": deepcopy(source),
                }
            ]
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 2)
            self.assertIn("collides", " ".join(result["errors"]))
            self.assertEqual(
                {item["finding_id"] for item in result["findings"]}, {"RUN-2", "VER-1"}
            )
            self.assertEqual(result["dismissed_findings"][0]["finding"]["severity"], "high")
            fixture.qa["manual_merges"] = []
            fixture.qa["severity_overrides"] = [
                {
                    "finding_id": "RUN-1",
                    "severity": "medium",
                    "reason": "cannot alter original after dismissal",
                }
            ]
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 2)
            self.assertEqual(result["dismissed_findings"][0]["finding"]["severity"], "high")

    def test_metadata_only_findings_keep_severity_and_render_operation(self) -> None:
        for mode, operation in (("branch", "mode"), ("pr", "rename")):
            with self.subTest(mode=mode, operation=operation):
                temp, fixture = self.fixture(
                    mode=mode, path="scripts/start.sh", diff_kind=operation
                )
                with temp:
                    fixture.add_finding(severity="high")
                    completed, result, report = fixture.execute()
                    self.assertEqual(completed.returncode, 2)
                    self.assertEqual(result["code_verdict"], "NEEDS_WORK")
                    self.assertEqual(len(result["findings"]), 1)
                    self.assertIsNone(result["findings"][0]["line"])
                    self.assertIn("scripts/start.sh:file operation", report)
                    self.assertIn(operation + ":", report)
                    fixture.qa["code_verdict"] = "NEEDS_WORK"
                    completed, result, _ = fixture.execute()
                    self.assertEqual(completed.returncode, 0, completed.stderr)
                    self.assertEqual(result["pipeline_status"], "COMPLETE")

    def test_operation_evidence_requires_exact_metadata_and_authoritative_hash(self) -> None:
        for operation in ("mode", "rename"):
            with self.subTest(operation=operation):
                temp, fixture = self.fixture(
                    mode="branch", path="scripts/start.sh", diff_kind=operation
                )
                with temp:
                    finding = fixture.add_finding(severity="high")
                    fixture.qa["code_verdict"] = "NEEDS_WORK"
                    field = "old_mode" if operation == "mode" else "old_path"
                    finding["evidence"][0][field] = "100644" if operation == "mode" else "other.sh"
                    completed, result, _ = fixture.execute()
                    self.assertEqual(completed.returncode, 2)
                    self.assertEqual(result["findings"], [])
                    finding["evidence"] = [deepcopy(fixture.evidence)]
                    diff_path = Path(fixture.manifest["diff_file"])
                    diff_path.write_text(diff_path.read_text() + "\n")
                    completed, result, _ = fixture.execute()
                    self.assertEqual(completed.returncode, 2)
                    self.assertEqual(result["findings"], [])
                    self.assertIn("diff: sha256 mismatch", result["errors"])

    def test_operation_is_not_a_generic_path_evidence_bypass(self) -> None:
        for mode in ("feature", "branch"):
            with self.subTest(mode=mode):
                temp, fixture = self.fixture(mode=mode)
                with temp:
                    fake_operation: dict[str, Any] = {
                        "kind": "file_operation",
                        "path": fixture.path,
                        "operation": "mode",
                        "old_mode": "100755",
                        "new_mode": "100644",
                    }
                    fixture.add_finding(evidence=fake_operation, severity="high")
                    completed, result, _ = fixture.execute()
                    self.assertEqual(completed.returncode, 2)
                    self.assertEqual(result["findings"], [])
        temp, fixture = self.fixture(mode="branch", path="scripts/start.sh", diff_kind="mode")
        with temp:
            parsed = parse_diff(Path(fixture.manifest["diff_file"]).read_text())
            for evidence in (source_evidence(fixture.path), binary_evidence(fixture.path)):
                valid, _ = validate_evidence(evidence, fixture.manifest, parsed, {})
                self.assertFalse(valid)

    def test_operation_metadata_must_be_complete_and_consistent(self) -> None:
        invalid = (
            "old mode 100755\n",
            "old mode 100755\nnew mode 100755\n",
            "old mode 100755\nnew mode 999999\n",
            "old mode 100755\nnew mode 100644\nnew mode 100600\n",
            "rename from scripts/old.sh\n",
            "rename from scripts/wrong.sh\nrename to scripts/start.sh\n",
            "rename from scripts/old.sh\nrename to scripts/wrong.sh\n",
        )
        for metadata in invalid:
            with self.subTest(metadata=metadata):
                with self.assertRaises(ValueError):
                    parse_diff("diff --git a/scripts/old.sh b/scripts/start.sh\n" + metadata)

    def test_real_git_metadata_diff_with_spaces_and_combined_operations(self) -> None:
        temp, fixture = self.fixture(mode="branch", path="scripts/new name.sh", diff_kind="rename")
        with temp:

            def git(*argv: str) -> str:
                return subprocess.run(
                    ["git", *argv], cwd=fixture.root, check=True, text=True, capture_output=True
                ).stdout

            git("init", "-q")
            source = fixture.root / "scripts/old.sh"
            source.parent.mkdir(exist_ok=True)
            source.write_text("#!/bin/sh\nprintf start\n")
            source.chmod(0o755)
            git("add", "scripts/old.sh")
            git(
                "-c",
                "user.name=Test",
                "-c",
                "user.email=test@example.invalid",
                "commit",
                "-qm",
                "base",
            )
            source.rename(fixture.root / fixture.path)
            (fixture.root / fixture.path).chmod(0o644)
            git("add", "-A", "scripts")
            diff = git("diff", "--cached", "--find-renames")
            parsed = parse_diff(diff)
            self.assertEqual(len(parsed["file_operations"][fixture.path]), 2)
            self.assertEqual(parsed["new"], set())
            self.assertEqual(parsed["old"], set())
            diff_path = Path(fixture.manifest["diff_file"])
            diff_path.write_text(diff)
            fixture.manifest["diff_sha256"] = hashlib.sha256(diff.encode()).hexdigest()
            fixture.manifest["scope_hash"] = canonical_scope_hash(fixture.manifest)
            for artifact in [*fixture.tools, *fixture.lenses, fixture.qa]:
                artifact.update(identity(fixture.manifest))
            finding = fixture.add_finding(severity="high")
            finding["evidence"].append(
                {
                    "kind": "file_operation",
                    "path": fixture.path,
                    "operation": "mode",
                    "old_mode": "100755",
                    "new_mode": "100644",
                }
            )
            fixture.qa["code_verdict"] = "NEEDS_WORK"
            completed, result, _ = fixture.execute()
            self.assertEqual(completed.returncode, 0, completed.stderr)
            self.assertEqual(result["pipeline_status"], "COMPLETE")

    def test_conditional_file_routing_is_mandatory(self) -> None:
        temp, fixture = self.fixture(
            path="lib/packages/features/demo/presentation/demo_widget.dart"
        )
        with temp:
            runtime = next(item for item in fixture.lenses if item["lens"] == "runtime-safety")
            runtime["gates"] = [gate for gate in runtime["gates"] if gate["gate_id"] != "RUN-UI"]
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
        cases: dict[str, Any] = {
            "infrastructure/anistar/lib/src/html_anistar_client.dart": (
                "system-design",
                "SYS-CLIENT",
            ),
            "lib/app/app_container.dart": ("system-design", "SYS-CLIENT"),
            "lib/packages/features/catalog/data/repositories/catalog_repository.dart": (
                "system-design",
                "SYS-DATA",
            ),
            "test/packages/features/catalog/data/mapper_test.dart": ("system-design", "SYS-DATA"),
            "test/infrastructure/anistar/episode_dto_test.dart": ("system-design", "SYS-DATA"),
            "test/packages/features/catalog/repositories_test.dart": (
                "runtime-safety",
                "RUN-ASYNC",
            ),
            "infrastructure/storage/lib/src/cookie_storage.dart": ("runtime-safety", "RUN-SESSION"),
            "lib/packages/features/player/presentation/player_bloc.dart": (
                "runtime-safety",
                "RUN-PLAYER",
            ),
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
            ".factory/contracts/common/session.md",
            ".factory/skills/factory-code-review/tests/test_review_scripts.py",
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
            self.assertIn("- ✅ **Protocol:** `COMPLETE`", rendered)
            self.assertIn("🚧 **Review does not permit approval:**", rendered)
            self.assertIn("### 🟡 Medium", rendered)
            self.assertIn("💥 **Impact:**", rendered)
            self.assertIn("🛠 **How to fix:**", rendered)
            self.assertIn("🧾 **Details:**", rendered)
            self.assertIn("<summary>🧰 Review internals</summary>", rendered)

            result["pipeline_status"] = "INCOMPLETE"
            result["review_id"] = "<script>alert(1)</script>"
            report_path = fixture.root / "visual-report.md"
            render_report(report_path, result)
            rendered = report_path.read_text(encoding="utf-8")
            self.assertIn("⚠️ **Review does not permit approval:** review incomplete", rendered)
            self.assertNotIn("<script>", rendered)
            self.assertIn(r"\<script\>alert\(1\)\</script\>", rendered)


if __name__ == "__main__":
    unittest.main(verbosity=2)
