"""Build worker packets shared by native and ACP; no model calls.

Public entry points: build, factory_files, CLI main.
Validation, material selection and byte loading are separate steps.
Extend ROLE_REFS for role documents or STAGE_RULES for conditional documents;
factory_files derives frozen dependencies from those same rules.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from collections.abc import Callable, Mapping
from dataclasses import dataclass
from pathlib import Path
from typing import Annotated, Literal, NotRequired, cast

from pydantic import ConfigDict, Field, TypeAdapter, ValidationError, with_config
from typing_extensions import TypedDict

# Direct CLI execution and import-by-path use the same tool modules.
from factory import file_reader
from factory.logging_config import diagnostic_operation
from factory.project.contracts import (
    BoundaryGate,
    MaterialEntry,
    Policy,
    ReviewCriterion,
    Rule,
    Snapshot,
)
from factory.project.profile_io import (
    check_frozen,
    review_materials,
    safe_path,
    selected_materials,
    validate_snapshot,
)
from factory.project.profile_rules import boundary_gates, matches, review_criteria
from factory.runtime.contracts import (
    Config,
    ContextNode,
    Model,
    Node,
    Nonblank,
    Profile,
    ProfileCommon,
)
from factory.runtime.reports.acceptance import ensure
from factory.tasks.contracts import Task, TaskSelection
from factory.validation import validation_message

PROCESS_ROLES = {
    "implement": {
        "implementer",
        "tester",
        "judge",
        "doc-writer",
        "bug-hunter",
        "code-explorer",
    },
    "planning": {"architect", "code-explorer"},
    "decompose": {"task-decomposer", "task-reviewer"},
    "code-review": {"reviewer"},
}
COMMON = [
    "adapters/worker/common.md",
    "contracts/common/worker-rules.md",
    "gates/common/verification-rules.md",
    "contracts/common/communication.md",
    "contracts/common/code-discovery.md",
]
DECOMPOSE_REPAIR_REFS = ("skills/factory-decompose/references/staging-contract.md",)
DECOMPOSE_REVIEW_REFS = (
    "gates/skills/decompose/review-contract.md",
    "skills/factory-decompose/references/decomposition-policy.md",
    "skills/factory-decompose/references/task-template.md",
    "contracts/common/implementation-detail.md",
)
ROLE_REFS = {
    "implementer": [
        "gates/roles/implementer.md",
        "contracts/common/coding-principles.md",
        "contracts/common/testing-principles.md",
    ],
    "tester": ["gates/roles/tester.md", "contracts/common/testing-principles.md"],
    "architect": [
        "skills/factory-planning/references/architect-input.md",
        "skills/factory-planning/references/architect-plan-contract.md",
        "skills/factory-planning/references/plan-content.md",
    ],
    "task-decomposer": [
        "skills/factory-decompose/references/decomposition-policy.md",
        "skills/factory-decompose/references/generation-contract.md",
        *DECOMPOSE_REPAIR_REFS,
        "skills/factory-decompose/references/task-template.md",
        "contracts/common/implementation-detail.md",
    ],
    "task-reviewer": list(DECOMPOSE_REVIEW_REFS),
    "judge": ["gates/roles/judge.md", "contracts/common/review-principles.md"],
    "reviewer": [
        "gates/roles/reviewer.md",
        "contracts/common/review-principles.md",
        "skills/factory-code-review/references/lens-result.md",
    ],
}
COMMAND_REFS = [
    "contracts/common/check-execution.md",
    "skills/factory-implement/references/project-checks.md",
]
REVIEW_FINDINGS_CONTRACT = "contracts/common/review-findings.md"
WRITE_RESULT_CONTRACT = "contracts/common/implement-write-result.md"
AUTHORS = frozenset({"implementer", "doc-writer"})


@dataclass(frozen=True)
class MaterialRule:
    """A factory document group selected by process, role and reserved resource."""

    paths: tuple[str, ...]
    reason: str
    process: str
    roles: frozenset[str] = frozenset()
    resource: str | None = None

    def matches(self, process: str, role: str, node: Node | ContextNode) -> bool:
        return (
            self.process == process
            and (not self.roles or role in self.roles)
            and (self.resource is None or self.resource in node.get("resources", []))
        )


STAGE_RULES = (
    MaterialRule(
        ("contracts/common/implement-handoff.md",), "Implement handoff evidence", "implement"
    ),
    MaterialRule(
        ("contracts/common/implement-result.md",), "Implement result/stage interface", "implement"
    ),
    MaterialRule(
        tuple(COMMAND_REFS), "reserved command stage", "implement", resource="project-checks"
    ),
    MaterialRule(
        (REVIEW_FINDINGS_CONTRACT,),
        "Implement review interface",
        "implement",
        roles=frozenset({"judge", "tester"}),
    ),
    MaterialRule((WRITE_RESULT_CONTRACT,), "Implement write handoff", "implement", roles=AUTHORS),
)
WORKER_PROFILE_FIELDS = ("role", "contract", "adapter", "capabilities", "enforcement", "mcp")
IMPLEMENT_STAGES = {"work", "docs", "explore", "verify", "review"}


@with_config(ConfigDict(strict=True, extra="allow"))
class ContextInput(TypedDict):
    # Each process owns its payload; this projection validates what context consumes.
    source: Annotated[dict[str, object], Field(min_length=1)]
    task: NotRequired[Task | TaskSelection]
    node: NotRequired[Node | ContextNode]
    read: NotRequired[list[Nonblank]]
    scope_files: NotRequired[list[Nonblank]]
    project_policy: NotRequired[Snapshot]
    owned_gates: NotRequired[dict[str, str]]
    decompose_mode: NotRequired[Literal["review", "repair"]]


@with_config(ConfigDict(strict=True, extra="forbid"))
class WorkerProfile(ProfileCommon):
    adapter: str


@with_config(ConfigDict(strict=True, extra="forbid"))
class PolicyContext(TypedDict):
    id: str
    sha256: str
    scope_status: Literal["known", "unknown"]
    gates: list[BoundaryGate]
    review_criteria: list[ReviewCriterion]


@with_config(ConfigDict(strict=True, extra="allow"))
class ContextPacket(TypedDict):
    process: Literal["implement", "planning", "decompose", "code-review"]
    role: Nonblank
    workspace: Nonblank
    profile: WorkerProfile
    model: Model
    instructions: list[MaterialEntry]
    project_policy: PolicyContext


CONTEXT_INPUT = TypeAdapter[ContextInput](ContextInput)
CONTEXT_PACKET = TypeAdapter[ContextPacket](ContextPacket)


def _validate_path(rel: str) -> None:
    if not (
        isinstance(rel, str)
        and rel
        and (not Path(rel).is_absolute())
        and (".." not in Path(rel).parts)
    ):
        raise ValueError("Invalid context path")


def path(root: str | Path, rel: str, *, exists: bool = True) -> Path:
    _validate_path(rel)
    root = Path(root).resolve()
    target = root / rel
    ensure(target.resolve().is_relative_to(root), "Context path escapes root")
    ensure(
        not any(
            (root / Path(*Path(rel).parts[:i])).is_symlink()
            for i in range(1, len(Path(rel).parts) + 1)
        ),
        "Symlink context path",
    )
    ensure(not exists or target.is_file(), f"Missing context file: {rel}")
    return target


def accepted_path(config: Config, root: str | Path, rel: str, *, exists: bool = True) -> Path:
    """Resolve an accepted path without inspecting its candidate replacement."""
    _validate_path(rel)
    target = Path(root) / rel
    if str(target) in config["_documents"]:
        return target
    return path(root, rel, exists=exists)


def accepted_bytes(
    config: Config, file: Path, fallback: Callable[[Path], bytes] = file_reader.read_bytes
) -> bytes:
    key = str(file)
    pinned = config["_documents"].get(key)
    expected = config.get("_project_documents", {}).get(key) or config["_files"].get(key)
    recovery = (
        f"Accepted document bytes unavailable or invalid: {file}. "
        "Restore hash-matching bytes or explicitly re-intake this document."
    )
    try:
        raw = pinned.encode("utf-8") if pinned is not None else fallback(file)
    except FileNotFoundError as exc:
        if expected is not None:
            raise ValueError(recovery) from exc
        raise
    if expected is not None and hashlib.sha256(raw).hexdigest() != expected:
        raise ValueError(recovery)
    return raw


def factory_files(config: Config) -> list[str]:
    """Files that affect packet selection/content; freeze with the active config."""
    result = set(
        COMMON
        + [
            "contracts/common/project-policy.md",
            "adapters/common.md",
            "adapters/worker/native-packet.md",
            "roles/teacher.md",
            "skills/factory-lessons/SKILL.md",
            "skills/factory-lessons/references/dispatch.md",
            "skills/factory-lessons/references/capture.md",
            "skills/factory-lessons/references/edit.md",
            "skills/factory-lessons/references/refresh.md",
            "skills/factory-meta-retune-lessons/SKILL.md",
        ]
    )
    result.update(
        [
            "tooling/bootstrap.py",
            "tooling/bin/cli",
            "tooling/bin/cli.cmd",
            "tooling/requirements.txt",
        ]
    )
    result.update(p for rule in STAGE_RULES for p in rule.paths)
    result.update(p for refs in ROLE_REFS.values() for p in refs)
    result.update(DECOMPOSE_REPAIR_REFS)
    for adapter in config["adapters"].values():
        result.add(adapter["worker_instructions"])
    return sorted(result)


def _validate_assignment(
    config: Config, profile_name: str, role: str, process: str, assignment: ContextInput
) -> tuple[Profile, Node | ContextNode, list[str]]:
    """Validate routing and capabilities before any material is read."""
    if not (
        isinstance(process, str)
        and isinstance(role, str)
        and (process in PROCESS_ROLES)
        and (role in PROCESS_ROLES[process])
    ):
        raise ValueError("Role not allowed in context process")
    if not (isinstance(profile_name, str) and profile_name in config["_roles"].get(role, [])):
        raise ValueError("Context profile not allowed for role")
    profile = config["profiles"][profile_name]
    ensure(
        profile["enforcement"] == "instructions",
        "BLOCKED_CAPABILITIES: generic adapter cannot enforce required tool isolation",
    )
    node: Node | ContextNode = assignment.get("node") or ContextNode()
    resources = node.get("resources", [])
    requires_edit = node.get("owns") or (
        role == "task-reviewer" and assignment.get("decompose_mode") == "repair"
    )
    ensure(not requires_edit or profile["capabilities"]["edit"], "Profile forbids edits")
    if process == "implement":
        if node.get("stage") not in IMPLEMENT_STAGES:
            raise ValueError("Invalid worker stage")
        if not (assignment.get("task") or TaskSelection()).get("scope"):
            raise ValueError("Missing task context")
        ensure(
            "project-checks" not in resources
            or profile["capabilities"]["commands"]
            or (role == "judge" and node.get("stage") == "review"),
            "Context commands forbidden by profile",
        )
    reads = node.get("read", assignment.get("read", []))
    return profile, node, reads


def _owns_unresolved_finding(role: str, node_id: object, findings: object) -> bool:
    if not isinstance(node_id, str) or not isinstance(findings, dict):
        return False
    return any(
        isinstance(item, dict)
        and item.get("owner_node_id") == node_id
        and item.get("owner_role") == role
        and item.get("status") in ("open", "ready")
        for item in findings.values()
    )


def factory_materials(
    profile: Profile,
    worker_instructions: str,
    role: str,
    process: str,
    node: Node | ContextNode,
    assignment: Mapping[str, object],
) -> list[tuple[str, str]]:
    """Select paths and reasons without reading files or changing the assignment."""
    selected = [(p, "shared worker/verification rules") for p in COMMON]
    selected += [
        (profile["contract"], "role interface"),
        (profile["role"], "role procedure"),
        (worker_instructions, "worker environment"),
    ]
    if process == "implement" and profile["runner"] == "native":
        selected.append(("adapters/worker/native-packet.md", "native packet transport"))
    selected += [(p, "process-specific role reference") for p in ROLE_REFS.get(role, [])]
    if role == "task-reviewer" and assignment.get("decompose_mode") == "repair":
        selected += [(p, "Decompose repair contract") for p in DECOMPOSE_REPAIR_REFS]
    for rule in STAGE_RULES:
        if rule.matches(process, role, node):
            if rule.paths == tuple(COMMAND_REFS) and not profile["capabilities"]["commands"]:
                continue
            write_only = (
                role in AUTHORS
                and node.get("stage") in {"work", "docs"}
                and "project-checks" not in node.get("resources", [])
            )
            if WRITE_RESULT_CONTRACT in rule.paths and not write_only:
                continue
            if "contracts/common/implement-result.md" in rule.paths and write_only:
                continue
            selected.extend((p, rule.reason) for p in rule.paths)
    if (
        process == "implement"
        and role in AUTHORS
        and _owns_unresolved_finding(
            role, node.get("id", assignment.get("node_id")), assignment.get("review_findings")
        )
    ):
        selected.append((REVIEW_FINDINGS_CONTRACT, "Assigned Implement review findings"))
    return selected


def coordinator_instructions(config: Config, root: Path) -> set[str]:
    """Resolve coordinator-only paths for every project-material entry point."""
    forbidden = {
        str(root / p)
        for p in [
            config["router"],
            config["orchestration"],
            "workflow/README.md",
            "roles/orchestrator.md",
            "contracts/orchestrator.md",
            "contracts/common/agent-checkpoint.md",
            "adapters/common.md",
        ]
    }
    forbidden.update(str(root / a["instructions"]) for a in config["adapters"].values())
    return forbidden


def _project_materials(
    config: Config, root: Path, workspace: Path, reads: list[str], *, include_agents: bool = True
) -> list[tuple[Path, str, str]]:
    """Resolve project reading while excluding coordinator-only instructions."""
    forbidden = coordinator_instructions(config, root)
    selected = []
    for rel in (["AGENTS.md"] if include_agents else []) + reads:
        file = accepted_path(config, workspace, rel)
        ensure(
            str(file) not in forbidden and file.name != "SKILL.md",
            "Coordinator instructions cannot be injected as worker reading; use scoped references",
        )
        selected.append((file, "mandatory project reading", "project"))
    return selected


def _read_instructions(
    materials: list[tuple[Path, str, str]], read_bytes: Callable[[Path], bytes]
) -> list[MaterialEntry]:
    """Read each path once; content and digest describe the same byte snapshot."""
    result: list[MaterialEntry] = []
    seen: set[str] = set()
    for file, reason, audience in materials:
        if str(file) in seen:
            continue
        seen.add(str(file))
        data = read_bytes(file)
        try:
            content = data.decode("utf-8")
        except UnicodeDecodeError as exc:
            raise ValueError(f"Context file is not UTF-8: {file}") from exc
        result.append(
            dict(
                path=str(file),
                content=content,
                sha256=hashlib.sha256(data).hexdigest(),
                reason=reason,
                audience=audience,
            )
        )
    return result


def _label_instructions(
    config: Config,
    policy_files: dict[str, str],
    instructions: list[MaterialEntry],
    selected: list[tuple[Path, Rule]],
    active: bool,
) -> None:
    for entry in instructions:
        rules = [rule for file, rule in selected if str(file) == entry["path"]]
        if rules:
            entry["rules"] = [
                cast(Rule, {k: r[k] for k in ("id", "for", "usage") if k in r}) for r in rules
            ]
        expected = policy_files.get(entry["path"]) or config.get("_project_documents", {}).get(
            entry["path"]
        )
        if expected is not None and entry["sha256"] != expected:
            raise ValueError("Project policy changed during packet build")
        if active and (expected is not None or entry["path"] in config["_files"]):
            entry["reason"] = "accepted baseline: " + entry["reason"]
        elif active:
            entry["reason"] = "current assigned reading: " + entry["reason"]


def build(
    config: Config,
    workspace: str | Path,
    profile_name: object,
    role: object,
    process: object,
    assignment: object,
    *,
    read_bytes: Callable[[Path], bytes] = file_reader.read_bytes,
) -> ContextPacket:
    """Return a complete packet from a loaded config and explicit assignment.

    read_bytes is a narrow I/O seam; selection and path checks always apply.
    The reader returns original UTF-8 bytes or raises an I/O error.
    Existing positional callers and the JSON packet schema remain supported.
    """
    if not isinstance(role, str) or not isinstance(process, str):
        raise ValueError("Role not allowed in context process")
    if not isinstance(profile_name, str):
        raise ValueError("Context profile not allowed for role")
    try:
        data = CONTEXT_INPUT.validate_python(assignment)
    except ValidationError as exc:
        raise ValueError(
            validation_message("Invalid context assignment", exc, CONTEXT_INPUT)
        ) from None
    profile, node, reads = _validate_assignment(config, profile_name, role, process, data)
    root, workspace = Path(config["_path"]).parent.resolve(), Path(workspace).resolve()
    active = process == "implement" and "_project_documents" in config
    materials = [
        ((accepted_path(config, root, rel) if active else path(root, rel)), reason, "worker")
        for rel, reason in factory_materials(
            profile,
            config["adapters"][profile["adapter"]]["worker_instructions"],
            role,
            process,
            node,
            data,
        )
    ]
    if process == "implement":
        orchestrator_paths = {
            str(root / rel)
            for rel in (
                "roles/orchestrator.md",
                "contracts/orchestrator.md",
                "skills/factory-implement/SKILL.md",
            )
        }
        for file, _, _ in materials:
            ensure(
                str(file) not in orchestrator_paths,
                f"Coordinator instructions cannot be injected as worker material: "
                f"{file.relative_to(root)}. Check adapter worker_instructions or role configuration.",
            )
    policy = config["_project"]
    task = data.get("task") or TaskSelection()
    scope = task.get("scope", data.get("scope_files"))
    pinned = None
    if process == "code-review":
        pinned = data.get("project_policy")
        if pinned is None:
            raise ValueError("Code review context requires pinned project_policy")
        policy = {
            **policy,
            "data": validate_snapshot(pinned),
            "hash": pinned["sha256"],
            "files": {},
        }
        selected = []
    else:
        if not active:
            check_frozen(policy["files"])
            check_frozen(config.get("_project_documents", {}))
        selected = selected_materials(
            policy,
            workspace,
            process=process,
            audience="worker",
            resolve=lambda root, rel: (
                accepted_path(config, root, rel) if active else safe_path(root, rel)
            ),
            role=role,
            stage=node.get("stage"),
            scope=scope,
        )
    project_reading = _project_materials(
        config, root, workspace, reads, include_agents=pinned is None
    )
    forbidden = coordinator_instructions(config, root)
    for file, rule in selected:
        ensure(
            str(file) not in forbidden and file.name != "SKILL.md",
            "Coordinator instructions cannot be injected as project rules",
        )
        materials.append((file, "project profile: " + rule["id"], "project"))
    user = root / "memory/USER.md"
    if pinned is None and str(user) in config["_files"]:
        materials.append(
            (accepted_path(config, root, "memory/USER.md"), "project user instructions", "project")
        )
    materials.extend(project_reading)

    def packet_bytes(file: Path) -> bytes:
        return accepted_bytes(config, file, read_bytes)

    instructions = _read_instructions(materials, packet_bytes if active else read_bytes)
    if pinned is not None:
        accepted = review_materials(
            pinned, root, workspace, role=role, stage=node.get("stage") or "review", scope=scope
        )
        by_path = {entry["path"]: entry for entry in instructions}
        by_path.update({entry["path"]: entry for entry in accepted})
        instructions = list(by_path.values())
    _label_instructions(config, policy["files"], instructions, selected, active)
    packet = dict(data)
    packet.update(
        {
            "process": process,
            "role": role,
            "workspace": str(workspace),
            "profile": {
                key: value for key, value in profile.items() if key in WORKER_PROFILE_FIELDS
            },
            "model": config["models"][profile["model"]],
            "instructions": instructions,
            "project_policy": {
                "id": policy["data"]["id"],
                "sha256": policy["hash"],
                "scope_status": "unknown" if scope is None else "known",
                "gates": boundary_gates(
                    policy["data"],
                    "implement." + str(node.get("stage")),
                    task,
                )
                if process == "implement"
                else [],
                "review_criteria": [
                    g
                    for g in review_criteria(
                        policy["data"],
                        "code-review.complete" if process == "code-review" else "implement.review",
                    )
                    if matches(
                        g.get("for", {}),
                        process=process,
                        role=role,
                        stage=node.get("stage"),
                        scope=scope,
                    )
                    and (role != "reviewer" or g["lens"] == data.get("lens"))
                    and (role != "reviewer" or g["id"] not in data.get("owned_gates", {}))
                ]
                if role in {"judge", "reviewer"}
                else [],
            },
        }
    )
    try:
        return CONTEXT_PACKET.validate_python(packet)
    except ValidationError as exc:
        raise ValueError(
            validation_message("Invalid context packet", exc, CONTEXT_PACKET)
        ) from None


def build_parser(
    parser: argparse.ArgumentParser | None = None,
) -> argparse.ArgumentParser:
    parser = parser or argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", default=".factory/factory.yaml")
    parser.add_argument("--workspace", default=".")
    parser.add_argument("--process", choices=sorted(PROCESS_ROLES), required=True)
    parser.add_argument("--role", required=True)
    parser.add_argument("--profile", required=True)
    parser.add_argument(
        "assignment", help="JSON with source, exact artifact/write paths and read documents"
    )
    return parser


def run(args: argparse.Namespace, parser: argparse.ArgumentParser) -> None:
    from factory.runtime.workflow_config import load_config

    try:
        with diagnostic_operation(args.workspace, "context"):
            assignment = json.loads(file_reader.read_text(Path(args.assignment), encoding="utf-8"))
            policy: Policy | None = None
            if args.process == "code-review":
                pinned = CONTEXT_INPUT.validate_python(assignment).get("project_policy")
                if pinned is None:
                    raise ValueError("Code review context requires pinned project_policy")
                workspace = Path(args.workspace).resolve()
                policy = {
                    "data": validate_snapshot(pinned),
                    "hash": pinned["sha256"],
                    "path": str(workspace / pinned["profile_root"] / pinned["manifest"]),
                    "workspace": str(workspace),
                    "profile_root": pinned["profile_root"],
                    "files": {},
                }
            packet = build(
                load_config(args.config, policy=policy),
                args.workspace,
                args.profile,
                args.role,
                args.process,
                assignment,
            )
            print(json.dumps(packet, ensure_ascii=False, indent=2))
    except (ValueError, KeyError, OSError) as exc:
        if getattr(args, "json", False):
            raise
        parser.exit(1, f"BLOCKED: {exc}\n")


def main() -> None:
    parser = build_parser()
    run(parser.parse_args(), parser)


if __name__ == "__main__":
    main()
