"""Validation of runner receipts against the current dispatch and files."""

from pathlib import Path

from factory_tooling.runtime.contracts import Check, State
from factory_tooling.runtime.workflow_core import Invalid, digest, relative, require, snapshot


def check_receipts(
    root: Path,
    state: State,
    node_id: str,
    checks: list[Check],
    *,
    complete: bool = True,
    require_pass: bool = True,
) -> None:
    n = next(n for n in state["graph"]["nodes"] if n["id"] == node_id)
    task = state["graph"]["tasks"][n["task"]]
    v = state["nodes"][node_id]
    for spec in task["required_checks"]:
        if spec["kind"] == "observation":
            continue
        actual = next((c for c in checks if c.get("id") == spec["id"]), None)
        if actual is None and not complete:
            continue
        if not (actual is not None):
            raise Invalid("Missing required check result")
        if not (isinstance(actual.get("execution_id"), str)):
            raise Invalid("Required command has no runner receipt")
        record = state.get("executions", {}).get(actual["execution_id"])
        if not (record is not None):
            raise Invalid("Required command has no runner receipt")
        require(
            record["run_id"] == state["run_id"]
            and record["node_id"] == node_id
            and record["dispatch_id"] == v["dispatch_id"]
            and record["spec"] == spec
            and record["source_hash"] == state["graph"]["sources"][task["source"]]["hash"],
            "Stale or mismatched runner receipt",
        )
        same_check = [
            r
            for r in state["executions"].values()
            if r["node_id"] == node_id
            and r["dispatch_id"] == v["dispatch_id"]
            and r["spec"]["id"] == spec["id"]
        ]
        require(
            same_check[-1] is record,
            "A later command attempt superseded this receipt",
        )
        require(
            record["status"] in ({"PASS"} if require_pass else {"PASS", "FAIL", "BLOCKED"})
            and actual == record.get("result"),
            "Runner result changed or not passed",
        )
        require(
            record["after_files"] == snapshot(root, record["input_scope"])
            and (record["status"] != "PASS" or record["files"] == record["after_files"]),
            "Runner evidence invalidated by later write",
        )
        output = relative(root, record["output"])
        require(
            output.is_file() and digest(output.read_bytes()) == record["output_hash"],
            "Runner output missing or changed",
        )
