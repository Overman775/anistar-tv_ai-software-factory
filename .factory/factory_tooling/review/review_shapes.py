"""Wire records shared by standalone Review producers and consumers."""

from typing import Annotated, Literal, NotRequired

from pydantic import ConfigDict, Field, StringConstraints, with_config
from typing_extensions import TypedDict

from factory_tooling.gates.gate_contract import GateResult
from factory_tooling.project.contracts import Hash, Nonblank, ProjectCommand, Snapshot
from factory_tooling.runtime.command_contract import Argument, CommandExecution

GitHash = Annotated[str, StringConstraints(pattern=r"^[0-9a-f]{40}$")]
Lens = Literal["system-design", "runtime-safety", "verification-quality"]
Severity = Literal["critical", "high", "medium"]
Positive = Annotated[int, Field(gt=0)]
Index = Annotated[int, Field(ge=0)]


@with_config(ConfigDict(strict=True, extra="forbid"))
class Identity(TypedDict):
    schema_version: Literal["4"]
    review_id: Nonblank
    mode: Literal["branch", "pr", "feature"]
    base_sha: GitHash | None
    head_sha: GitHash
    scope_hash: Hash


@with_config(ConfigDict(strict=True, extra="forbid"))
class SourceSnapshot(TypedDict):
    id: Nonblank
    locator: Nonblank
    content: Nonblank
    captured_at: Nonblank


@with_config(ConfigDict(strict=True, extra="forbid"))
class Requirement(TypedDict):
    id: Nonblank
    source_id: Nonblank
    text: Nonblank


@with_config(ConfigDict(strict=True, extra="forbid"))
class PrSnapshot(TypedDict):
    url: Nonblank
    title: str
    body: str
    captured_at: Nonblank
    head_sha: GitHash


@with_config(ConfigDict(strict=True, extra="forbid"))
class ReviewContext(TypedDict):
    sources: list[SourceSnapshot]
    requirements: list[Requirement]
    limitations: list[Nonblank]
    pr: PrSnapshot | None


@with_config(ConfigDict(strict=True, extra="forbid"))
class ReviewCommand(TypedDict):
    argv: Annotated[list[Argument], Field(min_length=1)]
    cwd: NotRequired[Argument]
    timeout_seconds: NotRequired[Annotated[int, Field(ge=1, le=86400)]]


@with_config(ConfigDict(strict=True, extra="forbid"))
class PlannedExecution(ReviewCommand):
    inputs: NotRequired[list[Nonblank]]


@with_config(ConfigDict(strict=True, extra="forbid"))
class AdditionalCheck(TypedDict):
    id: Annotated[str, StringConstraints(pattern=r"^[A-Za-z0-9][A-Za-z0-9_-]*$")]
    method: Nonblank
    execution: PlannedExecution
    after: NotRequired[list[Nonblank]]


@with_config(ConfigDict(strict=True, extra="forbid"))
class PlannedCheck(TypedDict):
    id: Nonblank
    method: Nonblank
    execution: CommandExecution
    after: NotRequired[list[Nonblank]]


@with_config(ConfigDict(strict=True, extra="forbid"))
class Assignment(TypedDict):
    id: Lens
    name: Nonblank
    role: Literal["reviewer"]
    profile: Literal["reviewer"]
    criteria: list[Nonblank]


@with_config(ConfigDict(strict=True, extra="forbid"))
class PinnedSource(TypedDict):
    content: str
    sha256: Hash


@with_config(ConfigDict(strict=True, extra="forbid"))
class Manifest(Identity):
    target: Nonblank
    scope_files: Annotated[list[Nonblank], Field(min_length=1)]
    diff_file: NotRequired[Nonblank | None]
    diff_sha256: NotRequired[Hash | None]
    source_sha256: NotRequired[dict[str, Hash] | None]
    project_policy: Snapshot
    context: ReviewContext
    additional_checks: list[AdditionalCheck]
    checks: list[PlannedCheck | ProjectCommand]
    assignments: list[Assignment]
    core_criteria: list[Annotated[list[Nonblank], Field(min_length=3, max_length=3)]]
    command_selection_reason: Nonblank
    source_evidence: dict[str, PinnedSource]


@with_config(ConfigDict(strict=True, extra="forbid"))
class SourceEvidence(TypedDict):
    kind: Literal["source"]
    path: Nonblank
    line: Positive
    side: Literal["new", "old"]


@with_config(ConfigDict(strict=True, extra="forbid"))
class Inspection(TypedDict):
    kind: Literal["inspection"]
    path: Nonblank
    line: Positive


@with_config(ConfigDict(strict=True, extra="forbid"))
class Binary(TypedDict):
    kind: Literal["binary"]
    path: Nonblank


@with_config(ConfigDict(strict=True, extra="forbid"))
class ModeChange(TypedDict):
    kind: Literal["file_operation"]
    path: Nonblank
    operation: Literal["mode"]
    old_mode: Nonblank
    new_mode: Nonblank


@with_config(ConfigDict(strict=True, extra="forbid"))
class Rename(TypedDict):
    kind: Literal["file_operation"]
    path: Nonblank
    operation: Literal["rename"]
    old_path: Nonblank
    new_path: Nonblank


@with_config(ConfigDict(strict=True, extra="forbid"))
class RequirementEvidence(TypedDict):
    kind: Literal["requirement"]
    requirement_id: Nonblank


@with_config(ConfigDict(strict=True, extra="forbid"))
class ToolEvidence(TypedDict):
    kind: Literal["tool"]
    tool_id: Nonblank
    command_index: Index


Evidence = Annotated[
    SourceEvidence
    | Inspection
    | Binary
    | RequirementEvidence
    | ToolEvidence
    | Annotated[ModeChange | Rename, Field(discriminator="operation")],
    Field(discriminator="kind"),
]
EvidenceList = Annotated[list[Evidence], Field(min_length=1)]


@with_config(ConfigDict(strict=True, extra="forbid"))
class Finding(TypedDict):
    finding_id: Nonblank
    gate_id: NotRequired[Nonblank | None]
    kind: NotRequired[Literal["missing-requirement"]]
    path: NotRequired[Nonblank | None]
    line: NotRequired[Positive | None]
    rule: Nonblank
    description: Nonblank
    fix: Nonblank
    severity: Severity
    confidence: Literal["high", "medium"]
    evidence: Annotated[list[object], Field(min_length=1)]
    investigation: NotRequired[Nonblank]


@with_config(ConfigDict(strict=True, extra="forbid"))
class LensGate(TypedDict):
    gate_id: Nonblank
    status: Literal["PASS", "FINDING", "NOT_APPLICABLE", "NOT_RUN"]
    reason: NotRequired[Nonblank]
    evidence: NotRequired[list[object]]


@with_config(ConfigDict(strict=True, extra="forbid"))
class LensResult(Identity):
    lens: Lens
    done_signal: Literal["COMPLETE"]
    gates: list[object]
    findings: list[object]


@with_config(ConfigDict(strict=True, extra="forbid"))
class Dismissal(TypedDict):
    finding_id: Nonblank
    reason: Nonblank
    evidence: EvidenceList


@with_config(ConfigDict(strict=True, extra="forbid"))
class SeverityOverride(TypedDict):
    finding_id: Nonblank
    severity: Severity
    reason: Nonblank


@with_config(ConfigDict(strict=True, extra="forbid"))
class ManualMerge(TypedDict):
    source_ids: Annotated[list[Nonblank], Field(min_length=2)]
    reason: Nonblank
    finding: Finding


@with_config(ConfigDict(strict=True, extra="forbid"))
class QA(Identity):
    code_verdict: Literal["APPROVE", "NEEDS_WORK", "RETHINK"]
    semantic_gap: NotRequired[str | None]
    notes: NotRequired[list[str]]
    added_findings: NotRequired[list[object]]
    dismissals: NotRequired[list[object]]
    severity_overrides: NotRequired[list[object]]
    manual_merges: NotRequired[list[object]]


@with_config(ConfigDict(strict=True, extra="forbid"))
class CommandResult(ReviewCommand):
    exit_code: int | None
    error: NotRequired[Nonblank | None]
    stdout_path: NotRequired[Nonblank]
    stderr_path: NotRequired[Nonblank]
    stdout_excerpt: str
    stderr_excerpt: str
    stdout_truncated: bool
    stderr_truncated: bool


@with_config(ConfigDict(strict=True, extra="forbid"))
class CompletedTool(Identity):
    tool_id: Nonblank
    status: Literal["PASS", "FAIL", "BLOCKED"]
    reason: NotRequired[None]
    commands: Annotated[list[CommandResult], Field(min_length=1)]


@with_config(ConfigDict(strict=True, extra="forbid"))
class SkippedTool(Identity):
    tool_id: Nonblank
    status: Literal["NOT_RUN", "NOT_APPLICABLE"]
    reason: Nonblank
    commands: NotRequired[Annotated[list[CommandResult], Field(max_length=0)] | None]


ToolResult = Annotated[CompletedTool | SkippedTool, Field(discriminator="status")]


@with_config(ConfigDict(strict=True, extra="forbid"))
class NormalizedFinding(Finding):
    found_by: list[Nonblank]
    source_ids: list[Nonblank]
    qa_severity_reason: NotRequired[Nonblank]
    qa_merge_reason: NotRequired[Nonblank]


@with_config(ConfigDict(strict=True, extra="forbid"))
class DismissedFinding(TypedDict):
    finding: NormalizedFinding
    dismissed_by: Literal["qa"]
    reason: Nonblank
    evidence: EvidenceList


@with_config(ConfigDict(strict=True, extra="forbid"))
class FailingCommand(CommandResult):
    tool_id: Nonblank
    command_index: Index


@with_config(ConfigDict(strict=True, extra="forbid"))
class GateCoverage(TypedDict):
    expected: list[Nonblank]
    reported: list[Nonblank]


@with_config(ConfigDict(strict=True, extra="forbid"))
class ProtocolResult(TypedDict):
    schema_version: Literal["4"] | None
    review_id: Nonblank | None
    mode: Literal["branch", "pr", "feature"] | None
    base_sha: GitHash | None
    head_sha: GitHash | None
    scope_hash: Hash | None
    pipeline_status: Literal["INCOMPLETE", "COMPLETE"]
    code_verdict: Literal["APPROVE", "NEEDS_WORK", "RETHINK"]
    semantic_gap: str | None
    findings: list[NormalizedFinding]
    dismissed_findings: list[DismissedFinding]
    tool_statuses: dict[
        str, Literal["MISSING", "PASS", "FAIL", "BLOCKED", "NOT_APPLICABLE", "NOT_RUN"]
    ]
    tool_failures: list[Nonblank]
    failing_commands: list[FailingCommand]
    gate_coverage: dict[Lens, GateCoverage]
    qa_notes: list[str]
    context_limitations: list[Nonblank]
    errors: list[Nonblank]
    done_signal: Literal["FAILED", "COMPLETE"]
    gate_result: GateResult


@with_config(ConfigDict(strict=True, extra="forbid"))
class InputLock(TypedDict):
    workspace: Nonblank
    files: dict[Nonblank, Hash | None]
    manifest_sha256: Hash


@with_config(ConfigDict(strict=True, extra="forbid"))
class ReviewSource(TypedDict):
    kind: Literal["review"]
    target: Nonblank


@with_config(ConfigDict(strict=True, extra="forbid"))
class ReviewAssignmentTask(TypedDict):
    scope: Annotated[list[Nonblank], Field(min_length=1)]


@with_config(ConfigDict(strict=True, extra="forbid"))
class ReviewAssignment(Identity):
    name: Nonblank
    lens: Lens
    source: ReviewSource
    task: ReviewAssignmentTask
    project_policy: Snapshot
    manifest: Nonblank
    context: ReviewContext
    owned_gates: dict[Nonblank, Nonblank]
    parent_evidence: list[Nonblank]
