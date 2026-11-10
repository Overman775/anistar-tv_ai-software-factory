"""Loaded task documents preserve untrusted fields until validation completes."""

from typing import TypedDict


class LoadedTask(TypedDict, total=False):
    id: str
    file: str
    markdown_file: str | None
    name: str
    estimate: str
    estimate_min_hours: float
    estimate_max_hours: float
    raw_presence: dict[str, bool]
    raw_values: dict[str, object]
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
    estimate_confidence: object
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
