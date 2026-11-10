"""Build and validate a fixed review plan from accepted policy, never from reported coverage."""

from __future__ import annotations

import re
from copy import deepcopy
from typing import Any

from factory_tooling.project.contracts import ProjectCheck
from factory_tooling.project.profile_io import validate_snapshot
from factory_tooling.project.profile_rules import matches, require
from factory_tooling.project.review_definition import CORE_CRITERIA, DIRECTIONS
from factory_tooling.review.review_contracts import expected_gates
from factory_tooling.runtime.command_contract import validate_execution


def review_checks(manifest: dict[str, Any]) -> list[ProjectCheck]:
    profile = validate_snapshot(manifest["project_policy"])
    checks = [
        deepcopy(c)
        for g in profile.get("gates", [])
        if "code-review.complete" in g["at"]
        for c in g.get("checks", [])
        if matches(c.get("for", {}), process="code-review", scope=manifest["scope_files"])
    ]
    extra = manifest.get("additional_checks", [])
    if not (isinstance(extra, list)):
        raise ValueError("Project policy: " + "additional_checks must be a list")
    checks += deepcopy(extra)
    seen = set()
    for c in checks:
        if not (isinstance(c, dict)):
            raise ValueError("Project policy: " + "check must be object")
        cid = c.get("id")
        if not (
            isinstance(cid, str)
            and re.fullmatch("[A-Za-z0-9][A-Za-z0-9_-]*", cid)
            and (cid not in seen)
        ):
            raise ValueError("Project policy: " + "invalid/duplicate review check")
        seen.add(cid)
        if not (isinstance(c.get("method"), str) and c["method"].strip()):
            raise ValueError("Project policy: " + "check needs method")
        require("decision" not in c, "review decision routing is not enabled")
        if isinstance(c.get("execution"), dict):
            c["execution"].setdefault("timeout_seconds", 600)
        validate_execution(c.get("execution"))
        from factory_tooling.project.profile_rules import relative

        relative(c["execution"]["cwd"])
        for path in c["execution"].get("inputs", []):
            relative(path)
        # Preserve argv exactly; these are commands, never interpreted templates.
        if not (isinstance(c.get("after", []), list)):
            raise ValueError("Project policy: " + "invalid check dependencies")
    for c in checks:
        if not (
            all(isinstance(x, str) and x in seen and (x != c["id"]) for x in c.get("after", []))
        ):
            raise ValueError("Project policy: " + "inactive/unknown review dependency")
    done: set[str] = set()
    while done != seen:
        ready = {c["id"] for c in checks if set(c.get("after", [])) <= done} - done
        require(ready, "review dependency cycle")
        done |= ready
    return checks


def assignments(manifest: dict[str, Any]) -> list[dict[str, Any]]:
    coverage = expected_gates(manifest["scope_files"], manifest["project_policy"])
    return [
        {
            "id": lens,
            "name": name,
            "role": "reviewer",
            "profile": "reviewer",
            "criteria": coverage[lens],
        }
        for lens, name in DIRECTIONS.items()
    ]


def validate_context(manifest: dict[str, Any]) -> None:
    ctx = manifest.get("context")
    if not (isinstance(ctx, dict) and set(ctx) == {"sources", "requirements", "limitations", "pr"}):
        raise ValueError(
            "Project policy: " + "context needs sources, requirements, limitations, pr"
        )
    if not (isinstance(ctx["sources"], list) and isinstance(ctx["requirements"], list)):
        raise ValueError("Project policy: " + "invalid context lists")
    ids = set()
    for source in ctx["sources"]:
        if not (
            isinstance(source, dict)
            and all(
                isinstance(source.get(k), str) and source[k].strip()
                for k in ("id", "locator", "content", "captured_at")
            )
        ):
            raise ValueError("Project policy: " + "invalid source snapshot")
        require(source["id"] not in ids, "duplicate source ID")
        ids.add(source["id"])
    rids = set()
    for req in ctx["requirements"]:
        if not (
            isinstance(req, dict)
            and isinstance(req.get("id"), str)
            and req["id"]
            and (req["id"] not in rids)
            and isinstance(req.get("text"), str)
            and req["text"].strip()
            and (req.get("source_id") in ids)
        ):
            raise ValueError("Project policy: " + "invalid requirement/source")
        rids.add(req["id"])
    if not (
        isinstance(ctx["limitations"], list)
        and all(isinstance(x, str) and x.strip() for x in ctx["limitations"])
    ):
        raise ValueError("Project policy: " + "invalid limitations")
    if not ctx["requirements"]:
        require(ctx["limitations"], "missing intent needs an explicit limitation")
    if manifest["mode"] == "pr":
        pr = ctx["pr"]
        if not (
            isinstance(pr, dict)
            and all(isinstance(pr.get(k), str) for k in ("url", "title", "body", "captured_at"))
            and pr["url"]
            and pr["captured_at"]
            and (pr.get("head_sha") == manifest["head_sha"])
        ):
            raise ValueError(
                "Project policy: " + "PR title/body snapshot and matching head required"
            )
    else:
        if ctx["pr"] is not None:
            raise ValueError("Project policy: " + "non-PR context must use pr=null")


def validate_plan(manifest: dict[str, Any]) -> dict[str, Any]:
    validate_context(manifest)
    if not (
        isinstance(manifest.get("command_selection_reason"), str)
        and manifest["command_selection_reason"].strip()
    ):
        raise ValueError(
            "Project policy: " + "explain command selection, including when no commands apply"
        )
    require(
        manifest.get("core_criteria") == [list(c) for c in CORE_CRITERIA],
        "core criteria changed; new intake required",
    )
    require(manifest.get("checks") == review_checks(manifest), "missing/changed mandatory commands")
    require(
        manifest.get("assignments") == assignments(manifest),
        "missing/changed mandatory assignments",
    )
    sources = manifest.get("source_evidence", {})
    if not (isinstance(sources, dict)):
        raise ValueError("Project policy: " + "source_evidence must be mapping")
    from factory_tooling.review.review_contracts import valid_scope_path

    for path, value in sources.items():
        if not (
            valid_scope_path(path)
            and isinstance(value, dict)
            and isinstance(value.get("content"), str)
        ):
            raise ValueError("Project policy: " + "invalid source evidence")
        import hashlib

        require(
            value.get("sha256") == hashlib.sha256(value["content"].encode()).hexdigest(),
            "source evidence hash mismatch",
        )
    return manifest


def prepare(manifest: dict[str, Any]) -> dict[str, Any]:
    manifest = deepcopy(manifest)
    manifest["schema_version"] = "4"
    manifest["core_criteria"] = [list(c) for c in CORE_CRITERIA]
    manifest.setdefault("additional_checks", [])
    manifest.setdefault("source_evidence", {})
    manifest["assignments"] = assignments(manifest)
    manifest["checks"] = review_checks(manifest)
    validate_plan(manifest)
    from factory_tooling.review.review_contracts import canonical_scope_hash

    manifest["scope_hash"] = canonical_scope_hash(manifest)
    return manifest


def questions(manifest: dict[str, Any], lens: str) -> dict[str, str]:
    profile = validate_snapshot(manifest["project_policy"])
    definitions = {cid: question for cid, _, question in CORE_CRITERIA}
    definitions.update(
        {c["id"]: c["question"] for g in profile.get("gates", []) for c in g.get("criteria", [])}
    )
    return {
        cid: definitions[cid]
        for cid in expected_gates(manifest["scope_files"], manifest["project_policy"])[lens]
    }
