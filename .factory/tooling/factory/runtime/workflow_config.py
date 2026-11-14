"""Load and validate factory configuration and freeze runtime dependencies."""

from __future__ import annotations

from collections.abc import Iterator
from copy import deepcopy
from pathlib import Path
from typing import Annotated, NotRequired

import yaml
from pydantic import ConfigDict, Field, TypeAdapter, ValidationError, with_config

# Direct CLI execution and import-by-path use the same tool modules.
from factory.context import context
from factory.project.contracts import Selection
from factory.project.profile_io import (
    freeze_materials,
    load_profile,
    parse_yaml,
    safe_path,
)
from factory.runtime import escalation
from factory.runtime.contracts import (
    Alias,
    Config,
    GraphTopology,
    Node,
    Profile,
    ProfileCommon,
    ProfileVariant,
    Settings,
    State,
    agent_key,
)
from factory.runtime.workflow_core import (
    Invalid,
    acceptance_guard,
    digest,
    relative,
    require,
)
from factory.validation import validation_message


@with_config(ConfigDict(strict=True, extra="forbid"))
class ProfileGroup(ProfileCommon):
    default: NotRequired[Alias]
    variants: Annotated[dict[Alias, ProfileVariant], Field(min_length=1)]


ProfileGroups = Annotated[dict[Alias, ProfileGroup], Field(min_length=1)]


@with_config(ConfigDict(strict=True, extra="forbid"))
class FactoryConfig(Settings):
    profiles: ProfileGroups


FACTORY_CONFIG = TypeAdapter[FactoryConfig](FactoryConfig)
PROFILE_GROUPS = TypeAdapter[ProfileGroups](ProfileGroups, config=ConfigDict(strict=True))
RUNTIME_CONFIG = TypeAdapter[Config](Config)


def expand_profiles(groups: object) -> tuple[dict[str, Profile], dict[str, str]]:
    try:
        return _expand_profiles(PROFILE_GROUPS.validate_python(groups))
    except ValidationError as exc:
        raise Invalid(validation_message("Invalid profile groups", exc, PROFILE_GROUPS)) from None


def _expand_profiles(groups: ProfileGroups) -> tuple[dict[str, Profile], dict[str, str]]:
    """One explicit group per specialty; emit the flat runtime contract."""
    profiles: dict[str, Profile] = {}
    defaults: dict[str, str] = {}
    for role, group in groups.items():
        require(
            group["role"] == f"roles/{role}.md" and group["contract"] == f"contracts/{role}.md",
            "Profile group and role/contract must identify the same specialty",
        )
        variants = group["variants"]
        default = group.get("default", next(iter(variants)) if len(variants) == 1 else "")
        require(default in variants, "Multiple profiles require an explicit valid default")
        if "default" in group:
            defaults[group["role"]] = default
        for name, variant in variants.items():
            require(
                name != "human" and name not in profiles,
                f"Invalid or duplicate profile name: {name}",
            )
            profiles[name] = {
                "role": group["role"],
                "contract": group["contract"],
                "capabilities": group["capabilities"].copy(),
                "enforcement": group["enforcement"],
                "mcp": list(group["mcp"]),
                "model": variant["model"],
                "adapter": variant["adapter"],
            }
            if "escalation" in variant:
                profiles[name]["escalation"] = deepcopy(variant["escalation"])
    return profiles, defaults


def load_config(path: str | Path) -> Config:
    if yaml is None:
        raise Invalid("Install .factory/tooling/requirements.txt in a virtualenv")
    path = Path(path).resolve()
    raw = path.read_bytes()
    try:
        settings = FACTORY_CONFIG.validate_python(parse_yaml(raw))
    except ValidationError as exc:
        raise Invalid(
            validation_message("Invalid factory configuration", exc, FACTORY_CONFIG)
        ) from None
    except ValueError as exc:
        raise Invalid(f"Invalid factory configuration: {exc}") from exc
    profiles, defaults = _expand_profiles(settings["profiles"])
    models = settings["models"]
    if "orchestrator" in settings:
        require(settings["orchestrator"]["model"] in models, "Unknown orchestrator model alias")
    policy = acceptance_guard(
        load_profile, acceptance_guard(safe_path, path.parent, settings["project"])
    )
    require(relative(path.parent, settings["router"]).is_file(), "Missing router policy")
    require(
        relative(path.parent, settings["orchestration"]).is_file(), "Missing orchestration policy"
    )
    limits = {"native": settings["native"]["max_parallel_agents"]}
    endpoints = set()
    if "acpx" in settings:
        for name, conn in settings["acpx"]["connections"].items():
            endpoint = (conn["command"], *conn.get("args", []))
            require(
                endpoint not in endpoints,
                "Duplicate backend alias; use one shared connection pool",
            )
            endpoints.add(endpoint)
            limits[f"acpx:{name}"] = conn["max_parallel_agents"]

    files = {str(path): digest(raw), **policy["files"]}
    adapters = settings["adapters"]
    for adapter in adapters.values():
        if adapter["runner"] == "acpx":
            require(f"acpx:{adapter.get('connection')}" in limits, "Unknown connection")
        else:
            require(adapter["harness"] in {"codex", "claude"}, "Unsupported runner/harness mapping")
            require("connection" not in adapter, "Native adapter cannot have ACP connection")
        for name in (adapter["instructions"], adapter["worker_instructions"]):
            f = relative(path.parent, name)
            require(f.is_file(), f"Missing adapter instruction: {name}")
            files[str(f)] = digest(f.read_bytes())
    for p in profiles.values():
        require(p["adapter"] in adapters, "Profile needs known adapter")
        require(p["model"] in models, "Unknown model alias")
        require(p["capabilities"]["read"], "Profiles must read assigned instructions")
        for name in (p["role"], p["contract"]):
            f = relative(path.parent, name)
            require(f.is_file(), f"Missing role/contract: {name}")
            files[str(f)] = digest(f.read_bytes())
        adapter = adapters[p["adapter"]]
        p["worker_instructions"] = adapter["worker_instructions"]
        p["harness"] = adapter["harness"]
        p["runner"] = adapter["runner"]
        if "connection" in adapter:
            p["connection"] = adapter["connection"]
    for name in (settings["orchestration"], settings["router"]):
        file = relative(path.parent, name)
        files[str(file)] = digest(file.read_bytes())

    roles, runtime_defaults = acceptance_guard(escalation.routing, profiles, defaults)
    result = {
        **settings,
        "profiles": profiles,
        "routing": {"defaults": defaults},
        "_roles": roles,
        "_defaults": runtime_defaults,
        "_project": policy,
        "_path": str(path),
        "_files": files,
        "_limits": limits,
    }
    try:
        c = RUNTIME_CONFIG.validate_python(result)
    except ValidationError as exc:
        raise Invalid(
            validation_message("Invalid runtime configuration", exc, RUNTIME_CONFIG)
        ) from None
    files = c["_files"]
    dependencies: set[Path] = set()
    for relative_path in (
        "skills/factory-implement/SKILL.md",
        "roles/orchestrator.md",
        "workflow/README.md",
        "contracts/common/agent-checkpoint.md",
        "skills/factory-implement/references/execution-source-contract.md",
        "contracts/orchestrator.md",
        "contracts/common/communication.md",
        "contracts/common/project-policy.md",
        "gates/common/verification-rules.md",
        "gates/skills/implement.md",
        "gates/skills/planning/gate.md",
        "gates/skills/decompose/gate.md",
        "gates/skills/code-review/gate.md",
        "contracts/common/review-findings.md",
        "tooling/bin/workflow.py",
        "gates/skills/planning/validate_plan.py",
        "tooling/factory/runtime/acceptance.py",
        "tooling/factory/runtime/workflow.py",
        "tooling/factory/runtime/workflow_core.py",
        "tooling/factory/runtime/workflow_sources.py",
        "tooling/factory/runtime/workflow_config.py",
        "tooling/factory/runtime/workflow_graph.py",
        "tooling/factory/checks/command.py",
        "tooling/factory/runtime/assignment.py",
        "tooling/factory/runtime/check_process.py",
        "tooling/factory/runtime/review_findings.py",
        "tooling/factory/runtime/escalation.py",
        "tooling/factory/runtime/transition_gates.py",
        "tooling/factory/gates/gate_contract.py",
        "tooling/factory/gates/catalog.py",
        "tooling/factory/runtime/escalation_policy.py",
        "tooling/factory/adapters/acpx_adapter.py",
        "tooling/factory/decisions/decision_contract.py",
        "contracts/common/decisions.md",
        "tooling/factory/project/profile_rules.py",
        "tooling/factory/project/profile_io.py",
        "tooling/factory/project/project.py",
        "tooling/factory/planning/validate_plan.py",
        "tooling/factory/planning/plan_document.py",
        "tooling/factory/planning/plan_rules.py",
        "tooling/factory/planning/plan_revision.py",
    ):
        contract = relative(path.parent, relative_path)
        require(contract.is_file(), f"Missing factory dependency: {relative_path}")
        dependencies.add(contract)
    for reference in (path.parent / "skills/factory-implement/references").glob("*.md"):
        dependencies.add(relative(path.parent, reference.relative_to(path.parent).as_posix()))
    for module in (path.parent / "tooling/factory").rglob("*.py"):
        dependencies.add(relative(path.parent, module.relative_to(path.parent).as_posix()))
    for rel in context.factory_files(c):
        file = relative(path.parent, rel)
        require(file.is_file(), f"Missing context dependency: {rel}")
        dependencies.add(file)
    for dependency in dependencies:
        if str(dependency) not in files:
            files[str(dependency)] = digest(dependency.read_bytes())
    return c


def check_capabilities(profile: Profile, node: Node | None = None) -> None:
    require(
        profile["enforcement"] == "instructions",
        "BLOCKED_CAPABILITIES: generic adapter cannot enforce required tool isolation",
    )
    if node:
        require(
            not node.get("owns") or profile["capabilities"]["edit"],
            "Profile forbids edits",
        )
        require(
            "project-checks" not in node.get("resources", [])
            or profile["capabilities"]["commands"],
            "Profile forbids project commands",
        )


def check_config(state: State, *, graph: GraphTopology | None = None) -> None:
    for path, expected in state["config"]["_files"].items():
        require(
            Path(path).is_file() and digest(Path(path).read_bytes()) == expected,
            "Config/instructions drift; reconcile explicitly",
        )
    actual = acceptance_guard(
        freeze_materials,
        state["config"]["_project"],
        state["workspace"],
        graph_selections(graph if graph is not None else state["graph"]),
    )
    require(
        actual == state["config"].get("_project_documents", {}),
        "Project document/scope drift; reconcile explicitly",
    )


def graph_selections(graph: GraphTopology) -> Iterator[Selection]:
    scope = sorted({p for t in graph["tasks"].values() for p in t["scope"]})
    yield dict(process="implement", audience="coordinator", scope=scope)
    for node in graph["nodes"]:
        if node["stage"] != "accept":
            yield dict(
                process="implement",
                audience="worker",
                stage=node["stage"],
                role=graph["agents"][agent_key(node)]["role"],
                scope=graph["tasks"][node["task"]]["scope"],
            )


def freeze_project(config: Config, graph: GraphTopology, workspace: str | Path) -> Config:
    from copy import deepcopy

    result = deepcopy(config)
    result["_project_documents"] = acceptance_guard(
        freeze_materials, config["_project"], workspace, graph_selections(graph)
    )
    return result


def pool(config: Config, profile: str) -> str:
    p = config["profiles"][profile]
    return "native" if p["runner"] == "native" else "acpx:" + p["connection"]
