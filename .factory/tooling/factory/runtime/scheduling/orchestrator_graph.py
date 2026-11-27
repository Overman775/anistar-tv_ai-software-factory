"""Evaluate the orchestrator's next assignment, acceptance, recovery or wait at a checkpoint."""

from __future__ import annotations

from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path
from typing import TYPE_CHECKING, Literal, Protocol, cast

from pydantic_graph import Graph, StepContext
from pydantic_graph.step import StepFunction
from typing_extensions import TypedDict

from factory.dependency_graph import run_program
from factory.graphs.program import Operations, compile_program
from factory.runtime import upstream
from factory.runtime.commands.evidence import check_generated
from factory.runtime.contracts import (
    Dispatch,
    ExecutionReceipt,
    Node,
    Report,
    ReportRef,
    State,
    agent_key,
)
from factory.runtime.reports import review_findings
from factory.runtime.scheduling import escalation
from factory.runtime.scheduling.claim_policy import check_contention
from factory.runtime.workflow_config import check_capabilities, pool
from factory.runtime.workflow_core import (
    Invalid,
    acceptance_guard,
    graph_identity,
    relative,
    require,
    snapshot,
)
from factory.runtime.workflow_graph import completed_nodes, execution_graph
from factory.tasks.contracts import Task


class GateEvidence(Protocol):
    root: Path

    def active_commands(self, state: State) -> dict[str, ExecutionReceipt]: ...
    def check_sources(self, state: State, task: Task) -> None: ...
    def check_current_verification(
        self, state: State, node: Node, report: Report, stale_message: str
    ) -> None: ...


@dataclass(frozen=True)
class Candidate:
    node: Node
    dispatch: Dispatch
    source_holds: tuple[str, ...]


@dataclass(frozen=True)
class Eligible:
    node_id: str
    profile: str
    pool: str
    runner: Literal["native", "acpx"]
    handle: str | None


@dataclass(frozen=True)
class Assign(Eligible):
    action: Literal["spawn", "continue", "prepare_acp"]


def assignment_ticket(run_id: str, revision: int, node_id: str, attempt: int) -> str:
    """The same permitted attempt has the same identity in every CLI process."""
    from uuid import NAMESPACE_URL, uuid5

    return uuid5(NAMESPACE_URL, f"overfactory/{run_id}/{revision}/{node_id}/{attempt}").hex


def stop_identity(state: State, task: str) -> str:
    stop = state["escalation_stops"][task]
    previous_resolutions = sum(
        e["event"] == "task_resumed" and e.get("task") == task for e in state["events"]
    )
    node = state["nodes"][stop["node_id"]]
    return graph_identity(
        [
            state["run_id"],
            task,
            stop,
            node.get("dispatch_id"),
            node["attempt"],
            previous_resolutions,
        ]
    )


@dataclass(frozen=True)
class Accept:
    node_id: str
    task: Task


@dataclass(frozen=True)
class Hold:
    node_id: str
    reason: str
    corrections: tuple[str, ...] = ()
    targets: tuple[RepairTarget, ...] = ()
    required: str | None = None
    next_role: str | None = None


class RepairTarget(TypedDict):
    action: Literal["correct", "retry"]
    node_id: str
    dispatch_id: str
    stage: str
    evidence: ReportRef


def repair_targets(state: State, node: Node) -> tuple[RepairTarget, ...]:
    source = state["nodes"][node["id"]]
    ref = source.get("report_ref")
    if ref is None or source["status"] != "blocked":
        return ()
    debts = {
        f["owner_node_id"]
        for items in state.get("review_findings", {}).values()
        for f in items.values()
        if f["status"] == "open" and f.get("reviewed", {}).get("dispatch_id") == ref["dispatch_id"]
    }
    graph = state["graph"]
    if not debts:
        debts = {
            n["id"] for n in graph["nodes"] if n["task"] == node["task"] and n.get("owns")
        } or {node["id"]}
    targets: list[RepairTarget] = []
    for target in graph["nodes"]:
        if target["id"] not in debts or not (
            dispatch_id := state["nodes"][target["id"]].get("dispatch_id")
        ):
            continue
        agent = graph["agents"][agent_key(target)]
        escalate = agent["role"] == "implementer" and state["config"]["profiles"][
            agent["profile"]
        ].get("escalation")
        stage = (
            "review"
            if node["stage"] == "review"
            else "static"
            if source.get("report", {}).get("stage_result") == "BLOCKED_STATIC_FAILURE"
            else "docs"
            if target["stage"] == "docs"
            else "tests"
        )
        targets.append(
            {
                "action": "correct" if escalate else "retry",
                "node_id": target["id"],
                "dispatch_id": dispatch_id,
                "stage": stage,
                "evidence": ref,
            }
        )
    return tuple(targets)


@dataclass(frozen=True)
class Observe:
    node_id: str


type Outcome = Assign | Accept | Hold | Observe


@dataclass
class Checkpoint:
    run: State
    nodes: dict[str, Node]
    evidence: GateEvidence
    run_blocker: str | None = None
    paths: dict[str, list[str]] = field(default_factory=dict, init=False)
    commands: bool = field(init=False)
    active: bool = field(init=False)
    complete: frozenset[str] = field(init=False)
    ready: frozenset[str] = field(init=False)
    source_stops: dict[str, dict[str, str]] = field(init=False)

    def __post_init__(self) -> None:
        self.source_stops = {
            task: holds
            for task in self.run["graph"]["tasks"]
            if (holds := upstream.pending_prerequisites(self.run, task))
        }
        self.commands = bool(self.evidence.active_commands(self.run))
        self.active = any(d["status"] in escalation.ACTIVE for d in self.run["nodes"].values())
        self.complete = completed_nodes(self.run)
        self.ready = execution_graph(self.nodes).ready(self.complete)

    def record_path(self, candidate: Candidate, path: list[str]) -> None:
        self.paths[candidate.node["id"]] = path

    def authorize(self) -> None:
        require(self.run["status"] == "active", "Run is not active")
        require(not self.run.get("pause_reason"), "Run is paused by user")
        if self.run_blocker is not None:
            raise Invalid(self.run_blocker)

    def evaluate(self, keys: list[str]) -> dict[str, Outcome]:
        candidates = [
            Candidate(
                self.nodes[key],
                self.run["nodes"][key],
                tuple(self.source_stops.get(self.nodes[key]["task"], {}).values()),
            )
            for key in keys
        ]
        if not candidates:
            return {}
        outcomes = cast(
            list[Outcome],
            run_program(orchestrator_graph(self.run["definitions"]), state=self, inputs=candidates),
        )
        # Independent branches can join in any order. The public schedule follows intake order.
        return {result.node_id: result for result in outcomes}


if TYPE_CHECKING:
    # The pinned SDK uses infer_variance TypeVars that mypy cannot specialize.
    class Context(Protocol):
        @property
        def state(self) -> Checkpoint: ...
        @property
        def inputs(self) -> Candidate: ...
else:
    type Context = StepContext[Checkpoint, None, Candidate]


async def assignment_gate(ctx: Context) -> Eligible | Hold:
    return authorize_assignment(ctx.state, ctx.inputs)


def authorize_assignment(cp: Checkpoint, candidate: Candidate) -> Eligible | Hold:
    node = candidate.node
    state, key = cp.run, node["id"]
    try:
        cp.authorize()
        require(candidate.dispatch["status"] == "pending", "Attempt already issued")
        require(not candidate.source_holds, "External prerequisites are not resolved")
        require(node["stage"] != "accept", "Only the coordinator can accept")
        for path in node.get("owns", []):
            relative(cp.evidence.root, path)
        profile = state["graph"]["agents"][agent_key(node)]["profile"]
        check_capabilities(state["config"]["profiles"][profile], node)
        require(key in cp.ready, "Dependencies not complete")
        cp.evidence.check_sources(state, state["graph"]["tasks"][node["task"]])
        acceptance_guard(escalation.guard, state, node["task"], profile, key)
        resource_pool = pool(state["config"], profile)
        check_contention(state, cp.nodes, node, resource_pool, has_active_commands=cp.commands)
        session = state["sessions"].get(agent_key(node))
        return Eligible(
            key,
            profile,
            resource_pool,
            state["config"]["profiles"][profile]["runner"],
            session["handle"] if session else None,
        )
    except Invalid as exc:
        return Hold(key, str(exc))


@dataclass(frozen=True)
class VerificationSlot:
    permit: Eligible | Hold
    focused: bool
    peers: tuple[str, ...]


async def verification_gate(ctx: Context) -> VerificationSlot:
    cp, candidate = ctx.state, ctx.inputs
    node = candidate.node
    permit = authorize_assignment(cp, candidate)
    focused = "required_check_ids" in node
    peers = []
    # Arbitration only applies to independently ready checks on the same verified result.
    if isinstance(permit, Eligible) and any(
        cp.nodes[key]["stage"] == "verify" and cp.run["nodes"][key].get("report", {}).get("checks")
        for key in node["depends_on"]
    ):
        for key in cp.ready:
            other = cp.nodes[key]
            if (
                other["task"] == node["task"]
                and other["stage"] == "verify"
                and set(other["depends_on"]) == set(node["depends_on"])
                and ("required_check_ids" in other) != focused
            ):
                peer = Candidate(other, cp.run["nodes"][key], candidate.source_holds)
                if isinstance(authorize_assignment(cp, peer), Eligible):
                    peers.append(key)
    return VerificationSlot(permit, focused, tuple(sorted(peers)))


async def verified_assignment(ctx: StepContext) -> Eligible | Hold:
    return cast(VerificationSlot, ctx.inputs).permit


async def wait_for_verification(ctx: StepContext) -> Eligible | Hold:
    slot = cast(VerificationSlot, ctx.inputs)
    if isinstance(slot.permit, Hold):
        return slot.permit
    if not slot.peers:
        return Hold(slot.permit.node_id, "No eligible verification peer", required="resolve_graph")
    return Hold(slot.permit.node_id, "Waiting for queued verification: " + ", ".join(slot.peers))


def deliver(action: Literal["spawn", "continue", "prepare_acp"]) -> StepFunction:
    async def select(ctx: StepContext) -> Assign | Hold:
        e = ctx.inputs
        if isinstance(e, Hold):
            return e
        if not isinstance(e, Eligible):
            raise Invalid("Delivery needs an authorized worker")
        if (action == "prepare_acp") != (e.runner == "acpx") or (
            e.runner == "native" and (action == "continue") != (e.handle is not None)
        ):
            return Hold(e.node_id, "Delivery requires the configured adapter and session")

        return Assign(e.node_id, e.profile, e.pool, e.runner, e.handle, action)

    return select


async def acceptance_gate(ctx: Context) -> Accept | Hold:
    cp, node = ctx.state, ctx.inputs.node
    state, key = cp.run, node["id"]
    try:
        cp.authorize()
        require(
            ctx.inputs.dispatch["status"] == "pending" and node["stage"] == "accept",
            "Invalid acceptance attempt",
        )
        require(not ctx.inputs.source_holds, "External prerequisites are not resolved")
        acceptance_guard(escalation.guard, state, node["task"])
        require(not cp.commands, "Unresolved project commands")
        upstream = execution_graph(cp.nodes).ancestors(key)
        require(upstream <= cp.complete, "Required work not done")
        task = state["graph"]["tasks"][node["task"]]
        cp.evidence.check_sources(state, task)
        api = set(state["config"]["_project"]["data"].get("public_contracts", {})) & set(
            task["scope"]
        )
        if any(
            state["contract_baseline"].get(path) != value
            for path, value in snapshot(cp.evidence.root, sorted(api)).items()
        ):
            require(
                any(
                    cp.nodes[p]["task"] == node["task"] and cp.nodes[p]["stage"] == "review"
                    for p in upstream
                ),
                "Changed public contract requires independent Judge review",
            )
        for predecessor in upstream:
            prior = cp.nodes[predecessor]
            if prior["task"] != node["task"]:
                continue
            report = state["nodes"][predecessor].get("report")
            if prior["stage"] in {"verify", "review"}:
                if report is None:
                    raise Invalid(f"Missing verification report: {predecessor}")
                cp.evidence.check_current_verification(
                    state, prior, report, "Evidence invalidated by later write"
                )
            check_generated(
                cp.evidence.root, state, predecessor, report["checks"] if report else []
            )
        acceptance_guard(
            review_findings.gate,
            state,
            node["task"],
            snapshot(cp.evidence.root, task["scope"]),
            state["graph"]["sources"][task["source"]]["hash"],
        )
        return Accept(key, task)
    except Invalid as exc:
        return Hold(key, str(exc))


async def reconcile_transport(ctx: Context) -> Hold:
    return Hold(ctx.inputs.node["id"], "Reconcile actual transport ownership before retry")


@dataclass(frozen=True)
class BlockedAttempt:
    node: Node
    dispatch: Dispatch
    report: Report | None
    reason: str
    stopped: bool
    available: bool
    targets: tuple[RepairTarget, ...]


async def correction_gate(ctx: Context) -> BlockedAttempt:
    cp, node, dispatch = ctx.state, ctx.inputs.node, ctx.inputs.dispatch
    report = dispatch.get("report")
    return BlockedAttempt(
        node,
        dispatch,
        report,
        report["stage_result"] if report else "Blocked",
        node["task"] in cp.run.get("escalation_stops", {}),
        not (cp.active or cp.commands or cp.run.get("pause_reason") or cp.run_blocker),
        repair_targets(cp.run, node),
    )


def correction_action(action: str, next_role: str | None = None) -> StepFunction:
    async def offer(ctx: StepContext) -> Hold:
        item = cast(BlockedAttempt, ctx.inputs)
        report = item.report
        allowed = {
            "resume-task": item.stopped,
            "resume-approved": bool(report and report.get("approval_request")),
            "reintake": bool(report and report.get("observed_source_drift")),
            "revise": requested_checks(item),
            "retry": not (
                item.stopped
                or requested_checks(item)
                or (
                    report
                    and (report.get("approval_request") or report.get("observed_source_drift"))
                )
            ),
        }
        if not allowed[action]:
            return Hold(
                item.node["id"],
                f"Recovery operation {action} lacks its required evidence",
                required="resolve_graph",
            )
        return Hold(
            item.node["id"],
            item.reason,
            (action,) if item.available else (),
            required=action,
            next_role=next_role,
        )

    return offer


async def direct_diagnosis(ctx: StepContext) -> Hold:
    item = cast(BlockedAttempt, ctx.inputs)
    return Hold(
        item.node["id"],
        "Gather a BugHunter diagnosis for " + item.reason,
        ("revise",) if item.available else (),
        required="revise",
        next_role="bug-hunter",
    )


async def diagnose_failed_attempt(ctx: StepContext) -> Hold:
    item = cast(BlockedAttempt, ctx.inputs)
    targets = item.targets if item.available else ()
    return Hold(
        item.node["id"], item.reason, tuple(dict.fromkeys(t["action"] for t in targets)), targets
    )


async def wait_source_prerequisite(ctx: Context) -> Hold:
    try:
        ctx.state.authorize()
    except Invalid as exc:
        return Hold(ctx.inputs.node["id"], str(exc))
    return Hold(
        ctx.inputs.node["id"],
        "External prerequisite: " + ", ".join(ctx.inputs.source_holds),
        ("resume-task",),
        required="resume-task",
    )


async def observe_attempt(ctx: Context) -> Observe:
    return Observe(ctx.inputs.node["id"])


async def wait(ctx: StepContext) -> Hold:
    return cast(Hold, ctx.inputs)


def requested_checks(b: BlockedAttempt) -> bool:
    report = b.report
    return bool(
        report
        and report["terminal"]
        and report["outcome"] == "BLOCKED"
        and report["stage_result"] == "CHECKS_REQUESTED"
        and b.dispatch.get("role") == "judge"
        and b.node["stage"] == "review"
    )


def routing_operations() -> Operations:
    return Operations(
        actions={
            "verification_gate": verification_gate,
            "verified_assignment": verified_assignment,
            "wait_for_verification": wait_for_verification,
            "assignment_gate": assignment_gate,
            "acceptance_gate": acceptance_gate,
            "correction_gate": correction_gate,
            "observe_attempt": observe_attempt,
            "wait_source_prerequisite": wait_source_prerequisite,
            "reconcile_transport": reconcile_transport,
            "wait": wait,
            "prepare_acp": deliver("prepare_acp"),
            "continue_native": deliver("continue"),
            "spawn_native": deliver("spawn"),
            "wait_approval": correction_action("resume-approved", "owner"),
            "wait_owner": correction_action("resume-task"),
            "reintake": correction_action("reintake"),
            "request_checks": correction_action("revise", "tester"),
            "retry": correction_action("retry"),
            "diagnose_failure": diagnose_failed_attempt,
            "request_diagnosis": direct_diagnosis,
        },
        decisions={
            "tester_state": {
                "started": lambda c: c.dispatch["status"] != "pending",
                "prerequisite": lambda c: bool(c.source_holds),
                "pending": lambda c: c.dispatch["status"] == "pending",
            },
            "check_order": {
                "full_with_peer": lambda slot: bool(slot.peers) and not slot.focused,
                "focused_with_peer": lambda slot: bool(slot.peers) and slot.focused,
                "eligible": lambda _: True,
            },
            "attempt": {
                "tester": lambda c: c.node["stage"] == "verify",
                "unknown": lambda c: c.dispatch["status"] == "unknown",
                "blocked": lambda c: c.dispatch["status"] == "blocked",
                "started": lambda c: c.dispatch["status"] != "pending",
                "prerequisite": lambda c: bool(c.source_holds),
                "acceptance": lambda c: c.node["stage"] == "accept",
                "pending": lambda c: c.dispatch["status"] == "pending",
            },
            "delivery": {
                "held": lambda e: isinstance(e, Hold),
                "acp": lambda e: isinstance(e, Eligible) and e.runner == "acpx",
                "bound": lambda e: isinstance(e, Eligible) and e.handle is not None,
                "native": lambda e: isinstance(e, Eligible) and e.runner == "native",
            },
            "blocked_attempt": {
                "approval": lambda b: (
                    b.report is not None and b.report["stage_result"] == "APPROVAL_REQUIRED"
                ),
                "stopped": lambda b: b.stopped,
                "source_drift": lambda b: bool(b.report and b.report.get("observed_source_drift")),
                "requested_checks": requested_checks,
                "unknown_cause": lambda b: bool(
                    b.report
                    and b.report["terminal"]
                    and b.dispatch.get("role") == "tester"
                    and b.report["stage_result"] == "UNKNOWN_CAUSE"
                ),
                "terminal_worker": lambda b: bool(
                    b.report
                    and b.report["terminal"]
                    and b.dispatch.get("role") in {"implementer", "tester", "judge"}
                ),
                "blocked": lambda _: True,
            },
        },
        inputs={
            "tester_state": Candidate,
            "verification_gate": Candidate,
            **dict.fromkeys(
                ("check_order", "verified_assignment", "wait_for_verification"), VerificationSlot
            ),
            **dict.fromkeys(
                (
                    "attempt",
                    "assignment_gate",
                    "acceptance_gate",
                    "correction_gate",
                    "observe_attempt",
                    "reconcile_transport",
                    "wait_source_prerequisite",
                ),
                Candidate,
            ),
            **dict.fromkeys(
                (
                    "blocked_attempt",
                    "wait_approval",
                    "wait_owner",
                    "reintake",
                    "request_checks",
                    "diagnose_failure",
                    "retry",
                    "request_diagnosis",
                ),
                BlockedAttempt,
            ),
            **dict.fromkeys(
                ("delivery", "prepare_acp", "continue_native", "spawn_native"), (Eligible, Hold)
            ),
            "wait": Hold,
        },
        record=Checkpoint.record_path,
        hold=lambda c, reason: Hold(c.node["id"], reason, required="resolve_graph"),
    )


@lru_cache(maxsize=16)
def _compile(documents: tuple[tuple[str, str], ...]) -> Graph:
    return compile_program("implement", dict(documents), routing_operations(), batch=True)


def orchestrator_graph(documents: dict[str, str]) -> Graph:
    return _compile(tuple(sorted(documents.items())))
