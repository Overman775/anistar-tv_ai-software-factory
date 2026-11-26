"""One authorized node-state transition per durable ledger command."""

from __future__ import annotations

from dataclasses import dataclass
from functools import cache, partial
from typing import Literal, cast

from pydantic_graph import Graph, GraphBuilder, StepContext
from pydantic_graph.step import StepFunction

from factory.dependency_graph import run_program
from factory.runtime.contracts import Dispatch, DispatchStatus
from factory.runtime.workflow_core import Invalid

type Action = Literal[
    "claim",
    "bind",
    "lost",
    "recover_reserved",
    "recover_running",
    "recover_blocked",
    "pass",
    "fail",
    "accept",
    "invalidate",
]


@dataclass(frozen=True)
class Change:
    source: DispatchStatus
    action: Action


# Domain-specific evidence, budgets and ownership are checked inside the caller's transaction.
ROUTES: dict[Action, tuple[tuple[DispatchStatus, ...], DispatchStatus]] = {
    "claim": (("pending",), "reserved"),
    "accept": (("pending",), "done"),
    "bind": (("reserved",), "running"),
    "lost": (("reserved", "running", "unknown"), "unknown"),
    "recover_reserved": (("unknown",), "reserved"),
    "recover_running": (("unknown",), "running"),
    "recover_blocked": (("unknown",), "blocked"),
    "pass": (("running",), "done"),
    "fail": (("running",), "blocked"),
    "invalidate": (("pending", "blocked", "unknown", "done"), "pending"),
}


def allows(action: Action, change: Change) -> bool:
    return change.action == action and change.source in ROUTES[action][0]


def arrive(status: DispatchStatus) -> StepFunction:
    async def transition(ctx: StepContext) -> DispatchStatus:
        return status

    return transition


async def reject(ctx: StepContext) -> DispatchStatus:
    change = cast(Change, ctx.inputs)
    raise Invalid(f"Cannot {change.action} a {change.source} dispatch")


@cache
def attempt_graph() -> Graph:
    builder = GraphBuilder(name="Attempt", input_type=Change, auto_instrument=False)
    destinations = {
        status: builder.step(arrive(status), node_id=status) for _, status in ROUTES.values()
    }
    route = builder.decision(node_id="transition")
    for action, (_, status) in ROUTES.items():
        route = route.branch(
            builder.match(Change, matches=partial(allows, action)).to(destinations[status])
        )
    invalid = builder.step(reject)
    route = route.branch(builder.match(Change).to(invalid))
    builder.add_edge(builder.start_node, route)
    builder.add(builder.edge_from(*destinations.values(), invalid).to(builder.end_node))
    return builder.build()


def advance(dispatch: Dispatch, action: Action) -> DispatchStatus:
    change = Change(dispatch["status"], action)
    return cast(DispatchStatus, run_program(attempt_graph(), inputs=change))


def invalidate(dispatch: Dispatch) -> Dispatch:
    return {"status": advance(dispatch, "invalidate"), "attempt": dispatch["attempt"]}
