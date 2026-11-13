"""Data retained by the workflow runtime and shared with its consumers."""

from __future__ import annotations

from typing import Any, NotRequired, TypedDict

from factory_tooling.gates.gate_contract import GateResult
from factory_tooling.project.contracts import Policy
from factory_tooling.runtime.command_contract import Execution


class Criterion(TypedDict):
    id: str
    applies_to: str
    requirement: str
    verification: str


class Check(TypedDict, total=False):
    id: str
    kind: str
    category: str
    criteria: list[str]
    method: str
    execution: Execution
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


class Task(TypedDict, total=False):
    slice: str
    source: str
    outcome: str
    reason: str
    risk: str
    kind: str
    independent_review: bool
    scope: list[str]
    depends_on: list[str]
    acceptance_ids: list[str]
    contributes_to_acceptance_ids: list[str]
    local_acceptance_criteria: list[Criterion]
    parent_plan_ref: str
    required_checks: list[Check]
    policy_decisions: dict[str, object]


class ExternalApproval(TypedDict):
    state: str
    source_path: str
    content_sha256: str
    selected_scope: str | list[str]
    approved_by: str
    evidence_ref: str


class Source(TypedDict, total=False):
    text: str
    path: str
    kind: str
    selected_scope: str | list[str]
    acceptance: list[Criterion]
    hash: str
    external_approval: ExternalApproval
    acceptance_origin: str
    parent_plan_ref: str
    execution_mode: str
    directive: str
    selected_acceptance_ids: list[str]
    snapshot: str
    content_hash: str
    plan_id: str
    plan_revision: int
    plan_state: str
    approved_revision: int
    source: str


class Agent(TypedDict):
    role: str
    profile: str


class Node(TypedDict, total=False):
    id: str
    task: str
    stage: str
    agent: str | None
    depends_on: list[str]
    owns: list[str]
    resources: list[str]
    read: list[str]
    required_check_ids: list[str]


class Graph(TypedDict):
    sources: dict[str, Source]
    agents: dict[str, Agent]
    tasks: dict[str, Task]
    nodes: list[Node]


class EscalationPolicy(TypedDict):
    to: str
    after_failed_attempts: int


class Capabilities(TypedDict):
    read: bool
    edit: bool
    commands: bool
    web: bool


class Adapter(TypedDict, total=False):
    instructions: str
    worker_instructions: str
    harness: str
    runner: str
    connection: str


class Profile(Adapter):
    role: str
    contract: str
    model: str
    adapter: str
    capabilities: Capabilities
    enforcement: str
    mcp: list[str]
    escalation: NotRequired[EscalationPolicy | None]


class Model(TypedDict):
    id: str | None
    effort: NotRequired[str]


class RetryBudgets(TypedDict):
    static: int
    tests: int
    docs: int
    recovery: int
    review: dict[str, int]


class ExecutionPolicy(TypedDict):
    retry_budgets: RetryBudgets
    on_budget_exhausted: str


class Connection(TypedDict, total=False):
    command: str
    args: list[str]
    max_parallel_agents: int
    permissions: str
    timeout_seconds: int
    adapter: str
    config: str
    env: dict[str, str]


class Acpx(TypedDict):
    command: str
    connections: dict[str, Connection]


class Native(TypedDict):
    max_parallel_agents: int


class Routing(TypedDict):
    defaults: dict[str, str]


class Config(TypedDict):
    project: str
    router: str
    orchestration: str
    orchestrator: NotRequired[dict[str, str]]
    execution: ExecutionPolicy
    profiles: dict[str, Profile]
    models: dict[str, Model]
    adapters: dict[str, Adapter]
    native: Native
    acpx: NotRequired[Acpx]
    routing: Routing
    _path: str
    _files: dict[str, str]
    _limits: dict[str, int]
    _roles: dict[str, list[str]]
    _defaults: dict[str, str]
    # Declarative project data is composed and validated by the profile boundary.
    _project: Policy
    _project_documents: NotRequired[dict[str, str]]


class Report(TypedDict, total=False):
    run_id: str
    dispatch_id: str
    node_id: str
    task_id: str
    slice_id: str
    source_hash: str
    terminal: bool
    outcome: str
    summary: str
    files: dict[str, str]
    stage_result: str
    checks: list[Check]
    review_checks: list[dict[str, str]]
    not_applicable: dict[str, str]
    verdict: str
    observed_source_drift: bool
    approval_request: dict[str, Any]
    gate_results: list[GateResult]
    findings: list[dict[str, Any]]
    finding_updates: list[dict[str, Any]]
    evidence: str
    unsuccessful_attempt: dict[str, str]


class Dispatch(TypedDict, total=False):
    status: str
    attempt: int
    dispatch_id: str
    pool: str
    profile: str
    role: str
    handle: str
    model: str
    report: Report
    assignment: dict[str, object]
    report_ref: dict[str, str]
    prompt: dict[str, str]
    packet_file: dict[str, str]
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


class CompositeStage(TypedDict):
    execution_id: str
    spec: Check
    output: str


class ExecutionReceipt(TypedDict, total=False):
    run_id: str
    node_id: str
    dispatch_id: str
    source_hash: str
    spec: Check
    input_scope: list[str]
    files: dict[str, str]
    status: str
    started_at: float
    runner_pid: int
    request_id: str
    composite_stages: list[CompositeStage]
    composite_parent: str
    mode: str
    selection: dict[str, int | str]
    output_before: dict[str, str]
    output_after: dict[str, str]
    pid: int
    output: str
    environment: dict[str, str | None]
    ended_at: float
    error: str | None
    after_files: dict[str, str]
    output_hash: str
    result: Check


class State(TypedDict):
    run_id: str
    revision: int
    status: str
    workspace: str
    graph: Graph
    config: Config
    nodes: dict[str, Dispatch]
    counters: dict[str, int]
    executions: NotRequired[dict[str, ExecutionReceipt]]
    sessions: dict[str, dict[str, str]]
    transport_artifacts: NotRequired[list[str]]
    packet_hashes: NotRequired[dict[str, str]]
    archive_path: NotRequired[str]
    acp_created: NotRequired[dict[str, str]]
    epochs: NotRequired[dict[str, int]]
    retired_handles: NotRequired[list[str]]
    handle_owners: NotRequired[dict[str, str]]
    # Events and findings retain process-specific historical evidence payloads.
    events: list[dict[str, Any]]
    corrections: NotRequired[list[dict[str, Any]]]
    review_findings: NotRequired[dict[str, dict[str, dict[str, Any]]]]
    escalation_stops: NotRequired[dict[str, dict[str, Any]]]
    retired_node_profiles: NotRequired[dict[str, list[str]]]
    summary: NotRequired[str]
    report_hashes: NotRequired[dict[str, str]]
    report_index: NotRequired[dict[str, dict[str, str]]]
    pause_reason: NotRequired[str]
    processed_results: NotRequired[list[str]]


def agent_key(node: Node) -> str:
    agent = node["agent"]
    if agent is None:
        raise ValueError("Worker node requires an agent")
    return agent
