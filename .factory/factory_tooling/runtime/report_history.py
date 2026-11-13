"""Immutable terminal report and assignment references."""

import json
from pathlib import Path

from factory_tooling.runtime.contracts import Dispatch, Node, Report, State, agent_key
from factory_tooling.runtime.memory import read_evidence
from factory_tooling.runtime.workflow_core import atomic_json, digest, relative, require


def identity(value: object) -> str:
    return digest(json.dumps(value, sort_keys=True, ensure_ascii=False).encode())


def assignment(state: State, node: Node, requirements: object) -> dict[str, object]:
    task = state["graph"]["tasks"][node["task"]]
    source = state["graph"]["sources"][task["source"]]
    return {
        "task": task,
        "source": source,
        "node": node,
        "requirements": requirements,
        "agent": state["graph"]["agents"][agent_key(node)],
        "policy_hash": state["config"]["_project"]["hash"],
    }


def store(root: Path, state: State, dispatch: Dispatch, report: Report) -> dict[str, str]:
    body = {"assignment": dispatch["assignment"], "report": report}
    checksum = identity(body)
    name = (
        f".factory/memory/history/{state['run_id']}/reports/"
        f"{report['node_id']}-{report['dispatch_id']}-{checksum}.json"
    )
    path = relative(root, name)
    if not path.exists():
        atomic_json(path, body)
    ref = {
        "run_id": state["run_id"],
        "node_id": report["node_id"],
        "dispatch_id": report["dispatch_id"],
        "path": name,
        "sha256": digest(path.read_bytes()),
        "content_identity": checksum,
    }
    read(root, ref)
    return ref


def read(root: Path, ref: dict[str, str]) -> dict[str, object]:
    data = read_evidence(root, ref["path"], run_id=ref["run_id"])
    body = json.loads(data)
    require(
        digest(data) == ref["sha256"]
        and identity(body) == ref["content_identity"]
        and body["report"]["run_id"] == ref["run_id"]
        and body["report"]["node_id"] == ref["node_id"]
        and body["report"]["dispatch_id"] == ref["dispatch_id"],
        "Report reference digest or dispatch mismatch",
    )
    return dict(body)


def historical(root: Path, state: State, node_id: str, dispatch_id: str) -> dict[str, object]:
    ref = state.get("report_index", {}).get(dispatch_id)
    require(ref is not None and ref["node_id"] == node_id, "Unknown historical dispatch")
    assert ref is not None
    return read(root, ref)
