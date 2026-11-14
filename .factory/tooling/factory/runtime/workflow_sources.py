"""Source locking and approval validation; no run-state mutations."""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

from pydantic import TypeAdapter, ValidationError

from factory.paths import FACTORY_ROOT
from factory.runtime import acceptance
from factory.runtime.contracts import LockedSource, Source
from factory.runtime.workflow_core import (
    Invalid,
    acceptance_guard,
    digest,
    relative,
    require,
)
from factory.validation import validation_message

SOURCE = TypeAdapter[Source](Source)
LOCKED_SOURCE = TypeAdapter[LockedSource](LockedSource)


def lock_source(root: str | Path, raw: object, check_expected: bool = True) -> LockedSource:
    try:
        src = SOURCE.validate_python(raw)
    except ValidationError as exc:
        label = "Invalid workflow source"
        if isinstance(raw, dict) and raw.get("kind") == "approved_plan":
            label = "BLOCKED_NO_APPROVED_PLAN"
        raise Invalid(validation_message(label, exc, SOURCE)) from None
    require(bool(src.get("path")) != bool(src.get("text")), "Source needs exactly one path or text")
    content = relative(root, src["path"]).read_bytes() if src.get("path") else src["text"].encode()
    src.setdefault("kind", "local_task" if src.get("path") else "direct")
    src.setdefault(
        "execution_mode", "approved_plan" if src["kind"] == "approved_plan" else "single_task"
    )
    require(
        src["kind"] in {"direct", "local_task", "factory_decompose_task", "approved_plan"},
        "Invalid source kind",
    )
    require(src["execution_mode"] in {"single_task", "approved_plan"}, "Invalid execution mode")
    require(
        (src["kind"] == "approved_plan") == (src["execution_mode"] == "approved_plan"),
        "Approved-plan kind and execution_mode must agree",
    )
    if src["execution_mode"] == "approved_plan":
        require(
            src.get("path") and src.get("selected_scope"),
            "Approved plan needs path and selected_scope",
        )
        approval_kind = src.get("approval_evidence", "canonical_plan_metadata")
        if approval_kind == "explicit_external_hash_approval":
            # Canonical sources must never bypass their revision/status validator.
            text = content.decode()
            frontmatter = re.match(r"\A---\s*\n(.*?)\n---(?:\s|$)", text, re.DOTALL)
            canonical = Path(src["path"]).parts[:2] == ("docs", "plans") or (
                frontmatter and re.search(r"(?m)^(?:plan_id|approved_revision)\s*:", frontmatter[1])
            )
            require(
                not canonical,
                "BLOCKED_NO_APPROVED_PLAN: canonical plan requires canonical validation",
            )
            approval = src.get("external_approval")
            if approval is None:
                raise Invalid("BLOCKED_NO_APPROVED_PLAN: missing external approval")
            require(
                approval.get("state") == "approved"
                and approval.get("source_path") == src["path"]
                and approval.get("content_sha256") == digest(content)
                and approval.get("selected_scope") == src["selected_scope"],
                "BLOCKED_NO_APPROVED_PLAN: external approval does not match content/path/scope",
            )
            # Provenance authenticity and semantic scope are checked by the parent,
            # like actual user authorization elsewhere in this ledger.
        else:
            validator = FACTORY_ROOT / "gates/skills/planning/validate_plan.py"
            check = subprocess.run(
                [
                    sys.executable,
                    str(validator),
                    "--plan",
                    str(relative(root, src["path"])),
                    "--phase",
                    "approved",
                ],
                capture_output=True,
                text=True,
            )
            require(
                check.returncode == 0,
                "BLOCKED_NO_APPROVED_PLAN: " + check.stdout[-1000:] + check.stderr[-1000:],
            )
    if src["execution_mode"] == "approved_plan" and approval_kind == "canonical_plan_metadata":
        extracted = acceptance_guard(acceptance.plan_criteria, content.decode())
        require(
            src.get("acceptance") == extracted,
            "Acceptance differs from approved plan; re-intake required",
        )
    acceptance_guard(acceptance.criteria_map, src.get("acceptance"))
    if src["kind"] == "factory_decompose_task":
        match = re.search(r"(?m)^- \*\*Acceptance criteria:\*\* (.+)$", content.decode())
        if not (match is not None):
            raise Invalid("Task acceptance field missing from decomposition")
        inherited = set(re.findall(r"AC-\d{2,}", match[1]))
        if inherited:
            require(
                inherited == {c["id"] for c in src["acceptance"]},
                "Task acceptance differs from decomposition",
            )
        else:
            require(
                src.get("acceptance_origin") == "task_local" and src.get("parent_plan_ref"),
                "Preparatory task needs local acceptance and parent plan provenance",
            )
    normalized = "\n".join(
        line.rstrip()
        for line in content.decode().replace("\r\n", "\n").replace("\r", "\n").split("\n")
    ).rstrip()
    semantic = {
        "content": normalized,
        "selected_scope": src.get("selected_scope", "all"),
        "kind": src["kind"],
        "execution_mode": src["execution_mode"],
        "directive": src.get("directive", "none"),
        "acceptance": src["acceptance"],
        "selected_acceptance_ids": src.get("selected_acceptance_ids"),
        "acceptance_origin": src.get("acceptance_origin"),
        "parent_plan_ref": src.get("parent_plan_ref"),
    }
    content_hash = digest(content)
    semantic_hash = digest(json.dumps(semantic, sort_keys=True, ensure_ascii=False).encode())
    if check_expected:
        require(
            not src.get("content_hash") or src["content_hash"] == content_hash,
            "SOURCE_DRIFT in prepared graph",
        )
        require(
            not src.get("hash") or src["hash"] == semantic_hash,
            "SOURCE_DRIFT in prepared graph semantics",
        )
    src["content_hash"], src["hash"] = content_hash, semantic_hash
    src["snapshot"] = content.decode()
    return LOCKED_SOURCE.validate_python(src)
