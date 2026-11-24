"""Workflow graph constraints, dependency traversal and diagram rendering."""

from __future__ import annotations

import re
import unicodedata
from collections.abc import Mapping, Sequence
from copy import deepcopy
from pathlib import Path
from typing import Any

from pydantic import TypeAdapter, ValidationError

from factory.project.profile_rules import (
    check_task,
    required_checks,
)
from factory.runtime.contracts import (
    Agent,
    Config,
    Graph,
    GraphTopology,
    Node,
    State,
    agent_key,
)
from factory.runtime.reports import acceptance, finish_requirements
from factory.runtime.workflow_core import (
    Invalid,
    acceptance_guard,
    relative,
    require,
)
from factory.tasks.contracts import Task
from factory.validation import validation_message

GRAPH = TypeAdapter[Graph](Graph)


def expand_intake_checks(raw: object, config: Config) -> Graph:
    """Expand opt-in project checks before validating and saving an intake graph."""
    graph = deepcopy(raw)
    if isinstance(graph, dict) and isinstance(graph.get("tasks"), dict):
        tasks = graph["tasks"]
        for task in tasks.values():
            if not isinstance(task, dict) or "project_check_inputs" not in task:
                continue
            inputs = task.pop("project_check_inputs")
            require(isinstance(inputs, dict), "project_check_inputs must be a mapping")
            checks = acceptance_guard(
                required_checks,
                config["_project"]["data"],
                task,
                final=len(tasks) == 1 or task.get("kind") == "integration",
            )
            by_id = {check["id"]: check for check in checks}
            require(set(inputs) <= set(by_id), "Unknown or inactive project check inputs")
            for check_id, paths in inputs.items():
                check = by_id[check_id]
                if check["kind"] == "observation":
                    raise Invalid("Observation cannot have inputs")
                if not isinstance(paths, list) or not all(isinstance(p, str) for p in paths):
                    raise Invalid("project check inputs must be a list of paths")
                check["execution"]["inputs"] = list(
                    dict.fromkeys([*check["execution"].get("inputs", []), *paths])
                )
            explicit = task.get("required_checks")
            if not isinstance(explicit, list):
                raise Invalid("required_checks must be a list")
            require(
                all(isinstance(c, dict) and c.get("id") not in by_id for c in explicit),
                "Explicit check conflicts with derived project check",
            )
            task["required_checks"] = [*explicit, *checks]
    return parse_graph(graph)


def parse_graph(raw: object) -> Graph:
    try:
        return GRAPH.validate_python(raw)
    except ValidationError as exc:
        raise Invalid(validation_message("Invalid workflow graph", exc, GRAPH)) from None


def ancestors(nodes: dict[str, Node], node_id: str) -> set[str]:
    seen = set()

    def visit(n: str) -> None:
        for dep in nodes[n]["depends_on"]:
            if dep not in seen:
                seen.add(dep)
                visit(dep)

    visit(node_id)
    return seen


def validate_check_paths(t: Task, workspace: Path) -> None:
    """Validate the exact filesystem targets declared by task checks."""
    for check in t["required_checks"]:
        if check["kind"] != "observation" and check["execution"]["cwd"] != ".":
            relative(workspace, check["execution"]["cwd"])
    for check in t["required_checks"]:
        if check["kind"] == "observation":
            continue
        execution = check["execution"]
        for path in execution.get("inputs", []) + execution.get("outputs", []):
            target = relative(workspace, path)
            require(not target.is_dir(), "Check paths must name exact files")
        require(
            not execution.get("outputs") or check["kind"] == "codegen",
            "Only code generation can declare outputs",
        )


def validate_task_topology(g: Graph, config: Config, nodes: dict[str, Node]) -> None:
    """Validate each task’s acceptance path, review, and predecessor ordering."""
    agents, tasks = g["agents"], g["tasks"]
    for tid, task in tasks.items():
        own = {k: n for k, n in nodes.items() if n["task"] == tid}
        accepts = [k for k, n in own.items() if n["stage"] == "accept"]
        require(len(accepts) == 1, "Each task needs exactly one acceptance node")
        accept = accepts[0]
        upstream = ancestors(nodes, accept)
        require(set(own) - {accept} <= upstream, "Task has work outside acceptance path")
        verify = [k for k, n in own.items() if n["stage"] == "verify"]
        full_verify = [k for k in verify if "required_check_ids" not in nodes[k]]
        require(full_verify, "Missing full final verification")
        writers = {k for k, n in own.items() if n.get("owns")}
        require(
            any(writers <= ancestors(nodes, v) for v in full_verify),
            "Verification must follow all writers",
        )
        for check in task["required_checks"]:
            if check["kind"] == "observation":
                continue
            outputs = check["execution"].get("outputs", [])
            if not outputs:
                continue
            producers = [
                n
                for n in own.values()
                if n.get("agent")
                and check
                in finish_requirements.requirements(
                    config["_project"]["data"], n, task, agents[agent_key(n)]["role"]
                )["required_checks"]
            ]
            require(
                len(producers) == 1
                and set(outputs) <= set(task["scope"])
                and set(outputs) <= set(producers[0].get("owns", [])),
                "Generation needs one assigned writer owning every exact output path",
            )
            require(
                all(
                    any(
                        final_check["kind"] != "observation"
                        and output in final_check["execution"].get("inputs", [])
                        and not final_check["execution"].get("outputs")
                        and final_check["execution"].get("mode", "full") == "full"
                        for final_check in task["required_checks"]
                    )
                    for output in outputs
                ),
                "Generated outputs need a read-only full verification check declaring each output input",
            )
        reviews = [k for k, n in own.items() if n["stage"] == "review"]
        if task["independent_review"]:
            require(
                reviews and any(set(verify) <= ancestors(nodes, r) for r in reviews),
                "Missing final review after verification",
            )
        authors = {agent_key(n) for n in own.values() if n.get("owns")}
        require(
            len(authors) <= 1,
            "Each task has at most one product author",
        )
        testers = {agent_key(nodes[v]) for v in verify}
        require(not authors & testers, "Author cannot verify its own changes")
        require(
            all(nodes[r]["agent"] not in authors | testers for r in reviews),
            "Independent Judge must differ from author and Tester",
        )
        if task["risk"] == "high":
            require(reviews, "High risk requires independent Judge review")
        for dep in task.get("depends_on", []):
            if tasks[dep]["slice"] != task["slice"]:
                slice_tasks = {k for k, t in tasks.items() if t["slice"] == tasks[dep]["slice"]}
                require(
                    slice_tasks <= set(task["depends_on"]),
                    "Cross-slice dependency must await all tasks in predecessor slice",
                )
            da = [k for k, n in nodes.items() if n["task"] == dep and n["stage"] == "accept"]
            require(
                len(da) == 1 and all(da[0] in ancestors(nodes, k) for k in own),
                "Dependent task must follow accepted predecessor",
            )


def _validate_nodes(
    nodes: dict[str, Node],
    tasks: dict[str, Task],
    agents: dict[str, Agent],
    config: Config,
    workspace: Path,
) -> None:
    for n in nodes.values():
        require(n["task"] in tasks, "Unknown task")
        require(set(n["depends_on"]).issubset(nodes), "Unknown node dependency")
        require(n["id"] not in n["depends_on"], "Self dependency")
        if n["stage"] == "accept":
            if n.get("agent") is not None:
                raise Invalid("Acceptance belongs to orchestrator")
        else:
            require(n.get("agent") in agents, "Unknown agent")
        for p in n.get("owns", []):
            relative(workspace, p)
        for p in n.get("handoff_inputs", []):
            handoff_path = relative(workspace, p)
            require(
                not handoff_path.exists() or handoff_path.is_file(),
                f"Node {n['id']} handoff_inputs must contain files: {p}",
            )
        if n["stage"] in {"verify", "review", "accept", "explore"}:
            require(not n.get("owns"), "Read/check node cannot own product writes")
        if n["stage"] == "verify":
            require(
                "project-checks" in n.get("resources", []),
                "Verification needs project-checks lock",
            )
        if n["stage"] != "accept":
            obligations = acceptance_guard(
                finish_requirements.requirements,
                config["_project"]["data"],
                n,
                tasks[n["task"]],
                agents[agent_key(n)]["role"],
            )
            if n.get("required_check_ids"):
                validate_check_paths(
                    {**tasks[n["task"]], "required_checks": obligations["allowed_checks"]},
                    workspace,
                )
        if n["stage"] == "verify":
            require(agents[agent_key(n)]["role"] == "tester", "Verification needs Tester")
        if n["stage"] == "review":
            require(agents[agent_key(n)]["role"] == "judge", "Integrated review needs Judge")
        if n.get("owns"):
            role = agents[agent_key(n)]["role"]
            require(
                role in {"implementer", "doc-writer"},
                "Role cannot write product scope",
            )
            for path in n["owns"]:
                require(
                    any(overlaps([path], [p]) for p in tasks[n["task"]]["scope"]),
                    "Ownership outside task scope",
                )


def validate_graph(
    raw: object, config: Config, workspace: str | Path | None = None
) -> dict[str, Node]:
    workspace = Path(workspace).resolve() if workspace is not None else Path.cwd()
    g = parse_graph(raw)
    require(g.get("tasks") and g.get("sources") and g.get("nodes"), "Empty workflow")
    agents, tasks = g["agents"], g["tasks"]
    nodes = {n["id"]: n for n in g["nodes"]}
    require(len(nodes) == len(g["nodes"]), "Duplicate node ID")
    for group in (agents, tasks, nodes, g["sources"]):
        if not (all(re.fullmatch("[A-Za-z0-9][A-Za-z0-9_-]*", k) for k in group)):
            raise Invalid("Invalid identity")
    for a in agents.values():
        require(a["role"] != "teacher", "Teacher runs once after successful archival")
        require(
            a["role"] not in {"developer", "test-writer", "generalist"},
            "Legacy author role cannot receive a new assignment",
        )
        require(
            a["profile"] in config["_roles"].get(a["role"], []),
            "Profile not allowed for role",
        )
    source_criteria = {
        key: acceptance_guard(acceptance.criteria_map, src.get("acceptance"))
        for key, src in g["sources"].items()
    }
    for key, src in g["sources"].items():
        if "selected_acceptance_ids" in src:
            selected = acceptance_guard(
                acceptance.ids,
                src["selected_acceptance_ids"],
                "selected_acceptance_ids",
            )
            require(
                selected <= set(source_criteria[key])
                and src.get("selected_scope") not in (None, "", "all"),
                "Selected criteria require explicit bounded source scope",
            )
            source_criteria[key] = {
                cid: c for cid, c in source_criteria[key].items() if cid in selected
            }
    for t in tasks.values():
        require(t["source"] in g["sources"], "Missing source")
        available = dict(source_criteria[t["source"]])
        if t.get("kind") == "integration":
            available.update(
                {
                    f"{source}:{cid}": c
                    for source, criteria in source_criteria.items()
                    if source != t["source"]
                    for cid, c in criteria.items()
                }
            )
        acceptance_guard(acceptance.check_plan, t, available)
        acceptance_guard(
            check_task,
            config["_project"]["data"],
            t,
            final=len(tasks) == 1 or t.get("kind") == "integration",
        )
        validate_check_paths(t, workspace)
        require(
            t["risk"] == "low" or t["independent_review"],
            "Non-low task requires review",
        )
        require(
            len({unicodedata.normalize("NFC", p).casefold() for p in t["scope"]})
            == len(t["scope"]),
            "Duplicate/case-alias file scope",
        )
        for p in t["scope"]:
            require(not relative(workspace, p).is_dir(), f"Scope must contain real files: {p}")
        require(set(t.get("depends_on", [])).issubset(tasks), "Unknown task dependency")
    for source, criteria in source_criteria.items():
        assigned = {
            cid
            for t in tasks.values()
            if t["source"] == source
            for cid in t["acceptance_ids"]
            if ":" not in cid
        }
        require(assigned == set(criteria), "Unassigned source acceptance criteria")
    _validate_nodes(nodes, tasks, agents, config, workspace)
    # Kahn traversal avoids recursion into cycles.
    done: set[str] = set()
    while len(done) < len(nodes):
        ready = {k for k, n in nodes.items() if k not in done and set(n["depends_on"]) <= done}
        require(ready, "Dependency cycle")
        done.update(ready)
    validate_task_topology(g, config, nodes)
    if len(tasks) > 1:
        finals = [k for k, t in tasks.items() if t["kind"] == "integration"]
        require(len(finals) == 1, "Batch needs one final integration task")
        final = tasks[finals[0]]
        expected_criteria = {
            cid if source == final["source"] else f"{source}:{cid}"
            for source, criteria in source_criteria.items()
            for cid in criteria
        }
        require(
            set(final["acceptance_ids"]) == expected_criteria,
            "Integration must recheck all selected acceptance criteria",
        )
        require(
            set(final.get("depends_on", [])) == set(tasks) - set(finals),
            "Integration must depend on all tasks",
        )
        require(
            set(final["scope"])
            >= {p for k, t in tasks.items() if k != finals[0] for p in t["scope"]},
            "Integration scope must cover all tasks",
        )
        require(
            final["independent_review"],
            "Integration requires independent review",
        )
    return nodes


def validate_assignment_lineage(
    graph: GraphTopology, config: Config, corrections: Sequence[Mapping[str, Any]] | None = None
) -> None:
    """Every specialist starts at its group default; only registered corrections advance it."""
    for node in graph["nodes"]:
        require("profile_selection" not in node, "Initial profile choices are unsupported")
        if not node.get("agent"):
            continue
        agent = graph["agents"][agent_key(node)]
        if agent["role"] not in {"implementer"}:
            continue
        expected = config["_defaults"][agent["role"]]
        logical_agent = None
        for record in corrections or []:
            if node["id"] not in record.get("reassigned_nodes", []):
                continue
            require(
                record["task_id"] == node["task"] and record["from_profile"] == expected,
                "Broken correction profile lineage",
            )
            mapping = record.get("agents", {})
            require(
                isinstance(mapping, dict) and len(mapping) == 1,
                "Invalid correction agent lineage",
            )
            origin, target = next(iter(mapping.items()))
            require(
                logical_agent is None or logical_agent == origin,
                "Broken correction agent lineage",
            )
            require(
                graph["agents"].get(origin) == {"role": agent["role"], "profile": expected}
                and graph["agents"].get(target)
                == {"role": agent["role"], "profile": record["to_profile"]},
                "Correction agent registration changed",
            )
            logical_agent = target
            expected = record["to_profile"]
        require(
            logical_agent is None or logical_agent == node["agent"],
            "Correction agent mismatch",
        )
        require(
            agent["profile"] == expected,
            f"Assignment requires profile {expected} from default/correction lineage",
        )


def overlaps(left: list[str], right: list[str]) -> bool:
    # Conservative on every platform, also safe on case-insensitive/APFS volumes.
    left = [unicodedata.normalize("NFC", a).casefold() for a in left]
    right = [unicodedata.normalize("NFC", b).casefold() for b in right]
    return any(
        a == b or a.startswith(b.rstrip("/") + "/") or b.startswith(a.rstrip("/") + "/")
        for a in left
        for b in right
    )


def diagram(state: State) -> str:
    graph, config = state["graph"], state["config"]
    lines = [
        "sequenceDiagram",
        "    autonumber",
        "    participant O as 🧭 Orchestrator",
    ]
    ids = {a: f"A{i}" for i, a in enumerate(graph["agents"], 1)}

    def label(value: object) -> str:
        return (
            str(value)
            .replace("\n", " ")
            .replace(":", " ")
            .replace(";", ",")
            .replace("<", "")
            .replace(">", "")
        )

    for a, info in graph["agents"].items():
        p = config["profiles"][info["profile"]]
        lines.append(
            f"    participant {ids[a]} as {label(a)} · {label(info['role'])} / {label(p['model'])} / {p['runner']}"
        )
    lines.append("    participant T as Teacher")
    nodes = {n["id"]: n for n in graph["nodes"]}
    done: set[str] = set()
    while len(done) < len(nodes):
        ready = [n for k, n in nodes.items() if k not in done and set(n["depends_on"]) <= done]
        require(ready, "Cycle")
        if len(ready) > 1:
            lines.append("    par Ready branches (subject to slots/ownership)")
        for i, n in enumerate(ready):
            if i and len(ready) > 1:
                lines.append("    and Ready branch")
            dispatch = state["nodes"].get(n["id"])
            status = dispatch["status"] if dispatch else "planned"
            if n["stage"] == "accept":
                lines.append(f"        O->>O: {label(n['task'])} acceptance · {status}")
            else:
                target = ids[agent_key(n)]
                lines.append(f"        O->>{target}: {label(n['id'])} · {status}")
                lines.append(f"        {target}-->>O: Result and evidence")
            done.add(n["id"])
        if len(ready) > 1:
            lines.append("    end")
    for e in state.get("events", []):
        if e["event"] == "retry":
            n = nodes[e["node"]]
            lines += [
                "    opt Recorded correction",
                f"        O-->>{ids[agent_key(n)]}: {label(e['reason'])}",
                "    end",
            ]
    if state["status"] == "cancelled":
        lines.append("    Note over O,T: Run cancelled · skip final Teacher review")
    else:
        lines += [
            "    opt After successful archive",
            "        O->>O: Archive completed run",
            "        O->>T: Final Teacher review (planned)"
            if state["status"] == "active"
            else "        O-->>T: Teacher assignment queued at archive",
            "    end",
        ]
    return "\n".join(lines) + "\n"
