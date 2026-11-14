"""Loaded task documents preserve untrusted fields until validation completes."""

from typing import Annotated, Literal, NotRequired

from pydantic import ConfigDict, Field, StringConstraints, with_config
from typing_extensions import TypedDict

from factory.project.contracts import Hash
from factory.tasks.contracts import Criterion


class LoadedTask(TypedDict, total=False):
    id: str
    file: str
    markdown_file: str | None
    name: str
    estimate: str
    estimate_min_hours: float
    estimate_max_hours: float
    source_id: object
    acceptance_ids: object
    contributes_to_acceptance_ids: object
    local_acceptance_criteria: object
    filename: object
    title: object
    outcome: object
    scope: object
    affected_layers: object
    contract_type: object
    purpose: object
    implemented: object
    consumers: object
    research_question: object
    timebox_hours: object
    expected_result: object
    estimate_raw: object
    structural_errors: list[str]
    depends_on: object
    blocked_by: object
    parent_task: object
    deferred: object


class Envelope(TypedDict):
    file: str
    relative_file: str
    source_plan: object
    capability_coverage: object
    summary: object
    total_min_hours: object
    total_max_hours: object


class LoadResult(TypedDict):
    tasks: dict[str, LoadedTask]
    envelopes: list[Envelope]
    errors: list[str]


Text = Annotated[str, StringConstraints(pattern=r"\S")]
CapabilityId = Annotated[str, StringConstraints(pattern=r"^CAP-\d{2,}$")]
AcceptanceId = Annotated[str, StringConstraints(pattern=r"^AC-\d{2,}$")]
Hours = Annotated[int, Field(ge=0)] | Annotated[float, Field(ge=0, allow_inf_nan=False)]
PlanHash = Annotated[str, StringConstraints(pattern=r"^sha256:[0-9a-f]{64}$")]
Revision = Annotated[int, Field(gt=0)]


@with_config(ConfigDict(strict=True, extra="forbid"))
class Deferred(TypedDict):
    behavior: Text
    temporary_behavior: Text
    completed_by: Text


@with_config(ConfigDict(strict=True, extra="forbid"))
class Estimate(TypedDict):
    min_hours: Hours
    max_hours: Hours
    confidence: NotRequired[Literal["low", "medium", "high"]]


@with_config(ConfigDict(strict=True, extra="forbid"))
class RawTask(TypedDict):
    id: Text
    acceptance_ids: list[AcceptanceId]
    filename: Text
    title: Text
    purpose: Literal["functionality", "technical_preparation", "research"]
    scope: Annotated[str, StringConstraints(pattern=r"^[a-z0-9][a-z0-9_-]*$")]
    outcome: Text
    affected_layers: NotRequired[list[Text]]
    contract_type: Literal[
        "backend_api",
        "platform_plugin_api",
        "storage",
        "local_contract",
        "external_contract",
        "none",
    ]
    implemented: Annotated[list[Text], Field(min_length=1)]
    deferred: list[Deferred]
    parent_task: Text | None
    depends_on: list[Text]
    blocked_by: list[Text]
    estimate: Estimate
    consumers: NotRequired[Annotated[list[Text], Field(min_length=1)]]
    research_question: NotRequired[Text]
    timebox_hours: NotRequired[Annotated[float, Field(gt=0, allow_inf_nan=False)]]
    expected_result: NotRequired[Text]
    contributes_to_acceptance_ids: NotRequired[list[AcceptanceId]]
    local_acceptance_criteria: NotRequired[list[Criterion]]


@with_config(ConfigDict(strict=True, extra="forbid"))
class SourcePlan(TypedDict):
    plan_id: Text
    revision: Revision
    hash: PlanHash


@with_config(ConfigDict(strict=True, extra="forbid"))
class Coverage(TypedDict):
    capability_id: CapabilityId
    coverage: Literal["complete", "external", "out_of_scope"]
    task_ids: list[Text]
    reason: NotRequired[Text]


@with_config(ConfigDict(strict=True, extra="forbid"))
class TaskEnvelope(TypedDict):
    source_plan: SourcePlan
    capability_coverage: list[Coverage]
    summary: Text
    total_min_hours: Hours
    total_max_hours: Hours
    tasks: Annotated[list[RawTask], Field(min_length=1)]


@with_config(ConfigDict(strict=True, extra="forbid"))
class SourceLock(TypedDict):
    plan_id: Text
    plan_revision: Revision
    plan_hash: PlanHash
    plan_content_hash: PlanHash
    plan_path: Text
    plan_commit: NotRequired[
        Annotated[str, StringConstraints(pattern=r"^(?:[0-9a-f]{40}|[0-9a-f]{64})$")] | None
    ]
    capability_ids: Annotated[list[CapabilityId], Field(min_length=1)]
    acceptance_ids: Annotated[list[AcceptanceId], Field(min_length=1)]
    project_policy_sha256: NotRequired[Hash]
