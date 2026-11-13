"""QA decisions and finding deduplication; no file writes."""

from __future__ import annotations

import json
from collections import Counter
from copy import deepcopy
from typing import Any

from pydantic import TypeAdapter, ValidationError

from factory_tooling.review.review_contracts import identity_errors
from factory_tooling.review.review_evidence import validate_evidence
from factory_tooling.review.review_lenses import validate_finding
from factory_tooling.review.review_shapes import QA, Dismissal, ManualMerge, SeverityOverride
from factory_tooling.validation import validation_message

QA_RESULT = TypeAdapter[QA](QA)
DISMISSAL = TypeAdapter[Dismissal](Dismissal)
MERGE = TypeAdapter[ManualMerge](ManualMerge)
OVERRIDE = TypeAdapter[SeverityOverride](SeverityOverride)


def apply_qa(
    raw: object,
    findings: list[dict[str, Any]],
    manifest: dict[str, Any],
    diff: dict[str, Any],
    tool_commands: dict[str, int],
    registry: dict[str, list[str]],
) -> tuple[list[dict[str, Any]], str, list[str], list[str], str | None, list[dict[str, Any]]]:
    try:
        qa = QA_RESULT.validate_python(raw)
    except ValidationError as exc:
        return (
            findings,
            "NEEDS_WORK",
            [validation_message("Invalid qa", exc, QA_RESULT)],
            [],
            None,
            [],
        )
    errors = identity_errors(dict(qa), manifest, "qa")
    if errors:
        return findings, "NEEDS_WORK", errors, [], None, []
    verdict = qa["code_verdict"]
    notes = qa.get("notes", [])
    semantic_gap = qa.get("semantic_gap")
    if verdict == "RETHINK" and (not isinstance(semantic_gap, str) or not semantic_gap):
        errors.append("qa: RETHINK requires semantic_gap")
    if verdict != "RETHINK" and semantic_gap not in (None, ""):
        errors.append("qa: semantic_gap only allowed for RETHINK")

    gate_owners = {gate_id: lens for lens, gate_ids in registry.items() for gate_id in gate_ids}
    added_findings = qa.get("added_findings", [])
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
    # Ambiguous or repeated decisions cannot erase a source finding.
    dismissal_counts = Counter(
        item["finding_id"]
        for item in dismissals
        if isinstance(item, dict) and isinstance(item.get("finding_id"), str)
    )
    dismissed: list[dict[str, Any]] = []
    dismissed_ids: set[str] = set()
    for raw_item in dismissals:
        try:
            item = DISMISSAL.validate_python(raw_item)
        except ValidationError as exc:
            errors.append(validation_message("Invalid qa dismissal", exc, DISMISSAL))
            continue
        finding_id = item["finding_id"]
        target = by_id.get(finding_id)
        reason, evidence = item["reason"], item["evidence"]
        if target is None or dismissal_counts[finding_id] != 1:
            errors.append("qa: dismissal target invalid or repeated")
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
    for raw_item in overrides:
        try:
            override = OVERRIDE.validate_python(raw_item)
        except ValidationError as exc:
            errors.append(validation_message("Invalid qa severity override", exc, OVERRIDE))
            continue
        target = by_id.get(override["finding_id"])
        if target is None:
            errors.append("qa: severity override target invalid")
            continue
        target["severity"] = override["severity"]
        target["qa_severity_reason"] = override["reason"]

    merges = qa.get("manual_merges", [])
    consumed: set[str] = set()
    merged: list[dict[str, Any]] = []
    merge_ids: set[str] = set()
    severity_rank = {"medium": 0, "high": 1, "critical": 2}
    for raw_item in merges:
        try:
            merge = MERGE.validate_python(raw_item)
        except ValidationError as exc:
            errors.append(validation_message("Invalid qa manual merge", exc, MERGE))
            continue
        source_ids, reason, candidate = merge["source_ids"], merge["reason"], merge["finding"]
        if len(source_ids) != len(set(source_ids)) or any(
            source_id not in by_id or source_id in consumed for source_id in source_ids
        ):
            errors.append("qa: manual merge source_ids invalid")
            continue
        candidate_id = candidate["finding_id"]
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
