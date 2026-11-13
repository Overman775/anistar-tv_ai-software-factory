"""Build and validate a fixed review plan from accepted policy, never from reported coverage."""

from __future__ import annotations

from copy import deepcopy
from typing import Any

from pydantic import ConfigDict, TypeAdapter, ValidationError

from factory_tooling.project.profile_io import validate_snapshot
from factory_tooling.project.profile_rules import matches, require
from factory_tooling.project.review_definition import CORE_CRITERIA, DIRECTIONS
from factory_tooling.review.review_contracts import expected_gates, parse_manifest
from factory_tooling.review.review_shapes import AdditionalCheck, ReviewContext
from factory_tooling.runtime.command_contract import validate_execution
from factory_tooling.validation import validation_message

ADDITIONAL_CHECKS = TypeAdapter[list[AdditionalCheck]](
    list[AdditionalCheck], config=ConfigDict(strict=True)
)
CONTEXT = TypeAdapter[ReviewContext](ReviewContext)


def review_checks(manifest: dict[str, Any]) -> list[dict[str, Any]]:
    profile = validate_snapshot(manifest["project_policy"])
    checks: list[dict[str, Any]] = [
        dict(deepcopy(c))
        for g in profile.get("gates", [])
        if "code-review.complete" in g["at"]
        for c in g.get("checks", [])
        if matches(c.get("for", {}), process="code-review", scope=manifest["scope_files"])
    ]
    try:
        extra = ADDITIONAL_CHECKS.validate_python(manifest.get("additional_checks", []))
    except ValidationError as exc:
        raise ValueError(
            validation_message("Invalid additional_checks", exc, ADDITIONAL_CHECKS)
        ) from None
    checks.extend(dict(c) for c in extra)
    seen = set()
    for c in checks:
        cid = c["id"]
        require(cid not in seen, "duplicate review check")
        seen.add(cid)
        require("decision" not in c, "review decision routing is not enabled")
        execution = {"cwd": ".", "timeout_seconds": 600, **c["execution"]}
        c["execution"] = validate_execution(execution)
        from factory_tooling.project.profile_rules import relative

        relative(c["execution"]["cwd"])
        for path in c["execution"].get("inputs", []):
            relative(path)
    for c in checks:
        if not (all(x in seen and x != c["id"] for x in c.get("after", []))):
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
    try:
        ctx = CONTEXT.validate_python(manifest.get("context"))
    except ValidationError as exc:
        raise ValueError(validation_message("Invalid review context", exc, CONTEXT)) from None
    ids = {source["id"] for source in ctx["sources"]}
    require(len(ids) == len(ctx["sources"]), "duplicate source ID")
    rids = {req["id"] for req in ctx["requirements"]}
    require(
        len(rids) == len(ctx["requirements"])
        and all(req["source_id"] in ids for req in ctx["requirements"]),
        "invalid requirement/source",
    )
    if not ctx["requirements"]:
        require(ctx["limitations"], "missing intent needs an explicit limitation")
    if manifest["mode"] == "pr":
        pr = ctx["pr"]
        require(
            pr is not None and pr["head_sha"] == manifest["head_sha"],
            "PR title/body snapshot and matching head required",
        )
    else:
        require(ctx["pr"] is None, "non-PR context must use pr=null")


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
    from factory_tooling.review.review_contracts import canonical_scope_hash

    manifest["scope_hash"] = canonical_scope_hash(manifest)
    return validate_plan(parse_manifest(manifest))


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
