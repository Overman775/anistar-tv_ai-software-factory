"""Task dependency and parent/deferred cycle analysis."""

from __future__ import annotations

from collections.abc import Iterator
from dataclasses import dataclass, field
from functools import cache, cached_property
from graphlib import CycleError
from typing import Literal

from pydantic_graph import BaseNode, End, Graph, GraphBuilder, GraphRunContext

from factory.decompose.contracts import LoadedTask
from factory.decompose.graph.task_data import (
    _is_nonempty_text,
    _relation_ids,
)
from factory.dependency_graph import DependencyGraph, compile_dependencies, run_program

type Relation = Literal["depends_on", "parent_task", "deferred"]
type RelationKind = Relation | Literal["blocked_by"]
type Edge = tuple[str, RelationKind]


@dataclass
class RelationScan:
    edges: dict[str, list[Edge]]
    roots: Iterator[str]
    path: list[str] = field(default_factory=list)
    positions: dict[str, int] = field(default_factory=dict)
    stack: list[Iterator[Edge]] = field(default_factory=list)
    kinds: list[RelationKind] = field(default_factory=list)
    finished: set[str] = field(default_factory=set)
    reached: set[str] = field(default_factory=set)
    cycles: list[tuple[list[str], list[RelationKind]]] = field(default_factory=list)

    def enter(self, key: str) -> None:
        self.positions[key] = len(self.path)
        self.path.append(key)
        self.stack.append(iter(self.edges[key]))


@dataclass
class SelectRoot(BaseNode[RelationScan, None, None]):
    async def run(self, ctx: GraphRunContext[RelationScan, None]) -> FollowEdge | End[None]:
        scan = ctx.state
        root = next((key for key in scan.roots if key not in scan.finished), None)
        if root is None:
            return End(None)
        scan.enter(root)
        return FollowEdge()


@dataclass
class FollowEdge(BaseNode[RelationScan, None, None]):
    async def run(self, ctx: GraphRunContext[RelationScan, None]) -> FollowEdge | SelectRoot:
        scan = ctx.state
        edge = next(scan.stack[-1], None)
        if edge is None:
            scan.stack.pop()
            key = scan.path.pop()
            del scan.positions[key]
            scan.finished.add(key)
            if scan.kinds:
                scan.kinds.pop()
            return FollowEdge() if scan.stack else SelectRoot()
        target, kind = edge
        scan.reached.add(target)
        if target in scan.positions:
            start = scan.positions[target]
            scan.cycles.append((scan.path[start:] + [target], scan.kinds[start:] + [kind]))
        elif target not in scan.finished:
            scan.kinds.append(kind)
            scan.enter(target)
        return FollowEdge()


@cache
def diagnostic_graph() -> Graph:
    builder = GraphBuilder(
        name="DecompositionRelations",
        state_type=RelationScan,
        input_type=SelectRoot,
        auto_instrument=False,
    )
    builder.add(
        builder.node(SelectRoot),
        builder.node(FollowEdge),
        builder.edge_from(builder.start_node).to(SelectRoot),
    )
    return builder.build()


def build_relation_graph(tasks: dict[str, LoadedTask]) -> dict[str, list[Edge]]:
    relations = {}
    for task_id in sorted(tasks, key=str):
        task = tasks[task_id]
        task_relations: list[Edge] = []
        seen_targets = set()
        for dependency_id in sorted(_relation_ids(task.get("depends_on")), key=str):
            if dependency_id in tasks and dependency_id not in seen_targets:
                task_relations.append((dependency_id, "depends_on"))
                seen_targets.add(dependency_id)

        parent_task = task.get("parent_task")
        if (
            _is_nonempty_text(parent_task)
            and parent_task in tasks
            and parent_task not in seen_targets
        ):
            task_relations.append((parent_task, "parent_task"))
            seen_targets.add(parent_task)
        for blocker_id in sorted(_relation_ids(task.get("blocked_by")), key=str):
            if blocker_id in tasks and blocker_id not in seen_targets:
                task_relations.append((blocker_id, "blocked_by"))
                seen_targets.add(blocker_id)
        relations[task_id] = task_relations
    return relations


@dataclass
class TaskRelationGraph:
    """Directed relations among tasks in one decomposition."""

    edges: dict[str, list[Edge]]

    @classmethod
    def for_relation(cls, tasks: dict[str, LoadedTask], relation: Relation) -> TaskRelationGraph:
        edges: dict[str, list[Edge]] = {}
        for task_id, task in tasks.items():
            if relation == "depends_on":
                targets = _relation_ids(task.get("depends_on"))
            elif relation == "parent_task":
                parent = task.get("parent_task")
                targets = [parent] if _is_nonempty_text(parent) else []
            else:
                deferred = task.get("deferred")
                targets = [
                    target
                    for item in (deferred if isinstance(deferred, list) else [])
                    if isinstance(item, dict)
                    and _is_nonempty_text(target := item.get("completed_by"))
                ]
            edges[task_id] = [(target, relation) for target in targets if target in tasks]
        return cls(edges)

    @cached_property
    def program(self) -> DependencyGraph | None:
        try:
            return compile_dependencies(
                {key: [target for target, _ in edges] for key, edges in self.edges.items()}
            )
        except CycleError:
            # Invalid input still needs labeled cycle witnesses for the gate report.
            return None

    def predecessors(self, task_id: str) -> set[str]:
        if self.program is not None:
            return set(self.program.ancestors(task_id))
        return self._scan(iter((task_id,))).reached

    def _scan(self, roots: Iterator[str]) -> RelationScan:
        scan = RelationScan(self.edges, roots)
        run_program(diagnostic_graph(), state=scan, inputs=SelectRoot())
        return scan

    def _cycle_paths(self) -> list[tuple[list[str], list[RelationKind]]]:
        if self.program is not None:
            return []
        return self._scan(iter(self.edges)).cycles

    def cycles(self) -> list[str]:
        return [" -> ".join(path) for path, _ in self._cycle_paths()]

    def mixed_cycles(self) -> list[str]:
        cycles = []
        seen = set()
        for path, relations in self._cycle_paths():
            kinds = set(relations)
            if "blocked_by" in kinds or {"depends_on", "parent_task"} <= kinds:
                identity = frozenset(path)
                if identity not in seen:
                    cycles.append(" -> ".join(path))
                    seen.add(identity)
        return cycles


def check_circular_dependencies(tasks: dict[str, LoadedTask]) -> list[str]:
    return TaskRelationGraph.for_relation(tasks, "depends_on").cycles()


def check_parent_task_cycles(tasks: dict[str, LoadedTask]) -> list[str]:
    return TaskRelationGraph.for_relation(tasks, "parent_task").cycles()


def check_deferred_cycles(tasks: dict[str, LoadedTask]) -> list[str]:
    return TaskRelationGraph.for_relation(tasks, "deferred").cycles()


def check_mixed_relation_cycles(tasks: dict[str, LoadedTask]) -> list[str]:
    return TaskRelationGraph(build_relation_graph(tasks)).mixed_cycles()
