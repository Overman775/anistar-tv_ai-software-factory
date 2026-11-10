#!/usr/bin/env python3
"""Prepare an identity-bound review request or assemble reviewed local tasks."""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

from factory_tooling.decompose.contracts import LoadedTask
from factory_tooling.decompose.output_safety import (
    atomic_write_text,
    factory_inputs,
    guard_evidence_aliases,
    guard_output,
    protected_inputs,
)
from factory_tooling.decompose.task_data import find_markdown_file, load_source_lock, load_tasks
from factory_tooling.gates.catalog import core_result
from factory_tooling.gates.gate_contract import GateCheck, digest, evidence, require_pass
from factory_tooling.paths import FACTORY_ROOT
from factory_tooling.planning.plan_document import parse_metadata
from factory_tooling.planning.validate_plan import validate as validate_plan
from factory_tooling.project.contracts import Policy, Selection
from factory_tooling.project.profile_io import check_frozen as check_frozen
from factory_tooling.project.profile_io import (
    freeze_materials,
    load_profile,
    safe_path,
    sha,
)
from factory_tooling.project.project import configured_profile
from factory_tooling.project.skill_gates import artifact_hash, check_decomposition_gates

REVIEW_CRITERIA = ["plan-coverage", "task-cohesion", "architecture", "verification"]


def write_json(path: str | Path, value: object) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".decompose-output-", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(value, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def preflight_outputs(args: argparse.Namespace, *, assembling: bool) -> None:
    policy = load_profile(configured_profile(args.config))
    protected = protected_inputs(args.config, args.staging_dir, args.source_lock, policy)
    request = Path(args.request).resolve()
    if assembling:
        protected.add(request)
        protected.add(Path(args.review).resolve())
        if not re.fullmatch(r"[a-z0-9][a-z0-9_-]*", args.bundle_id):
            raise ValueError("Safe bundle ID required")
        destination = safe_path(policy["workspace"], "docs/tasks/" + args.bundle_id, exists=False)
        guard_output(destination, protected)
        guard_output(destination, {Path(args.evidence_dir).resolve()})
    else:
        guard_output(args.request, protected)
        if getattr(args, "review", None):
            protected.add(Path(args.review).resolve())
            guard_output(args.request, protected)
        protected.add(request)
    guard_output(args.evidence_dir, protected)
    guard_evidence_aliases(args.evidence_dir)


def binding(config: str | Path, staging: str | Path, source: str | Path) -> tuple[Policy, str, str]:
    policy = load_profile(configured_profile(config))
    artifacts = artifact_hash(staging, source)
    core = {
        p.relative_to(FACTORY_ROOT).as_posix(): sha(p.read_bytes())
        for p in sorted(factory_inputs())
    }
    selections: list[Selection] = [dict(process="decompose", audience="coordinator", scope=None)]
    selections += [
        dict(process="decompose", audience="worker", role=r, scope=None)
        for r in ("task-decomposer", "task-reviewer")
    ]
    documents = freeze_materials(policy, policy["workspace"], selections)
    return (
        policy,
        artifacts,
        digest({"project": policy["hash"], "core": core, "documents": documents}),
    )


def inspect(
    config: str | Path, staging: str | Path, source: str | Path, output_dir: str | Path
) -> tuple[Policy, str, str, dict[str, LoadedTask], list[GateCheck]]:
    """Run core checks and project supplements separately to retain mixed outcomes."""
    policy, artifacts, policy_hash = binding(config, staging, source)
    lock, source_errors = load_source_lock(source)
    if lock is not None and lock.get("project_policy_sha256") != policy["hash"]:
        source_errors.append("Project policy changed: new intake required")
    if lock is not None:
        try:
            plan_text = Path(lock["plan_path"]).read_text()
            source_errors += [str(x) for x in validate_plan(plan_text, phase="approved")]
            metadata, _ = parse_metadata(plan_text)
            if metadata.get("plan_id") != lock["plan_id"] or metadata.get("revision") != str(
                lock["plan_revision"]
            ):
                source_errors.append("Source plan identity/revision differs from intake")
        except (OSError, ValueError) as exc:
            source_errors.append(str(exc))
    source_record = evidence(
        "source",
        "BLOCKED" if source_errors else "PASS",
        "; ".join(source_errors) or "Approved plan and policy are current",
        [str(source)],
    )
    output_dir = Path(output_dir).absolute()
    guard_output(output_dir, protected_inputs(config, staging, source, policy))
    guard_evidence_aliases(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    command = [
        sys.executable,
        str(FACTORY_ROOT / "gates/skills/decompose/generate_task_graph.py"),
        "--config",
        str(config),
        "--staging-dir",
        str(staging),
        "--source-lock",
        str(source),
        "--output",
        str(output_dir / "graph.md"),
        "--core-only",
    ]
    completed = subprocess.run(command, capture_output=True, text=True)
    atomic_write_text(output_dir / "graph.log", completed.stdout + completed.stderr)
    graph_record = evidence(
        "graph",
        "BLOCKED"
        if source_errors
        else "PASS"
        if completed.returncode == 0
        else "FAIL"
        if completed.returncode == 1
        else "BLOCKED",
        "Graph validated"
        if not completed.returncode
        else completed.stderr.strip() or "Graph validation unavailable",
        [str(output_dir / "graph.log")],
    )
    loaded = load_tasks(staging)
    tasks, envelopes = loaded["tasks"], loaded["envelopes"]
    if completed.returncode == 0 and not source_errors:
        project = check_decomposition_gates(policy, tasks, envelopes, staging, source, output_dir)
        states = {r["status"] for r in project}
        state = "FAIL" if "FAIL" in states else "BLOCKED" if "BLOCKED" in states else "PASS"
        message = (
            "; ".join(c["message"] for g in project for c in g["checks"] if c["status"] != "PASS")
            or "All applicable project checks passed"
        )
        project_record = evidence(
            "project-checks",
            state,
            message,
            [
                str(output_dir / "decomposition-gates.json")
                if project
                else "No project checks declared"
            ],
        )
    else:
        project_record = evidence(
            "project-checks",
            "BLOCKED",
            "Core validation must pass before project commands",
            [str(output_dir / "graph.log")],
        )
    if binding(config, staging, source)[1:] != (artifacts, policy_hash):
        source_record = evidence(
            "source", "BLOCKED", "Inputs changed during validation", [str(source)]
        )
    return policy, artifacts, policy_hash, tasks, [source_record, graph_record, project_record]


def validate_request(request: Any) -> None:
    fields = {
        "run_id",
        "assignment_id",
        "author_id",
        "reviewer_id",
        "role",
        "artifact_hash",
        "policy_hash",
        "task_ids",
        "criteria",
    }
    if not isinstance(request, dict) or set(request) != fields:
        raise ValueError("Invalid review request")
    if not all(
        isinstance(request[k], str) and request[k].strip()
        for k in fields - {"task_ids", "criteria"}
    ):
        raise ValueError("Review request needs identities and hashes")
    if request["role"] != "task-reviewer" or request["author_id"] == request["reviewer_id"]:
        raise ValueError("TaskReviewer must be independent of the author")
    if (
        request["criteria"] != REVIEW_CRITERIA
        or not request["task_ids"]
        or len(set(request["task_ids"])) != len(request["task_ids"])
    ):
        raise ValueError("Invalid review coverage")


def review_record(
    request: Any,
    report: Any,
    artifacts: str,
    policy_hash: str,
    task_ids: dict[str, LoadedTask],
    reference: str | Path,
) -> GateCheck:
    try:
        validate_request(request)
        if (request["artifact_hash"], request["policy_hash"], request["task_ids"]) != (
            artifacts,
            policy_hash,
            sorted(task_ids),
        ):
            raise ValueError("Review request is stale: rebind current tasks and repeat review")
        expected = {
            "request_hash",
            "run_id",
            "assignment_id",
            "reviewer_id",
            "role",
            "verdict",
            "criteria",
            "findings",
        }
        if not isinstance(report, dict) or set(report) != expected:
            raise ValueError("Missing/invalid TaskReviewer report")
        if report["request_hash"] != digest(request) or any(
            report[k] != request[k] for k in ("run_id", "assignment_id", "reviewer_id", "role")
        ):
            raise ValueError("TaskReviewer identity or request mismatch")
        if report["verdict"] not in ("APPROVE", "NEEDS_WORK", "BLOCKED"):
            raise ValueError("Invalid review verdict")
        criteria = report["criteria"]
        if not isinstance(criteria, list) or len(criteria) != len(REVIEW_CRITERIA):
            raise ValueError("Incomplete review criteria")
        if {c.get("id") for c in criteria if isinstance(c, dict)} != set(REVIEW_CRITERIA):
            raise ValueError("Unknown/duplicate/missing review criteria")
        records = [evidence(c["id"], c["status"], c["message"], c["evidence"]) for c in criteria]
        findings = report["findings"]
        if not isinstance(findings, list) or any(
            not isinstance(f, dict)
            or set(f) != {"id", "blocking", "message", "evidence"}
            or not isinstance(f["blocking"], bool)
            or any(not isinstance(f[k], str) or not f[k].strip() for k in ("id", "message"))
            or not isinstance(f["evidence"], list)
            or not f["evidence"]
            or any(not isinstance(e, str) or not e.strip() for e in f["evidence"])
            for f in findings
        ):
            raise ValueError("Invalid review findings")
        if len({f["id"] for f in findings}) != len(findings):
            raise ValueError("Duplicate review findings")
        failed = (
            any(c["status"] == "FAIL" for c in records)
            or any(f["blocking"] for f in findings)
            or report["verdict"] == "NEEDS_WORK"
        )
        blocked = any(c["status"] == "BLOCKED" for c in records) or report["verdict"] == "BLOCKED"
        state = "FAIL" if failed else "BLOCKED" if blocked else "PASS"
        details = [c["id"] + ": " + c["message"] for c in records if c["status"] != "PASS"]
        details += [f["id"] + ": " + f["message"] for f in findings if f["blocking"]]
        return evidence(
            "task-review",
            state,
            "TaskReviewer: " + report["verdict"] + "; " + "; ".join(details),
            [str(reference)],
        )
    except (ValueError, KeyError, TypeError) as exc:
        return evidence("task-review", "BLOCKED", str(exc), [str(reference)])


def prepare(args: argparse.Namespace) -> dict[str, Any]:
    preflight_outputs(args, assembling=False)
    policy, artifacts, policy_hash, tasks, records = inspect(
        args.config, args.staging_dir, args.source_lock, args.evidence_dir
    )
    if any(r["status"] != "PASS" for r in records):
        raise ValueError("; ".join(r["message"] for r in records if r["status"] != "PASS"))
    request = {
        "run_id": args.run_id,
        "assignment_id": args.assignment_id,
        "author_id": args.author_id,
        "reviewer_id": args.reviewer_id,
        "role": "task-reviewer",
        "artifact_hash": artifacts,
        "policy_hash": policy_hash,
        "task_ids": sorted(tasks),
        "criteria": REVIEW_CRITERIA,
    }
    validate_request(request)
    guard_output(
        args.request, protected_inputs(args.config, args.staging_dir, args.source_lock, policy)
    )
    write_json(args.request, request)
    return request


def assemble(args: argparse.Namespace) -> dict[str, Any]:
    preflight_outputs(args, assembling=True)
    policy, artifacts, policy_hash, tasks, records = inspect(
        args.config, args.staging_dir, args.source_lock, args.evidence_dir
    )
    try:
        review_inputs = {Path(p): Path(p).read_bytes() for p in (args.request, args.review)}
        request = json.loads(review_inputs[Path(args.request)])
        report = json.loads(review_inputs[Path(args.review)])
    except (OSError, ValueError):
        request, report = {}, {}
    records.append(review_record(request, report, artifacts, policy_hash, tasks, args.review))
    result = core_result(
        "decompose.complete",
        str(request.get("run_id") or Path(args.source_lock).absolute()),
        policy_hash,
        artifacts,
        records,
    )
    write_json(Path(args.evidence_dir) / "gate-result.json", result)
    require_pass(result)
    if not re.fullmatch(r"[a-z0-9][a-z0-9_-]*", args.bundle_id):
        raise ValueError("Safe bundle ID required")
    workspace = Path(policy["workspace"])
    destination = safe_path(workspace, "docs/tasks/" + args.bundle_id, exists=False)
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        raise ValueError("Task bundle already exists; never overwrite existing work")
    # All final files are one atomic directory; preserve staging for recovery.
    with tempfile.TemporaryDirectory(prefix=".decompose-", dir=destination.parent) as tmp:
        target = Path(tmp) / args.bundle_id
        target.mkdir()
        for task in tasks.values():
            source_file = find_markdown_file(task, task["file"])
            if not source_file:
                raise ValueError("Missing task Markdown")
            shutil.copyfile(source_file, target / task["filename"])
        if len(tasks) > 1:
            lock = json.loads(Path(args.source_lock).read_text())
            listing = "\n".join(f"- [{task['id']}]({task['filename']})" for task in tasks.values())
            manifest = {
                "kind": "epic",
                "id": args.bundle_id,
                "title": args.bundle_id,
                "outcome": "Tasks from approved plan " + lock["plan_id"],
                "tasks": [
                    {"id": t["id"], "file": "docs/tasks/" + args.bundle_id + "/" + t["filename"]}
                    for t in tasks.values()
                ],
            }
            graph = (Path(args.evidence_dir) / "graph.md").read_text()
            (target / "epic.md").write_text(
                "# "
                + args.bundle_id
                + "\n\nSource: "
                + lock["plan_id"]
                + " revision "
                + str(lock["plan_revision"])
                + "\n\n"
                + listing
                + "\n\n"
                + graph
                + "\n\n```json\n"
                + json.dumps(manifest, ensure_ascii=False, indent=2)
                + "\n```\n"
            )
        if binding(args.config, args.staging_dir, args.source_lock)[1:] != (artifacts, policy_hash):
            raise ValueError("Inputs changed before final assembly")
        # Require copied bytes to equal reviewed bytes, not merely unchanged filenames.
        for task in tasks.values():
            if (target / task["filename"]).read_bytes() != Path(
                find_markdown_file(task, task["file"]) or ""
            ).read_bytes():
                raise ValueError("Task bytes changed while copying")
        if any(path.read_bytes() != content for path, content in review_inputs.items()):
            raise ValueError("Review inputs changed during assembly")
        if destination.exists():
            raise ValueError("Destination appeared during assembly")
        target.rename(destination)
    return result | {"destination": str(destination)}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["review-request", "assemble"])
    parser.add_argument("--config", default=str(FACTORY_ROOT / "factory.yaml"))
    parser.add_argument("--staging-dir", required=True)
    parser.add_argument("--source-lock", required=True)
    parser.add_argument("--request", required=True)
    parser.add_argument("--evidence-dir", required=True)
    parser.add_argument("--review")
    parser.add_argument("--bundle-id")
    for key in ("run-id", "assignment-id", "author-id", "reviewer-id"):
        parser.add_argument("--" + key)
    args = parser.parse_args()
    for path in (args.request, args.evidence_dir, args.review):
        if path and Path(path).resolve().is_relative_to(Path(args.staging_dir).resolve()):
            parser.error("Review/evidence files must be outside staging task inputs")
    if args.action == "assemble" and (not args.review or not args.bundle_id):
        parser.error("assemble needs --review and --bundle-id")
    return args


if __name__ == "__main__":
    try:
        args = parse_args()
        result = prepare(args) if args.action == "review-request" else assemble(args)
        if args.action == "review-request":
            result = {"request": result, "request_hash": digest(result)}
        print(json.dumps(result, ensure_ascii=False))
    except (ValueError, OSError, KeyError, TypeError) as exc:
        status = "FAIL" if str(exc).startswith("Gate FAIL:") else "BLOCKED"
        print(status + ": " + str(exc), file=sys.stderr)
        sys.exit(1 if status == "FAIL" else 2)
