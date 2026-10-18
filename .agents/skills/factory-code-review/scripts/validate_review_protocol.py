#!/usr/bin/env python3
"""Validate current-only Factory review artifacts and render one safe report."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from copy import deepcopy
from pathlib import Path
from typing import Any

from render_review_report import render_report
from review_protocol_schema import (
    CONFIDENCES,
    GATE_STATUSES,
    LENSES,
    REGISTRY_RULE_IDS,
    SEVERITIES,
    TOOL_IDS,
    UNIVERSAL_GATES,
    VERDICTS,
    expected_gates,
    identity_errors,
    load_diff_context,
    load_object,
    validate_evidence,
    validate_manifest,
    validate_tool_results,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--lens-output", type=Path, action="append", required=True)
    parser.add_argument("--tool-result", type=Path, action="append", required=True)
    parser.add_argument("--qa-output", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--report-output", type=Path, required=True)
    return parser.parse_args()


def validate_finding(
    finding: Any,
    lens: str,
    owned_gates: set[str],
    manifest: dict[str, Any],
    diff: dict[str, Any],
    tool_commands: dict[str, int],
) -> tuple[dict[str, Any] | None, str | None]:
    if not isinstance(finding, dict):
        return None, "finding must be object"
    required_text = ("finding_id", "gate_id", "path", "rule", "description", "fix")
    if any(not isinstance(finding.get(field), str) or not finding[field] for field in required_text):
        return None, "finding required text missing"
    if finding["gate_id"] not in owned_gates:
        return None, "finding gate not owned by lens"
    if finding["path"] not in manifest.get("scope_files", []):
        return None, "finding path outside scope"
    if finding.get("severity") not in SEVERITIES or finding.get("confidence") not in CONFIDENCES:
        return None, "finding severity/confidence invalid"
    rule_id = finding.get("rule_id")
    if rule_id is not None and rule_id not in REGISTRY_RULE_IDS:
        return None, "finding rule_id not in registry"
    evidence = finding.get("evidence")
    if not isinstance(evidence, list) or not evidence:
        return None, "finding evidence missing"
    for item in evidence:
        ok, reason = validate_evidence(item, manifest, diff, tool_commands)
        if not ok:
            return None, reason
    line = finding.get("line")
    matching_source = any(
        isinstance(item, dict)
        and item.get("kind") == "source"
        and item.get("path") == finding["path"]
        and item.get("line") == line
        for item in evidence
    )
    matching_binary = any(
        isinstance(item, dict)
        and item.get("kind") == "binary"
        and item.get("path") == finding["path"]
        for item in evidence
    )
    if not ((type(line) is int and line > 0 and matching_source) or (line is None and matching_binary)):
        return None, "finding path/line lacks matching source or binary evidence"
    normalized = deepcopy(finding)
    normalized["found_by"] = [lens]
    normalized["source_ids"] = [finding["finding_id"]]
    return normalized, None


def validate_lens(
    value: dict[str, Any],
    manifest: dict[str, Any],
    diff: dict[str, Any],
    tool_commands: dict[str, int],
    registry: dict[str, list[str]],
) -> tuple[str | None, list[dict[str, Any]], list[str], list[str]]:
    lens = value.get("lens")
    errors = identity_errors(value, manifest, f"lens {lens}")
    if lens not in LENSES:
        return None, [], [*errors, "lens: unknown lens"], []
    identity_valid = not errors
    if value.get("done_signal") != "COMPLETE":
        errors.append(f"lens {lens}: done_signal must be COMPLETE")
    gates = value.get("gates")
    findings = value.get("findings")
    if not isinstance(gates, list):
        errors.append(f"lens {lens}: gates must be list")
        gates = []
    if not isinstance(findings, list):
        errors.append(f"lens {lens}: findings must be list")
        findings = []
    expected = set(registry[lens])
    universal = set(UNIVERSAL_GATES[lens])
    gate_status: dict[str, str] = {}
    gate_ids = [gate.get("gate_id") for gate in gates if isinstance(gate, dict)]
    duplicates = {gate_id for gate_id, count in Counter(gate_ids).items() if count > 1}
    if duplicates:
        errors.append(f"lens {lens}: duplicate gates {sorted(duplicates)}")
    for gate in gates:
        if not isinstance(gate, dict):
            errors.append(f"lens {lens}: malformed gate")
            continue
        gate_id, status = gate.get("gate_id"), gate.get("status")
        if gate_id not in expected:
            errors.append(f"lens {lens}: foreign gate {gate_id}")
            continue
        if status not in GATE_STATUSES:
            errors.append(f"lens {lens}: gate {gate_id} invalid status")
            continue
        gate_status[gate_id] = status
        if status in {"NOT_APPLICABLE", "NOT_RUN"}:
            if not isinstance(gate.get("reason"), str) or not gate["reason"]:
                errors.append(f"lens {lens}: gate {gate_id} requires reason")
            if status == "NOT_APPLICABLE" and gate_id in universal:
                errors.append(f"lens {lens}: universal gate {gate_id} cannot be NOT_APPLICABLE")
            if status == "NOT_RUN":
                errors.append(f"lens {lens}: gate {gate_id} NOT_RUN")
            continue
        evidence = gate.get("evidence")
        if not isinstance(evidence, list) or not evidence:
            errors.append(f"lens {lens}: gate {gate_id} requires evidence")
            continue
        for item in evidence:
            ok, reason = validate_evidence(item, manifest, diff, tool_commands)
            if not ok:
                errors.append(f"lens {lens}: gate {gate_id}: {reason}")
    missing = sorted(expected - set(gate_ids))
    if missing:
        errors.append(f"lens {lens}: missing gates {missing}")

    valid_findings: list[dict[str, Any]] = []
    if identity_valid:
        for index, finding in enumerate(findings):
            normalized, reason = validate_finding(
                finding, lens, expected, manifest, diff, tool_commands
            )
            if reason:
                errors.append(f"lens {lens}: finding[{index}] {reason}")
                continue
            assert normalized is not None
            status = gate_status.get(normalized["gate_id"])
            if status is not None and status != "FINDING":
                errors.append(
                    f"lens {lens}: finding {normalized['finding_id']} contradicts gate {status}"
                )
                continue
            valid_findings.append(normalized)
    for gate_id, status in gate_status.items():
        if status == "FINDING" and not any(item["gate_id"] == gate_id for item in valid_findings):
            errors.append(f"lens {lens}: gate {gate_id} FINDING has no valid finding")
    return lens, valid_findings, errors, gate_ids


def apply_qa(
    qa: dict[str, Any],
    findings: list[dict[str, Any]],
    manifest: dict[str, Any],
    diff: dict[str, Any],
    tool_commands: dict[str, int],
    registry: dict[str, list[str]],
) -> tuple[list[dict[str, Any]], str, list[str], list[str], str | None]:
    errors = identity_errors(qa, manifest, "qa")
    if errors:
        return findings, "NEEDS_WORK", errors, [], None
    verdict = qa.get("code_verdict")
    if verdict not in VERDICTS:
        errors.append("qa: invalid code_verdict")
        verdict = "NEEDS_WORK"
    notes = qa.get("notes", [])
    if not isinstance(notes, list) or any(not isinstance(note, str) for note in notes):
        errors.append("qa: notes must be strings")
        notes = []
    semantic_gap = qa.get("semantic_gap")
    if verdict == "RETHINK" and (not isinstance(semantic_gap, str) or not semantic_gap):
        errors.append("qa: RETHINK requires semantic_gap")
    if verdict != "RETHINK" and semantic_gap not in (None, ""):
        errors.append("qa: semantic_gap only allowed for RETHINK")

    gate_owners = {
        gate_id: lens for lens, gate_ids in registry.items() for gate_id in gate_ids
    }
    added_findings = qa.get("added_findings", [])
    if not isinstance(added_findings, list):
        errors.append("qa: added_findings must be list")
        added_findings = []
    valid_added: list[dict[str, Any]] = []
    retained_ids = {item["finding_id"] for item in findings}
    for index, finding in enumerate(added_findings):
        gate_id = finding.get("gate_id") if isinstance(finding, dict) else None
        owner = gate_owners.get(gate_id)
        if owner is None:
            errors.append(f"qa: added_finding[{index}] gate not in current registry")
            continue
        normalized, added_error = validate_finding(
            finding, owner, set(registry[owner]), manifest, diff, tool_commands
        )
        if added_error:
            errors.append(f"qa: added_finding[{index}] {added_error}")
            continue
        assert normalized is not None
        if normalized["finding_id"] in retained_ids:
            errors.append(
                f"qa: added_finding[{index}] finding_id collides with retained finding"
            )
            continue
        normalized["found_by"] = ["qa"]
        valid_added.append(normalized)
        retained_ids.add(normalized["finding_id"])
    findings = [*findings, *valid_added]

    by_id = {item["finding_id"]: item for item in findings}
    overrides = qa.get("severity_overrides", [])
    if not isinstance(overrides, list):
        errors.append("qa: severity_overrides must be list")
        overrides = []
    for item in overrides:
        if not isinstance(item, dict):
            errors.append("qa: malformed severity override")
            continue
        target = by_id.get(item.get("finding_id"))
        if target is None or item.get("severity") not in SEVERITIES:
            errors.append("qa: severity override target/value invalid")
            continue
        if not isinstance(item.get("reason"), str) or not item["reason"]:
            errors.append("qa: severity override requires reason")
            continue
        target["severity"] = item["severity"]
        target["qa_severity_reason"] = item["reason"]

    merges = qa.get("manual_merges", [])
    if not isinstance(merges, list):
        errors.append("qa: manual_merges must be list")
        merges = []
    consumed: set[str] = set()
    merged: list[dict[str, Any]] = []
    merge_ids: set[str] = set()
    severity_rank = {"medium": 0, "high": 1, "critical": 2}
    for item in merges:
        if not isinstance(item, dict):
            errors.append("qa: malformed manual merge")
            continue
        source_ids, reason, candidate = (
            item.get("source_ids"),
            item.get("reason"),
            item.get("finding"),
        )
        invalid = (
            not isinstance(source_ids, list)
            or len(source_ids) < 2
            or len(source_ids) != len(set(source_ids))
            or any(source_id not in by_id or source_id in consumed for source_id in source_ids)
            or not isinstance(reason, str)
            or not reason
            or not isinstance(candidate, dict)
        )
        if invalid:
            errors.append("qa: manual merge source_ids/reason/finding invalid")
            continue
        candidate_id = candidate.get("finding_id")
        if candidate_id in merge_ids or (
            candidate_id in by_id and candidate_id not in source_ids
        ):
            errors.append("qa: manual merge finding_id collides with retained finding")
            continue
        source_severity = max(
            (by_id[source_id]["severity"] for source_id in source_ids),
            key=severity_rank.__getitem__,
        )
        if severity_rank.get(candidate.get("severity"), -1) < severity_rank[source_severity]:
            errors.append("qa: manual merge cannot lower source severity")
            continue
        source_lenses = sorted(
            {lens for source_id in source_ids for lens in by_id[source_id]["found_by"]}
        )
        source_gates = {by_id[source_id]["gate_id"] for source_id in source_ids}
        normalized, merge_error = validate_finding(
            candidate, source_lenses[0], source_gates, manifest, diff, tool_commands
        )
        if merge_error:
            errors.append(f"qa: manual merge {merge_error}")
            continue
        assert normalized is not None
        normalized["source_ids"] = source_ids
        normalized["found_by"] = source_lenses
        normalized["qa_merge_reason"] = reason
        evidence_by_key = {
            json.dumps(evidence, sort_keys=True, separators=(",", ":")): evidence
            for source_id in source_ids
            for evidence in by_id[source_id]["evidence"]
        }
        for evidence in normalized["evidence"]:
            key = json.dumps(evidence, sort_keys=True, separators=(",", ":"))
            evidence_by_key[key] = evidence
        normalized["evidence"] = list(evidence_by_key.values())
        merged.append(normalized)
        merge_ids.add(normalized["finding_id"])
        consumed.update(source_ids)
    findings = [item for item in findings if item["finding_id"] not in consumed] + merged
    return findings, verdict, errors, notes, semantic_gap if isinstance(semantic_gap, str) else None


def auto_dedupe(findings: list[dict[str, Any]]) -> list[dict[str, Any]]:
    output: list[dict[str, Any]] = []
    groups: dict[tuple[str, str, Any], list[dict[str, Any]]] = {}
    for finding in findings:
        rule_id = finding.get("rule_id")
        if rule_id in REGISTRY_RULE_IDS:
            groups.setdefault((rule_id, finding["path"], finding["line"]), []).append(finding)
        else:
            output.append(finding)
    for items in groups.values():
        first = deepcopy(items[0])
        comparable = ("gate_id", "severity", "confidence", "rule", "description", "fix")
        if len(items) == 1 or any(
            any(item.get(field) != first.get(field) for field in comparable)
            for item in items[1:]
        ):
            output.extend(items)
            continue
        first["source_ids"] = sorted(
            {source for item in items for source in item["source_ids"]}
        )
        first["found_by"] = sorted(
            {lens for item in items for lens in item["found_by"]}
        )
        evidence = {
            json.dumps(item, sort_keys=True, separators=(",", ":")): item
            for finding in items
            for item in finding["evidence"]
        }
        first["evidence"] = list(evidence.values())
        output.append(first)
    return output


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

    registry = expected_gates(manifest.get("scope_files", []))
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
        findings, verdict, qa_errors, notes, semantic_gap = apply_qa(
            load_object(args.qa_output), findings, manifest, diff, tool_commands, registry
        )
        errors.extend(qa_errors)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        errors.append(f"qa: {exc}")
        verdict, notes, semantic_gap = "NEEDS_WORK", [], None

    findings = auto_dedupe(findings)
    post_qa_duplicates = {
        finding_id
        for finding_id, count in Counter(item["finding_id"] for item in findings).items()
        if count > 1
    }
    if post_qa_duplicates:
        errors.append(f"findings: post-QA duplicate IDs {sorted(post_qa_duplicates)}")
        findings = [
            item for item in findings if item["finding_id"] not in post_qa_duplicates
        ]
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
                failing_commands.append(
                    {"tool_id": tool_id, "command_index": index, **command}
                )
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
            "tool_statuses": {
                tool_id: tools[tool_id].get("status") if tool_id in tools else "MISSING"
                for tool_id in TOOL_IDS
            },
            "tool_failures": tool_failures,
            "failing_commands": failing_commands,
            "gate_coverage": {
                lens: {"expected": registry[lens], "reported": gate_coverage.get(lens, [])}
                for lens in LENSES
            },
            "qa_notes": notes,
            "errors": errors,
            "done_signal": "FAILED" if errors else "COMPLETE",
        }
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
