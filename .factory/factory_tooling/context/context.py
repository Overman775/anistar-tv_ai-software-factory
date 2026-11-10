"""Build worker packets shared by native and ACP; no model calls.

Public entry points: build, factory_files, CLI main.
Validation, material selection and byte loading are separate steps.
Extend ROLE_REFS for role documents or STAGE_RULES for conditional documents;
factory_files derives frozen dependencies from those same rules.
"""

from __future__ import annotations

# Direct CLI execution and import-by-path use the same tool modules.
import hashlib
import json
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path
from typing import Any, cast

from factory_tooling.project.contracts import MaterialEntry, Rule
from factory_tooling.project.profile_io import (
    check_frozen,
    review_materials,
    selected_materials,
    validate_snapshot,
)
from factory_tooling.project.profile_rules import boundary_gates, matches, review_criteria
from factory_tooling.runtime.acceptance import ensure
from factory_tooling.runtime.contracts import Config, Node, Profile

PROCESS_ROLES = {
    "implement": {
        "developer",
        "test-writer",
        "generalist",
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
ROLE_REFS = {
    "developer": ["gates/roles/developer.md", "contracts/common/coding-principles.md"],
    "test-writer": ["gates/roles/test-writer.md", "contracts/common/testing-principles.md"],
    "generalist": [
        "gates/roles/generalist.md",
        "contracts/common/coding-principles.md",
        "contracts/common/testing-principles.md",
    ],
    "architect": [
        "skills/factory-planning/references/architect-input.md",
        "skills/factory-planning/references/plan-contract.md",
        "contracts/common/implementation-detail.md",
    ],
    "task-decomposer": [
        "skills/factory-decompose/references/decomposition-policy.md",
        "skills/factory-decompose/references/generation-contract.md",
        "skills/factory-decompose/references/task-template.md",
        "contracts/common/implementation-detail.md",
    ],
    "task-reviewer": [
        "skills/factory-decompose/references/decomposition-policy.md",
        "skills/factory-decompose/references/generation-contract.md",
        "skills/factory-decompose/references/task-template.md",
        "contracts/common/implementation-detail.md",
    ],
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


@dataclass(frozen=True)
class MaterialRule:
    """A factory document group selected by process, role and reserved resource."""

    paths: tuple[str, ...]
    reason: str
    process: str
    roles: frozenset[str] = frozenset()
    resource: str | None = None

    def matches(self, process: str, role: str, node: Node) -> bool:
        return (
            self.process == process
            and (not self.roles or role in self.roles)
            and (self.resource is None or self.resource in node.get("resources", []))
        )


STAGE_RULES = (
    MaterialRule(
        ("contracts/common/implement-result.md",), "Implement result/stage interface", "implement"
    ),
    MaterialRule(
        tuple(COMMAND_REFS), "reserved command stage", "implement", resource="project-checks"
    ),
    MaterialRule(
        (REVIEW_FINDINGS_CONTRACT,),
        "Implement review/correction interface",
        "implement",
        roles=frozenset({"developer", "test-writer", "doc-writer", "judge"}),
    ),
)
WORKER_PROFILE_FIELDS = ("role", "contract", "adapter", "capabilities", "enforcement", "mcp")
IMPLEMENT_STAGES = {"work", "docs", "explore", "verify", "review"}


def path(root: str | Path, rel: str) -> Path:
    if not (
        isinstance(rel, str)
        and rel
        and (not Path(rel).is_absolute())
        and (".." not in Path(rel).parts)
    ):
        raise ValueError("Invalid context path")
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
    ensure(target.is_file(), f"Missing context file: {rel}")
    return target


def factory_files(config: Config) -> list[str]:
    """Files that affect packet selection/content; freeze with the active config."""
    result = set(
        COMMON
        + [
            "contracts/common/project-policy.md",
            "adapters/common.md",
            "adapters/worker/native-packet.md",
            "tools/context.py",
            "tools/acpx_adapter.py",
        ]
    )
    result.update(
        ["tools/python_runtime.py", "tools/python.sh", "tools/python.cmd", "tools/requirements.txt"]
    )
    result.update(p for rule in STAGE_RULES for p in rule.paths)
    result.update(p for refs in ROLE_REFS.values() for p in refs)
    for adapter in config["adapters"].values():
        result.add(adapter["worker_instructions"])
    return sorted(result)


def _validate_assignment(
    config: Config, profile_name: str, role: str, process: str, assignment: Any
) -> tuple[Profile, Node, list[str]]:
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
    if not (
        isinstance(assignment, dict)
        and isinstance(assignment.get("source"), dict)
        and assignment["source"]
    ):
        raise ValueError("Context requires explicit source data")
    profile = config["profiles"][profile_name]
    ensure(
        profile["enforcement"] == "instructions",
        "BLOCKED_CAPABILITIES: generic adapter cannot enforce required tool isolation",
    )
    node = assignment.get("node", {})
    if not (isinstance(node, dict)):
        raise ValueError("Invalid context node")
    resources = node.get("resources", [])
    if not (isinstance(resources, list) and all(isinstance(r, str) for r in resources)):
        raise ValueError("Invalid context resources")
    ensure(not node.get("owns") or profile["capabilities"]["edit"], "Profile forbids edits")
    if process == "implement":
        if not (isinstance(node.get("stage"), str) and node["stage"] in IMPLEMENT_STAGES):
            raise ValueError("Invalid worker stage")
        if not (isinstance(assignment.get("task"), dict) and assignment["task"].get("scope")):
            raise ValueError("Missing task context")
        ensure(
            "project-checks" not in resources or profile["capabilities"]["commands"],
            "Context commands forbidden by profile",
        )
    reads = node.get("read", assignment.get("read", []))
    if not (isinstance(reads, list)):
        raise ValueError("Invalid project reading list")
    ensure(all(isinstance(item, str) for item in reads), "Invalid project reading list")
    return profile, cast(Node, node), cast(list[str], reads)


def _generalist_owns_unresolved_finding(node_id: object, findings: object) -> bool:
    if not isinstance(node_id, str) or not isinstance(findings, dict):
        return False
    return any(
        isinstance(item, dict)
        and item.get("owner_node_id") == node_id
        and item.get("owner_role") == "generalist"
        and item.get("status") in ("open", "ready")
        for item in findings.values()
    )


def _factory_materials(
    config: Config,
    profile: Profile,
    role: str,
    process: str,
    node: Node,
    assignment: dict[str, Any],
) -> list[tuple[str, str]]:
    """Select paths and reasons without reading files or changing the assignment."""
    selected = [(p, "shared worker/verification rules") for p in COMMON]
    selected += [
        (profile["contract"], "role interface"),
        (profile["role"], "role procedure"),
        (config["adapters"][profile["adapter"]]["worker_instructions"], "worker environment"),
    ]
    if process == "implement" and profile["runner"] == "native":
        selected.append(("adapters/worker/native-packet.md", "native packet transport"))
    selected += [(p, "process-specific role reference") for p in ROLE_REFS.get(role, [])]
    for rule in STAGE_RULES:
        if rule.matches(process, role, node):
            selected.extend((p, rule.reason) for p in rule.paths)
    if (
        process == "implement"
        and role == "generalist"
        and _generalist_owns_unresolved_finding(
            node.get("id", assignment.get("node_id")), assignment.get("review_findings")
        )
    ):
        selected.append((REVIEW_FINDINGS_CONTRACT, "Assigned Implement review findings"))
    return selected


def coordinator_instructions(config: Config, root: Path) -> set[str]:
    """Resolve coordinator-only paths for every project-material entry point."""
    forbidden = {
        str((root / p).resolve())
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
    forbidden.update(str((root / a["instructions"]).resolve()) for a in config["adapters"].values())
    return forbidden


def _project_materials(
    config: Config, root: Path, workspace: Path, reads: list[str], *, include_agents: bool = True
) -> list[tuple[Path, str, str]]:
    """Resolve project reading while excluding coordinator-only instructions."""
    forbidden = coordinator_instructions(config, root)
    selected = []
    for rel in (["AGENTS.md"] if include_agents else []) + reads:
        file = path(workspace, rel)
        ensure(
            str(file.resolve()) not in forbidden and file.name != "SKILL.md",
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


def build(
    config: Config,
    workspace: str | Path,
    profile_name: object,
    role: object,
    process: object,
    assignment: Any,
    *,
    read_bytes: Callable[[Path], bytes] = Path.read_bytes,
) -> dict[str, Any]:
    """Return a complete packet from a loaded config and explicit assignment.

    read_bytes is a narrow I/O seam; selection and path checks always apply.
    The reader returns original UTF-8 bytes or raises an I/O error.
    Existing positional callers and the JSON packet schema remain supported.
    """
    if not isinstance(role, str) or not isinstance(process, str):
        raise ValueError("Role not allowed in context process")
    if not isinstance(profile_name, str):
        raise ValueError("Context profile not allowed for role")
    profile, node, reads = _validate_assignment(config, profile_name, role, process, assignment)
    root, workspace = Path(config["_path"]).parent.resolve(), Path(workspace).resolve()
    materials = [
        (path(root, rel), reason, "worker")
        for rel, reason in _factory_materials(config, profile, role, process, node, assignment)
    ]
    if process == "implement":
        orchestrator_paths = {
            str((root / rel).resolve())
            for rel in (
                "roles/orchestrator.md",
                "contracts/orchestrator.md",
                "skills/factory-implement/SKILL.md",
            )
        }
        for file, _, _ in materials:
            ensure(
                str(file.resolve()) not in orchestrator_paths,
                f"Coordinator instructions cannot be injected as worker material: "
                f"{file.relative_to(root)}. Check adapter worker_instructions or role configuration.",
            )
    policy = config["_project"]
    scope = assignment.get("task", {}).get("scope", assignment.get("scope_files"))
    pinned = None
    if process == "code-review":
        pinned = assignment.get("project_policy")
        policy = {
            **policy,
            "data": validate_snapshot(pinned),
            "hash": pinned["sha256"],
            "files": {},
        }
        selected = []
    else:
        check_frozen(policy["files"])
        check_frozen(config.get("_project_documents", {}))
        selected = selected_materials(
            policy,
            workspace,
            process=process,
            audience="worker",
            role=role,
            stage=node.get("stage"),
            scope=scope,
        )
    forbidden = coordinator_instructions(config, root)
    for file, rule in selected:
        ensure(
            str(file.resolve()) not in forbidden and file.name != "SKILL.md",
            "Coordinator instructions cannot be injected as project rules",
        )
        materials.append((file, "project profile: " + rule["id"], "project"))
    materials.extend(
        _project_materials(config, root, workspace, reads, include_agents=pinned is None)
    )
    instructions = _read_instructions(materials, read_bytes)
    if pinned is not None:
        accepted = review_materials(pinned, root, workspace, role=role, scope=scope)
        by_path = {entry["path"]: entry for entry in instructions}
        by_path.update({entry["path"]: entry for entry in accepted})
        instructions = list(by_path.values())
    for entry in instructions:
        rules = [rule for file, rule in selected if str(file) == entry["path"]]
        if rules:
            entry["rules"] = [
                cast(Rule, {k: r[k] for k in ("id", "for", "usage") if k in r}) for r in rules
            ]
        expected = policy["files"].get(entry["path"]) or config.get("_project_documents", {}).get(
            entry["path"]
        )
        if not (expected is None or entry["sha256"] == expected):
            raise ValueError("Project policy changed during packet build")
    packet = dict(assignment)
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
                    assignment.get("task", {}),
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
                ]
                if role in {"judge", "reviewer"}
                else [],
            },
        }
    )
    return packet


def main() -> None:
    # Planning/Decompose use their own source gates; this command only assembles context.
    import argparse

    from factory_tooling.runtime.workflow_config import load_config

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", default=".factory/factory.yaml")
    parser.add_argument("--workspace", default=".")
    parser.add_argument("--process", choices=sorted(PROCESS_ROLES), required=True)
    parser.add_argument("--role", required=True)
    parser.add_argument("--profile", required=True)
    parser.add_argument(
        "assignment", help="JSON with source, exact artifact/write paths and read documents"
    )
    args = parser.parse_args()
    try:
        packet = build(
            load_config(args.config),
            args.workspace,
            args.profile,
            args.role,
            args.process,
            json.loads(Path(args.assignment).read_text()),
        )
        print(json.dumps(packet, ensure_ascii=False, indent=2))
    except (ValueError, KeyError, OSError) as exc:
        parser.exit(1, f"BLOCKED: {exc}\n")


if __name__ == "__main__":
    main()
