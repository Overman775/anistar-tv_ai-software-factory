"""Revise the graph and refresh authorized source documents, preserving work and retry history."""

from __future__ import annotations

import time
from copy import deepcopy
from pathlib import Path
from typing import NamedTuple

from factory import file_reader
from factory.context.context import accepted_bytes, accepted_path
from factory.decisions.decision_contract import preserve_obligations
from factory.project.profile_io import load_profile
from factory.runtime.commands.evidence import active_commands, check_receipts
from factory.runtime.contracts import (
    Config,
    Graph,
    GraphTopology,
    LockedGraph,
    Node,
    State,
    TestRetry,
    agent_key,
)
from factory.runtime.history import report_history
from factory.runtime.run_journal import RunJournal
from factory.runtime.scheduling import escalation
from factory.runtime.scheduling.assignment import worker_node
from factory.runtime.scheduling.attempt_graph import invalidate as invalidate_attempt
from factory.runtime.scheduling.escalation_policy import RetryBudget
from factory.runtime.workflow_config import (
    check_config,
    document_paths,
    freeze_project,
    reconcile_source_documents,
)
from factory.runtime.workflow_core import acceptance_guard, digest, relative, require, snapshot
from factory.runtime.workflow_graph import (
    ancestors,
    execution_graph,
    overlaps,
    parse_graph,
    validate_assignment_lineage,
    validate_graph,
)
from factory.runtime.workflow_sources import SOURCE, lock_source
from factory.tasks.contracts import Task


class TestRetryRequest(NamedTuple):
    test_node: str
    failed_dispatch: str
    diagnosis_node: str
    repair_node: str


def has_prior_dispatch_evidence(state: State, node_id: str) -> bool:
    """Common reservation/correction evidence; callers retain their own policies."""
    return any(
        event.get("node") == node_id and event.get("event") == "reserved"
        for event in state["events"]
    ) or any(
        node_id in record.get("reassigned_nodes", []) or record.get("node_id") == node_id
        for record in state.get("corrections", [])
    )


def validate_assignment_change(state: State, graph: GraphTopology) -> None:
    validate_assignment_lineage(graph, state["config"], state.get("corrections", []))
    old = state["graph"]
    new_nodes = {n["id"]: n for n in graph["nodes"]}
    old_ids = {n["id"] for n in old["nodes"]}
    for previous in old["nodes"]:
        node_id = previous["id"]
        require(node_id in new_nodes, "Retain stable node IDs/history")
        node = new_nodes[node_id]
        require(
            node["task"] == previous["task"] and node["stage"] == previous["stage"],
            "Keep task/stage identity for existing nodes",
        )
        if not (state["nodes"][node_id]["attempt"] or has_prior_dispatch_evidence(state, node_id)):
            continue
        aid = previous.get("agent")
        if aid is None:
            continue
        assignment = old["agents"][aid]
        require(
            node.get("agent") == aid and graph["agents"].get(aid) == assignment,
            "Started assignments require correct",
        )
        if assignment["role"] not in {"implementer"}:
            continue
        owns = previous.get("owns", [])
        require(set(owns) <= set(node.get("owns", [])), "Keep started assignment ownership")
        for added in (n for n in graph["nodes"] if n["id"] not in old_ids):
            if added["task"] == previous["task"] and overlaps(owns, added.get("owns", [])):
                require(
                    node_id in ancestors(new_nodes, added["id"]),
                    "New overlapping work must follow the started assignment",
                )


def preserve_task_guards(before: Task, after: Task) -> None:
    """Keep checks, scope, risk and independent review across graph changes."""
    previous_checks = {check["id"]: check for check in before["required_checks"]}
    next_checks = {check["id"]: check for check in after["required_checks"]}
    require(
        all(next_checks.get(cid) == check for cid, check in previous_checks.items()),
        "Cannot remove or weaken required checks",
    )
    require(set(after["scope"]) >= set(before["scope"]), "Cannot remove verification scope")
    require(
        ["low", "moderate", "high"].index(after["risk"])
        >= ["low", "moderate", "high"].index(before["risk"]),
        "Cannot weaken risk assessment",
    )
    require(
        not before["independent_review"] or after["independent_review"],
        "Cannot remove independent review",
    )


def expand_scope(journal: RunJournal, task_id: str, paths: list[str], reason: str) -> None:
    with journal.locked():
        state = journal.read()
        require(task_id in state["graph"]["tasks"], "Unknown task")
        require(paths and reason.strip(), "Need added verification paths and reason")
        graph = deepcopy(state["graph"])
        for path in paths:
            relative(journal.root, path)
        task = graph["tasks"][task_id]
        task["scope"] = list(dict.fromkeys([*task["scope"], *paths]))
        for integration in graph["tasks"].values():
            if integration["kind"] == "integration" and task_id in integration.get(
                "depends_on", []
            ):
                integration["scope"] = list(dict.fromkeys([*integration["scope"], *paths]))
        _revise(journal, state, graph, reason)


def revise(
    journal: RunJournal,
    graph: Graph | LockedGraph,
    reason: str,
    *,
    retry_tests: tuple[str, str, str, str] | None = None,
) -> None:
    with journal.locked():
        request = TestRetryRequest(*retry_tests) if retry_tests is not None else None
        _revise(journal, journal.read(), graph, reason, retry_tests=request)


def _revise(
    journal: RunJournal,
    s: State,
    graph: Graph | LockedGraph,
    reason: str,
    *,
    retry_tests: TestRetryRequest | None = None,
) -> None:
    require(not s.get("pause_reason"), "Run is paused by user")
    require(
        s["status"] == "active" and reason,
        "Need active run and revision reason",
    )
    require(
        not any(v["status"] in {"reserved", "running", "unknown"} for v in s["nodes"].values()),
        "Quiesce runtime before graph revision",
    )
    require(not active_commands(s), "Unresolved project commands")
    check_config(s)
    graph = parse_graph(graph)
    for name, proposal in graph["sources"].items():
        if "hash" not in proposal:
            graph["sources"][name] = SOURCE.validate_python(lock_source(journal.root, proposal))
    new_nodes = validate_graph(graph, s["config"], journal.root)
    old = s["graph"]
    if graph == old and retry_tests is None:
        return
    _preserve_test_retry_dependencies(s, new_nodes)
    validate_assignment_change(s, graph)
    require(
        graph["sources"] == old["sources"] and set(graph["tasks"]) == set(old["tasks"]),
        "Revision cannot alter locked tasks/sources; re-intake required",
    )
    strengthened = set()
    for tid, before in old["tasks"].items():
        after = graph["tasks"][tid]
        mutable = {
            "scope",
            "risk",
            "independent_review",
            "reason",
            "required_checks",
            "policy_decisions",
        }
        require(
            {k: v for k, v in before.items() if k not in mutable}
            == {k: v for k, v in after.items() if k not in mutable},
            "Revision cannot alter locked tasks/sources",
        )
        try:
            preserve_obligations(
                s["config"]["_project"]["data"].get("decisions", []),
                before.get("policy_decisions", {}),
                after.get("policy_decisions", {}),
            )
        except ValueError as exc:
            require(False, str(exc))
        preserve_task_guards(before, after)
        if before != after:
            strengthened.add(tid)
    invalidate = set()
    for n in old["nodes"]:
        require(
            n["id"] in new_nodes,
            "Keep stable node identities; do not erase work",
        )
        require(
            n["task"] == new_nodes[n["id"]]["task"] and n["stage"] == new_nodes[n["id"]]["stage"],
            "Keep task/stage identity for existing nodes",
        )
        if worker_node(n) != worker_node(new_nodes[n["id"]]) or (
            n["task"] in strengthened and n["stage"] in {"verify", "review", "accept"}
        ):
            invalidate.add(n["id"])
    dependencies = execution_graph(new_nodes)
    invalidate = dependencies.affected_by(invalidate)
    test_retry = None
    if retry_tests is not None:
        test_retry = _prepare_test_retry(journal, s, graph, new_nodes, retry_tests, invalidate)
        invalidate.update(dependencies.affected_by({test_retry["node"]}))
    for a, old_assignment in old["agents"].items():
        if a in s["sessions"]:
            require(
                graph["agents"].get(a) == old_assignment,
                "Replace physical session before changing role/profile",
            )
    s["config"] = freeze_project(s["config"], graph, journal.root)
    s["graph"] = {**graph, "sources": old["sources"]}
    s["revision"] += 1
    for n in graph["nodes"]:
        s["nodes"].setdefault(n["id"], {"status": "pending", "attempt": 0})
        if n["id"] in invalidate:
            prev = s["nodes"][n["id"]]
            s["events"].append(
                {
                    "at": time.time(),
                    "event": "invalidated",
                    "node": n["id"],
                    "previous": prev,
                }
            )
            # A technical graph edit is not a free retry of failed work.
            prior_task = old["tasks"][n["task"]]
            current_task = graph["tasks"][n["task"]]
            verify_changed = n["stage"] in {"verify", "review"} and any(
                prior_task.get(field) != current_task.get(field)
                for field in ("scope", "required_checks")
            )
            check_request = _targeted_check_request(journal, s, old, new_nodes, n)
            if (
                prev["status"] != "blocked"
                or check_request
                or (
                    verify_changed
                    and prev.get("report", {}).get("outcome") == "FAIL"
                    and n["task"] not in s.get("escalation_stops", {})
                )
            ):
                s["nodes"][n["id"]] = invalidate_attempt(prev)
    details: dict[str, object] = {}
    if test_retry is not None:
        tests = test_retry["node"]
        RetryBudget.for_task(s, new_nodes[tests]["task"], "tests").spend()
        s["nodes"][tests] = invalidate_attempt(s["nodes"][tests])
        s["nodes"][tests]["attempt"] = test_retry["attempt"]
        details["test_retry"] = test_retry
    journal.save(s, "revised", reason=reason, previous_graph=old, **details)


def _targeted_check_request(
    journal: RunJournal, state: State, old: Graph | LockedGraph, nodes: dict[str, Node], node: Node
) -> bool:
    previous = state["nodes"][node["id"]]
    report = previous.get("report", {})
    if not (
        node["stage"] == "review"
        and state["graph"]["agents"][agent_key(node)]["role"] == "judge"
        and report.get("outcome") == "BLOCKED"
        and report.get("stage_result") == "CHECKS_REQUESTED"
    ):
        return False
    old_ids = {entry["id"] for entry in old["nodes"]}
    extra = [
        nodes[key]
        for key in ancestors(nodes, node["id"]) - old_ids
        if nodes[key]["stage"] == "verify" and nodes[key].get("required_check_ids")
    ]
    if not extra:
        return False
    requested = {
        key
        for assessment in report.get("criterion_assessments", {}).values()
        for key in assessment.get("requested_checks", [])
    }
    require(
        {key for item in extra for key in item.get("required_check_ids", [])} == requested,
        "Focused assignment must match the Judge's requested checks",
    )
    extra_ids = {entry["id"] for entry in extra}
    require(set(nodes) - old_ids == extra_ids, "Check request adds only focused verification nodes")
    require(old["agents"] == state["graph"]["agents"], "Check request cannot change agents")
    for previous_node in old["nodes"]:
        replacement = nodes[previous_node["id"]]
        if previous_node["id"] == node["id"]:
            require(
                {key: value for key, value in previous_node.items() if key != "depends_on"}
                == {key: value for key, value in replacement.items() if key != "depends_on"}
                and set(previous_node["depends_on"]) <= set(replacement["depends_on"])
                and set(replacement["depends_on"]) - set(previous_node["depends_on"]) <= extra_ids,
                "Check request only adds review prerequisites",
            )
        else:
            require(
                previous_node == replacement, "Check request cannot change existing assignments"
            )
    task = state["graph"]["tasks"][node["task"]]
    require(old["tasks"][node["task"]] == task, "Check request cannot change task obligations")
    current = snapshot(journal.root, task["scope"])
    require(report.get("files") == current, "Check request candidate changed")
    journal.check_sources(state, task)
    for previous_node in old["nodes"]:
        if previous_node["task"] != node["task"] or previous_node["stage"] != "verify":
            continue
        verified = state["nodes"][previous_node["id"]]
        verification = verified.get("report")
        require(
            verified["status"] == "done"
            and verification is not None
            and verification.get("outcome") == "PASS"
            and verification.get("files") == current,
            "Check request needs current completed verification",
        )
        if verification is not None:
            check_receipts(
                journal.root,
                state,
                previous_node["id"],
                verification.get("checks", []),
                complete=False,
            )
    require(
        all(entry["task"] == node["task"] for entry in extra),
        "Requested checks must belong to the reviewed task",
    )
    return True


def _prepare_test_retry(
    journal: RunJournal,
    state: State,
    graph: Graph | LockedGraph,
    nodes: dict[str, Node],
    request: TestRetryRequest,
    invalidate: set[str],
) -> TestRetry:
    tests, failed_dispatch = request.test_node, request.failed_dispatch
    diagnose, repair = request.diagnosis_node, request.repair_node
    current = state["nodes"]
    require(
        {tests, diagnose, repair} <= nodes.keys() and {tests, diagnose, repair} <= current.keys(),
        "Test retry needs existing test, diagnosis and repair nodes",
    )
    task_id = nodes[tests]["task"]
    task = graph["tasks"][task_id]
    require(
        nodes[diagnose]["task"] == nodes[repair]["task"] == task_id
        and graph["agents"][agent_key(nodes[tests])]["role"] == "tester"
        and graph["agents"][agent_key(nodes[diagnose])]["role"] == "bug-hunter"
        and graph["agents"][agent_key(nodes[repair])]["role"] == "implementer"
        and diagnose in ancestors(nodes, repair)
        and repair in ancestors(nodes, tests),
        "Test retry needs a BugHunter diagnosis before Implementer repair before Tester",
    )
    require(
        current[tests]["status"] == "blocked"
        and current[tests].get("dispatch_id") == failed_dispatch,
        "Test retry needs the current blocked test dispatch",
    )
    diagnosis_dispatch = current[diagnose].get("dispatch_id")
    require(
        current[diagnose]["status"] == "done"
        and diagnosis_dispatch is not None
        and diagnose not in invalidate,
        "Test retry needs an accepted diagnosis retained by the revision",
    )
    assert diagnosis_dispatch is not None
    require(
        current[repair]["status"] == "pending"
        or (current[repair]["status"] == "done" and repair in invalidate),
        "Test retry needs pending Implementer repair",
    )
    journal.check_sources(state, state["graph"]["tasks"][task_id])
    files = snapshot(journal.root, task["scope"])
    source_hash = state["graph"]["sources"][task["source"]]["hash"]
    for node, dispatch_id, outcome, results in (
        (tests, failed_dispatch, "FAIL", {"FAIL_TEST", "FAIL_CODE"}),
        (diagnose, diagnosis_dispatch, "PASS", {"ROOT_CAUSE_FOUND"}),
    ):
        saved = report_history.historical(
            journal.root, state, node, dispatch_id, history=journal.history
        )
        report, assignment = saved["report"], saved["assignment"]
        require(
            report["terminal"]
            and report["outcome"] == outcome
            and report["stage_result"] in results
            and report["task_id"] == task_id
            and assignment["agent"]["role"] == graph["agents"][agent_key(nodes[node])]["role"],
            "Test retry needs terminal Tester failure and BugHunter root-cause reports",
        )
        require(
            not report.get("observed_source_drift")
            and report["source_hash"] == source_hash
            and report["files"] == files
            and task["required_checks"] == assignment["task"]["required_checks"],
            "Test retry evidence is stale for current source, files or checks",
        )
    acceptance_guard(escalation.guard, state, task_id)
    RetryBudget.for_task(state, task_id, "tests").require_available()
    return {
        "node": tests,
        "attempt": current[tests]["attempt"],
        "failed_dispatch": failed_dispatch,
        "diagnosis_dispatch": diagnosis_dispatch,
        "repair_node": repair,
    }


def _preserve_test_retry_dependencies(state: State, nodes: dict[str, Node]) -> None:
    for event in state["events"]:
        retry = event.get("test_retry")
        if retry is None:
            continue
        tests = retry["node"]
        current = state["nodes"][tests]
        if current["status"] == "pending" and current["attempt"] == retry["attempt"]:
            require(
                tests in nodes and retry["repair_node"] in ancestors(nodes, tests),
                "Keep the Implementer repair dependency for the pending test retry",
            )


def _refresh_config(
    root: Path, old_config: Config, graph: GraphTopology, documents: list[str] | None
) -> Config:
    """Refresh only the accepted documents named in the re-intake authorization."""
    old_policy = old_config["_project"]
    old_data = old_policy["data"]
    new_config = deepcopy(old_config)
    contents = new_config["_documents"]
    hashes = new_config.setdefault("_project_documents", {})
    requested = {str(relative(root, name)) for name in documents or []}
    documents_in_config = document_paths(old_config)
    executable = old_config["_files"].keys() - documents_in_config
    require(
        requested <= (contents.keys() | hashes.keys() | documents_in_config) - executable,
        "Only existing accepted documents may be refreshed",
    )
    replacements = {name: file_reader.read_bytes(Path(name)) for name in sorted(requested)}
    structured = requested & old_policy["files"].keys()
    if structured:
        # Compose only from explicitly authorized replacements and accepted bytes.
        new_policy = acceptance_guard(
            load_profile,
            old_policy["path"],
            resolve=lambda root, rel: accepted_path(new_config, root, rel),
            read_bytes=lambda path: (
                replacements[str(path)]
                if str(path) in replacements
                else accepted_bytes(old_config, path)
            ),
        )
        new_data = new_policy["data"]
        require(
            {k: v for k, v in old_data.items() if k != "decisions"}
            == {k: v for k, v in new_data.items() if k != "decisions"}
            and old_policy["files"].keys() == new_policy["files"].keys(),
            "Only decision definitions or prose may be refreshed within this run",
        )
        new_config["_project"] = new_policy
    for name, raw in replacements.items():
        contents[name] = raw.decode("utf-8")
        if name in new_config["_files"]:
            new_config["_files"][name] = digest(raw)
        if name in hashes:
            hashes[name] = digest(raw)
    return freeze_project(new_config, graph, root)


def reintake(
    journal: RunJournal,
    graph: Graph | LockedGraph,
    reason: str,
    authorization: str,
    *,
    documents: list[str] | None = None,
) -> None:
    graph = parse_graph(graph)
    with journal.locked():
        s = journal.read()
        require(not s.get("pause_reason"), "Run is paused by user")
        require(
            s["status"] == "active" and reason and authorization,
            "Source re-intake requires reason and source/user authorization evidence",
        )
        require(
            not any(v["status"] in {"reserved", "running", "unknown"} for v in s["nodes"].values()),
            "Quiesce workers before re-intake",
        )
        require(
            set(graph["tasks"]) == set(s["graph"]["tasks"])
            and set(graph["sources"]) == set(s["graph"]["sources"]),
            "New tasks/sources need a separate run",
        )
        require(not active_commands(s), "Unresolved project commands")
        old_config = s["config"]
        s["config"] = _refresh_config(journal.root, old_config, graph, documents)
        check_config(s)
        for tid, before in s["graph"]["tasks"].items():
            after = graph["tasks"][tid]
            try:
                preserve_obligations(
                    s["config"]["_project"]["data"].get("decisions", []),
                    before.get("policy_decisions", {}),
                    after.get("policy_decisions", {}),
                    reintake=True,
                    previous_definitions=old_config["_project"]["data"].get("decisions", []),
                )
            except ValueError as exc:
                require(False, str(exc))
            preserve_task_guards(before, after)
        refreshed_sources = {
            k: lock_source(journal.root, src, check_expected=False)
            for k, src in graph["sources"].items()
        }
        reconcile_source_documents(s["config"], journal.root, refreshed_sources, refresh=True)
        locked_graph: LockedGraph = {**graph, "sources": refreshed_sources}
        new_nodes = validate_graph(locked_graph, s["config"], journal.root)
        _preserve_test_retry_dependencies(s, new_nodes)
        validate_assignment_change(s, graph)
        for a in s["sessions"]:
            require(
                graph["agents"].get(a) == s["graph"]["agents"].get(a),
                "Replace session before role/profile change",
            )
        previous, previous_nodes = s["graph"], s["nodes"]
        s["graph"], s["revision"] = locked_graph, s["revision"] + 1
        s["nodes"] = {
            n["id"]: (
                previous_nodes[n["id"]]
                if n["id"] in previous_nodes and previous_nodes[n["id"]]["status"] == "blocked"
                else invalidate_attempt(previous_nodes[n["id"]])
                if n["id"] in previous_nodes
                else {"status": "pending", "attempt": 0}
            )
            for n in graph["nodes"]
        }
        # Re-intake authorizes a new source, not a free retry of a quality
        # failure. Only explicit source-drift blockers gain a recovery route.
        for tid in graph["tasks"]:
            drift_nodes = [
                nid
                for nid, old in previous_nodes.items()
                if old["status"] == "blocked"
                and nid in s["nodes"]
                and next(n for n in graph["nodes"] if n["id"] == nid)["task"] == tid
                and (
                    old.get("report", {}).get("stage_result") == "SOURCE_DRIFT"
                    or old.get("report", {}).get("observed_source_drift")
                )
            ]
            if drift_nodes and tid not in s.get("escalation_stops", {}):
                budget = RetryBudget.for_task(s, tid, "recovery")
                s.setdefault("escalation_stops", {})[tid] = dict(
                    reason=reason,
                    decision="blocked",
                    node_id=drift_nodes[0],
                    node_ids=drift_nodes,
                    kind="source_reintake",
                    cause="recovery",
                    budget_exhausted=budget.remaining <= 0,
                    authorization=authorization,
                )
        journal.save(
            s,
            "source_reintake",
            reason=reason,
            authorization=authorization,
            previous_graph=previous,
            previous_nodes=previous_nodes,
            previous_config=old_config,
        )
