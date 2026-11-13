"""Per-lens findings, evidence and gate validation."""

from __future__ import annotations

from collections import Counter
from copy import deepcopy
from typing import Any

from pydantic import TypeAdapter, ValidationError

from factory_tooling.project.profile_io import validate_snapshot as validate_snapshot
from factory_tooling.review.review_contracts import (
    UNIVERSAL_GATES,
    identity_errors,
)
from factory_tooling.review.review_evidence import validate_evidence
from factory_tooling.review.review_shapes import Finding, LensGate, LensResult
from factory_tooling.validation import validation_message

FINDING = TypeAdapter[Finding](Finding)
LENS_GATE = TypeAdapter[LensGate](LensGate)
LENS_RESULT = TypeAdapter[LensResult](LensResult)


def validate_finding(
    raw: object,
    lens: str,
    owned_gates: set[str],
    manifest: dict[str, Any],
    diff: dict[str, Any],
    tool_commands: dict[str, int],
) -> tuple[dict[str, Any] | None, str | None]:
    try:
        finding = FINDING.validate_python(raw)
    except ValidationError as exc:
        return None, validation_message("Invalid finding", exc, FINDING)
    gate_id = finding.get("gate_id")
    if gate_id is not None and gate_id not in owned_gates:
        return None, "finding gate not owned by lens"
    missing = finding.get("kind") == "missing-requirement"
    if not missing and finding.get("path") not in manifest.get("scope_files", []):
        return None, "finding path outside scope"
    if missing:
        if finding.get("path") is not None or finding.get("line") is not None:
            return None, "missing requirement must not fabricate a source location"
        if "investigation" not in finding:
            return None, "missing requirement needs investigation explanation"
    evidence = finding["evidence"]
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
    requirement = any(isinstance(e, dict) and e.get("kind") == "requirement" for e in evidence)
    inspection = any(
        isinstance(e, dict) and e.get("kind") in {"inspection", "source", "tool", "file_operation"}
        for e in evidence
    )
    if missing and not (requirement and inspection):
        return None, "missing requirement needs requirement and investigation evidence"
    if not missing and not (
        (type(line) is int and line > 0 and matching_source)
        or (line is None and (matching_binary or matching_operation))
    ):
        return None, "finding path/line lacks matching source, binary, or file operation evidence"
    normalized = dict(deepcopy(finding))
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
    try:
        result = LENS_RESULT.validate_python(value)
    except ValidationError as exc:
        return None, [], [validation_message("Invalid lens result", exc, LENS_RESULT)], []
    lens = result["lens"]
    errors = identity_errors(dict(result), manifest, f"lens {lens}")
    identity_valid = not errors
    gates = []
    for raw_gate in result["gates"]:
        try:
            gates.append(LENS_GATE.validate_python(raw_gate))
        except ValidationError as exc:
            errors.append(validation_message(f"Invalid lens {lens} gate", exc, LENS_GATE))
    findings = result["findings"]
    expected = set(registry[lens])
    universal = set(UNIVERSAL_GATES[lens])
    gate_status: dict[str, str] = {}
    gate_ids = [gate["gate_id"] for gate in gates]
    duplicates = {gate_id for gate_id, count in Counter(gate_ids).items() if count > 1}
    if duplicates:
        errors.append(f"lens {lens}: duplicate gates {sorted(str(item) for item in duplicates)}")
    for gate in gates:
        gate_id, status = gate["gate_id"], gate["status"]
        if gate_id not in expected:
            errors.append(f"lens {lens}: foreign gate {gate_id}")
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
            if "reason" not in gate:
                errors.append(f"lens {lens}: gate {gate_id} requires reason")
            if status == "NOT_APPLICABLE" and gate_id in universal:
                errors.append(f"lens {lens}: universal gate {gate_id} cannot be NOT_APPLICABLE")
            if status == "NOT_RUN":
                errors.append(f"lens {lens}: gate {gate_id} NOT_RUN")
            continue
        evidence = gate.get("evidence")
        if not evidence:
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
    for gate_id, recorded_status in gate_status.items():
        if recorded_status == "FINDING" and not any(
            item["gate_id"] == gate_id for item in valid_findings
        ):
            errors.append(f"lens {lens}: gate {gate_id} FINDING has no valid finding")
    return lens, valid_findings, errors, gate_ids
