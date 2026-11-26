"""Convert approved Planning and Decompose outputs at the Orchestrator intake boundary."""

import re
from collections.abc import Collection
from pathlib import Path

from pydantic import TypeAdapter

from factory import file_reader
from factory.database.provider import current_database
from factory.planning.plan_document import parse_plan_header
from factory.processes.publication import identity
from factory.runtime.contracts import Source, State, UpstreamTask
from factory.runtime.workflow_core import (
    Invalid,
    acceptance_guard,
    digest,
    graph_identity,
    relative,
    require,
)
from factory.tasks.contracts import Task
from factory.tasks.criteria import plan_criteria


def approved_plan(root: Path, path: str, scope: str | list[str] = "all") -> Source:
    text = file_reader.read_text(relative(root, path), encoding="utf-8")
    return plan_identity(text, path, scope)


def plan_identity(text: str, path: str, scope: str | list[str]) -> Source:
    header = parse_plan_header(text).validated
    if (
        header is None
        or header["status"] != "approved"
        or header["approved_revision"] != header["revision"]
    ):
        raise Invalid("BLOCKED_NO_APPROVED_PLAN: approved revision required")
    return {
        "kind": "approved_plan",
        "path": path,
        "selected_scope": scope,
        "plan_id": header["plan_id"],
        "plan_revision": int(header["revision"]),
        "approved_revision": int(header["approved_revision"]),
        "acceptance": acceptance_guard(plan_criteria, text),
    }


def field(text: str, name: str, *, default: str | None = None) -> str:
    header = re.split(r"(?m)^## ", text, maxsplit=1)[0]
    found = [
        match.group(1)
        for match in re.finditer(rf"(?m)^-[^\S\n]+\*\*{re.escape(name)}:\*\*[^\S\n]*(.*)$", header)
    ]
    if not found and default is not None:
        return default
    require(len(found) == 1, f"Decompose task needs exactly one {name} field")
    return found[0].strip()


def identifiers(text: str, name: str, *, optional: bool = False) -> list[str]:
    value = field(text, name, default="—" if optional else None)
    return (
        [] if value in {"—", "-", "none"} else [key.strip().strip("`") for key in value.split(",")]
    )


def source_prerequisites(state: State, task_id: str) -> dict[str, str]:
    """Match external facts to this task and the most recent intake of its source."""
    task = state["graph"]["tasks"][task_id]
    source = state["graph"]["sources"][task["source"]]
    original = source.get("upstream_tasks", {}).get(task_id)
    if original is not None:
        known: Collection[str] = source["upstream_tasks"].keys()
        blockers = original["blocked_by"]
    elif source["kind"] == "factory_decompose_task":
        known = state["graph"]["tasks"].keys()
        blockers = identifiers(source["snapshot"], "Blocked by", optional=True)
    else:
        return {}
    external = [name for name in blockers if name not in known]
    if not external:
        return {}
    generation = sum(event["event"] == "source_reintake" for event in state["events"])
    return {
        graph_identity([state["run_id"], task_id, source["hash"], generation, name]): name
        for name in external
    }


def resolution_evidence(state: State, task_id: str) -> dict[str, str]:
    keys = source_prerequisites(state, task_id)
    if not keys:
        return {}
    return {
        keys[event["request_id"]]: event["evidence"]
        for event in state["events"]
        if event["event"] == "source_prerequisite_resolved"
        and event.get("task") == task_id
        and event["request_id"] in keys
    }


def pending_prerequisites(state: State, task_id: str) -> dict[str, str]:
    prerequisites = source_prerequisites(state, task_id)
    if prerequisites:
        for event in state["events"]:
            if event["event"] == "source_prerequisite_resolved" and event.get("task") == task_id:
                prerequisites.pop(event["request_id"], None)
    return prerequisites


def decomposition(root: Path, plan: str, run_id: str) -> dict[str, UpstreamTask]:
    run = current_database().processes.get(root, run_id)
    require(
        run.process == "decompose" and run.state.terminal == "completed",
        "Decomposition requires a published, checked run",
    )
    source = run.subject["source_lock"]
    require(
        source["plan_content_hash"] == "sha256:" + digest(plan.encode()),
        "Decomposition belongs to a different plan revision",
    )
    publication = run.state.facts["publication"]
    require(
        identity(relative(root, publication["destination"])) == publication["owned"],
        "Published task bundle changed; new intake required",
    )
    return TypeAdapter(dict[str, UpstreamTask]).validate_python(run.state.facts["gate"]["tasks"])


def check_tasks(sources: dict[str, Source], tasks: dict[str, Task], root: Path) -> None:
    for source_key, source in sources.items():
        for key, upstream in source.get("upstream_tasks", {}).items():
            task = tasks.get(key)
            if task is None or task["source"] != source_key:
                raise Invalid(f"Missing decomposed task {key}")
            require(
                set(upstream["depends_on"]) <= set(task.get("depends_on", [])),
                f"Lost hard dependency for {key}",
            )
            require(
                task["acceptance_ids"] == upstream["acceptance_ids"]
                and task.get("contributes_to_acceptance_ids", [])
                == upstream["contributes_to_acceptance_ids"]
                and task.get("local_acceptance_criteria", [])
                == upstream["local_acceptance_criteria"]
                and task["outcome"] == upstream["outcome"],
                f"Decomposed task contract changed: {key}",
            )
        if source.get("kind") == "factory_decompose_task":
            text = (
                source.get("snapshot")
                or source.get("text")
                or file_reader.read_text(relative(root, source["path"]), encoding="utf-8")
            )
            key = field(text, "ID").strip("`")
            task = tasks.get(key)
            require(
                task is not None and task["source"] == source_key, f"Missing decomposed task {key}"
            )
            assert task is not None
            require(
                {
                    *identifiers(text, "Depends on"),
                    *identifiers(text, "Parent task", optional=True),
                    *(
                        dep
                        for dep in identifiers(text, "Blocked by", optional=True)
                        if dep in tasks
                    ),
                }
                <= set(task.get("depends_on", [])),
                f"Lost hard dependency for {key}",
            )
