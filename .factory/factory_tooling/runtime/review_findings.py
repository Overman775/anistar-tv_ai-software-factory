"""Task-qualified Judge findings; no model or semantic verdict inference."""

from __future__ import annotations

import re
import time
from copy import deepcopy
from typing import cast

from pydantic import TypeAdapter, ValidationError

from factory_tooling.runtime.acceptance import ensure
from factory_tooling.runtime.contracts import (
    Finding,
    FindingEvent,
    FindingRecord,
    FindingView,
    Node,
    Report,
    State,
    agent_key,
)
from factory_tooling.validation import validation_message

RECORD = TypeAdapter[FindingRecord](FindingRecord)
EVENT = TypeAdapter[FindingEvent](FindingEvent)

ROLES = {"developer", "test-writer", "generalist", "doc-writer", "judge"}
CLOSED = {"fixed", "dismissed"}


def review_tasks(state: State, task_id: str) -> list[str]:
    """Only final integration may review its declared predecessor tasks."""
    task = state["graph"]["tasks"][task_id]
    return [task_id, *task.get("depends_on", [])] if task["kind"] == "integration" else [task_id]


def view(
    state: State, task_id: str, *, include_dependencies: bool = True
) -> dict[str, FindingView]:
    result: dict[str, FindingView] = {}
    integration = state["graph"]["tasks"][task_id]["kind"] == "integration"
    for tid in review_tasks(state, task_id) if include_dependencies else [task_id]:
        for fid, item in state.get("review_findings", {}).get(tid, {}).items():
            value: FindingView = {
                "id": item["id"],
                "status": item["status"],
                "blocking": item["blocking"],
                "owner_role": item["owner_role"],
                "owner_node_id": item["owner_node_id"],
                "summary": item["summary"],
                "evidence": item["evidence"],
            }
            if "reviewed" in item:
                value["reviewed"] = deepcopy(item["reviewed"])
            if "task_id" in item:
                value["task_id"] = item["task_id"]
            if integration:
                value.update({"task_id": tid, "id": fid})
            result[f"{tid}:{fid}" if integration else fid] = value
    return result


def consistent(report: Report, review: bool = False) -> None:
    outcome, stage, verdict = (
        report["outcome"],
        report.get("stage_result", ""),
        report.get("verdict"),
    )
    if stage.startswith("FAIL") or stage == "NEEDS_WORK":
        ensure(outcome == "FAIL", "Contradictory stage_result/outcome")
    if stage.startswith("BLOCKED") or stage == "RETHINK":
        ensure(outcome == "BLOCKED", "Contradictory stage_result/outcome")
    if verdict is not None or review:
        expected = {
            "APPROVE": "PASS",
            "NEEDS_WORK": "FAIL",
            "RETHINK": "BLOCKED",
            "BLOCKED_TOOL_ERROR": "BLOCKED",
        }
        if not (
            isinstance(verdict, str) and verdict in expected and (expected[verdict] == outcome)
        ):
            raise ValueError("Contradictory verdict/outcome")


def _new_finding(state: State, node: Node, tid: str, update: Finding) -> FindingRecord:
    """Resolve an unambiguous writer and create an independent registry entry."""
    writers = [
        n
        for n in state["graph"]["nodes"]
        if n["task"] == tid
        and n.get("owns")
        and state["graph"]["agents"][agent_key(n)]["role"] == update.get("owner_role")
    ]
    if not (
        isinstance(update.get("owner_role"), str)
        and update["owner_role"] in ROLES - {"judge"}
        and writers
    ):
        raise ValueError("Invalid finding owner_role")
    owner = update.get("owner_node_id")
    if owner is None:
        ensure(
            tid == node["task"] and len(writers) == 1,
            "Integration or ambiguous finding requires owner_node_id",
        )
        owner = writers[0]["id"]
    ensure(owner in {n["id"] for n in writers}, "Invalid finding owner_node_id")
    if not (isinstance(update.get("summary"), str) and update["summary"].strip()):
        raise ValueError("Missing finding summary")
    try:
        return RECORD.validate_python({**update, "owner_node_id": owner, "history": []})
    except ValidationError as exc:
        raise ValueError(validation_message("Invalid new finding", exc, RECORD)) from None


def apply(state: State, node: Node, report: Report) -> None:
    """Validate a complete report before committing a copied registry to state."""
    role = state["graph"]["agents"][agent_key(node)]["role"]
    reviewer = node["stage"] in {"verify", "review"} and role == "judge"
    review = node["stage"] == "review" and reviewer
    consistent(report, review)
    registry = deepcopy(state.get("review_findings", {}))
    allowed = review_tasks(state, node["task"]) if reviewer else [node["task"]]
    updates = report.get("finding_updates", [])
    incoming = report.get("findings", []) if reviewer else updates
    ensure(not reviewer or not updates, "Reviewer uses findings, not finding_updates")
    seen = set()
    for update in incoming:
        tid, fid, status = (
            update.get("task_id", node["task"]),
            update.get("id"),
            update.get("status"),
        )
        if not (isinstance(tid, str) and tid in allowed):
            raise ValueError("Finding task must be this task or an integration predecessor")
        if not (fid and re.fullmatch("REV-\\d+", fid) and ((tid, fid) not in seen)):
            raise ValueError("Invalid/duplicate review finding ID")
        seen.add((tid, fid))
        items = registry.setdefault(tid, {})
        old = items.get(fid)
        evidence = update.get("evidence")
        if not (isinstance(evidence, str) and evidence.strip()):
            raise ValueError("Review finding needs evidence")
        if reviewer:
            finding = cast(Finding, update)
            ensure(
                review or status == "open",
                "Verification may discover findings; closure requires review",
            )
            ensure(status in {"open", "fixed", "dismissed"}, "Invalid reviewer finding status")
            if old is None:
                ensure(status == "open", "New review finding must start open")
                ensure(
                    type(update.get("blocking")) is bool, "Review finding needs boolean blocking"
                )
                old = _new_finding(state, node, tid, finding)
                items[fid] = old
            for key in ("blocking", "owner_role", "owner_node_id", "summary"):
                ensure(
                    key not in finding or dict(finding)[key] == dict(old)[key],
                    "Cannot rewrite finding identity or severity",
                )
            if status == "fixed":
                ensure(
                    old.get("status") in {"ready", "fixed"},
                    "Fix must be handed off before reviewer closes it",
                )
        else:
            if not (old is not None):
                raise ValueError("Unknown review finding")
            # Node identity survives escalation; another same-role author cannot
            # claim the fix for a task-qualified integration finding.
            ensure(
                role == old["owner_role"]
                and node["id"] == old["owner_node_id"]
                and status == "ready",
                "Only assigned owner may mark ready; cannot close finding",
            )
            ensure(
                old.get("status") in {"open", "ready"}, "Closed finding needs reviewer reopening"
            )
        target = state["graph"]["tasks"][tid]
        ensure(
            set(target["scope"]) <= set(report["files"]), "Review lacks finding task file evidence"
        )
        event = EVENT.validate_python(
            dict(
                status=status,
                evidence=evidence,
                node_id=node["id"],
                agent=node["agent"],
                dispatch_id=state["nodes"][node["id"]]["dispatch_id"],
                at=time.time(),
                revision=state["revision"],
                files={p: report["files"][p] for p in target["scope"]},
                source_hash=state["graph"]["sources"][target["source"]]["hash"],
                review_task_id=node["task"],
            )
        )
        old["status"] = event["status"]
        old["evidence"] = event["evidence"]
        old["history"].append(event)
        if reviewer:
            old["reviewed"] = event
    if review and report["outcome"] == "PASS":
        ensure(
            all(
                not item["blocking"] or ((tid, fid) in seen and item["status"] in CLOSED)
                for tid in allowed
                for fid, item in registry.get(tid, {}).items()
            ),
            "Unresolved or omitted blocking review finding",
        )
    # Authors cannot evade the owner-only update route using the old findings field.
    if not reviewer:
        ensure(
            not any(
                f.get("id") in registry.get(node["task"], {}) for f in report.get("findings", [])
            ),
            "Use finding_updates for tracked review findings",
        )
    state["review_findings"] = registry


def gate(state: State, task_id: str, files: dict[str, str], source_hash: str) -> None:
    for item in state.get("review_findings", {}).get(task_id, {}).values():
        if not item["blocking"]:
            continue
        ensure(item["status"] in CLOSED, "Unresolved blocking review finding")
        reviewed = item["reviewed"]
        ensure(
            reviewed["files"] == files
            and reviewed["source_hash"] == source_hash
            and reviewed["revision"] == state["revision"],
            "Stale review finding resolution",
        )
