"""Pydantic execution of named, all-of dependencies across durable CLI checkpoints."""

from __future__ import annotations

import asyncio
import re
from asyncio import Event
from collections.abc import Callable, Collection, Mapping
from concurrent.futures import ThreadPoolExecutor
from contextvars import copy_context
from dataclasses import dataclass, field
from functools import cached_property, lru_cache
from graphlib import TopologicalSorter
from typing import cast

from pydantic_graph import Graph, GraphBuilder, StepContext, reduce_null
from pydantic_graph.step import StepFunction

type Visit = Callable[[str, frozenset[str]], None]
type Edges = tuple[tuple[str, tuple[str, ...]], ...]


def run_program(program: Graph, *, state: object = None, inputs: object = None) -> object:
    """Keep the synchronous ledger usable from a host that already owns an asyncio loop."""
    try:
        asyncio.get_running_loop()
    except RuntimeError:
        return program.run_sync(state=state, inputs=inputs)
    with ThreadPoolExecutor(max_workers=1) as runner:
        return runner.submit(
            copy_context().run, asyncio.run, program.run(state=state, inputs=inputs)
        ).result()


@dataclass
class Evaluation:
    """Signals belong to this in-process evaluation, never to a persisted agent attempt."""

    reached: dict[str, Event]
    visit: Visit


def vertex(key: str, parents: frozenset[str], additional: tuple[str, ...]) -> StepFunction:
    async def evaluate(ctx: StepContext) -> None:
        state = cast(Evaluation, ctx.state)
        for parent in additional:
            await state.reached[parent].wait()
        state.visit(key, parents)
        state.reached[key].set()

    return evaluate


@dataclass(eq=False)
class DependencyGraph:
    program: Graph
    parents: dict[str, tuple[str, ...]]

    _last_ready: tuple[frozenset[str], frozenset[str]] | None = field(
        default=None, init=False, repr=False
    )

    def run(self, visit: Visit) -> None:
        state = Evaluation({key: Event() for key in self.parents}, visit)
        run_program(self.program, state=state)

    def ancestors(self, key: str) -> frozenset[str]:
        """Inspect only the compiled incoming dependencies reachable from this vertex."""
        seen = set(self.parents[key])
        pending = list(seen)
        while pending:
            for parent in self.parents[pending.pop()]:
                if parent not in seen:
                    seen.add(parent)
                    pending.append(parent)
        return frozenset(seen)

    def affected_by(self, roots: set[str]) -> set[str]:
        """Include the selected nodes and all work that depends on them."""
        affected = set(roots)
        if affected:
            for layer in self.layers:
                for key in layer:
                    if not affected.isdisjoint(self.parents[key]):
                        affected.add(key)
        return affected

    @cached_property
    def layers(self) -> tuple[tuple[str, ...], ...]:
        depths: dict[str, int] = {}

        def measure(key: str, parents: frozenset[str]) -> None:
            depths[key] = 1 + max((depths[parent] for parent in parents), default=-1)

        self.run(measure)
        layers: list[list[str]] = [[] for _ in range(max(depths.values(), default=-1) + 1)]
        for key in self.parents:
            layers[depths[key]].append(key)
        return tuple(tuple(layer) for layer in layers)

    def ready(self, completed: frozenset[str]) -> frozenset[str]:
        previous = self._last_ready
        if previous is not None and previous[0] == completed:
            return previous[1]
        eligible = set[str]()

        def select(key: str, parents: frozenset[str]) -> None:
            if key not in completed and parents <= completed:
                eligible.add(key)

        self.run(select)
        result = frozenset(eligible)
        self._last_ready = completed, result
        return result


def compile_dependencies(dependencies: Mapping[str, Collection[str]]) -> DependencyGraph:
    edges = tuple((key, tuple(dict.fromkeys(parents))) for key, parents in dependencies.items())
    return _compile(edges)


def mermaid_label(key: str) -> str:
    return "".join(
        char if char.isalnum() or char in " _-." else f"#{ord(char)};"
        for char in " ".join(key.splitlines())
    )


@lru_cache(maxsize=128)
def _compile(edges: Edges) -> DependencyGraph:
    parents = dict(edges)
    if any(dep not in parents for deps in parents.values() for dep in deps):
        raise ValueError("Unknown node dependency")
    # Cycles are valid Pydantic state machines but invalid all-of wait conditions.
    TopologicalSorter(parents).prepare()
    builder = GraphBuilder(state_type=Evaluation, name="Dependencies", auto_instrument=False)
    # A step has one activating edge. Extra edges are all-of prerequisites:
    # crossing two fork scopes must never activate the same business node twice.
    labels = {key: mermaid_label(key) for key in parents}
    steps = {
        key: builder.step(
            vertex(key, frozenset(deps), deps[1:]),
            node_id="task_" + key if re.fullmatch(r"[A-Za-z0-9_-]+", key) else f"node_{index}",
            label=labels[key]
            + (
                " (also waits for " + ", ".join(labels[p] for p in deps[1:]) + ")"
                if deps[1:]
                else ""
            ),
        )
        for index, (key, deps) in enumerate(edges)
    }
    children: dict[str | None, list[str]] = {None: []}
    children.update({key: [] for key in parents})
    for key, deps in edges:
        children[deps[0] if deps else None].append(key)
    # Every leaf descends from the first fork after the common prefix.
    # Naming it avoids the SDK's dominator search on graphs with nested branches.
    outer: str | None = None
    while len(children[outer]) == 1:
        outer = children[outer][0]
    for parent, targets in children.items():
        if targets:
            source = builder.start_node if parent is None else steps[parent]
            builder.add(
                builder.edge_from(source).to(
                    steps[targets[0]],
                    *(steps[k] for k in targets[1:]),
                    fork_id="outer_fork" if parent == outer else None,
                )
            )
    leaves = [steps[key] for key in parents if not children[key]]
    if len(leaves) > 1:
        collect = builder.join(
            reduce_null, initial=None, node_id="complete", parent_fork_id="outer_fork"
        )
        builder.add(builder.edge_from(*leaves).to(collect))
        builder.add_edge(collect, builder.end_node)
    elif leaves:
        builder.add_edge(leaves[0], builder.end_node)
    else:
        builder.add_edge(builder.start_node, builder.end_node)
    return DependencyGraph(builder.build(), parents)
