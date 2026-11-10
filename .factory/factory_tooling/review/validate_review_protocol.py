#!/usr/bin/env python3
"""Validate current-only Factory review artifacts and render one safe report."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from factory_tooling.gates.catalog import core_result
from factory_tooling.gates.gate_contract import digest, evidence
from factory_tooling.review.render_review_report import render_report
from factory_tooling.review.review_contracts import CONFIDENCES as CONFIDENCES
from factory_tooling.review.review_contracts import GATE_STATUSES as GATE_STATUSES
from factory_tooling.review.review_contracts import (
    LENSES,
    UNIVERSAL_GATES,
    expected_gates,
    validate_manifest,
)
from factory_tooling.review.review_contracts import SEVERITIES as SEVERITIES
from factory_tooling.review.review_contracts import VERDICTS as VERDICTS
from factory_tooling.review.review_contracts import identity_errors as identity_errors
from factory_tooling.review.review_diff import load_diff_context
from factory_tooling.review.review_evidence import validate_evidence as validate_evidence
from factory_tooling.review.review_evidence import validate_tool_results
from factory_tooling.review.review_io import load_object
from factory_tooling.review.review_lenses import validate_finding as validate_finding

# Compatibility exports: existing imports and command entry points stay valid.
from factory_tooling.review.review_lenses import (
    validate_lens,
)
from factory_tooling.review.review_qa import (
    apply_qa,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--lens-output", type=Path, action="append", required=True)
    parser.add_argument("--tool-result", type=Path, action="append", default=[])
    parser.add_argument("--qa-output", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--report-output", type=Path, required=True)
    return parser.parse_args()


def validate_protocol(args: argparse.Namespace) -> tuple[dict[str, Any], int]:
    errors: list[str] = []
    try:
        manifest = load_object(args.manifest)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        manifest = {}
        errors.append(f"manifest: {exc}")
    errors.extend(validate_manifest(manifest))
    diff, diff_errors = load_diff_context(manifest)
    errors.extend(diff_errors)
    tools, tool_commands, tool_errors, tool_failures = validate_tool_results(
        args.tool_result, manifest
    )
    errors.extend(tool_errors)

    try:
        registry = expected_gates(manifest.get("scope_files", []), manifest.get("project_policy"))
    except (ValueError, TypeError) as exc:
        errors.append(str(exc))
        registry = {lens: list(gates) for lens, gates in UNIVERSAL_GATES.items()}
    lens_names: list[str] = []
    findings: list[dict[str, Any]] = []
    gate_coverage: dict[str, list[str]] = {}
    for path in args.lens_output:
        try:
            lens, valid, lens_errors, gates = validate_lens(
                load_object(path), manifest, diff, tool_commands, registry
            )
        except (OSError, json.JSONDecodeError, ValueError) as exc:
            errors.append(f"{path}: {exc}")
            continue
        errors.extend(lens_errors)
        findings.extend(valid)
        if lens is not None:
            lens_names.append(lens)
            gate_coverage[lens] = gates
    duplicates = {lens for lens, count in Counter(lens_names).items() if count > 1}
    if duplicates:
        errors.append(f"lenses: duplicate outputs {sorted(duplicates)}")
    if set(lens_names) != set(LENSES) or len(lens_names) != len(LENSES):
        errors.append("lenses: exactly three unique outputs required")

    duplicate_ids = {
        finding_id
        for finding_id, count in Counter(item["finding_id"] for item in findings).items()
        if count > 1
    }
    if duplicate_ids:
        errors.append(f"findings: duplicate IDs {sorted(duplicate_ids)}")
        findings = [item for item in findings if item["finding_id"] not in duplicate_ids]
    try:
        findings, verdict, qa_errors, notes, semantic_gap, dismissed_findings = apply_qa(
            load_object(args.qa_output), findings, manifest, diff, tool_commands, registry
        )
        errors.extend(qa_errors)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        errors.append(f"qa: {exc}")
        verdict, notes, semantic_gap, dismissed_findings = "NEEDS_WORK", [], None, []

    post_qa_duplicates = {
        finding_id
        for finding_id, count in Counter(item["finding_id"] for item in findings).items()
        if count > 1
    }
    if post_qa_duplicates:
        errors.append(f"findings: post-QA duplicate IDs {sorted(post_qa_duplicates)}")
        findings = [item for item in findings if item["finding_id"] not in post_qa_duplicates]
    merge_blocker = bool(tool_failures) or any(
        item["severity"] in {"critical", "high"} for item in findings
    )
    if tool_failures:
        verdict = "NEEDS_WORK"
    elif verdict == "APPROVE" and merge_blocker:
        errors.append("verdict: APPROVE forbidden by Critical/High finding")
        verdict = "NEEDS_WORK"
    if errors and verdict == "APPROVE":
        verdict = "NEEDS_WORK"
    if verdict != "RETHINK":
        semantic_gap = None
    failing_commands: list[dict[str, Any]] = []
    for tool_id, tool in tools.items():
        commands = tool.get("commands")
        if not isinstance(commands, list):
            continue
        for index, command in enumerate(commands):
            if isinstance(command, dict) and command.get("exit_code") != 0:
                failing_commands.append({"tool_id": tool_id, "command_index": index, **command})
    result = {
        field: manifest.get(field)
        for field in ("schema_version", "review_id", "mode", "base_sha", "head_sha", "scope_hash")
    }
    result.update(
        {
            "pipeline_status": "INCOMPLETE" if errors else "COMPLETE",
            "code_verdict": verdict,
            "semantic_gap": semantic_gap,
            "findings": findings,
            "dismissed_findings": dismissed_findings,
            "tool_statuses": {
                tool_id: tools[tool_id].get("status") if tool_id in tools else "MISSING"
                for tool_id in [c["id"] for c in manifest.get("checks", [])]
            },
            "tool_failures": tool_failures,
            "failing_commands": failing_commands,
            "gate_coverage": {
                lens: {"expected": registry[lens], "reported": gate_coverage.get(lens, [])}
                for lens in LENSES
            },
            "qa_notes": notes,
            "context_limitations": manifest.get("context", {}).get("limitations", []),
            "errors": errors,
            "done_signal": "FAILED" if errors else "COMPLETE",
        }
    )
    result["gate_result"] = core_result(
        "code-review.complete",
        str(manifest.get("review_id") or args.manifest),
        digest(
            {
                "policy": manifest.get("project_policy"),
                "validators": {p.name: p.read_text() for p in Path(__file__).parent.glob("*.py")},
            }
        ),
        digest(
            {
                str(p): Path(p).read_text() if Path(p).is_file() else "MISSING"
                for p in [args.manifest, args.qa_output, *args.lens_output, *args.tool_result]
            }
        ),
        [
            evidence(
                "review-protocol",
                "BLOCKED" if errors else "PASS",
                "; ".join(errors) or "Review report complete; code verdict is separate",
                [str(args.manifest)],
            )
        ],
    )
    return result, 2 if errors else 0


def main() -> int:
    args = parse_args()
    result, exit_code = validate_protocol(args)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    render_report(args.report_output, result)
    print(json.dumps(result, ensure_ascii=False))
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
