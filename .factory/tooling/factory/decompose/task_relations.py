"""Task dependency and parent/deferred cycle analysis."""

from __future__ import annotations

from factory.decompose.contracts import LoadedTask
from factory.decompose.task_data import (
    _is_nonempty_text,
    _relation_ids,
)


def check_circular_dependencies(tasks: dict[str, LoadedTask]) -> list[str]:
    state: dict[str, int] = {}
    stack: list[str] = []
    cycles: list[str] = []

    def dfs(task_id: str) -> None:
        if state.get(task_id) == 1:
            cycle_start = stack.index(task_id)
            cycles.append(" -> ".join(stack[cycle_start:] + [task_id]))
            return
        if state.get(task_id) == 2:
            return

        state[task_id] = 1
        stack.append(task_id)
        for dependency_id in _relation_ids(tasks.get(task_id, {}).get("depends_on")):
            if dependency_id in tasks:
                dfs(dependency_id)
        stack.pop()
        state[task_id] = 2

    for task_id in tasks:
        if not state.get(task_id):
            dfs(task_id)
    return cycles


def check_parent_task_cycles(tasks: dict[str, LoadedTask]) -> list[str]:
    state: dict[str, int] = {}
    stack: list[str] = []
    cycles: list[str] = []

    def dfs(task_id: str) -> None:
        if state.get(task_id) == 1:
            cycle_start = stack.index(task_id)
            cycles.append(" -> ".join(stack[cycle_start:] + [task_id]))
            return
        if state.get(task_id) == 2:
            return

        state[task_id] = 1
        stack.append(task_id)
        parent_task = tasks.get(task_id, {}).get("parent_task")
        if _is_nonempty_text(parent_task) and parent_task in tasks:
            dfs(parent_task)
        stack.pop()
        state[task_id] = 2

    for task_id in tasks:
        if not state.get(task_id):
            dfs(task_id)
    return cycles


def check_deferred_cycles(tasks: dict[str, LoadedTask]) -> list[str]:
    state: dict[str, int] = {}
    stack: list[str] = []
    cycles: list[str] = []

    def dfs(task_id: str) -> None:
        if state.get(task_id) == 1:
            cycle_start = stack.index(task_id)
            cycles.append(" -> ".join(stack[cycle_start:] + [task_id]))
            return
        if state.get(task_id) == 2:
            return

        state[task_id] = 1
        stack.append(task_id)
        deferred = tasks.get(task_id, {}).get("deferred")
        if isinstance(deferred, list):
            for item in deferred:
                if not isinstance(item, dict):
                    continue
                completed_by = item.get("completed_by")
                if _is_nonempty_text(completed_by) and completed_by in tasks:
                    dfs(completed_by)
        stack.pop()
        state[task_id] = 2

    for task_id in tasks:
        if not state.get(task_id):
            dfs(task_id)
    return cycles


def build_relation_graph(tasks: dict[str, LoadedTask]) -> dict[str, list[tuple[str, str]]]:
    relations = {}
    for task_id in sorted(tasks, key=str):
        task = tasks[task_id]
        task_relations = []
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


def check_mixed_relation_cycles(tasks: dict[str, LoadedTask]) -> list[str]:
    relations = build_relation_graph(tasks)
    state: dict[str, int] = {}
    node_stack: list[str] = []
    edge_stack: list[str] = []
    cycles: list[str] = []
    seen_cycles = set()

    def dfs(task_id: str) -> None:
        state[task_id] = 1
        node_stack.append(task_id)
        for target_id, relation_type in relations.get(task_id, []):
            if state.get(target_id) == 1:
                cycle_start = node_stack.index(target_id)
                relation_types = edge_stack[cycle_start:] + [relation_type]
                unique_relations = set(relation_types)
                if "blocked_by" in unique_relations or {"depends_on", "parent_task"}.issubset(
                    unique_relations
                ):
                    cycle_nodes = node_stack[cycle_start:] + [target_id]
                    cycle_key = tuple(sorted(set(cycle_nodes), key=str))
                    if cycle_key not in seen_cycles:
                        seen_cycles.add(cycle_key)
                        cycles.append(" -> ".join(cycle_nodes))
            elif state.get(target_id) != 2:
                edge_stack.append(relation_type)
                dfs(target_id)
                edge_stack.pop()
        node_stack.pop()
        state[task_id] = 2

    for task_id in sorted(tasks, key=str):
        if not state.get(task_id):
            dfs(task_id)
    return cycles
