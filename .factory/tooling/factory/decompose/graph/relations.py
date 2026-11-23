"""Task dependency and parent/deferred cycle analysis."""

from __future__ import annotations

from collections.abc import Iterator
from dataclasses import dataclass
from typing import Literal

from factory.decompose.contracts import LoadedTask
from factory.decompose.graph.task_data import (
    _is_nonempty_text,
    _relation_ids,
)

type Relation = Literal["depends_on", "parent_task", "deferred"]
type RelationKind = Relation | Literal["blocked_by"]
type Edge = tuple[str, RelationKind]


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

    def predecessors(self, task_id: str) -> set[str]:
        reached: set[str] = set()
        pending = [task_id]
        while pending:
            for target, _ in self.edges[pending.pop()]:
                if target not in reached:
                    reached.add(target)
                    pending.append(target)
        return reached

    def _cycle_paths(self) -> Iterator[tuple[list[str], list[RelationKind]]]:
        finished: set[str] = set()
        for root in self.edges:
            if root in finished:
                continue
            path = [root]
            positions = {root: 0}
            relations: list[RelationKind] = []
            stack = [iter(self.edges[root])]
            while stack:
                edge = next(stack[-1], None)
                if edge is None:
                    stack.pop()
                    node = path.pop()
                    finished.add(node)
                    del positions[node]
                    if relations:
                        relations.pop()
                    continue
                target, relation = edge
                if target in positions:
                    start = positions[target]
                    yield path[start:] + [target], relations[start:] + [relation]
                elif target not in finished:
                    positions[target] = len(path)
                    path.append(target)
                    relations.append(relation)
                    stack.append(iter(self.edges[target]))

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
