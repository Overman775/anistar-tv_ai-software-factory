"""Load and validate factory configuration and freeze runtime dependencies."""

from __future__ import annotations

import re
from collections.abc import Iterator
from copy import deepcopy
from pathlib import Path
from typing import Any, cast

import yaml

# Direct CLI execution and import-by-path use the same tool modules.
from factory_tooling.context import context
from factory_tooling.project.contracts import Selection
from factory_tooling.project.profile_io import freeze_materials, load_profile, safe_path
from factory_tooling.runtime import escalation
from factory_tooling.runtime.contracts import (
    Config,
    Graph,
    Node,
    Profile,
    State,
    agent_key,
)
from factory_tooling.runtime.workflow_core import (
    Invalid,
    acceptance_guard,
    digest,
    relative,
    require,
)


def fields(value: Any, allowed: set[str], label: str) -> None:
    if not (isinstance(value, dict)):
        raise Invalid(f"{label} must be a mapping")
    require(
        not (set(value) - set(allowed)),
        f"Unknown {label} fields: {set(value) - set(allowed)}",
    )


def expand_profiles(groups: Any) -> tuple[dict[str, Profile], dict[str, str]]:
    """One explicit group per specialty; emit the existing flat runtime contract."""
    if not (isinstance(groups, dict) and groups):
        raise Invalid("Missing profile groups")
    common_fields = ("role", "contract", "capabilities", "enforcement", "mcp")
    profiles, defaults = {}, {}
    for role, group in groups.items():
        if not (isinstance(role, str) and re.fullmatch("[a-z][a-z0-9-]*", role)):
            raise Invalid("Invalid profile group")
        fields(
            group,
            set(common_fields) | {"default", "variants", "initial_profile_decision"},
            "profile group",
        )
        require(
            set(common_fields) <= set(group),
            "Profile group needs explicit common fields",
        )
        require(
            group["role"] == f"roles/{role}.md" and group["contract"] == f"contracts/{role}.md",
            "Profile group and role/contract must identify the same specialty",
        )
        variants = group.get("variants")
        if not (isinstance(variants, dict) and variants):
            raise Invalid("Profile group needs variants")
        default = group.get("default", next(iter(variants)) if len(variants) == 1 else None)
        if not (isinstance(default, str) and default in variants):
            raise Invalid("Multiple profiles require an explicit valid default")
        if "default" in group:
            defaults[group["role"]] = default
        for name, variant in variants.items():
            if not (
                isinstance(name, str)
                and re.fullmatch("[a-z][a-z0-9-]*", name)
                and (name != "human")
            ):
                raise Invalid("Invalid profile name")
            require(name not in profiles, f"Duplicate profile name: {name}")
            fields(variant, {"model", "adapter", "escalation"}, "profile variant")
            if not (
                isinstance(variant.get("model"), str) and isinstance(variant.get("adapter"), str)
            ):
                raise Invalid("Profile variant needs model and adapter")
            profiles[name] = deepcopy({k: group[k] for k in common_fields} | variant)
            if "initial_profile_decision" in group:
                profiles[name]["initial_profile_decision"] = group["initial_profile_decision"]
    return profiles, defaults


def load_config(path: str | Path) -> Config:
    if not (yaml is not None):
        raise Invalid("Install .factory/tools/requirements.txt in a virtualenv")
    path = Path(path).resolve()

    # Reject duplicate keys: silently overriding a model or limit is unsafe.
    class UniqueLoader(yaml.SafeLoader):
        pass

    def mapping(
        loader: yaml.SafeLoader, node: yaml.MappingNode, deep: bool = False
    ) -> dict[str, Any]:
        result = {}
        for key_node, value_node in node.value:
            key = loader.construct_object(key_node, deep=deep)
            require(key not in result, f"Duplicate YAML key: {key}")
            result[key] = loader.construct_object(value_node, deep=deep)
        return result

    UniqueLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, mapping)
    raw = path.read_bytes()
    c = yaml.load(raw, Loader=UniqueLoader)  # noqa: S506  # SafeLoader with duplicate-key rejection.
    fields(
        c,
        {
            "project",
            "router",
            "orchestration",
            "orchestrator",
            "execution",
            "profiles",
            "models",
            "adapters",
            "native",
            "acpx",
        },
        "configuration",
    )
    c["profiles"], defaults = expand_profiles(c.get("profiles"))
    c["routing"] = {"defaults": defaults}
    fields(c.get("native"), {"max_parallel_agents"}, "native")
    require("max_parallel_agents" in c["native"], "Missing native limit")
    models = c.get("models")
    if not (isinstance(models, dict) and models):
        raise Invalid("Missing models")
    for name, model in models.items():
        if not (isinstance(name, str) and re.fullmatch("[a-z][a-z0-9-]*", name)):
            raise Invalid("Invalid model alias")
        fields(model, {"id", "effort"}, "model")
        if not (
            "id" in model
            and (model["id"] is None or (isinstance(model["id"], str) and model["id"].strip()))
        ):
            raise Invalid("Model needs explicit id or null")
        if not (
            "effort" not in model or (isinstance(model["effort"], str) and model["effort"].strip())
        ):
            raise Invalid("Invalid model effort")
    if "orchestrator" in c:
        fields(c["orchestrator"], {"model"}, "orchestrator")
        alias = c["orchestrator"].get("model")
        require(isinstance(alias, str) and alias in models, "Unknown orchestrator model alias")
    require("project" in c, "Missing project profile; select it explicitly")
    require(
        not any(k in c for k in ("extensions", "runtime")),
        "External runtime/packs are not supported in this profile version",
    )
    c["_project"] = acceptance_guard(
        load_profile, acceptance_guard(safe_path, path.parent, c["project"])
    )
    validate_profile_decisions(c)
    require(
        relative(path.parent, c["orchestration"]).is_file(),
        "Missing orchestration policy",
    )
    require(
        c.get("router") and relative(path.parent, c["router"]).is_file(),
        "Missing router policy",
    )
    limits = {"native": c["native"]["max_parallel_agents"]}
    endpoints = set()
    acpx = c.get("acpx", {})
    if not (isinstance(acpx, dict) and set(acpx) <= {"command", "connections"}):
        raise Invalid(
            "Unsupported acpx field; MCP servers and credentials belong in the harness configuration"
        )
    for name, conn in c.get("acpx", {}).get("connections", {}).items():
        if not (re.fullmatch("[a-z][a-z0-9-]*", name)):
            raise Invalid("Invalid connection alias")
        if not (
            isinstance(conn, dict)
            and set(conn) <= {"command", "args", "max_parallel_agents", "permissions"}
        ):
            raise Invalid(
                "Unsupported connection field; env/MCP injection is not implemented; configure the harness"
            )
        if not (isinstance(conn.get("args", []), list)):
            raise Invalid("Connection args must be an argv list")
        argv = [conn["command"], *conn.get("args", [])]
        if not (all(isinstance(x, str) and x for x in argv)):
            raise Invalid("Invalid connection argv")
        endpoint = tuple(argv)
        require(
            endpoint not in endpoints,
            "Duplicate backend alias; use one shared connection pool",
        )
        endpoints.add(endpoint)
        require(
            conn.get("permissions", "approve-reads")
            in {"approve-reads", "approve-all", "deny-all"},
            "Invalid permission mode",
        )
        limits[f"acpx:{name}"] = conn["max_parallel_agents"]
    require(
        all(type(v) is int and v > 0 for v in limits.values()),
        "Limits must be positive integers",
    )
    files = {str(path): digest(raw)}
    files.update(c["_project"]["files"])
    if not (isinstance(c.get("adapters"), dict) and c["adapters"]):
        raise Invalid("Missing adapters")
    for name, adapter in c["adapters"].items():
        if not (isinstance(name, str) and re.fullmatch("[a-z][a-z0-9-]*", name)):
            raise Invalid("Invalid adapter alias")
        fields(
            adapter,
            {"instructions", "worker_instructions", "harness", "runner", "connection"},
            "adapter",
        )
        if not (
            isinstance(adapter, dict)
            and isinstance(adapter.get("harness"), str)
            and re.fullmatch("[a-z][a-z0-9-]*", adapter["harness"])
        ):
            raise Invalid("Unknown adapter harness")
        require(adapter.get("runner") in {"native", "acpx"}, "Unknown adapter runner")
        require(
            (adapter["runner"] == "native" and adapter["harness"] in {"codex", "claude"})
            or adapter["runner"] == "acpx",
            "Unsupported runner/harness mapping",
        )
        if adapter["runner"] == "acpx":
            require(f"acpx:{adapter.get('connection')}" in limits, "Unknown connection")
        else:
            require("connection" not in adapter, "Native adapter cannot have ACP connection")
        for field in ("instructions", "worker_instructions"):
            value = adapter.get(field)
            if not isinstance(value, str):
                raise Invalid(f"Missing adapter {field}")
            f = relative(path.parent, value)
            require(f.is_file(), f"Missing adapter {field}")
            files[str(f)] = digest(f.read_bytes())
    for p in c["profiles"].values():
        require("instructions" not in p, "Profile instructions renamed to role")
        require(
            not any(k in p for k in ("runner", "harness", "connection")),
            "Transport belongs in adapters, not profiles",
        )
        require(
            p.get("role") and p.get("adapter") in c["adapters"],
            "Profile needs role and known adapter",
        )
        require(p["model"] in c["models"], "Unknown model alias")
        caps = p.get("capabilities")
        if not (
            isinstance(caps, dict)
            and set(caps) == {"read", "edit", "commands", "web"}
            and all(type(v) is bool for v in caps.values())
        ):
            raise Invalid("Explicit boolean capabilities required")
        require(caps["read"], "Profiles must read assigned instructions")
        require(
            p.get("enforcement") in {"instructions", "required"},
            "Explicit enforcement required",
        )
        if not (
            isinstance(p.get("mcp"), list)
            and all(
                isinstance(x, str) and re.fullmatch("[a-z][a-z0-9-]*\\.[A-Za-z0-9_-]+", x)
                for x in p["mcp"]
            )
        ):
            raise Invalid("Invalid MCP capability list")
        require(p.get("contract"), "Profile needs role interface contract")
        for key in ("role", "contract"):
            if key in p:
                f = relative(path.parent, p[key])
                require(f.is_file(), f"Missing {key}: {f}")
                files[str(f)] = digest(f.read_bytes())
        # Derived transport fields are frozen in run state; YAML stays single-source.
        p.update({k: v for k, v in c["adapters"][p["adapter"]].items() if k != "instructions"})
    for key in ("orchestration", "router"):
        policy = relative(path.parent, c[key])
        files[str(policy)] = digest(policy.read_bytes())
    acceptance_guard(escalation.configure, c)
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
        "tools/workflow.py",
        "gates/skills/planning/validate_plan.py",
        "factory_tooling/runtime/acceptance.py",
        "factory_tooling/runtime/workflow.py",
        "factory_tooling/runtime/workflow_core.py",
        "factory_tooling/runtime/workflow_sources.py",
        "factory_tooling/runtime/workflow_config.py",
        "factory_tooling/runtime/workflow_graph.py",
        "factory_tooling/runtime/command_contract.py",
        "factory_tooling/runtime/assignment.py",
        "factory_tooling/runtime/check_process.py",
        "factory_tooling/runtime/review_findings.py",
        "factory_tooling/runtime/escalation.py",
        "factory_tooling/runtime/transition_gates.py",
        "factory_tooling/gates/gate_contract.py",
        "factory_tooling/gates/catalog.py",
        "factory_tooling/runtime/escalation_policy.py",
        "factory_tooling/adapters/acpx_adapter.py",
        "factory_tooling/decisions/decision_contract.py",
        "contracts/common/decisions.md",
        "factory_tooling/project/profile_rules.py",
        "factory_tooling/project/profile_io.py",
        "factory_tooling/project/project.py",
        "factory_tooling/planning/validate_plan.py",
        "factory_tooling/planning/plan_document.py",
        "factory_tooling/planning/plan_rules.py",
        "factory_tooling/planning/plan_revision.py",
    ):
        contract = relative(path.parent, relative_path)
        require(contract.is_file(), f"Missing factory dependency: {relative_path}")
        dependencies.add(contract)
    for reference in (path.parent / "skills/factory-implement/references").glob("*.md"):
        dependencies.add(relative(path.parent, reference.relative_to(path.parent).as_posix()))
    for module in (path.parent / "factory_tooling").rglob("*.py"):
        dependencies.add(relative(path.parent, module.relative_to(path.parent).as_posix()))
    for rel in context.factory_files(c):
        file = relative(path.parent, rel)
        require(file.is_file(), f"Missing context dependency: {rel}")
        dependencies.add(file)
    for dependency in dependencies:
        if str(dependency) not in files:
            files[str(dependency)] = digest(dependency.read_bytes())
    c["_path"], c["_files"], c["_limits"] = str(path), files, limits
    return cast(Config, c)


def validate_profile_decisions(config: Config) -> None:
    from factory_tooling.decisions.decision_contract import parse_definition

    definitions = {d["id"]: d for d in config["_project"]["data"].get("decisions", [])}
    groups: dict[str, set[str]] = {}
    links: dict[str, object] = {}
    for name, profile in config["profiles"].items():
        role = profile["role"]
        groups.setdefault(role, set()).add(name)
        if "initial_profile_decision" in profile:
            links[role] = profile["initial_profile_decision"]
    for role, decision_id in links.items():
        require(
            isinstance(decision_id, str) and decision_id in definitions,
            "Missing profile decision",
        )
        definition = acceptance_guard(parse_definition, definitions[decision_id])
        require(
            definition.kind == "choice"
            and set(definition.options) == groups[role] | {"no-eligible-profile"},
            "Profile decision choices must match the role",
        )


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


def check_config(state: State) -> None:
    for path, expected in state["config"]["_files"].items():
        require(
            Path(path).is_file() and digest(Path(path).read_bytes()) == expected,
            "Config/instructions drift; reconcile explicitly",
        )
    actual = acceptance_guard(
        freeze_materials,
        state["config"]["_project"],
        state["workspace"],
        graph_selections(state["graph"]),
    )
    require(
        actual == state["config"].get("_project_documents", {}),
        "Project document/scope drift; reconcile explicitly",
    )


def graph_selections(graph: Graph) -> Iterator[Selection]:
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


def freeze_project(config: Config, graph: Graph, workspace: str | Path) -> Config:
    from copy import deepcopy

    result = deepcopy(config)
    result["_project_documents"] = acceptance_guard(
        freeze_materials, config["_project"], workspace, graph_selections(graph)
    )
    return result


def pool(config: Config, profile: str) -> str:
    p = config["profiles"][profile]
    return "native" if p["runner"] == "native" else "acpx:" + p["connection"]
