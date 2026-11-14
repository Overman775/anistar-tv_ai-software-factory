from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from copy import deepcopy
from pathlib import Path
from typing import Any

from factory.paths import FACTORY_ROOT
from factory.project.profile_io import load_profile, snapshot
from factory.review.review_contracts import expected_gates as resolve_gates
from tests.fixture_bundle import ROOT as FIXTURE_ROOT

POLICY = snapshot(
    load_profile(FIXTURE_ROOT / "project/project.yaml"), source="fixture:accepted-baseline"
)


def expected_gates(paths: list[str]) -> dict[str, list[str]]:
    return resolve_gates(paths, POLICY)


SCRIPTS = FACTORY_ROOT / "gates/skills/code-review"
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
        self.evidence: dict[str, Any]
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
            source_sha256: dict[str, str] | None = {
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
            elif diff_kind == "mode":
                self.evidence = {
                    "kind": "file_operation",
                    "path": path,
                    "operation": "mode",
                    "old_mode": "100755",
                    "new_mode": "100644",
                }
            elif diff_kind == "rename":
                self.evidence = {
                    "kind": "file_operation",
                    "path": path,
                    "operation": "rename",
                    "old_path": "scripts/old.sh",
                    "new_path": path,
                }
            else:
                self.evidence = source_evidence(path)
        self.manifest: dict[str, Any] = {
            "schema_version": "4",
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
        self.manifest["project_policy"] = {**POLICY}
        from factory.project.profile_io import fingerprint

        if self.manifest["mode"] in {"branch", "pr"}:
            self.manifest["project_policy"]["source"] = "git:" + self.manifest["base_sha"]
            self.manifest["project_policy"]["sha256"] = fingerprint(
                {k: v for k, v in self.manifest["project_policy"].items() if k != "sha256"}
            )
        self.manifest.update(
            context={
                "sources": [
                    {
                        "id": "task",
                        "locator": "user:request",
                        "content": "Return value 1",
                        "captured_at": "fixture",
                    }
                ],
                "requirements": [{"id": "AC1", "source_id": "task", "text": "Return value 1"}],
                "limitations": [],
                "pr": {
                    "url": "https://example.test/pr/1",
                    "title": "Return value",
                    "body": "",
                    "captured_at": "fixture",
                    "head_sha": "b" * 40,
                }
                if mode == "pr"
                else None,
            },
            additional_checks=[
                {
                    "id": cid,
                    "method": "fixture command",
                    "execution": {"argv": ["/usr/bin/true"], "cwd": "."},
                }
                for cid in ["static", "tests", "deps"]
            ],
            command_selection_reason="Fixture verifies commands",
            source_evidence={},
        )
        from factory.review.review_plan import prepare

        self.manifest = prepare(self.manifest)
        self.registry = expected_gates([path])
        self.tools = [self._tool(tool_id) for tool_id in ("static", "tests", "deps")]
        self.lenses = [self._lens(lens) for lens in self.registry]
        self.qa: dict[str, Any] = {
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
        if kind == "mode":
            return f"diff --git a/{path} b/{path}\nold mode 100755\nnew mode 100644\n"
        if kind == "rename":
            return (
                f"diff --git a/scripts/old.sh b/{path}\n"
                f"similarity index 100%\nrename from scripts/old.sh\nrename to {path}\n"
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
        finding: dict[str, Any] = {
            "finding_id": finding_id,
            "gate_id": selected_gate,
            "path": self.path,
            "line": (
                None
                if selected_evidence["kind"] in {"binary", "file_operation"}
                else selected_evidence["line"]
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

    def rebind(self) -> None:
        from factory.review.review_plan import prepare

        self.manifest = prepare(self.manifest)
        for artifact in [*self.tools, *self.lenses, self.qa]:
            artifact.update(identity(self.manifest))

    def execute(self) -> tuple[subprocess.CompletedProcess[str], dict[str, Any], str]:
        manifest_path = self.root / "manifest.json"
        lens_paths = [self.root / f"lens-{index}.json" for index in range(len(self.lenses))]
        tool_paths = [self.root / f"tool-{index}.json" for index in range(len(self.tools))]
        qa_path = self.root / "qa.json"
        output_path = self.root / "result.json"
        report_path = self.root / "report.md"
        write_json(manifest_path, self.manifest)
        for path, value in zip(lens_paths, self.lenses, strict=True):
            write_json(path, value)
        for path, value in zip(tool_paths, self.tools, strict=True):
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
