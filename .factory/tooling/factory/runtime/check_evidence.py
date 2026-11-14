"""Validation of runner receipts against the current dispatch and files."""

from pathlib import Path

from factory.runtime.contracts import CheckResult, ExecutionReceipt, State
from factory.runtime.workflow_core import Invalid, digest, relative, require, snapshot


def check_receipts(
    root: Path,
    state: State,
    node_id: str,
    checks: list[CheckResult],
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
        parent_id = record.get("composite_parent")
        if parent_id is not None:
            parent = state["executions"].get(parent_id)
            require(
                parent is not None
                and parent["run_id"] == record["run_id"]
                and parent["node_id"] == record["node_id"]
                and parent["dispatch_id"] == record["dispatch_id"]
                and parent["status"] == "PASS"
                and record.get("mode") == "full"
                and any(
                    stage["execution_id"] == actual["execution_id"]
                    and stage["spec"] == spec
                    and stage["output"] == record["output"]
                    for stage in parent.get("composite_stages", [])
                ),
                "Invalid composite child execution provenance",
            )
            if spec["kind"] == "tests" and record["status"] == "PASS":
                selection = record.get("selection", {})
                count = selection.get("selected")
                require(
                    selection.get("mode") == "full"
                    and type(count) is int
                    and count > 0
                    and selection.get("completed") == count,
                    "Missing full test stage selection evidence",
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
            and (
                record["status"] != "PASS"
                or all(
                    record["files"][p] == record["after_files"][p]
                    for p in record["input_scope"]
                    if p not in spec["execution"].get("outputs", [])
                )
            ),
            "Runner evidence invalidated by later write",
        )
        check_output(root, record)


def check_output(root: Path, record: ExecutionReceipt) -> None:
    output = relative(root, record["output"])
    require(
        output.is_file() and digest(output.read_bytes()) == record.get("output_hash"),
        "Runner output missing or changed",
    )


def check_generated(root: Path, state: State, node_id: str, checks: list[CheckResult]) -> None:
    """An author receipt remains current on explicit generator inputs and outputs."""
    dispatch = state["nodes"][node_id]
    for check in checks:
        execution = check.get("execution", {})
        outputs = execution.get("outputs", [])
        if not outputs:
            continue
        receipt = state.get("executions", {}).get(check.get("execution_id", ""))
        require(
            receipt is not None
            and receipt["run_id"] == state["run_id"]
            and receipt["node_id"] == node_id
            and receipt["dispatch_id"] == dispatch["dispatch_id"]
            and receipt["status"] == "PASS"
            and receipt["result"] == check,
            "Generator receipt is missing or stale",
        )
        assert receipt is not None
        check_output(root, receipt)
        declared = sorted(set(execution.get("inputs", []) + outputs))
        require(
            {path: receipt["after_files"][path] for path in declared} == snapshot(root, declared),
            "Generated inputs or outputs changed after the assigned command",
        )
