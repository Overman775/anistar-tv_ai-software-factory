"""Publish typed inputs for a later orchestrator command in the same checkout."""

from copy import deepcopy
from pathlib import Path
from typing import Literal, NotRequired

from pydantic import ConfigDict, TypeAdapter, with_config
from typing_extensions import TypedDict

from factory import file_reader
from factory.database.provider import current_database
from factory.runtime import upstream
from factory.runtime.contracts import Agent, Node, Report, ReportDraft, Source
from factory.runtime.lessons import Lesson
from factory.runtime.scheduling.escalation import CORRECTION_REQUEST, CorrectionRequest
from factory.runtime.state_io import parse_report, parse_report_draft
from factory.runtime.workflow_core import relative, require
from factory.tasks.contracts import Task


@with_config(ConfigDict(strict=True, extra="forbid"))
class ProposedTask(Task, total=False):
    project_check_inputs: dict[str, list[str]]


@with_config(ConfigDict(strict=True, extra="forbid"))
class ProposedGraph(TypedDict):
    sources: dict[str, Source]
    tasks: dict[str, ProposedTask]
    agents: dict[str, Agent]
    nodes: list[Node]
    after_archive: NotRequired[Literal["teacher"]]


PROPOSAL = TypeAdapter[ProposedGraph](ProposedGraph)


def propose(root: Path, graph: ProposedGraph) -> str:
    """Publish a graph proposal. Validation against the selected workspace occurs at intake."""
    return current_database().runs.publish_input(
        root.resolve(), "plan", PROPOSAL.validate_python(graph)
    )


def draft_report(root: Path, draft: ReportDraft) -> str:
    return current_database().runs.publish_input(root.resolve(), "draft", parse_report_draft(draft))


def propose_plan(
    root: Path,
    execution: ProposedGraph,
    source_id: str,
    plan: str,
    *,
    decomposition_run: str | None = None,
    scope: str | list[str] = "all",
    selected_acceptance_ids: list[str] | None = None,
    directive: str | None = None,
) -> str:
    """Add the approved source and its optional Decompose envelopes to the execution design."""
    graph = deepcopy(execution)
    source = upstream.approved_plan(root, plan, scope)
    if selected_acceptance_ids is not None:
        source["selected_acceptance_ids"] = selected_acceptance_ids
    if directive is not None:
        source["directive"] = directive
    graph["sources"][source_id] = source
    if decomposition_run is not None:
        inherited = upstream.decomposition(
            root, file_reader.read_text(relative(root, plan), encoding="utf-8"), decomposition_run
        )
        source["decomposition_run"], source["upstream_tasks"] = decomposition_run, inherited
        accepts = {node["task"]: node["id"] for node in graph["nodes"] if node["stage"] == "accept"}
        missing = inherited.keys() - graph["tasks"].keys()
        if graph["nodes"]:
            missing |= inherited.keys() - accepts.keys()
        require(not missing, f"Missing execution design for decomposed tasks: {sorted(missing)}")
        for key, original in inherited.items():
            task = graph["tasks"][key]
            task["source"] = source_id
            task["outcome"] = original["outcome"]
            task["acceptance_ids"] = original["acceptance_ids"]
            task["parent_plan_ref"] = plan
            task["contributes_to_acceptance_ids"] = original["contributes_to_acceptance_ids"]
            task["local_acceptance_criteria"] = original["local_acceptance_criteria"]
            task["depends_on"] = list(
                dict.fromkeys([*task.get("depends_on", []), *original["depends_on"]])
            )
            for node in graph["nodes"]:
                if node["task"] == key:
                    node["depends_on"] = list(
                        dict.fromkeys(
                            [*node["depends_on"], *(accepts[dep] for dep in original["depends_on"])]
                        )
                    )
    return propose(root, graph)


def publish_report(root: Path, report: Report) -> str:
    return current_database().runs.publish_input(root.resolve(), "submission", parse_report(report))


def propose_correction(root: Path, request: CorrectionRequest) -> str:
    return current_database().runs.publish_input(
        root.resolve(), "correction", CORRECTION_REQUEST.validate_python(request)
    )


def propose_lesson(root: Path, card: Lesson) -> str:
    """Publish a Teacher-authored card for the coordinator's event and revision checks."""
    return current_database().runs.publish_input(
        root.resolve(), "lesson", card.model_dump(exclude_unset=True)
    )
