"""Decomposition assignments, reviewed repair and publication of the checked task set."""

from pathlib import Path
from typing import Any

from factory.decompose import assemble, source_lock
from factory.decompose.staging.manifest import DONE_SIGNAL, staged_manifest
from factory.gates.gate_contract import digest as request_hash
from factory.graphs.program import Operations
from factory.processes import bundle, publication
from factory.processes.engine import Offer, active, offer, register
from factory.processes.records import Attempt, ProcessRun
from factory.project.profile_io import parse_yaml
from factory.runtime.workflow_core import digest, graph_identity, relative, require


def operations() -> Operations:
    return register(
        (
            "intake",
            "material_ready",
            "coverage_gap",
            "checked",
            "changes_requested",
            "authorized",
            "repair_ready",
            "rechecked",
            "semantic_gap",
            "approved",
            "install_ready",
            "published",
        ),
        "decomposition_phase",
        {
            "generate_tasks": offer("generate", "task-decomposer"),
            "verify_coverage": offer("validate"),
            "inspect_tasks": offer("review", "task-reviewer"),
            "authorize_repair": offer("authorize-repair"),
            "repair_tasks": offer("repair", "task-reviewer"),
            "inspect_repair": offer("recheck", "task-reviewer"),
            "return_planning": offer("planning"),
            "stage_bundle": offer("prepare-publication"),
            "install_bundle": offer("publish"),
            "complete_bundle": offer("finish"),
        },
    )


def subject(root: Path, config: Path, plan: str, name: str, authority: str) -> dict[str, Any]:
    require(
        plan and name and authority,
        "Provide the approved --plan, --destination and --authorization",
    )
    destination = publication.destination(root, name)
    require(not destination.exists(), "Task bundle requires an unoccupied public destination")
    return {
        "policy_binding": assemble.policy_binding(config),
        "source_lock": source_lock.prepare(relative(root, plan), config),
        "config": str(config),
        "destination": name,
        "authorization": authority,
    }


def progress(run: ProcessRun) -> dict[str, Any]:
    facts = run.state.facts
    received = {name: digest(content.encode()) for name, content in facts.get("files", {}).items()}
    expected = facts.get("manifest", {}).get("files", {})
    return {
        "received": received,
        "needs_manifest": not expected,
        "recovery": (
            "Confirm the independently observed hashes via confirm-files; coverage and review still apply"
            if received
            else "Restore exact task envelope and Markdown bytes from the original worker"
        )
        if not expected
        else None,
        "missing": sorted(k for k, checksum in expected.items() if received.get(k) != checksum),
        "unexpected": sorted(received.keys() - expected.keys()) if expected else [],
    }


def require_independent(run: ProcessRun, handle: str | None) -> None:
    require(
        handle and all(a.handle != handle for a in run.state.attempts.get("generate", [])),
        "TaskReviewer must be independent of every TaskDecomposer",
    )


def review_request(run: ProcessRun, worker: Attempt) -> assemble.ReviewRequest:
    facts = run.state.facts
    gate = facts["gate"]
    author = facts["author"]
    require_independent(run, worker.handle)
    return assemble.validate_request(
        {
            "run_id": run.run_id,
            "role": "task-reviewer",
            "assignment_id": worker.dispatch,
            "reviewer_id": worker.handle,
            "author_id": author,
            "artifact_hash": gate["basis"],
            "policy_hash": run.subject["policy_binding"],
            "task_ids": sorted(gate["tasks"]),
            "criteria": assemble.REVIEW_CRITERIA,
            "source_lock_sha256": graph_identity(run.subject["source_lock"]),
            "author_manifest": facts["original_manifest"],
            "repaired": worker.node == "recheck",
        }
    )


def deliver(
    root: Path, run: ProcessRun, worker: Attempt, action: str, data: dict[str, Any]
) -> dict[str, Any]:
    facts = run.state.facts
    files = facts.setdefault("files", {})
    if action == "deliver":
        name = data.get("path", "")
        relative(root, name)
        require("content" in data, "Deliver exact text bytes")
        if worker.node == "repair":
            require(
                worker.handle == facts["repair_actor"] and name in facts["allowed"],
                "File outside the repair assignment",
            )
        files[name] = data["content"]
    else:
        done = DONE_SIGNAL.validate_python(parse_yaml(data.get("content", "")))
        expected = {item["path"]: item["sha256"] for item in done["files"]}
        require(len(expected) == len(done["files"]), "Duplicate manifest path")
        for name in expected:
            relative(root, name)
        if worker.node == "repair":
            require(
                expected.keys() == facts["original_manifest"].keys(),
                "Repair changed task file membership",
            )
        facts["manifest"] = {"files": expected, "task_count": done["task_count"]}
    result = progress(run)
    if not result["needs_manifest"] and not result["missing"] and not result["unexpected"]:
        run.state.phase = "repair_ready" if worker.node == "repair" else "material_ready"
        if worker.node == "generate":
            facts["author"] = worker.handle
    return result


def confirm_files(run: ProcessRun, selected: Offer, data: dict[str, Any]) -> dict[str, Any]:
    require(selected.action in {"generate", "repair"}, "No author material awaits verification")
    attempts = run.state.attempts.get(selected.action, [])
    require(attempts and attempts[-1].handle, "Need the original bound assignment")
    files = run.state.facts.get("files", {})
    require(files, "Restore exact task envelope and Markdown bytes before confirming their hashes")
    observed = parse_yaml(data.get("content", ""))
    require(
        isinstance(observed, dict) and data.get("evidence"),
        "Supply the confirmed path/hash map and its source",
    )
    with bundle.materialize(files) as stage:
        hashes, count = staged_manifest(stage)
    require(observed == hashes, "Confirmed hash list must match every delivered byte")
    if selected.action == "repair":
        require(
            hashes.keys() == run.state.facts["original_manifest"].keys(),
            "Repair changed task membership",
        )
    run.state.facts["manifest"] = {"files": hashes, "task_count": count, "basis": data["evidence"]}
    if selected.action == "generate":
        run.state.facts["author"] = attempts[-1].handle
    run.state.phase = "repair_ready" if selected.action == "repair" else "material_ready"
    return {"task_count": count, "files": hashes, "observed": data["evidence"]}


def perform(
    root: Path, run: ProcessRun, selected: Offer, action: str, data: dict[str, Any]
) -> dict[str, Any]:
    facts, state = run.state.facts, run.state
    bundle.fresh(run)
    if action == "confirm-files":
        return confirm_files(run, selected, data)
    if action in {"deliver", "manifest", "report", "note"}:
        worker = active(run, selected.action, data.get("dispatch"))
        require(worker.status == "running", "Need the bound worker for this assignment")
        if action == "note":
            require(data.get("evidence"), "Need an observation or partial dependency map")
            worker.evidence.append({"observation": data["evidence"]})
            return {**progress(run), "observation": data["evidence"]}
        if action in {"deliver", "manifest"}:
            require(worker.node in {"generate", "repair"}, "Reviewer has read-only access")
            return deliver(root, run, worker, action, data)
        if data.get("outcome") == "SEMANTIC_GAP":
            require(
                data.get("evidence"), "Specify the unresolved meaning of the approved requirement"
            )
            state.phase = "semantic_gap"
            facts["reason"] = data["evidence"]
            worker.status, worker.outcome = "done", "SEMANTIC_GAP"
            return {
                "return_to": "planning",
                "question": facts["reason"],
                "source": run.subject["source_lock"],
            }
        require(worker.node in {"review", "recheck"}, "Only a review assignment accepts a verdict")
        request = review_request(run, worker)
        report = assemble.REVIEW_REPORT.validate_python(parse_yaml(data.get("content", "")))
        gate = facts["gate"]
        record = assemble.review_record(
            request, report, gate["basis"], request["policy_hash"], gate["tasks"], worker.dispatch
        )
        require(
            report["request_hash"] == request_hash(request)
            and all(
                report[k] == request[k] for k in ("run_id", "role", "assignment_id", "reviewer_id")
            ),
            "Stale reviewer request or assignment",
        )
        require(record["message"].startswith("TaskReviewer: "), record["message"])
        facts.setdefault("reviews", []).append(
            {"basis": gate["basis"], "request": request, "report": report, "gate": record}
        )
        if record["status"] == "PASS":
            state.phase = "approved"
        elif worker.node == "review" and record["status"] == "FAIL":
            state.phase = "changes_requested"
            facts["reviewer"] = worker.handle
        else:
            state.paused = record["message"]
            return dict(record)
        worker.status, worker.outcome = "done", report["verdict"]
        return dict(record)
    require(action == selected.action, "Action is unavailable at this graph node")
    if action == "validate":
        checked = bundle.check(run)
        repaired = state.phase == "repair_ready"
        worker = state.attempts["repair" if repaired else "generate"][-1]
        if checked["status"] != "PASS":
            state.phase = "authorized" if repaired else "coverage_gap"
            facts.pop("manifest", None)
        else:
            if repaired:
                require(
                    checked["tasks"].keys() == facts["gate"]["tasks"].keys(),
                    "Repair changed task identity",
                )
                require(
                    checked["basis"] != facts["gate"]["basis"],
                    "Repair did not change the candidate",
                )
            worker.status, worker.outcome = "done", "DONE"
            state.phase = "rechecked" if repaired else "checked"
            facts.setdefault("original_manifest", checked["files"])
        facts["gate"] = checked if checked["status"] == "PASS" else facts.get("gate", {})
        proof = {k: v for k, v in checked.items() if k not in {"tasks", "public", "diagram"}}
        facts.setdefault("gates", []).append(proof)
        return proof
    if action == "authorize-repair":
        paths = data.get("paths", [])
        require(
            paths
            and set(paths) <= facts["original_manifest"].keys()
            and data.get("reference")
            and data.get("actor") == facts["reviewer"],
            "Name the original reviewer, allowed files and repair authority",
        )
        facts.update(allowed=paths, repair_actor=data["actor"])
        facts.pop("manifest", None)
        state.phase = "authorized"
        return {"paths": paths, "actor": data["actor"], "reference": data["reference"]}
    if action == "prepare-publication":
        reviews = facts.get("reviews", [])
        require(
            state.phase == "approved"
            and reviews
            and reviews[-1]["gate"]["status"] == "PASS"
            and reviews[-1]["basis"] == facts["gate"]["basis"],
            "Publication requires independent approval of these checked bytes",
        )
        facts["publication"] = publication.prepare(
            root, run.subject["destination"], facts["gate"]["public"], None, directory=True
        )
        state.phase = "install_ready"
        return dict(facts["publication"])
    if action == "publish":
        require(state.phase == "install_ready", "No checked bundle prepared for installation")
        proof = publication.install(root, facts["publication"])
        state.phase, state.terminal = "published", "completed"
        return {
            **proof,
            "source": run.subject["source_lock"],
            "task_ids": sorted(facts["gate"]["tasks"]),
        }
    raise ValueError("Unsupported decomposition operation")
