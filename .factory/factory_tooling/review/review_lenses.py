"""Per-lens findings, evidence and gate validation."""

from __future__ import annotations

from collections import Counter
from copy import deepcopy
from typing import Any

from factory_tooling.project.profile_io import validate_snapshot as validate_snapshot
from factory_tooling.review.review_contracts import (
    CONFIDENCES,
    GATE_STATUSES,
    LENSES,
    SEVERITIES,
    UNIVERSAL_GATES,
    identity_errors,
)
from factory_tooling.review.review_evidence import validate_evidence


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
    required_text = ("finding_id", "rule", "description", "fix")
    if any(
        not isinstance(finding.get(field), str) or not finding[field] for field in required_text
    ):
        return None, "finding required text missing"
    gate_id = finding.get("gate_id")
    if gate_id is not None and (not isinstance(gate_id, str) or gate_id not in owned_gates):
        return None, "finding gate not owned by lens"
    missing = finding.get("kind") == "missing-requirement"
    if not missing and finding.get("path") not in manifest.get("scope_files", []):
        return None, "finding path outside scope"
    severity, confidence = finding.get("severity"), finding.get("confidence")
    if (
        not isinstance(severity, str)
        or severity not in SEVERITIES
        or not isinstance(confidence, str)
        or confidence not in CONFIDENCES
    ):
        return None, "finding severity/confidence invalid"
    if "rule_id" in finding:
        return None, "rule_id removed; use criterion or a free finding"
    if missing:
        if finding.get("path") is not None or finding.get("line") is not None:
            return None, "missing requirement must not fabricate a source location"
        if (
            not isinstance(finding.get("investigation"), str)
            or not finding["investigation"].strip()
        ):
            return None, "missing requirement needs investigation explanation"
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
    matching_operation = any(
        isinstance(item, dict)
        and item.get("kind") == "file_operation"
        and item.get("path") == finding["path"]
        for item in evidence
    )
    requirement = any(e.get("kind") == "requirement" for e in evidence)
    inspection = any(
        e.get("kind") in {"inspection", "source", "tool", "file_operation"} for e in evidence
    )
    if missing and not (requirement and inspection):
        return None, "missing requirement needs requirement and investigation evidence"
    if not missing and not (
        (type(line) is int and line > 0 and matching_source)
        or (line is None and (matching_binary or matching_operation))
    ):
        return None, "finding path/line lacks matching source, binary, or file operation evidence"
    normalized = deepcopy(finding)
    normalized.setdefault("gate_id", None)
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
    if not isinstance(value, dict):
        return None, [], ["reviewer result must be object"], []
    lens = value.get("lens")
    errors = identity_errors(value, manifest, f"lens {lens}")
    if not isinstance(lens, str) or lens not in LENSES:
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
    gate_ids = [
        gate["gate_id"]
        for gate in gates
        if isinstance(gate, dict) and isinstance(gate.get("gate_id"), str)
    ]
    duplicates = {gate_id for gate_id, count in Counter(gate_ids).items() if count > 1}
    if duplicates:
        errors.append(f"lens {lens}: duplicate gates {sorted(str(item) for item in duplicates)}")
    for gate in gates:
        if not isinstance(gate, dict):
            errors.append(f"lens {lens}: malformed gate")
            continue
        gate_id, status = gate.get("gate_id"), gate.get("status")
        if not isinstance(gate_id, str) or gate_id not in expected:
            errors.append(f"lens {lens}: foreign gate {gate_id}")
            continue
        if not isinstance(status, str) or status not in GATE_STATUSES:
            errors.append(f"lens {lens}: gate {gate_id} invalid status")
            continue
        gate_status[gate_id] = status
        if (
            gate_id == "SYS-INTENT"
            and not manifest.get("context", {}).get("requirements")
            and status != "NOT_RUN"
        ):
            errors.append(
                "AcceptanceReviewer: no grounded requirements; SYS-INTENT must be NOT_RUN"
            )
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
            normalized, finding_error = validate_finding(
                finding, lens, expected, manifest, diff, tool_commands
            )
            if finding_error:
                errors.append(f"lens {lens}: finding[{index}] {finding_error}")
                continue
            assert normalized is not None
            finding_status = gate_status.get(normalized["gate_id"])
            if finding_status is not None and finding_status != "FINDING":
                errors.append(
                    f"lens {lens}: finding {normalized['finding_id']} contradicts gate {finding_status}"
                )
                continue
            valid_findings.append(normalized)
    for gate_id, status in gate_status.items():
        if status == "FINDING" and not any(item["gate_id"] == gate_id for item in valid_findings):
            errors.append(f"lens {lens}: gate {gate_id} FINDING has no valid finding")
    return lens, valid_findings, errors, gate_ids
