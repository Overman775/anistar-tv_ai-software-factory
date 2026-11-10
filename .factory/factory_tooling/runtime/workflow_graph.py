"""Workflow graph constraints, dependency traversal and diagram rendering."""

from __future__ import annotations

import re
import unicodedata
from pathlib import Path
from typing import Any, cast

from factory_tooling.project.profile_rules import (
    boundary_gates,
    check_task,
    project_checks,
)
from factory_tooling.runtime import acceptance
from factory_tooling.runtime.contracts import (
    Config,
    Node,
    State,
    agent_key,
)
from factory_tooling.runtime.workflow_core import (
    Invalid,
    acceptance_guard,
    relative,
    require,
)


def ancestors(nodes: dict[str, Node], node_id: str) -> set[str]:
    seen = set()

    def visit(n: str) -> None:
        for dep in nodes[n]["depends_on"]:
            if dep not in seen:
                seen.add(dep)
                visit(dep)

    visit(node_id)
    return seen


def validate_graph(g: Any, config: Config, workspace: str | Path | None = None) -> dict[str, Node]:
    workspace = Path(workspace).resolve() if workspace is not None else Path.cwd()
    if not (isinstance(g, dict)):
        raise Invalid("Graph must be a mapping")
    require(g.get("tasks") and g.get("sources") and g.get("nodes"), "Empty workflow")
    agents, tasks = g["agents"], g["tasks"]
    nodes = {n["id"]: n for n in g["nodes"]}
    require(len(nodes) == len(g["nodes"]), "Duplicate node ID")
    for group in (agents, tasks, nodes, g["sources"]):
        if not (all(re.fullmatch("[A-Za-z0-9][A-Za-z0-9_-]*", k) for k in group)):
            raise Invalid("Invalid identity")
    for a in agents.values():
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
        require(
            t.get("outcome") and t.get("slice") and t.get("reason"),
            "Task needs outcome, slice, reason",
        )
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
        for check in t["required_checks"]:
            if check["kind"] != "observation" and check["execution"]["cwd"] != ".":
                relative(workspace, check["execution"]["cwd"])
        require(t["risk"] in {"low", "moderate", "high"}, "Invalid task risk")
        require(type(t["independent_review"]) is bool, "Explicit review decision required")
        require(
            t["risk"] == "low" or t["independent_review"],
            "Non-low task requires review",
        )
        if not (isinstance(t["scope"], list) and t["scope"]):
            raise Invalid("Exact file scope required")
        require(
            len({unicodedata.normalize("NFC", p).casefold() for p in t["scope"]})
            == len(t["scope"]),
            "Duplicate/case-alias file scope",
        )
        require(
            t.get("kind") in {"feature", "task", "refactor", "fix", "docs", "integration"},
            "Invalid task kind",
        )
        for p in t["scope"]:
            relative(workspace, p)
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
    for n in nodes.values():
        require(n["task"] in tasks, "Unknown task")
        require(
            n["stage"] in {"explore", "work", "docs", "verify", "review", "accept"},
            "Unknown stage",
        )
        if not (isinstance(n.get("depends_on"), list) and set(n["depends_on"]).issubset(nodes)):
            raise Invalid("Unknown node dependency")
        require(n["id"] not in n["depends_on"], "Self dependency")
        if n["stage"] == "accept":
            if n.get("agent") is not None:
                raise Invalid("Acceptance belongs to orchestrator")
        else:
            require(n.get("agent") in agents, "Unknown agent")
        for p in n.get("owns", []):
            relative(workspace, p)
        if n["stage"] in {"verify", "review", "accept", "explore"}:
            require(not n.get("owns"), "Read/check node cannot own product writes")
        if n["stage"] in {"verify", "review"}:
            require(
                "project-checks" in n.get("resources", []),
                "Verification needs project-checks lock",
            )
        gates = boundary_gates(
            config["_project"]["data"], "implement." + n["stage"], tasks[n["task"]]
        )
        ids = {cid for gate in gates for cid in gate.get("checks", [])}
        if any(
            c["id"] in ids and c["kind"] != "observation"
            for c in tasks[n["task"]]["required_checks"]
        ):
            require(
                "project-checks" in n.get("resources", []),
                "Stage gate needs project-checks reservation",
            )
        if n["stage"] == "review":
            require(agents[agent_key(n)]["role"] == "judge", "Integrated review needs Judge")
        if n.get("owns"):
            role = agents[agent_key(n)]["role"]
            require(
                role in {"developer", "test-writer", "generalist", "doc-writer"},
                "Role cannot write product scope",
            )
            for path in n["owns"]:
                require(
                    any(overlaps([path], [p]) for p in tasks[n["task"]]["scope"]),
                    "Ownership outside task scope",
                )
    # Kahn traversal avoids recursion into cycles.
    done: set[str] = set()
    while len(done) < len(nodes):
        ready = {k for k, n in nodes.items() if k not in done and set(n["depends_on"]) <= done}
        require(ready, "Dependency cycle")
        done.update(ready)
    for tid, task in tasks.items():
        own = {k: n for k, n in nodes.items() if n["task"] == tid}
        accepts = [k for k, n in own.items() if n["stage"] == "accept"]
        require(len(accepts) == 1, "Each task needs exactly one acceptance node")
        accept = accepts[0]
        upstream = ancestors(nodes, accept)
        require(set(own) - {accept} <= upstream, "Task has work outside acceptance path")
        verify = [k for k, n in own.items() if n["stage"] == "verify"]
        require(verify, "Missing final verification")
        writers = {k for k, n in own.items() if n.get("owns")}
        require(
            any(writers <= ancestors(nodes, v) for v in verify),
            "Verification must follow all writers",
        )
        reviews = [k for k, n in own.items() if n["stage"] == "review"]
        if task["independent_review"]:
            require(
                reviews and any(set(verify) <= ancestors(nodes, r) for r in reviews),
                "Missing final review after verification",
            )
            final_ids = {
                c["id"] for c in project_checks(config["_project"]["data"]) if c["level"] == "final"
            }
            if (len(tasks) == 1 or task["kind"] == "integration") and final_ids & {
                c["id"] for c in task["required_checks"]
            }:
                require(
                    any(
                        agents[nodes[v]["agent"]]["role"] == "judge"
                        and writers <= ancestors(nodes, v)
                        for v in verify
                    ),
                    "Final project checks require independent Judge verification",
                )
        authors = {n["agent"] for n in own.values() if n.get("owns")}
        if not task["independent_review"]:
            require(
                len(authors) == 1 and agents[next(iter(authors))]["role"] == "generalist",
                "Self-review requires one Generalist author",
            )
        require(
            all(nodes[r]["agent"] not in authors for r in reviews),
            "Author cannot independently review",
        )
        if task["risk"] == "high" and task["kind"] != "integration":
            require(
                not any(agents[a]["role"] == "generalist" for a in authors),
                "High risk requires separated authors",
            )
            require(
                any(agents[a]["role"] == "developer" for a in authors),
                "High risk needs Developer",
            )
            require(
                any(
                    n.get("agent")
                    and agents[agent_key(n)]["role"] == "test-writer"
                    and n["stage"] in {"work", "verify"}
                    for n in own.values()
                ),
                "High risk needs TestWriter",
            )
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
    return cast(dict[str, Node], nodes)


def validate_profile_selections(
    g: Any,
    config: Config,
    corrections: list[Any] | None = None,
    history: list[Any] | None = None,
    previous_graph: Any = None,
) -> None:
    """Validate coordinator choices and the node-specific correction chain."""
    from factory_tooling.decisions.decision_contract import validate_answer

    definitions = {d["id"]: d for d in config["_project"]["data"].get("decisions", [])}
    for node in g["nodes"]:
        if not node.get("agent"):
            require("profile_selection" not in node, "Acceptance cannot select a profile")
            continue
        agent = g["agents"][node["agent"]]
        profile = config["profiles"][agent["profile"]]
        decision = profile.get("initial_profile_decision")
        if decision is None:
            require("profile_selection" not in node, "No profile decision configured")
            continue
        selection = node.get("profile_selection")
        require(
            isinstance(selection, dict)
            and set(selection) == {"task_id", "node_id", "decision_id", "answer"},
            "Profile selection required",
        )
        require(
            selection["task_id"] == node["task"]
            and selection["node_id"] == node["id"]
            and selection["decision_id"] == decision,
            "Profile selection identity mismatch",
        )
        definition = definitions[decision]
        corrected = any(
            r.get("task_id") == node["task"] and node["id"] in r.get("reassigned_nodes", [])
            for r in corrections or []
        )
        prior_nodes = (previous_graph or g)["nodes"]
        immediately_prior = next(
            (n for n in prior_nodes if n["id"] == node["id"] and n["task"] == node["task"]), None
        )
        if (
            corrected
            and immediately_prior
            and immediately_prior.get("profile_selection") == selection
        ):
            for event in history or []:
                prior_graph, prior_config = (
                    event.get("previous_graph"),
                    event.get("previous_config"),
                )
                if not isinstance(prior_graph, dict) or not isinstance(prior_config, dict):
                    continue
                previous_node = next(
                    (
                        n
                        for n in prior_graph["nodes"]
                        if n["id"] == node["id"] and n["task"] == node["task"]
                    ),
                    None,
                )
                if previous_node and previous_node.get("profile_selection") == selection:
                    prior_defs = {
                        d["id"]: d for d in prior_config["_project"]["data"].get("decisions", [])
                    }
                    if decision in prior_defs:
                        definition = prior_defs[decision]
                        break
        result = acceptance_guard(validate_answer, definition, selection["answer"])
        selected = result["value"]
        selected_agent = None
        require(selected != "no-eligible-profile", "BLOCKED: no eligible profile")
        retained = previous_graph is None or (
            immediately_prior is not None
            and immediately_prior.get("profile_selection") == selection
        )
        for record in corrections or []:
            if (
                retained
                and record.get("task_id") == node["task"]
                and node["id"] in record.get("reassigned_nodes", [])
                and record.get("from_profile") == selected
            ):
                mapping = record.get("agents", {})
                require(
                    isinstance(mapping, dict) and len(mapping) == 1,
                    "Invalid correction agent lineage",
                )
                origin, target = next(iter(mapping.items()))
                require(
                    selected_agent is None or selected_agent == origin,
                    "Broken correction agent lineage",
                )
                selected_agent = target
                selected = record["to_profile"]
        require(
            selected_agent is None or selected_agent == node["agent"], "Correction agent mismatch"
        )
        require(
            selected == agent["profile"],
            "Profile selection does not authorize assignment",
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
            status = state.get("nodes", {}).get(n["id"], {}).get("status", "planned")
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
    return "\n".join(lines) + "\n"
