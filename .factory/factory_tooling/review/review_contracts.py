"""Review identities, scope constraints and project gate registry."""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path, PurePosixPath
from typing import Any

from factory_tooling.project.contracts import Snapshot as Snapshot
from factory_tooling.project.profile_io import validate_snapshot as validate_snapshot
from factory_tooling.project.profile_rules import matches as matches
from factory_tooling.project.profile_rules import require as require
from factory_tooling.project.profile_rules import review_criteria as review_criteria
from factory_tooling.project.review_definition import CORE_CRITERIA as CORE_CRITERIA
from factory_tooling.project.review_definition import DIRECTIONS as DIRECTIONS

SCHEMA_VERSION = "4"


LENSES = ("system-design", "runtime-safety", "verification-quality")


GATE_STATUSES = {"PASS", "FINDING", "NOT_APPLICABLE", "NOT_RUN"}


TOOL_STATUSES = {"PASS", "FAIL", "BLOCKED", "NOT_APPLICABLE", "NOT_RUN"}


SEVERITIES = {"critical", "high", "medium"}


CONFIDENCES = {"high", "medium"}


VERDICTS = {"APPROVE", "NEEDS_WORK", "RETHINK"}


IDENTITY_FIELDS = (
    "schema_version",
    "review_id",
    "mode",
    "base_sha",
    "head_sha",
    "scope_hash",
)


# Project data is supplied by the pinned review manifest, never module globals.

UNIVERSAL_GATES = {lens: tuple(c[0] for c in CORE_CRITERIA if c[1] == lens) for lens in DIRECTIONS}


def sha256_text(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def canonical_scope_hash(manifest: dict[str, Any]) -> str:
    payload = {
        "mode": manifest.get("mode"),
        "target": manifest.get("target"),
        "base_sha": manifest.get("base_sha"),
        "head_sha": manifest.get("head_sha"),
        "scope_files": manifest.get("scope_files"),
        "diff_sha256": manifest.get("diff_sha256"),
        "core_criteria": manifest.get("core_criteria"),
        "context": manifest.get("context"),
        "assignments": manifest.get("assignments"),
        "checks": manifest.get("checks"),
        "additional_checks": manifest.get("additional_checks"),
        "command_selection_reason": manifest.get("command_selection_reason"),
        "source_evidence": manifest.get("source_evidence"),
        "project_policy_sha256": manifest.get("project_policy", {}).get("sha256"),
    }
    if manifest.get("mode") == "feature":
        payload["source_sha256"] = manifest.get("source_sha256")
    return sha256_text(json.dumps(payload, sort_keys=True, separators=(",", ":")))


def valid_scope_path(value: Any) -> bool:
    if not isinstance(value, str) or not value:
        return False
    path = PurePosixPath(value)
    return not path.is_absolute() and ".." not in path.parts and str(path) == value


def feature_source_errors(manifest: dict[str, Any]) -> list[str]:
    scope = manifest.get("scope_files")
    hashes = manifest.get("source_sha256")
    if not isinstance(scope, list) or not isinstance(hashes, dict):
        return ["manifest: feature requires source_sha256 map"]
    if set(hashes) != set(scope):
        return ["manifest: feature source_sha256 keys must exactly equal scope_files"]
    errors: list[str] = []
    for path in scope:
        digest = hashes.get(path)
        if not re.fullmatch(r"[0-9a-f]{64}", str(digest or "")):
            errors.append(f"manifest: feature source_sha256 invalid for {path}")
            continue
        try:
            current = hashlib.sha256(Path(path).read_bytes()).hexdigest()
        except OSError:
            errors.append(f"manifest: feature source missing for {path}")
            continue
        if current != digest:
            errors.append(f"manifest: feature source bytes changed for {path}")
    return errors


def validate_manifest(manifest: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    try:
        from factory_tooling.review.review_plan import validate_plan

        validate_plan(manifest)
    except (ValueError, TypeError, KeyError) as exc:
        errors.append(f"review plan: {exc}")
    try:
        validate_snapshot(manifest.get("project_policy"))
        expected_gates(manifest.get("scope_files", []), manifest["project_policy"])
        if manifest.get("mode") in {"branch", "pr"} and manifest["project_policy"][
            "source"
        ] != "git:" + str(manifest.get("base_sha")):
            errors.append("manifest: project policy must come from the pinned base SHA")
    except (ValueError, TypeError) as exc:
        errors.append(str(exc))
    if manifest.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"manifest: schema_version must be {SCHEMA_VERSION}")
    for field in ("review_id", "target", "scope_hash"):
        if not isinstance(manifest.get(field), str) or not manifest[field]:
            errors.append(f"manifest: {field} must be nonempty")
    if manifest.get("mode") not in {"branch", "pr", "feature"}:
        errors.append("manifest: mode must be branch, pr, or feature")
    if not re.fullmatch(r"[0-9a-f]{40}", str(manifest.get("head_sha", ""))):
        errors.append("manifest: head_sha must be a full lowercase Git SHA")
    scope = manifest.get("scope_files")
    if (
        not isinstance(scope, list)
        or not scope
        or any(not valid_scope_path(path) for path in scope)
        or scope != sorted(set(scope))
    ):
        errors.append("manifest: scope_files must be nonempty, sorted, unique relative paths")
    mode = manifest.get("mode")
    if mode in {"branch", "pr"}:
        if not re.fullmatch(r"[0-9a-f]{40}", str(manifest.get("base_sha", ""))):
            errors.append(f"manifest: {mode} requires full base_sha")
        if not isinstance(manifest.get("diff_file"), str) or not manifest["diff_file"]:
            errors.append(f"manifest: {mode} requires diff_file")
        if not re.fullmatch(r"[0-9a-f]{64}", str(manifest.get("diff_sha256", ""))):
            errors.append(f"manifest: {mode} requires diff_sha256")
    elif mode == "feature":
        if manifest.get("base_sha") is not None:
            errors.append("manifest: feature requires null base_sha")
        if manifest.get("diff_file") is not None or manifest.get("diff_sha256") is not None:
            errors.append("manifest: feature forbids diff_file and diff_sha256")
        errors.extend(feature_source_errors(manifest))
    if mode in {"branch", "pr"} and manifest.get("source_sha256") not in (None, {}):
        errors.append("manifest: branch/PR source_sha256 must be absent or null")
    if manifest.get("scope_hash") != canonical_scope_hash(manifest):
        errors.append("manifest: scope_hash mismatch")
    return errors


def identity_errors(value: dict[str, Any], manifest: dict[str, Any], label: str) -> list[str]:
    return [
        f"{label}: identity mismatch for {field}"
        for field in IDENTITY_FIELDS
        if value.get(field) != manifest.get(field)
    ]


def expected_gates(scope_files: list[str], policy: Any) -> dict[str, list[str]]:
    profile = validate_snapshot(policy)
    result = {lens: list(gates) for lens, gates in UNIVERSAL_GATES.items()}
    core = {g for gates in UNIVERSAL_GATES.values() for g in gates}
    for gate in review_criteria(profile, "code-review.complete"):
        require(gate["id"] not in core, "project gate cannot replace universal gate")
        if matches(gate.get("for", {}), process="code-review", scope=scope_files):
            result[gate["lens"]].append(gate["id"])
    return {lens: sorted(gates) for lens, gates in result.items()}
