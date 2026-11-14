"""Validated task declarations and partial policy selections."""

from typing import Annotated, Literal, NotRequired

from pydantic import ConfigDict, Field, StringConstraints, with_config
from typing_extensions import TypedDict

from factory.checks.contracts import CheckSpec
from factory.decisions.decision_contract import Estimate

Nonblank = Annotated[str, StringConstraints(pattern=r"\S")]


@with_config(ConfigDict(strict=True, extra="forbid"))
class Criterion(TypedDict):
    id: Annotated[str, StringConstraints(pattern=r"^AC-\d{2,}$")]
    applies_to: Nonblank
    requirement: Nonblank
    verification: Nonblank


TaskScope = Annotated[list[Nonblank], Field(min_length=1)]


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
class TaskSelection(TypedDict, total=False):
    scope: TaskScope
    required_checks: list[CheckSpec]
    policy_decisions: dict[str, Estimate]
