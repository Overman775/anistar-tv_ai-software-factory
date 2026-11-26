"""Compile the sealed definitions into the same executable and renderable graph."""

from collections.abc import Callable, Mapping
from dataclasses import dataclass, field
from typing import Any, cast

from pydantic_graph import Graph, GraphBuilder, StepContext, reduce_list_append
from pydantic_graph.step import Step, StepFunction

from factory.graphs.definition import Action, Call, Definition, Node, Route, Selection, parse

type Predicates = Mapping[str, Callable[[Any], bool]]


@dataclass(frozen=True)
class Operations:
    actions: Mapping[str, StepFunction]
    decisions: Mapping[str, Predicates]
    hold: Callable[[Any, str], object]
    record: Callable[[Any, Any, list[str]], None] | None = None
    inputs: Mapping[str, type | tuple[type, ...]] = field(default_factory=dict)


@dataclass
class Frame:
    original: object
    value: object
    target: str = ""
    problem: str = ""
    visits: dict[str, int] = field(default_factory=dict)
    path: list[str] = field(default_factory=list)


async def enter(ctx: StepContext) -> Frame:
    return Frame(ctx.inputs, ctx.inputs)


def choose(value: object, routes: list[Route], predicates: Predicates) -> tuple[str, str]:
    facts = {key for key, predicate in predicates.items() if predicate(value)}
    matches = [r for r in routes if r.outcome in facts and facts.issuperset(r.requires)]
    priority = max((r.priority for r in matches), default=None)
    winners = {r.target for r in matches if r.priority == priority}
    if len(winners) == 1:
        return winners.pop(), ""
    return (
        "",
        f"outcomes={sorted(facts)}, rules={[(r.outcome, r.priority, r.target) for r in routes]}, matched targets={sorted(winners)}",
    )


def execute(address: str, node: Node, operations: Operations) -> StepFunction:
    async def run(ctx: StepContext) -> Frame:
        frame = cast(Frame, ctx.inputs)
        frame.path.append(address)
        if isinstance(node, Action | Selection):
            operation = node.operation if isinstance(node, Action) else node.decision
            expected = operations.inputs.get(operation)
            if expected is not None and not isinstance(frame.value, expected):
                frame.problem = (
                    f"{address}: {operation} cannot consume {type(frame.value).__name__}"
                )
                return frame
        if node.limit is not None:
            count = frame.visits.get(address, 0) + 1
            frame.visits[address] = count
            if count > node.limit:
                frame.problem = f"{address}: visit limit {node.limit} exhausted"
                return frame
        if isinstance(node, Action):
            frame.value = await operations.actions[node.operation](
                StepContext(state=ctx.state, deps=ctx.deps, inputs=frame.value)
            )
        elif isinstance(node, Selection):
            frame.target, reason = choose(
                frame.value, node.routes, operations.decisions[node.decision]
            )
            frame.path[-1] = f"{address} -> {frame.target or reason}"
            if reason:
                frame.problem = f"{address}: {reason}"
        return frame

    return run


def check_operation(address: str, node: Node, operations: Operations) -> None:
    if isinstance(node, Action) and node.operation not in operations.actions:
        raise ValueError(f"{address}: unknown operation {node.operation}")
    if isinstance(node, Selection):
        known = operations.decisions.get(node.decision)
        if known is None:
            raise ValueError(f"{address}: unknown decision {node.decision}")
        declared = {r.outcome for r in node.routes}
        unknown = (declared | {k for r in node.routes for k in r.requires}) - known.keys()
        missing = known.keys() - declared
        if missing or unknown:
            raise ValueError(
                f"{address}: missing outcomes {sorted(missing)}, unknown {sorted(unknown)}"
            )


def selected(target: str) -> Callable[[Frame], bool]:
    return lambda frame: frame.target == target


class Compiler:
    def __init__(self, definitions: dict[str, Definition], operations: Operations, name: str):
        self.definitions = definitions
        self.operations = operations
        self.builder = GraphBuilder(name=name, auto_instrument=False)

        async def hold(ctx: StepContext) -> object:
            frame = cast(Frame, ctx.inputs)
            if operations.record:
                operations.record(ctx.state, frame.original, frame.path)
            return operations.hold(frame.original, frame.problem)

        self.stop = self.builder.step(hold, node_id="hold_branch", label="Hold this branch")

    def emit(
        self, graph: str, path: tuple[str, ...], continuation: Step, ancestors: tuple[str, ...]
    ) -> Step:
        if graph in ancestors:
            raise ValueError(f"{'/'.join(path)}: recursive call to {graph}")
        definition = self.definitions[graph]
        b = self.builder
        steps: dict[str, Step] = {}
        for key, node in definition.nodes.items():
            address = "/".join((*path, key))
            check_operation(address, node, self.operations)
            # Length-prefix the components: distinct call sites must never share a vertex.
            uid = "n" + "".join(f"_{len(p)}_{p}" for p in (*path, key))
            steps[key] = b.step(execute(address, node, self.operations), node_id=uid, label=address)
        for key, node in definition.nodes.items():
            step = steps[key]
            if isinstance(node, Selection):
                decision = b.decision(node_id=f"{step.id}_route")
                decision = decision.branch(
                    b.match(Frame, matches=lambda f: bool(f.problem)).to(self.stop)
                )
                for target in dict.fromkeys(r.target for r in node.routes):
                    label = ", ".join(
                        f"{r.outcome} ({r.priority})" for r in node.routes if r.target == target
                    )
                    decision = decision.branch(
                        b.match(Frame, matches=selected(target)).label(label).to(steps[target])
                    )
                b.add_edge(step, decision)
                continue
            dest = steps[node.after] if node.after else continuation
            if isinstance(node, Call):
                dest = self.emit(node.call, (*path, key), dest, (*ancestors, graph))
            if node.limit is None and (
                not isinstance(node, Action) or node.operation not in self.operations.inputs
            ):
                b.add_edge(step, dest)
            else:
                decision = b.decision(node_id=f"{step.id}_limit")
                b.add_edge(
                    step,
                    decision.branch(
                        b.match(Frame, matches=lambda f: bool(f.problem)).to(self.stop)
                    ).branch(b.match(Frame).to(dest)),
                )
        return steps[definition.entry]


def compile_program(
    name: str, documents: dict[str, str], operations: Operations, *, batch: bool
) -> Graph:
    definitions = {key: parse(key, text) for key, text in documents.items()}
    compiler = Compiler(definitions, operations, name)
    b = compiler.builder

    async def leave(ctx: StepContext) -> object:
        frame = cast(Frame, ctx.inputs)
        if operations.record:
            operations.record(ctx.state, frame.original, frame.path)
        return frame.value

    end = b.step(leave, node_id="return_result")
    start = b.step(enter, node_id="enter_workflow")
    entry = compiler.emit(name, (name,), end, ())
    b.add_edge(start, entry)
    if batch:
        b.add(b.edge_from(b.start_node).map(fork_id="candidates").to(start))
        joined = b.join(
            reduce_list_append,
            initial_factory=list,
            node_id="schedule",
            parent_fork_id="candidates",
        )
        b.add(b.edge_from(end, compiler.stop).to(joined))
        b.add_edge(joined, b.end_node)
    else:
        b.add_edge(b.start_node, start)
        b.add(b.edge_from(end, compiler.stop).to(b.end_node))
    return b.build()
