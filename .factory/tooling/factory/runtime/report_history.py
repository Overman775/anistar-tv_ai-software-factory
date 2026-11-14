"""Immutable terminal report and assignment references."""

import json
from pathlib import Path

from pydantic import ConfigDict, TypeAdapter, ValidationError, with_config
from typing_extensions import TypedDict

from factory.runtime.contracts import (
    Assignment,
    Dispatch,
    Node,
    Report,
    ReportRef,
    State,
    agent_key,
)
from factory.runtime.finish_requirements import FinishRequirements
from factory.runtime.memory import read_evidence
from factory.runtime.workflow_core import Invalid, atomic_json, digest, relative, require
from factory.validation import validation_message


@with_config(ConfigDict(strict=True, extra="forbid"))
class HistoricalReport(TypedDict):
    assignment: Assignment
    report: Report


ASSIGNMENT = TypeAdapter[Assignment](Assignment)
HISTORY = TypeAdapter[HistoricalReport](HistoricalReport)
REFERENCE = TypeAdapter[ReportRef](ReportRef)


def validated_body(value: object) -> HistoricalReport:
    try:
        body = HISTORY.validate_python(value)
    except ValidationError as exc:
        raise Invalid(validation_message("Invalid historical report", exc, HISTORY)) from None
    return body


def identity(value: object) -> str:
    return digest(json.dumps(value, sort_keys=True, ensure_ascii=False).encode())


def assignment(state: State, node: Node, requirements: FinishRequirements) -> Assignment:
    task = state["graph"]["tasks"][node["task"]]
    source = state["graph"]["sources"][task["source"]]
    return ASSIGNMENT.validate_python(
        {
            "task": task,
            "source": source,
            "node": node,
            "requirements": requirements,
            "agent": state["graph"]["agents"][agent_key(node)],
            "policy_hash": state["config"]["_project"]["hash"],
        }
    )


def store(root: Path, state: State, dispatch: Dispatch, report: Report) -> ReportRef:
    body = validated_body({"assignment": dispatch["assignment"], "report": report})
    checksum = identity(body)
    name = (
        f".factory/memory/history/{state['run_id']}/reports/"
        f"{report['node_id']}-{report['dispatch_id']}-{checksum}.json"
    )
    path = relative(root, name)
    if not path.exists():
        atomic_json(path, body)
    ref: ReportRef = {
        "run_id": state["run_id"],
        "node_id": report["node_id"],
        "dispatch_id": report["dispatch_id"],
        "path": name,
        "sha256": digest(path.read_bytes()),
        "content_identity": checksum,
    }
    read(root, ref)
    return ref


def read(root: Path, raw: object) -> HistoricalReport:
    try:
        ref = REFERENCE.validate_python(raw)
    except ValidationError as exc:
        raise Invalid(validation_message("Invalid report reference", exc, REFERENCE)) from None
    data = read_evidence(root, ref["path"], run_id=ref["run_id"])
    require(digest(data) == ref["sha256"], "Report reference digest mismatch")
    original: object = json.loads(data)
    require(identity(original) == ref["content_identity"], "Report content identity mismatch")
    body = validated_body(original)
    report = body["report"]
    assignment_data = body["assignment"]
    require(
        report["run_id"] == ref["run_id"]
        and report["node_id"] == ref["node_id"] == assignment_data["node"]["id"]
        and report["dispatch_id"] == ref["dispatch_id"]
        and report["task_id"] == assignment_data["node"]["task"]
        and report["slice_id"] == assignment_data["task"]["slice"]
        and report["source_hash"] == assignment_data["source"]["hash"],
        "Report reference or assignment identity mismatch",
    )
    return body


def historical(root: Path, state: State, node_id: str, dispatch_id: str) -> HistoricalReport:
    ref = state.get("report_index", {}).get(dispatch_id)
    require(
        ref is not None
        and ref["node_id"] == node_id
        and ref["dispatch_id"] == dispatch_id
        and ref["run_id"] == state["run_id"],
        "Unknown historical dispatch",
    )
    assert ref is not None
    return read(root, ref)
