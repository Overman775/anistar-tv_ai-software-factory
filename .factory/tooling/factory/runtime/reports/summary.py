"""Select receipt-backed verification facts for a worker handoff."""

from collections import defaultdict
from copy import deepcopy

from pydantic import TypeAdapter

from factory.runtime.commands.verification import Verification
from factory.runtime.contracts import CheckEvidence, CheckResult, Dispatch, ReportSummary, State

REPORT_SUMMARY = TypeAdapter[ReportSummary](ReportSummary)


def unchanged_readiness(dispatch: Dispatch) -> bool:
    baseline = dispatch.get("initial_owned_files")
    report = dispatch.get("report")
    return bool(
        dispatch.get("attempt") == 1
        and baseline
        and report
        and report["outcome"] == "PASS"
        and report["stage_result"] == "WRITES_READY"
        and all(report["files"].get(path) == sha for path, sha in baseline.items())
    )


def initial_review_facts(report: ReportSummary) -> ReportSummary:
    """Keep verifiable delivery facts; the author's original remains accessible by its reference."""
    facts: ReportSummary = {
        "run_id": report["run_id"],
        "dispatch_id": report["dispatch_id"],
        "node_id": report["node_id"],
        "source_hash": report["source_hash"],
        "terminal": True,
        "outcome": report["outcome"],
        "summary": "Existing candidate submitted for independent assessment",
        "stage_result": report["stage_result"],
        "task_id": report["task_id"],
        "slice_id": report["slice_id"],
        "checks": report["checks"],
    }
    if "verification" in report:
        facts["verification"] = report["verification"]
    return facts


def compact_tester_report(state: State, node_id: str, report: ReportSummary) -> ReportSummary:
    """Delivery projection only; original reports and immutable references stay intact."""
    result = deepcopy(report)
    result["summary"] = "Verification " + report["outcome"]
    result.pop("evidence", None)
    # Canonical findings and gate prose remain available through report_ref; their
    # duplicated free text can contain successful test names and full-suite output.
    result.pop("gate_results", None)
    result.pop("findings", None)
    checks: list[CheckResult] = []
    observations: list[Verification] = []
    for check in report["checks"]:
        execution_id = check.get("execution_id")
        receipt = state.get("executions", {}).get(execution_id or "")
        linked = (
            receipt is not None
            and receipt["node_id"] == node_id
            and receipt["dispatch_id"] == report["dispatch_id"]
            and receipt["run_id"] == report["run_id"]
            and receipt["spec"]["id"] == check["id"]
        )
        status = (
            receipt["status"] if linked and receipt is not None else check.get("result", "BLOCKED")
        )
        if linked and receipt is not None:
            for observation in receipt.get("verification", []):
                observed = deepcopy(observation)
                if observed["scope"] == "unknown":
                    observed["scope"] = receipt.get("selection", {}).get(
                        "mode", receipt.get("mode", "unknown")
                    )
                for failure in observed["failures"]:
                    failure["check_id"] = check["id"]
                observations.append(observed)
            skipped_stages = [
                stage["spec"]["id"]
                for stage in receipt.get("composite_stages", [])
                if stage["execution_id"] not in state.get("executions", {})
            ]
            if skipped_stages:
                observations.append(
                    {
                        "suite": "combined-gate",
                        "scope": receipt.get("mode", "unknown"),
                        "phase": "not-executed",
                        "result": "BLOCKED",
                        "counts": {},
                        "failures": [],
                        "diagnostics": ["Not executed checks: " + ", ".join(skipped_stages)],
                    }
                )
        if status == "PASS":
            continue
        compact: CheckEvidence = {
            "id": check["id"],
            "result": status,
            "reason": "Structured diagnostics unavailable; inspect immutable report/check evidence",
        }
        if linked and receipt is not None:
            compact["evidence"] = receipt["output"]
            compact["execution_id"] = execution_id or ""
            if receipt.get("error"):
                compact["reason"] = receipt["error"] or ""
        elif not execution_id and check.get("kind") in {None, "observation"}:
            observation_evidence = check.get("evidence", "").strip()
            if observation_evidence:
                compact.pop("reason", None)
                compact["evidence"] = observation_evidence
                if check.get("kind") == "observation":
                    compact["kind"] = "observation"
        checks.append(compact)
    groups: dict[str, list[Verification]] = defaultdict(list)
    for observation in observations:
        groups[observation["scope"]].append(observation)
    result["verification"] = [scope_summary(scope, items) for scope, items in groups.items()] or [
        {
            "suite": "overall",
            "scope": "unknown",
            "phase": "verify",
            "result": report["outcome"],
            "counts": {},
            "failures": [],
            "diagnostics": [
                "Structured diagnostics unavailable; inspect immutable report/check evidence"
            ]
            + (
                [
                    "Unstructured reporter observation: "
                    + (report.get("evidence") or report["summary"])[:500]
                ]
                if report["outcome"] != "PASS"
                else []
            ),
        }
    ]
    result["checks"] = checks
    return result


def scope_summary(scope: str, observations: list[Verification]) -> Verification:
    counts: dict[str, int] = {}
    for item in observations:
        for key, value in item["counts"].items():
            counts[key] = counts.get(key, 0) + value
    statuses = {item["result"] for item in observations}
    return {
        "suite": "overall",
        "scope": scope,
        "phase": "verify",
        "result": "FAIL" if "FAIL" in statuses else "BLOCKED" if "BLOCKED" in statuses else "PASS",
        "counts": counts,
        "failures": [failure for item in observations for failure in item["failures"]],
        "diagnostics": [
            text
            for item in observations
            if item["result"] != "PASS"
            for text in item["diagnostics"]
        ],
    }
