"""Data retained by the workflow runtime and shared with its consumers."""

from __future__ import annotations

from typing import Annotated, Literal, NotRequired, Required

from pydantic import AfterValidator, ConfigDict, Field, StringConstraints, with_config
from typing_extensions import TypedDict

from factory_tooling.decisions.decision_contract import Estimate
from factory_tooling.gates.gate_contract import GateResult
from factory_tooling.project.contracts import BoundaryGate, Policy
from factory_tooling.runtime.command_contract import CommandExecution, CommandKind

Nonblank = Annotated[str, StringConstraints(pattern=r"\S")]
Alias = Annotated[str, StringConstraints(pattern=r"^[a-z][a-z0-9-]*$")]
Positive = Annotated[int, Field(gt=0)]
Budget = Annotated[int, Field(ge=0)]


def terminal_true(value: bool) -> bool:
    if not value:
        raise ValueError("terminal must be true")
    return value


Terminal = Annotated[bool, AfterValidator(terminal_true)]


@with_config(ConfigDict(strict=True, extra="forbid"))
class Criterion(TypedDict):
    id: Annotated[str, StringConstraints(pattern=r"^AC-\d{2,}$")]
    applies_to: Nonblank
    requirement: Nonblank
    verification: Nonblank


CheckId = Annotated[str, StringConstraints(pattern=r"^[A-Za-z0-9][A-Za-z0-9_-]*$")]


@with_config(ConfigDict(strict=True, extra="forbid"))
class CheckDeclaration(TypedDict):
    id: CheckId
    category: Literal["acceptance", "project"]
    criteria: list[Nonblank]
    method: Nonblank


@with_config(ConfigDict(strict=True, extra="forbid"))
class ObservationCheck(CheckDeclaration):
    kind: Literal["observation"]


@with_config(ConfigDict(strict=True, extra="forbid"))
class ExecutableCheck(CheckDeclaration):
    kind: CommandKind
    execution: CommandExecution


CheckSpec = Annotated[ObservationCheck | ExecutableCheck, Field(discriminator="kind")]


@with_config(ConfigDict(strict=True, extra="forbid"))
class CheckEvidence(TypedDict, total=False):
    """Reported evidence, including observations and incomplete additional checks."""

    id: Required[Nonblank]
    kind: str
    category: str
    criteria: list[str]
    method: str
    execution: CommandExecution
    result: str
    evidence: str
    command: list[str] | str | None
    exit_code: int | None
    receipt: str
    execution_id: str
    cwd: str
    stdout: str
    stderr: str
    reason: str
    resolution: dict[str, str]


@with_config(ConfigDict(strict=True, extra="forbid"))
class CommandResult(ExecutableCheck):
    command: list[str] | str
    cwd: str
    exit_code: int | None
    result: Literal["PASS", "FAIL", "BLOCKED"]
    evidence: Nonblank
    execution_id: Nonblank


CheckResult = CommandResult | CheckEvidence


@with_config(ConfigDict(strict=True, extra="forbid"))
class PendingCheck(TypedDict):
    id: CheckId
    execution_id: Nonblank
    result: Literal["RUNNING"]


TaskScope = Annotated[list[Nonblank], Field(min_length=1)]
Stage = Literal["explore", "work", "docs", "verify", "review", "accept"]


@with_config(ConfigDict(strict=True, extra="forbid"))
class TaskSelection(TypedDict, total=False):
    scope: TaskScope
    required_checks: list[CheckSpec]
    policy_decisions: dict[str, Estimate]


@with_config(ConfigDict(strict=True, extra="forbid"))
class Task(TypedDict):
    slice: Nonblank
    source: Nonblank
    outcome: Nonblank
    reason: Nonblank
    risk: Literal["low", "moderate", "high"]
    kind: Literal["feature", "task", "refactor", "fix", "docs", "integration"]
    independent_review: bool
    scope: TaskScope
    depends_on: NotRequired[list[str]]
    acceptance_ids: list[str]
    contributes_to_acceptance_ids: NotRequired[list[str]]
    local_acceptance_criteria: NotRequired[list[Criterion]]
    parent_plan_ref: NotRequired[str]
    required_checks: list[CheckSpec]
    policy_decisions: NotRequired[dict[str, Estimate]]


@with_config(ConfigDict(strict=True, extra="forbid"))
class ExternalApproval(TypedDict):
    state: Literal["approved"]
    source_path: str
    content_sha256: str
    selected_scope: str | list[str]
    approved_by: Nonblank
    evidence_ref: Nonblank


@with_config(ConfigDict(strict=True, extra="forbid"))
class SourceFields(TypedDict, total=False):
    text: str
    path: str
    selected_scope: str | list[str]
    acceptance: Required[Annotated[list[Criterion], Field(min_length=1)]]
    external_approval: ExternalApproval
    approval_evidence: Literal["canonical_plan_metadata", "explicit_external_hash_approval"]
    acceptance_origin: str
    parent_plan_ref: str
    directive: str
    selected_acceptance_ids: list[str]
    plan_id: str
    plan_revision: int
    plan_state: str
    approved_revision: int
    source: str


SourceKind = Literal["direct", "local_task", "factory_decompose_task", "approved_plan"]
ExecutionMode = Literal["single_task", "approved_plan"]


@with_config(ConfigDict(strict=True, extra="forbid"))
class Source(SourceFields, total=False):
    kind: str
    execution_mode: str
    snapshot: str
    content_hash: str
    hash: str


@with_config(ConfigDict(strict=True, extra="forbid"))
class LockedSource(SourceFields):
    kind: SourceKind
    execution_mode: ExecutionMode
    snapshot: str
    content_hash: Nonblank
    hash: Nonblank


@with_config(ConfigDict(strict=True, extra="forbid"))
class Agent(TypedDict):
    role: str
    profile: str


@with_config(ConfigDict(strict=True, extra="forbid"))
class NodeMaterials(TypedDict, total=False):
    owns: list[str]
    resources: list[str]
    read: list[str]


@with_config(ConfigDict(strict=True, extra="forbid"))
class ContextNode(NodeMaterials, total=False):
    stage: Stage
    id: str


@with_config(ConfigDict(strict=True, extra="forbid"))
class Node(NodeMaterials):
    id: Nonblank
    task: Nonblank
    stage: Stage
    agent: str | None
    depends_on: list[str]
    required_check_ids: NotRequired[list[str]]


@with_config(ConfigDict(strict=True, extra="forbid"))
class GraphTopology(TypedDict):
    agents: dict[str, Agent]
    tasks: dict[str, Task]
    nodes: list[Node]


@with_config(ConfigDict(strict=True, extra="forbid"))
class Graph(GraphTopology):
    sources: dict[str, Source]


@with_config(ConfigDict(strict=True, extra="forbid"))
class LockedGraph(GraphTopology):
    sources: dict[str, LockedSource]


@with_config(ConfigDict(strict=True, extra="forbid"))
class FinishRequirements(TypedDict):
    allowed_checks: list[CheckSpec]
    required_checks: list[CheckSpec]
    gates: list[BoundaryGate]
    evidence_kinds: list[str]
    not_applicable_allowed: list[str]
    require_test_receipt: bool
    require_approval: bool
    require_writes_ready: bool
    require_evidence: bool


@with_config(ConfigDict(strict=True, extra="forbid"))
class Assignment(TypedDict):
    task: Task
    source: LockedSource
    node: Node
    requirements: FinishRequirements
    agent: Agent
    policy_hash: Nonblank


@with_config(ConfigDict(strict=True, extra="forbid"))
class EscalationPolicy(TypedDict):
    to: str
    after_failed_attempts: Positive


@with_config(ConfigDict(strict=True, extra="forbid"))
class Capabilities(TypedDict):
    read: bool
    edit: bool
    commands: bool
    web: bool


@with_config(ConfigDict(strict=True, extra="forbid"))
class Adapter(TypedDict):
    instructions: Nonblank
    worker_instructions: Nonblank
    harness: Alias
    runner: Literal["native", "acpx"]
    connection: NotRequired[Alias]


@with_config(ConfigDict(strict=True, extra="forbid"))
class ProfileCommon(TypedDict):
    role: Nonblank
    contract: Nonblank
    capabilities: Capabilities
    enforcement: Literal["instructions", "required"]
    mcp: list[Annotated[str, StringConstraints(pattern=r"^[a-z][a-z0-9-]*\.[A-Za-z0-9_-]+$")]]


@with_config(ConfigDict(strict=True, extra="forbid"))
class ProfileVariant(TypedDict):
    model: Alias
    adapter: Alias
    escalation: NotRequired[EscalationPolicy | None]


@with_config(ConfigDict(strict=True, extra="forbid"))
class Profile(ProfileCommon, ProfileVariant):
    worker_instructions: NotRequired[Nonblank]
    harness: NotRequired[Alias]
    runner: NotRequired[Literal["native", "acpx"]]
    connection: NotRequired[Alias]


@with_config(ConfigDict(strict=True, extra="forbid"))
class Model(TypedDict):
    id: Nonblank | None
    effort: NotRequired[Nonblank]


@with_config(ConfigDict(strict=True, extra="forbid"))
class ReviewBudgets(TypedDict):
    feature: Budget
    other: Budget


@with_config(ConfigDict(strict=True, extra="forbid"))
class RetryBudgets(TypedDict):
    static: Budget
    tests: Budget
    docs: Budget
    recovery: Budget
    review: ReviewBudgets


@with_config(ConfigDict(strict=True, extra="forbid"))
class ExecutionPolicy(TypedDict):
    retry_budgets: RetryBudgets
    on_budget_exhausted: Literal["human"]


@with_config(ConfigDict(strict=True, extra="forbid"))
class Connection(TypedDict):
    command: Nonblank
    args: NotRequired[list[Nonblank]]
    max_parallel_agents: Positive
    permissions: NotRequired[Literal["approve-reads", "approve-all", "deny-all"]]


@with_config(ConfigDict(strict=True, extra="forbid"))
class Acpx(TypedDict):
    command: Nonblank
    connections: dict[Alias, Connection]


@with_config(ConfigDict(strict=True, extra="forbid"))
class Native(TypedDict):
    max_parallel_agents: Positive


@with_config(ConfigDict(strict=True, extra="forbid"))
class Routing(TypedDict):
    defaults: dict[str, str]


@with_config(ConfigDict(strict=True, extra="forbid"))
class Orchestrator(TypedDict):
    model: Alias


@with_config(ConfigDict(strict=True, extra="forbid"))
class Settings(TypedDict):
    project: Nonblank
    router: Nonblank
    orchestration: Nonblank
    orchestrator: NotRequired[Orchestrator]
    execution: ExecutionPolicy
    models: Annotated[dict[Alias, Model], Field(min_length=1)]
    adapters: Annotated[dict[Alias, Adapter], Field(min_length=1)]
    native: Native
    acpx: NotRequired[Acpx]


@with_config(ConfigDict(strict=True, extra="forbid"))
class Config(Settings):
    profiles: dict[Alias, Profile]
    routing: Routing
    _path: str
    _files: dict[str, str]
    _limits: dict[str, int]
    _roles: dict[str, list[str]]
    _defaults: dict[str, str]
    # Declarative project data is composed and validated by the profile boundary.
    _project: Policy
    _project_documents: NotRequired[dict[str, str]]


@with_config(ConfigDict(strict=True, extra="forbid"))
class ReviewPass(TypedDict):
    id: Nonblank
    result: Literal["PASS"]
    evidence: Nonblank
    reason: NotRequired[Nonblank]


@with_config(ConfigDict(strict=True, extra="forbid"))
class ReviewNotApplicable(TypedDict):
    id: Nonblank
    result: Literal["NOT_APPLICABLE"]
    evidence: Nonblank
    reason: Nonblank


ReviewCheck = Annotated[ReviewPass | ReviewNotApplicable, Field(discriminator="result")]


@with_config(ConfigDict(strict=True, extra="forbid"))
class ApprovalRequest(TypedDict):
    action: Nonblank
    execution_id: Nonblank
    evidence: Nonblank
    files: Annotated[
        dict[Nonblank, Annotated[str, StringConstraints(pattern=r"^[0-9a-f]{64}$")]],
        Field(min_length=1),
    ]
    revision: NotRequired[int]
    added_preimages: NotRequired[dict[str, str]]
    id: NotRequired[str]


@with_config(ConfigDict(strict=True, extra="forbid"))
class UnsuccessfulAttempt(TypedDict):
    attempted_work: Nonblank
    unmet_requirement: Nonblank
    evidence: Nonblank


@with_config(ConfigDict(strict=True, extra="forbid"))
class Finding(TypedDict):
    id: Nonblank
    status: Literal["open", "ready", "fixed", "dismissed"]
    blocking: NotRequired[bool]
    owner_role: NotRequired[Nonblank]
    owner_node_id: NotRequired[Nonblank]
    task_id: NotRequired[Nonblank]
    summary: NotRequired[Nonblank]
    evidence: NotRequired[Nonblank]


@with_config(ConfigDict(strict=True, extra="forbid"))
class FindingUpdate(TypedDict):
    id: Annotated[str, StringConstraints(pattern=r"^REV-\d+$")]
    status: Literal["ready"]
    evidence: Nonblank
    task_id: NotRequired[Nonblank]


@with_config(ConfigDict(strict=True, extra="forbid"))
class FindingEvent(TypedDict):
    status: Literal["open", "ready", "fixed", "dismissed"]
    evidence: Nonblank
    node_id: Nonblank
    agent: Nonblank
    dispatch_id: Nonblank
    at: float
    revision: Positive
    files: dict[str, str]
    source_hash: Nonblank
    review_task_id: Nonblank


@with_config(ConfigDict(strict=True, extra="forbid"))
class FindingView(TypedDict):
    id: Nonblank
    status: Literal["open", "ready", "fixed", "dismissed"]
    blocking: bool
    owner_role: Literal["developer", "test-writer", "generalist", "doc-writer"]
    owner_node_id: Nonblank
    task_id: NotRequired[Nonblank]
    summary: Nonblank
    evidence: Nonblank
    reviewed: NotRequired[FindingEvent]


@with_config(ConfigDict(strict=True, extra="forbid"))
class FindingRecord(FindingView):
    history: list[FindingEvent]


@with_config(ConfigDict(strict=True, extra="forbid"))
class ReportEvidence(TypedDict, total=False):
    review_checks: list[ReviewCheck]
    not_applicable: dict[str, str]
    verdict: Literal["APPROVE", "NEEDS_WORK", "RETHINK", "BLOCKED_TOOL_ERROR"]
    observed_source_drift: bool
    approval_request: ApprovalRequest
    gate_results: list[GateResult]
    findings: list[Finding]
    finding_updates: list[FindingUpdate]
    evidence: str
    unsuccessful_attempt: UnsuccessfulAttempt


@with_config(ConfigDict(strict=True, extra="forbid"))
class ReportCore(ReportEvidence):
    run_id: Nonblank
    dispatch_id: Nonblank
    node_id: Nonblank
    source_hash: Nonblank
    terminal: Terminal
    outcome: Literal["PASS", "FAIL", "BLOCKED"]
    summary: Nonblank
    stage_result: Nonblank


@with_config(ConfigDict(strict=True, extra="forbid"))
class ReportDraft(ReportCore):
    task_id: NotRequired[Nonblank]
    slice_id: NotRequired[Nonblank]
    checks: NotRequired[list[CheckResult]]


@with_config(ConfigDict(strict=True, extra="forbid"))
class ReportSummary(ReportCore):
    task_id: Nonblank
    slice_id: Nonblank
    checks: list[CheckResult]


@with_config(ConfigDict(strict=True, extra="forbid"))
class Report(ReportSummary):
    files: dict[str, str]


@with_config(ConfigDict(strict=True, extra="forbid"))
class ReportRef(TypedDict):
    run_id: str
    node_id: str
    dispatch_id: str
    path: str
    sha256: str
    content_identity: str


@with_config(ConfigDict(strict=True, extra="forbid"))
class PacketRef(TypedDict):
    run_id: str
    node_id: str
    dispatch_id: str
    source_hash: str
    path: str
    sha256: str
    revision: str


@with_config(ConfigDict(strict=True, extra="forbid"))
class Dispatch(TypedDict, total=False):
    status: Required[Literal["pending", "reserved", "running", "unknown", "done", "blocked"]]
    attempt: Required[Budget]
    dispatch_id: str
    pool: str
    profile: str
    role: str
    handle: str
    model: str
    report: Report
    assignment: Assignment
    report_ref: ReportRef
    prompt: dict[str, str]
    packet_file: PacketRef
    packet_chunks_read: int
    packet_receipt: str
    packet_confirmed: bool
    prompt_submitted: bool
    prompt_hash: str
    gate_result: GateResult
    project_gate_results: list[GateResult]
    observed: str
    terminal_evidence: str
    reason: str


@with_config(ConfigDict(strict=True, extra="forbid"))
class TestSelection(TypedDict):
    mode: Literal["full"]
    selected: Positive
    completed: Positive


@with_config(ConfigDict(strict=True, extra="forbid"))
class CompositeStage(TypedDict):
    execution_id: str
    spec: ExecutableCheck
    output: str


@with_config(ConfigDict(strict=True, extra="forbid"))
class ExecutionReceipt(TypedDict, total=False):
    run_id: Required[str]
    node_id: Required[str]
    dispatch_id: Required[str]
    source_hash: Required[str]
    spec: Required[ExecutableCheck]
    input_scope: Required[list[str]]
    files: Required[dict[str, str]]
    status: Required[str]
    started_at: Required[float]
    runner_pid: int
    request_id: Required[str]
    composite_stages: list[CompositeStage]
    composite_parent: str
    mode: str
    selection: TestSelection
    output_before: dict[str, str]
    output_after: dict[str, str]
    pid: int
    output: Required[str]
    environment: Required[dict[str, str | None]]
    ended_at: float
    error: str | None
    after_files: dict[str, str]
    output_hash: str
    result: CommandResult


@with_config(ConfigDict(strict=True, extra="forbid"))
class LedgerEvent(TypedDict):
    at: float
    event: Nonblank
    node: NotRequired[Nonblank]
    task: NotRequired[Nonblank]
    dispatch_id: NotRequired[Nonblank]
    execution_id: NotRequired[Nonblank]
    result: NotRequired[str]
    outcome: NotRequired[Literal["PASS", "FAIL", "BLOCKED"]]
    sha256: NotRequired[str]
    reason: NotRequired[str]
    handle: NotRequired[str]
    model: NotRequired[str]
    status: NotRequired[str]
    evidence: NotRequired[str]
    terminal_evidence: NotRequired[str]
    previous: NotRequired[Dispatch | Session | EscalationStop | None]
    previous_graph: NotRequired[LockedGraph]
    previous_nodes: NotRequired[dict[str, Dispatch]]
    previous_config: NotRequired[Config]
    authorization: NotRequired[str]
    agent: NotRequired[str]
    handoff: NotRequired[str]
    task_handoffs: NotRequired[dict[str, Nonblank]]
    stage: NotRequired[str]
    decision: NotRequired[str]
    target: NotRequired[str]
    retry_cause: NotRequired[str]
    request_id: NotRequired[str]
    added_scope: NotRequired[list[str]]
    session: NotRequired[str]
    operation: NotRequired[str]
    argv: NotRequired[list[str]]
    effort_argv: NotRequired[list[str]]
    exit_code: NotRequired[int]
    stdout: NotRequired[str]
    stderr: NotRequired[str]


@with_config(ConfigDict(strict=True, extra="forbid"))
class CorrectionSummary(TypedDict):
    identity: Annotated[list[Nonblank], Field(min_length=4, max_length=4)]
    source_hash: Nonblank
    from_profile: Nonblank
    kind: Literal["quality", "environment", "requirements"]
    cause: Literal["static", "tests", "docs", "review"]
    reason: Nonblank
    handoff: Nonblank
    evidence: Report


@with_config(ConfigDict(strict=True, extra="forbid"))
class CorrectionRecord(CorrectionSummary):
    request_hash: Nonblank
    task_id: Nonblank
    node_id: Nonblank
    to_profile: Nonblank
    terminal_evidence: Nonblank
    failure_count: Budget
    decision: Literal["blocked", "human", "retry", "escalate"]
    at: float
    budget_cause: Literal["static", "tests", "docs", "review", "recovery"]
    budget_remaining: int
    reassigned_nodes: NotRequired[list[Nonblank]]
    agents: NotRequired[dict[str, str]]


@with_config(ConfigDict(strict=True, extra="forbid"))
class EscalationStop(TypedDict):
    reason: Nonblank
    decision: Literal["blocked", "human"]
    node_id: Nonblank
    node_ids: NotRequired[list[Nonblank]]
    kind: Literal["quality", "environment", "requirements", "source_reintake"]
    cause: Literal["static", "tests", "docs", "review", "recovery"]
    budget_exhausted: bool
    authorization: NotRequired[Nonblank]


@with_config(ConfigDict(strict=True, extra="forbid"))
class Session(TypedDict):
    handle: Nonblank
    model: Nonblank


@with_config(ConfigDict(strict=True, extra="forbid"))
class State(TypedDict):
    run_id: str
    revision: Positive
    status: Literal["active", "completed", "cancelled"]
    workspace: Nonblank
    graph: LockedGraph
    config: Config
    nodes: dict[str, Dispatch]
    counters: dict[str, int]
    executions: NotRequired[dict[str, ExecutionReceipt]]
    sessions: dict[str, Session]
    transport_artifacts: NotRequired[list[str]]
    packet_hashes: NotRequired[dict[str, str]]
    archive_path: NotRequired[str]
    acp_created: NotRequired[dict[str, str]]
    epochs: NotRequired[dict[str, int]]
    retired_handles: NotRequired[list[str]]
    handle_owners: NotRequired[dict[str, str]]
    events: list[LedgerEvent]
    corrections: NotRequired[list[CorrectionRecord]]
    review_findings: NotRequired[dict[str, dict[str, FindingRecord]]]
    escalation_stops: NotRequired[dict[str, EscalationStop]]
    retired_node_profiles: NotRequired[dict[str, list[str]]]
    summary: NotRequired[str]
    report_hashes: NotRequired[dict[str, str]]
    report_index: NotRequired[dict[str, ReportRef]]
    pause_reason: NotRequired[str]
    processed_results: NotRequired[list[str]]


def agent_key(node: Node) -> str:
    agent = node["agent"]
    if agent is None:
        raise ValueError("Worker node requires an agent")
    return agent
