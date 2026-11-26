"""Select receipt-backed verification facts for a worker handoff."""

from copy import deepcopy

from pydantic import TypeAdapter

from factory.runtime.contracts import CheckEvidence, CheckResult, ReportSummary, State

REPORT_SUMMARY = TypeAdapter[ReportSummary](ReportSummary)


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
    observations = []
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
        checks.append(compact)
    counts: dict[str, int] = {}
    for observation in observations:
        for key, value in observation["counts"].items():
            counts[key] = counts.get(key, 0) + value
    scopes = {item["scope"] for item in observations}
    result["verification"] = [
        {
            "suite": "overall",
            "scope": next(iter(scopes)) if len(scopes) == 1 else "unknown",
            "phase": "verify",
            "result": result["outcome"],
            "counts": counts,
            "failures": [failure for item in observations for failure in item["failures"]],
            "diagnostics": [
                text
                for item in observations
                if item["result"] != "PASS"
                for text in item["diagnostics"]
            ]
            or (
                [
                    "Structured diagnostics unavailable; inspect immutable report/check evidence",
                    *(
                        [
                            "Unstructured reporter observation: "
                            + (report.get("evidence") or report["summary"])[:500]
                        ]
                        if report["outcome"] != "PASS"
                        else []
                    ),
                ]
                if not observations
                else []
            ),
        }
    ]
    result["checks"] = checks
    return result
