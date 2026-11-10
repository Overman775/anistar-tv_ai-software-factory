"""QA decisions and finding deduplication; no file writes."""

from __future__ import annotations

import json
from collections import Counter
from copy import deepcopy
from typing import Any

from factory_tooling.review.review_contracts import SEVERITIES, VERDICTS, identity_errors
from factory_tooling.review.review_evidence import validate_evidence
from factory_tooling.review.review_lenses import (
    validate_finding,
)


def apply_qa(
    qa: dict[str, Any],
    findings: list[dict[str, Any]],
    manifest: dict[str, Any],
    diff: dict[str, Any],
    tool_commands: dict[str, int],
    registry: dict[str, list[str]],
) -> tuple[list[dict[str, Any]], str, list[str], list[str], str | None, list[dict[str, Any]]]:
    errors = identity_errors(qa, manifest, "qa")
    if errors:
        return findings, "NEEDS_WORK", errors, [], None, []
    verdict = qa.get("code_verdict")
    if not isinstance(verdict, str) or verdict not in VERDICTS:
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

    gate_owners = {gate_id: lens for lens, gate_ids in registry.items() for gate_id in gate_ids}
    added_findings = qa.get("added_findings", [])
    if not isinstance(added_findings, list):
        errors.append("qa: added_findings must be list")
        added_findings = []
    valid_added: list[dict[str, Any]] = []
    retained_ids = {item["finding_id"] for item in findings}
    for index, finding in enumerate(added_findings):
        gate_id = finding.get("gate_id") if isinstance(finding, dict) else None
        if gate_id is not None and not isinstance(gate_id, str):
            errors.append(f"qa: added_finding[{index}] gate not in current registry")
            continue
        owner = gate_owners.get(gate_id) if gate_id is not None else next(iter(registry), None)
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
            errors.append(f"qa: added_finding[{index}] finding_id collides with retained finding")
            continue
        normalized["found_by"] = ["qa"]
        valid_added.append(normalized)
        retained_ids.add(normalized["finding_id"])
    findings = [*findings, *valid_added]

    by_id = {item["finding_id"]: item for item in findings}
    dismissals = qa.get("dismissals", [])
    if not isinstance(dismissals, list):
        errors.append("qa: dismissals must be list")
        dismissals = []
    # Ambiguous or repeated decisions cannot erase a source finding.
    dismissal_counts = Counter(
        item["finding_id"]
        for item in dismissals
        if isinstance(item, dict) and isinstance(item.get("finding_id"), str)
    )
    dismissed: list[dict[str, Any]] = []
    dismissed_ids: set[str] = set()
    for item in dismissals:
        if not isinstance(item, dict) or not isinstance(item.get("finding_id"), str):
            errors.append("qa: malformed dismissal")
            continue
        finding_id = item["finding_id"]
        target = by_id.get(finding_id)
        reason, evidence = item.get("reason"), item.get("evidence")
        if target is None or dismissal_counts[finding_id] != 1:
            errors.append("qa: dismissal target invalid or repeated")
            continue
        if not isinstance(reason, str) or not reason.strip():
            errors.append("qa: dismissal requires reason")
            continue
        if not isinstance(evidence, list) or not evidence:
            errors.append("qa: dismissal requires current evidence")
            continue
        evidence_errors = [
            error
            for entry in evidence
            for valid, error in [validate_evidence(entry, manifest, diff, tool_commands)]
            if not valid
        ]
        if evidence_errors:
            errors.extend(f"qa: dismissal {error}" for error in evidence_errors)
            continue
        if not any(
            entry.get("kind") in {"source", "inspection", "binary", "file_operation"}
            for entry in evidence
        ):
            errors.append("qa: dismissal requires source, binary, or file operation evidence")
            continue
        dismissed.append(
            {
                "finding": deepcopy(target),
                "dismissed_by": "qa",
                "reason": reason,
                "evidence": deepcopy(evidence),
            }
        )
        dismissed_ids.add(finding_id)
    findings = [item for item in findings if item["finding_id"] not in dismissed_ids]
    by_id = {item["finding_id"]: item for item in findings}
    overrides = qa.get("severity_overrides", [])
    if not isinstance(overrides, list):
        errors.append("qa: severity_overrides must be list")
        overrides = []
    for item in overrides:
        if not isinstance(item, dict):
            errors.append("qa: malformed severity override")
            continue
        finding_id, severity = item.get("finding_id"), item.get("severity")
        target = by_id.get(finding_id) if isinstance(finding_id, str) else None
        if target is None or not isinstance(severity, str) or severity not in SEVERITIES:
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
        if (
            not isinstance(source_ids, list)
            or len(source_ids) < 2
            or any(not isinstance(source_id, str) for source_id in source_ids)
            or len(source_ids) != len(set(source_ids))
            or any(source_id not in by_id or source_id in consumed for source_id in source_ids)
            or (not isinstance(reason, str))
            or (not reason)
            or (not isinstance(candidate, dict))
        ):
            errors.append("qa: manual merge source_ids/reason/finding invalid")
            continue
        candidate_id = candidate.get("finding_id")
        if not isinstance(candidate_id, str):
            errors.append("qa: manual merge finding_id must be a string")
            continue
        if (
            candidate_id in merge_ids
            or candidate_id in dismissed_ids
            or (candidate_id in by_id and candidate_id not in source_ids)
        ):
            errors.append("qa: manual merge finding_id collides with retained finding")
            continue
        source_severity = max(
            (by_id[source_id]["severity"] for source_id in source_ids),
            key=severity_rank.__getitem__,
        )
        if severity_rank.get(str(candidate.get("severity")), -1) < severity_rank[source_severity]:
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
    return (
        findings,
        verdict,
        errors,
        notes,
        semantic_gap if isinstance(semantic_gap, str) else None,
        dismissed,
    )
