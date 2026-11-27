"""Prepare and validate worker reports and commit their evidence with the terminal transition."""

from __future__ import annotations

from factory.runtime.commands.evidence import active_commands, check_receipts
from factory.runtime.contracts import Node, Report, ReportDraft
from factory.runtime.history import report_history
from factory.runtime.history.artifact_ref import Artifact
from factory.runtime.history.document import render
from factory.runtime.knowledge import case_search
from factory.runtime.packets.content import packet_confirmed
from factory.runtime.reports import (
    acceptance,
    finish_requirements,
    review_findings,
    role_material,
    write_handoff,
)
from factory.runtime.run_journal import RunJournal
from factory.runtime.scheduling import report_graph
from factory.runtime.scheduling.attempt_graph import advance
from factory.runtime.state_io import parse_report, parse_report_draft
from factory.runtime.workflow_config import check_config
from factory.runtime.workflow_core import (
    Invalid,
    acceptance_guard,
    graph_identity,
    require,
    snapshot,
)
from factory.runtime.workflow_graph import overlaps
from factory.tasks.contracts import Task


def report_scope(
    node: Node, task: Task, report: Report | ReportDraft, deferred_writer: bool
) -> list[str]:
    """Narrow only an intermediate handoff with explicitly bounded inputs."""
    if (
        deferred_writer
        and report.get("outcome") == "PASS"
        and report.get("stage_result") in {"WRITES_READY", "DOCS_UPDATED"}
        and node.get("owns")
        and "handoff_inputs" in node
    ):
        return sorted(
            {p for p in task["scope"] if overlaps([p], node["owns"])} | set(node["handoff_inputs"])
        )
    return task["scope"]


def prepare_report(
    journal: RunJournal,
    node_id: str,
    draft: object,
    receipt_ids: list[str],
    *,
    submit: bool = False,
) -> Report:
    """Capture the author's evidence at handoff for its exact running dispatch."""
    with journal.locked(wait=submit):
        state = journal.read()
        node = next((n for n in state["graph"]["nodes"] if n["id"] == node_id), None)
        if node is None or node_id not in state["nodes"]:
            raise Invalid("Unknown report node")
        dispatch_id = state["nodes"][node_id].get("dispatch_id")
        if isinstance(draft, dict):
            if (
                dispatch_id is not None
                and draft.get("run_id") == state["run_id"]
                and draft.get("node_id") == node_id
                and draft.get("dispatch_id") == dispatch_id
            ):
                journal.diagnostic_attempt = (node_id, dispatch_id)
            require("files" not in draft, "Existing evidence cannot be refreshed")
        report = parse_report_draft(draft)
        report.pop("observed_source_drift", None)
        checks = report.get("checks", [])
        draft_checks = checks
        current = state["nodes"][node_id]
        task = state["graph"]["tasks"][node["task"]]
        require(len(set(receipt_ids)) == len(receipt_ids), "Duplicate receipt")
        request_id = graph_identity([report, sorted(receipt_ids)])
        previous = current.get("submission")
        if submit and previous is not None and previous["request_id"] == request_id:
            return parse_report(
                journal.runs.read_input(journal.root, "submission", previous["report_id"])
            )
        require(
            state["status"] == "active" and current["status"] == "running",
            "Report needs a bound running node",
        )
        require(
            report.get("run_id") == state["run_id"]
            and report.get("dispatch_id") == current["dispatch_id"]
            and report.get("source_hash") == state["graph"]["sources"][task["source"]]["hash"]
            and report.get("node_id") == node_id
            and report.get("task_id", node["task"]) == node["task"]
            and report.get("slice_id", task["slice"]) == task["slice"],
            "Stale report identity",
        )
        outcome = report["outcome"]
        require_pass = outcome == "PASS"
        selected_ids = list(receipt_ids)
        selected_checks = {check["id"] for check in checks}
        selected_checks.update(
            record["spec"]["id"]
            for receipt_id in receipt_ids
            if (record := state.get("executions", {}).get(receipt_id)) is not None
        )
        for receipt_id in receipt_ids:
            parent = state.get("executions", {}).get(receipt_id)
            if parent is not None:
                for stage in parent.get("composite_stages", []):
                    child_id = stage["execution_id"]
                    if (
                        child_id in state["executions"]
                        and stage["spec"]["id"] not in selected_checks
                    ):
                        selected_ids.append(child_id)
                        selected_checks.add(stage["spec"]["id"])
        obligations = finish_requirements.for_node(state, node)
        for receipt_id in selected_ids:
            record = state.get("executions", {}).get(receipt_id)
            if record is None or record.get("result") is None:
                raise Invalid("Unknown or incomplete receipt")
            require(record["result"].get("execution_id") == receipt_id, "Receipt ID mismatch")

            require(record["spec"] in obligations["allowed_checks"], "Receipt is not assigned")
            check_receipts(
                journal.root,
                state,
                node_id,
                [record["result"]],
                complete=False,
                require_pass=require_pass,
            )
            require(
                not any(check.get("id") == record["result"]["id"] for check in checks),
                "Selected receipt duplicates a draft check",
            )
            checks = [*checks, record["result"]]
        check_receipts(
            journal.root, state, node_id, draft_checks, complete=False, require_pass=require_pass
        )
        acceptance_guard(finish_requirements.validate_selection, obligations, checks)
        result = parse_report(
            {
                **report,
                "task_id": node["task"],
                "slice_id": task["slice"],
                "checks": checks,
                "files": snapshot(
                    journal.root,
                    report_scope(
                        node,
                        task,
                        report,
                        obligations["require_writes_ready"] or current.get("role") == "doc-writer",
                    ),
                ),
            }
        )
        acceptance_guard(
            finish_requirements.validate_tester_outcome, state, node, obligations, result
        )
        if require_pass:
            acceptance_guard(finish_requirements.validate_pass, obligations, result)
            if current.get("role") == "implementer" and node.get("owns"):
                write_handoff.validate(journal.root, state, node, current, result)
        role_material.validate(journal.root, state, node, current, result)
        journal.source_drifted(state, task, outcome)
        if submit:
            report_id = graph_identity(["submission", result])
            current["submission"] = {"request_id": request_id, "report_id": report_id}
            path = f".factory/memory/history/{state['run_id']}/submissions/{report_id}.md"
            artifact = Artifact(
                path, "submission", render(result), node_id, current["dispatch_id"], document=result
            )
            journal.save_artifacts(
                state,
                "report_submitted",
                (artifact,),
                node=node_id,
                dispatch_id=current["dispatch_id"],
                result=report_id,
            )
        return result


def finish(journal: RunJournal, node_id: str, raw: object) -> None:
    # Runtime facts are derived from current evidence.
    if isinstance(raw, dict):
        raw = {
            key: value
            for key, value in raw.items()
            if key not in {"gate_results", "observed_source_drift"}
        }
    report = parse_report(raw)
    with journal.locked():
        s = journal.read()
        n = next(n for n in s["graph"]["nodes"] if n["id"] == node_id)
        v, task = s["nodes"][node_id], s["graph"]["tasks"][n["task"]]
        submission_key = graph_identity(["terminal", report])
        if v.get("terminal_input") == submission_key:
            return
        require(v["status"] == "running", "Cannot finish unbound/unknown work")
        require(
            not any(r["node_id"] == node_id for r in active_commands(s).values()),
            "Unresolved command result not passed; reconcile execution before finish",
        )
        src = s["graph"]["sources"][task["source"]]
        require(
            report.get("run_id") == s["run_id"]
            and report.get("dispatch_id") == v["dispatch_id"]
            and report.get("source_hash") == src["hash"]
            and report.get("node_id") == node_id
            and report.get("task_id") == n["task"]
            and report.get("slice_id") == task["slice"],
            "Stale report identity",
        )
        journal.diagnostic_attempt = (node_id, v["dispatch_id"])
        if submission := v.get("submission"):
            require(
                submission["report_id"] == graph_identity(["submission", report]),
                "Superseded report submission",
            )
        outcome = report["outcome"]
        if outcome == "PASS":
            for case in report.get("applied_cases", []):
                case_search.verified_case(journal.root, case["report_ref"], history=journal.history)
            require(
                "packet_receipt" not in v or packet_confirmed(v),
                "Confirm native packet before finishing successful work",
            )
            check_config(s)
        acceptance_guard(review_findings.consistent, report, n["stage"] == "review")
        if journal.source_drifted(s, task, outcome):
            report["observed_source_drift"] = True
        obligations = finish_requirements.for_node(s, n)
        scope = report_scope(
            n, task, report, obligations["require_writes_ready"] or v.get("role") == "doc-writer"
        )
        # A full handoff may also cover unowned task files, but never omit declared inputs.
        full_scope = set(task["scope"]) | set(scope)
        if set(report["files"]) == full_scope:
            scope = sorted(full_scope)
        require(
            report.get("files") == snapshot(journal.root, scope),
            "Stale/incomplete file evidence",
        )
        checks = report.get("checks", [])
        findings = report.get("findings", [])
        if outcome == "PASS" and n["stage"] not in {"verify", "review"}:
            for finding in findings:
                require(
                    "blocking" in finding,
                    "Untyped finding",
                )
                require(
                    not finding["blocking"] or finding.get("status") in {"fixed", "dismissed"},
                    "Open blocking finding",
                )
                if finding.get("status") in {"fixed", "dismissed"}:
                    require(finding.get("evidence"), "Finding resolution needs evidence")
        if checks:
            if any(c.get("kind") in {"tests", "static", "build", "codegen"} for c in checks):
                require(
                    "project-checks" in n.get("resources", []),
                    "Command executed without project-checks reservation",
                )
            if outcome == "PASS":
                require(
                    all(acceptance.successful(c) or acceptance.resolved_extra(c) for c in checks),
                    "Failed/incomplete command evidence",
                )
        acceptance_guard(finish_requirements.validate_selection, obligations, checks)
        acceptance_guard(finish_requirements.validate_tester_outcome, s, n, obligations, report)
        if outcome == "PASS":
            acceptance_guard(finish_requirements.validate_pass, obligations, report)
        check_receipts(
            journal.root, s, node_id, checks, complete=False, require_pass=outcome == "PASS"
        )
        if outcome == "PASS" and v.get("role") == "implementer" and n.get("owns"):
            write_handoff.validate(journal.root, s, n, v, report)
        role_material.validate(journal.root, s, n, v, report)
        acceptance_guard(review_findings.check_assessments, s, n, report)
        verdict = report_graph.evaluate(report_graph.Handoff(journal.root, s, n, task, report))
        unsuccessful = report.get("unsuccessful_attempt")
        if unsuccessful is not None:
            require(
                outcome == "FAIL" and report.get("stage_result") in {"FAIL_CODE", "FAIL_TEST"},
                "Unsuccessful attempt needs actual work, an unmet requirement and evidence",
            )
        report_ref, original = report_history.prepare(s, v, report)
        s.setdefault("report_hashes", {})[report_ref["path"]] = report_ref["sha256"]
        s.setdefault("report_index", {})[v["dispatch_id"]] = report_ref
        v.update(
            {
                "status": advance(v, verdict.action),
                "terminal_input": submission_key,
                "report": report,
                "report_ref": report_ref,
            }
        )
        journal.save_artifacts(
            s,
            "finished",
            (original,),
            node=node_id,
            dispatch_id=v["dispatch_id"],
            outcome=outcome,
            decision=verdict.route,
            reason=report["summary"],
        )
