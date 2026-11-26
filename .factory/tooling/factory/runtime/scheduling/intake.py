"""Resolve role assignments from task facts and the project's review obligations."""

from collections.abc import Iterable
from dataclasses import dataclass, field
from functools import lru_cache
from typing import Never, cast

from pydantic_graph import Graph as Program
from pydantic_graph import StepContext
from pydantic_graph.step import StepFunction

from factory.dependency_graph import run_program
from factory.graphs.definition import parse
from factory.graphs.program import Operations, compile_program
from factory.runtime.contracts import Config, Graph, Node, Stage
from factory.runtime.workflow_core import Invalid, require
from factory.tasks.contracts import Task


def needs_judge(task: Task, config: Config, owned: Iterable[str]) -> bool:
    public = config["_project"]["data"].get("public_contracts", {})
    return bool(
        task["independent_review"]
        or task["risk"] != "low"
        or task.get("owner_review_ref")
        or task["kind"] == "integration"
        or (set(owned) | set(task.get("write_scope", []))) & public.keys()
    )


@dataclass
class TaskRoute:
    graph: Graph
    task_id: str
    task: Task
    config: Config
    parents: list[str]
    steps: list[Node] = field(default_factory=list)

    @property
    def needs_judge(self) -> bool:
        owned = (path for node in self.steps for path in node.get("owns", []))
        return needs_judge(self.task, self.config, owned)


def assign(stage: Stage, role: str | None) -> StepFunction:
    async def step(ctx: StepContext) -> TaskRoute:
        route = cast(TaskRoute, ctx.inputs)
        key = f"{stage}-{route.task_id}"
        agent = None
        owns: list[str] = []
        if role is not None:
            agent = f"{role}-{route.task_id}"
            profile = route.config["_defaults"].get(role)
            require(profile is not None, f"Missing project profile for {role}")
            assert profile is not None
            expected = {"role": role, "profile": profile}
            require(
                agent not in route.graph["agents"] or route.graph["agents"][agent] == expected,
                f"Conflicting assignment for {agent}",
            )
            route.graph["agents"][agent] = {"role": role, "profile": profile}
        if stage in {"work", "docs"}:
            owns = route.task.get("write_scope", [])
            require(
                owns and set(owns) <= set(route.task["scope"]),
                "Automatic writer needs explicit write_scope inside task scope",
            )
        if stage == "review":
            route.task["independent_review"] = True
        node: Node = {
            "id": key,
            "task": route.task_id,
            "stage": stage,
            "agent": agent,
            "depends_on": route.parents,
            "owns": owns,
            "resources": ["project-checks"] if stage == "verify" else [],
        }
        route.steps.append(node)
        route.parents = [key]
        return route

    return step


def reject(_: TaskRoute, reason: str) -> Never:
    raise Invalid(reason)


@lru_cache(maxsize=16)
def route_program(documents: tuple[tuple[str, str], ...]) -> Program:
    definitions = dict(documents)
    binding = parse("implement", definitions["implement"]).assignments.get("intake")
    require(binding is not None, "Implement needs an intake definition")
    assert binding is not None
    actions = {
        "assign_author": assign("work", "implementer"),
        "assign_documents": assign("docs", "doc-writer"),
        "assign_exploration": assign("explore", "code-explorer"),
        "assign_diagnosis": assign("explore", "bug-hunter"),
        "assign_verification": assign("verify", "tester"),
        "assign_judge": assign("review", "judge"),
        "assign_acceptance": assign("accept", None),
    }
    decisions = {
        "task_intent": {
            "diagnose": lambda r: r.task.get("inquiry") == "diagnosis",
            "explore": lambda r: r.task.get("inquiry") == "research",
            "documents": lambda r: r.task["kind"] == "docs",
            "integration": lambda r: r.task["kind"] == "integration",
            "write": lambda r: bool(r.task.get("write_scope")),
        },
        "review_requirement": {"mandatory": lambda r: r.needs_judge, "ordinary": lambda _: True},
    }
    return compile_program(
        binding,
        definitions,
        Operations(
            actions, decisions, reject, inputs=dict.fromkeys([*actions, *decisions], TaskRoute)
        ),
        batch=False,
    )


@lru_cache(maxsize=16)
def source_program(documents: tuple[tuple[str, str], ...]) -> Program:
    definitions = dict(documents)
    entry = parse("implement", definitions["implement"]).assignments["source"]

    def reply(value: str) -> StepFunction:
        async def step(ctx: StepContext) -> str:
            return value

        return step

    actions = {
        "needs_planning": reply("NEEDS_PLANNING"),
        "delegated_planning": reply("PLANNING_REQUIRED"),
        "admit_source": reply("READY"),
    }
    decisions = {
        "source_readiness": {
            "forbidden": lambda src: bool(src.get("no_plan_ref")),
            "gap": lambda src: bool(src.get("semantic_gap")),
            "delegated": lambda src: bool(src.get("delegated_planning_ref")),
            "approved_or_ready": lambda src: True,
        }
    }
    return compile_program(
        entry,
        definitions,
        Operations(actions, decisions, reject, inputs=dict.fromkeys([*actions, *decisions], dict)),
        batch=False,
    )


def configure(graph: Graph, config: Config, documents: dict[str, str]) -> None:
    sealed = tuple(sorted(documents.items()))
    program = route_program(sealed)
    admission = source_program(sealed)
    for source in graph["sources"].values():
        verdict = run_program(admission, inputs=source)
        require(verdict == "READY", f"{verdict}: {source.get('semantic_gap', '')}")
    if graph["nodes"]:
        return
    for key, task in graph["tasks"].items():
        parents = [f"accept-{dep}" for dep in task.get("depends_on", [])]
        route = TaskRoute(graph, key, task, config, parents)
        run_program(program, inputs=route)
        require(
            not route.needs_judge or any(n["stage"] == "review" for n in route.steps),
            "Missing mandatory Judge assignment",
        )
        graph["nodes"].extend(route.steps)
