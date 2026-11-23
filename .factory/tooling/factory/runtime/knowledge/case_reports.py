"""Find current accepted reports in terminal archives from this checkout."""

from collections.abc import Iterator
from dataclasses import dataclass
from pathlib import Path

from factory.database.provider import current_database
from factory.paths import MEMORY as BASE
from factory.runtime.contracts import LedgerEvent, Report, ReportRef, State
from factory.runtime.history import report_history
from factory.runtime.history.history_repository import HistoryRepository
from factory.runtime.workflow_core import Invalid, relative, require
from factory.runtime.workspace import checkout_ref


@dataclass(frozen=True)
class AcceptedReport:
    report: Report
    ref: ReportRef
    attempt: int
    incident: str
    title: str
    checkout: str | None

    def verify(self, root: Path, *, history: HistoryRepository | None = None) -> None:
        path = self.ref["path"]
        require(
            path.startswith(f"{BASE}/history/{self.ref['run_id']}/reports/"),
            "Archived report path has the wrong owner",
        )
        relative(root, path)
        body = report_history.read(root, self.ref, history=history)
        require(body["report"] == self.report, "Archived report differs from accepted ledger")


def _acceptances(state: State, branch: str | None) -> dict[str, LedgerEvent]:
    by_node = {
        event["node"]: event
        for event in state["events"]
        if event["event"] == "accepted" and "node" in event
    }
    return {
        node["task"]: event
        for node in state["graph"]["nodes"]
        if node["stage"] == "accept"
        and (event := by_node.get(node["id"])) is not None
        and "lesson_checkout" in event
        and event["lesson_checkout"] == branch
        and "lesson_reports" in event
        and (current := state["nodes"].get(node["id"])) is not None
        and current["status"] == "done"
        and current.get("gate_result", {}).get("status") == "PASS"
    }


def accepted_reports(root: Path, state: State, branch: str | None) -> Iterator[AcceptedReport]:
    if state["workspace"] != str(root):
        return
    accepted = _acceptances(state, branch)
    for node in state["graph"]["nodes"]:
        event = accepted.get(node["task"])
        current = state["nodes"].get(node["id"])
        task = state["graph"]["tasks"].get(node["task"])
        if event is None or task is None or current is None or current["status"] != "done":
            continue
        report, ref = current.get("report"), current.get("report_ref")
        if (
            report is None
            or report["outcome"] != "PASS"
            or report["terminal"] is not True
            or report["task_id"] != node["task"]
            or ref is None
            or ref["run_id"] != state["run_id"]
            or ref["node_id"] != node["id"]
            or ref["dispatch_id"] != current.get("dispatch_id")
            or ref != state.get("report_index", {}).get(ref["dispatch_id"])
            or ref not in event.get("lesson_reports", [])
            or ref["sha256"] != state.get("report_hashes", {}).get(ref["path"])
            or current["attempt"] < 1
        ):
            continue
        yield AcceptedReport(
            report,
            ref,
            current["attempt"],
            event.get("lesson_incident", f"{state['run_id']}/{event['node']}"),
            task["outcome"],
            branch,
        )


def verified_case(
    root: Path, raw: object, *, history: HistoryRepository | None = None
) -> AcceptedReport:
    history = current_database().history if history is None else history
    root = root.resolve()
    ref = report_history.reference(raw)
    state = history.archived_state(root, ref["run_id"])
    require(history.visible(root, ref["run_id"], state["workspace"]), "Foreign history workspace")
    for case in accepted_reports(Path(state["workspace"]), state, checkout_ref(root)):
        if case.ref == ref:
            case.verify(root, history=history)
            return case
    raise Invalid("Report is not current accepted evidence in this checkout")
