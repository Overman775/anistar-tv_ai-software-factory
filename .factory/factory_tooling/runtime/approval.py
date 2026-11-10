"""Verify a narrowly scoped continuation after an external decision."""

import json
import re
from copy import deepcopy
from pathlib import Path

from factory_tooling.project.profile_rules import project_checks
from factory_tooling.runtime.check_evidence import check_receipts
from factory_tooling.runtime.contracts import Graph, Node, Report, State, Task
from factory_tooling.runtime.workflow_core import Invalid, digest, require, snapshot


def bind_request(root: Path, state: State, node: Node, task: Task, report: Report) -> None:
    request = report["approval_request"]
    require(
        node["stage"] == "verify"
        and report["outcome"] == "BLOCKED"
        and report.get("stage_result") == "APPROVAL_REQUIRED"
        and not report.get("observed_source_drift"),
        "Approval requires a current blocked verification",
    )
    action = request.get("action")
    evidence = request.get("evidence")
    files = request.get("files")
    require(
        isinstance(action, str)
        and action.strip()
        and isinstance(evidence, str)
        and evidence.strip(),
        "Approval request needs action and evidence",
    )
    require(
        isinstance(files, dict)
        and files
        and all(
            isinstance(path, str)
            and isinstance(value, str)
            and re.fullmatch(r"[0-9a-f]{64}", value)
            for path, value in files.items()
        ),
        "Approval request needs exact candidate hashes",
    )
    if not isinstance(files, dict):
        raise Invalid("Invalid approval files")
    before = report["files"]
    latest = {
        receipt["spec"]["id"]: receipt
        for receipt in state.get("executions", {}).values()
        if receipt["node_id"] == node["id"] and receipt["dispatch_id"] == report["dispatch_id"]
    }
    failed = [receipt for receipt in latest.values() if receipt["status"] != "PASS"]
    require(
        len(failed) == 1 and failed[0]["status"] == "FAIL",
        "Approval requires a single isolated failed check",
    )
    failed_id = failed[0]["spec"]["id"]
    policies = project_checks(state["config"]["_project"]["data"], all_processes=False)
    policy = next(
        (
            check
            for check in policies
            if check["id"] == failed_id and check.get("approval_action") == action
        ),
        None,
    )
    if policy is None:
        raise Invalid("Failed check does not allow this approval action")
    added = sorted(set(files) - set(task["scope"]))
    pattern = policy.get("approval_path_regex")
    require(
        all(
            pattern is not None and re.fullmatch(pattern, path)
            for path in (files if pattern is not None else added)
        ),
        "Approval candidate outside allowed scope",
    )
    preimages = snapshot(root, added)
    require(
        all(({**before, **preimages})[path] != sha for path, sha in files.items()),
        "Approval request must identify changed files",
    )
    result = failed[0].get("result")
    require(
        result is not None
        and result.get("execution_id") == request.get("execution_id")
        and result in report.get("checks", []),
        "Approval request needs the current failed check receipt",
    )
    require(
        not any(finding.get("blocking") for finding in report.get("findings", [])),
        "Approval cannot resolve a blocking finding",
    )
    deferred = {failed_id}
    while (
        downstream := {
            check["id"] for check in policies if deferred.intersection(check.get("after", []))
        }
        - deferred
    ):
        deferred.update(downstream)
    required = {check["id"] for check in task["required_checks"] if check["kind"] != "observation"}
    missing = required - latest.keys() - deferred
    require(not missing, "Missing required check before approval: " + ", ".join(sorted(missing)))

    checks = list(report["checks"])
    reported = {check.get("id") for check in checks}
    for check_id, receipt in latest.items():
        if check_id not in reported:
            current = receipt.get("result")
            if current is None:
                raise Invalid(f"Missing runner result before approval: {check_id}")
            checks.append(current)
    check_receipts(root, state, node["id"], checks, complete=False, require_pass=False)
    bound = {
        "action": action,
        "evidence": evidence,
        "files": files,
        "execution_id": request["execution_id"],
        "revision": state["revision"],
        "added_preimages": preimages,
    }
    identity = [
        report["run_id"],
        report["node_id"],
        report["dispatch_id"],
        report["source_hash"],
        before,
        bound,
    ]
    report["approval_request"] = {
        **bound,
        "id": digest(json.dumps(identity, sort_keys=True, ensure_ascii=False).encode("utf-8")),
    }


def expanded_graph(state: State, node: Node, report: Report) -> Graph:
    added = report["approval_request"].get("added_preimages", {})
    if not added:
        return state["graph"]
    require(
        not any(
            set(added) & set(task["scope"])
            for key, task in state["graph"]["tasks"].items()
            if key != node["task"]
        ),
        "Approval scope extension overlaps another task",
    )
    graph = deepcopy(state["graph"])
    graph["tasks"][node["task"]]["scope"].extend(added)
    return graph


def validate_resume(
    root: Path, state: State, node: Node, task: Task, request_id: str, evidence: str
) -> None:
    dispatch = state["nodes"][node["id"]]
    report = dispatch.get("report", {})
    request = report.get("approval_request", {})
    require(
        evidence.strip()
        and dispatch["status"] == "blocked"
        and node["stage"] == "verify"
        and report.get("outcome") == "BLOCKED"
        and report.get("stage_result") == "APPROVAL_REQUIRED"
        and request.get("id") == request_id
        and request.get("revision") == state["revision"]
        and report.get("dispatch_id") == dispatch.get("dispatch_id")
        and report.get("source_hash") == state["graph"]["sources"][task["source"]]["hash"],
        "Need current approval request and explicit authorization evidence",
    )
    require(
        snapshot(root, [*task["scope"], *request.get("added_preimages", {})])
        == {**report["files"], **request["files"]},
        "Approved files do not match the authorized candidate or other scoped files changed",
    )
