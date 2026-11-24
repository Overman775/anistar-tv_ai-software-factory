#!/usr/bin/env python3
"""Prepare an identity-bound review request or assemble reviewed local tasks."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Annotated, Literal, NotRequired

from pydantic import ConfigDict, Field, TypeAdapter, ValidationError, with_config
from typing_extensions import TypedDict

from factory import file_reader
from factory.cli_output import emit_error, emit_json
from factory.decompose.contracts import LoadedTask, Text
from factory.decompose.graph.task_data import find_markdown_file, load_source_lock, load_tasks
from factory.decompose.staging.manifest import Sha256, read_done_signal
from factory.decompose.staging.output_safety import (
    atomic_write_text,
    guard_evidence_aliases,
    guard_output,
    protected_inputs,
    review_inputs,
    review_worker_materials,
)
from factory.environment import bundle_python_environment
from factory.gates.catalog import core_result
from factory.gates.gate_contract import GateCheck, GateResult, digest, evidence
from factory.paths import FACTORY_ROOT
from factory.planning.plan_document import parse_metadata, parse_revision
from factory.planning.validate_plan import validate as validate_plan
from factory.project.contracts import Policy, Selection
from factory.project.profile_io import check_frozen as check_frozen
from factory.project.profile_io import (
    freeze_materials,
    load_profile,
    safe_path,
    sha,
)
from factory.project.project import configured_profile
from factory.project.skill_gates import artifact_hash, check_decomposition_gates
from factory.validation import validation_message

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
        for key in ("author_done", "repair_done", "previous_request"):
            if path := getattr(args, key, None):
                protected.add(Path(path).resolve())
        guard_output(args.request, protected)
        if getattr(args, "review", None):
            protected.add(Path(args.review).resolve())
            guard_output(args.request, protected)
        protected.add(request)
    guard_output(args.evidence_dir, protected)
    guard_evidence_aliases(args.evidence_dir)


def binding(
    config: str | Path,
    staging: str | Path,
    source: str | Path,
    selected: dict[str, str] | None = None,
) -> tuple[Policy, str, str]:
    policy = load_profile(configured_profile(config))
    artifacts = artifact_hash(staging, source)
    core = {
        p.relative_to(FACTORY_ROOT).as_posix(): sha(file_reader.read_bytes(p))
        for p in sorted(review_inputs())
    }
    selections: list[Selection] = [dict(process="decompose", audience="coordinator", scope=None)]
    selections += [
        dict(process="decompose", audience="worker", role=r, scope=None)
        for r in ("task-decomposer", "task-reviewer")
    ]
    documents = freeze_materials(policy, policy["workspace"], selections)
    agents = Path(policy["workspace"]) / "AGENTS.md"
    agents_hash = sha(file_reader.read_bytes(agents)) if agents.exists() else None
    workers = review_worker_materials(config, selected or {})
    coordinator = {
        rel: sha(file_reader.read_bytes(FACTORY_ROOT / rel))
        for rel in (
            "gates/skills/decompose/gate.md",
            "skills/factory-decompose/SKILL.md",
            "skills/factory-decompose/references/output-contract.md",
            "contracts/common/agent-checkpoint.md",
            "contracts/common/project-policy.md",
        )
    }
    return (
        policy,
        artifacts,
        digest(
            {
                "version": 4,
                "project": policy["hash"],
                "core": core,
                "documents": documents,
                "agents": agents_hash,
                "workers": workers,
                "coordinator": coordinator,
            }
        ),
    )


def inspect(
    config: str | Path,
    staging: str | Path,
    source: str | Path,
    output_dir: str | Path,
    selected: dict[str, str] | None = None,
    *,
    expected_artifacts: str | None = None,
) -> tuple[Policy, str, str, dict[str, LoadedTask], list[GateCheck]]:
    """Run core checks and project supplements separately to retain mixed outcomes."""
    policy, artifacts, policy_hash = binding(config, staging, source, selected)
    if expected_artifacts is not None and expected_artifacts != artifacts:
        raise ValueError("Staging changed after Done Signal validation")
    lock, source_errors = load_source_lock(source)
    if lock is not None and lock.get("project_policy_sha256") != policy["hash"]:
        source_errors.append("Project policy changed: new intake required")
    if lock is not None and not source_errors:
        try:
            plan_text = file_reader.read_text(Path(lock["plan_path"]), encoding="utf-8")
            source_errors += [str(x) for x in validate_plan(plan_text, phase="approved")]
            metadata, _ = parse_metadata(plan_text)
            if (
                metadata.get("plan_id") != lock["plan_id"]
                or parse_revision(metadata.get("revision", "")) != lock["plan_revision"]
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
        "-P",
        "-s",
        "-B",
        "-m",
        "factory.cli",
        "decompose",
        "graph",
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
    completed = subprocess.run(
        command, env=bundle_python_environment(), capture_output=True, text=True, check=False
    )
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
    if binding(config, staging, source, selected)[1:] != (artifacts, policy_hash):
        source_record = evidence(
            "source", "BLOCKED", "Inputs changed during validation", [str(source)]
        )
    return policy, artifacts, policy_hash, tasks, [source_record, graph_record, project_record]


@with_config(ConfigDict(strict=True, extra="forbid"))
class ReviewIdentity(TypedDict):
    run_id: Text
    assignment_id: Text
    reviewer_id: Text
    role: Literal["task-reviewer"]


@with_config(ConfigDict(strict=True, extra="forbid"))
class ReviewRequest(ReviewIdentity):
    author_id: Text
    artifact_hash: Text
    policy_hash: Text
    task_ids: Annotated[list[Text], Field(min_length=1)]
    criteria: list[Text]
    source_lock_sha256: Sha256
    author_manifest: dict[Text, Sha256]
    repaired: bool
    profiles: NotRequired[dict[Literal["task-decomposer", "task-reviewer"], Text]]


@with_config(ConfigDict(strict=True, extra="forbid"))
class ReviewFinding(TypedDict):
    id: Text
    blocking: bool
    message: Text
    evidence: Annotated[list[Text], Field(min_length=1)]


@with_config(ConfigDict(strict=True, extra="forbid"))
class ReviewReport(ReviewIdentity):
    request_hash: Text
    verdict: Literal["APPROVE", "NEEDS_WORK", "BLOCKED"]
    criteria: list[GateCheck]
    findings: list[ReviewFinding]


REVIEW_REQUEST = TypeAdapter[ReviewRequest](ReviewRequest)
REVIEW_REPORT = TypeAdapter[ReviewReport](ReviewReport)


def validate_request(raw: object) -> ReviewRequest:
    try:
        request = REVIEW_REQUEST.validate_python(raw)
    except ValidationError as exc:
        raise ValueError(
            validation_message("Invalid review request", exc, REVIEW_REQUEST)
        ) from None
    if request["author_id"] == request["reviewer_id"]:
        raise ValueError("TaskReviewer must be independent of the author")
    if request["criteria"] != REVIEW_CRITERIA or len(set(request["task_ids"])) != len(
        request["task_ids"]
    ):
        raise ValueError("Invalid review coverage")
    return request


def review_record(
    raw_request: object,
    raw_report: object,
    artifacts: str,
    policy_hash: str,
    task_ids: dict[str, LoadedTask],
    reference: str | Path,
) -> GateCheck:
    try:
        request = validate_request(raw_request)
        if (request["artifact_hash"], request["policy_hash"], request["task_ids"]) != (
            artifacts,
            policy_hash,
            sorted(task_ids),
        ):
            raise ValueError("Review request is stale: rebind current tasks and repeat review")
        report = REVIEW_REPORT.validate_python(raw_report)
        if report["request_hash"] != digest(raw_request) or any(
            report[k] != request[k] for k in ("run_id", "assignment_id", "reviewer_id", "role")
        ):
            raise ValueError("TaskReviewer identity or request mismatch")
        records = report["criteria"]
        if len(records) != len(REVIEW_CRITERIA) or {c["id"] for c in records} != set(
            REVIEW_CRITERIA
        ):
            raise ValueError("Unknown/duplicate/missing review criteria")
        findings = report["findings"]
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
    except ValidationError as exc:
        return evidence(
            "task-review",
            "BLOCKED",
            validation_message("Invalid TaskReviewer report", exc, REVIEW_REPORT),
            [str(reference)],
        )
    except (ValueError, KeyError, TypeError) as exc:
        return evidence("task-review", "BLOCKED", str(exc), [str(reference)])


def validate_repair(
    args: argparse.Namespace,
    previous: ReviewRequest,
    manifest: dict[str, str],
    profiles: dict[str, str],
) -> None:
    if (
        previous["repaired"]
        or (previous["run_id"], previous["author_id"], previous["reviewer_id"])
        != (args.run_id, args.author_id, args.reviewer_id)
        or previous["assignment_id"] == args.assignment_id
        or previous.get("profiles", {}) != profiles
    ):
        raise ValueError(
            "Reviewer repair needs the original review assignment and a new request ID"
        )
    original = previous["author_manifest"]
    if set(p for p in original if Path(p).name == "task_result.json") != {
        p for p in manifest if Path(p).name == "task_result.json"
    } or len(original) != len(manifest):
        raise ValueError("Reviewer repair cannot add, remove or move tasks to a new scope")


class ReviewRequestRejection(TypedDict):
    status: Literal["FAIL", "BLOCKED"]
    checks: list[GateCheck]


class AssemblyGateRejected(ValueError):
    def __init__(self, result: GateResult | ReviewRequestRejection) -> None:
        messages = "; ".join(c["message"] for c in result["checks"] if c["status"] != "PASS")
        super().__init__(f"Gate {result['status']}: {messages}")
        self.result = result


def prepare(args: argparse.Namespace) -> ReviewRequest:
    preflight_outputs(args, assembling=False)
    initial = getattr(args, "author_done", None)
    repair = getattr(args, "repair_done", None)
    previous = getattr(args, "previous_request", None)
    signal = initial or repair
    if signal is None or not (
        (initial and not repair and not previous) or (repair and previous and not initial)
    ):
        raise ValueError("Provide --author-done or both --previous-request and --repair-done")
    source_hash = sha(file_reader.read_bytes(Path(args.source_lock)))
    old = validate_request(json.loads(file_reader.read_bytes(Path(previous)))) if previous else None
    if old is not None and source_hash != old["source_lock_sha256"]:
        raise ValueError("Reviewer repair changed the accepted source lock")
    expected = artifact_hash(args.staging_dir, args.source_lock)
    manifest = read_done_signal(signal, args.staging_dir)
    profiles = {
        role: name
        for role, name in (
            ("task-decomposer", getattr(args, "decomposer_profile", None)),
            ("task-reviewer", getattr(args, "reviewer_profile", None)),
        )
        if name is not None
    }
    if old is not None:
        validate_repair(args, old, manifest, profiles)
    policy, artifacts, policy_hash, tasks, records = inspect(
        args.config,
        args.staging_dir,
        args.source_lock,
        args.evidence_dir,
        profiles,
        expected_artifacts=expected,
    )
    if any(r["status"] != "PASS" for r in records):
        status: Literal["FAIL", "BLOCKED"] = (
            "FAIL" if any(r["status"] == "FAIL" for r in records) else "BLOCKED"
        )
        raise AssemblyGateRejected({"status": status, "checks": records})
    if old is not None and (old["task_ids"] != sorted(tasks) or old["policy_hash"] != policy_hash):
        raise ValueError("Reviewer repair changed task identity or accepted policy")
    raw_request = {
        "run_id": args.run_id,
        "assignment_id": args.assignment_id,
        "author_id": args.author_id,
        "reviewer_id": args.reviewer_id,
        "role": "task-reviewer",
        "artifact_hash": artifacts,
        "policy_hash": policy_hash,
        "task_ids": sorted(tasks),
        "criteria": REVIEW_CRITERIA,
        "source_lock_sha256": source_hash,
        "author_manifest": old["author_manifest"] if old else manifest,
        "repaired": old is not None,
    }
    if profiles:
        raw_request["profiles"] = profiles
    request = validate_request(raw_request)
    guard_output(
        args.request, protected_inputs(args.config, args.staging_dir, args.source_lock, policy)
    )
    write_json(args.request, request)
    return request


def assemble(args: argparse.Namespace) -> dict[str, object]:
    preflight_outputs(args, assembling=True)
    try:
        review_inputs = {
            Path(p): file_reader.read_bytes(Path(p)) for p in (args.request, args.review)
        }
        request = json.loads(review_inputs[Path(args.request)])
        report = json.loads(review_inputs[Path(args.review)])
    except OSError, ValueError:
        request, report = {}, {}
    try:
        selected: dict[str, str] = {
            role: name for role, name in validate_request(request).get("profiles", {}).items()
        }
    except ValueError:
        selected = {}
    policy, artifacts, policy_hash, tasks, records = inspect(
        args.config, args.staging_dir, args.source_lock, args.evidence_dir, selected
    )
    records.append(review_record(request, report, artifacts, policy_hash, tasks, args.review))
    result = core_result(
        "decompose.complete",
        str(request.get("run_id") or Path(args.source_lock).absolute()),
        policy_hash,
        artifacts,
        records,
    )
    write_json(Path(args.evidence_dir) / "gate-result.json", result)
    if result["status"] != "PASS":
        raise AssemblyGateRejected(result)
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
            file_reader.copy_file(Path(source_file), target / task["filename"])
        if len(tasks) > 1:
            lock = json.loads(file_reader.read_text(Path(args.source_lock), encoding="utf-8"))
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
            graph = file_reader.read_text(Path(args.evidence_dir) / "graph.md", encoding="utf-8")
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
                + "\n```\n",
                encoding="utf-8",
            )
        if binding(args.config, args.staging_dir, args.source_lock, selected)[1:] != (
            artifacts,
            policy_hash,
        ):
            raise ValueError("Inputs changed before final assembly")
        # Require copied bytes to equal reviewed bytes, not merely unchanged filenames.
        for task in tasks.values():
            if file_reader.read_bytes(target / task["filename"]) != file_reader.read_bytes(
                Path(find_markdown_file(task, task["file"]) or "")
            ):
                raise ValueError("Task bytes changed while copying")
        if any(file_reader.read_bytes(path) != content for path, content in review_inputs.items()):
            raise ValueError("Review inputs changed during assembly")
        if destination.exists():
            raise ValueError("Destination appeared during assembly")
        target.rename(destination)
    return result | {"destination": str(destination)}


def build_parser(
    parser: argparse.ArgumentParser | None = None,
) -> argparse.ArgumentParser:
    parser = parser or argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["review-request", "assemble"])
    parser.add_argument("--config", default=str(FACTORY_ROOT / "factory.yaml"))
    parser.add_argument("--staging-dir", required=True)
    parser.add_argument("--source-lock", required=True)
    parser.add_argument("--request", required=True)
    parser.add_argument("--evidence-dir", required=True)
    parser.add_argument("--review")
    parser.add_argument("--author-done")
    parser.add_argument("--repair-done")
    parser.add_argument("--previous-request")
    parser.add_argument("--bundle-id")
    parser.add_argument("--decomposer-profile")
    parser.add_argument("--reviewer-profile")
    for key in ("run-id", "assignment-id", "author-id", "reviewer-id"):
        parser.add_argument("--" + key)
    return parser


def run(args: argparse.Namespace, parser: argparse.ArgumentParser) -> int:
    for path in (
        args.request,
        args.evidence_dir,
        args.review,
        args.author_done,
        args.repair_done,
        args.previous_request,
    ):
        if path and Path(path).resolve().is_relative_to(Path(args.staging_dir).resolve()):
            parser.error("Review/evidence files must be outside staging task inputs")
    if args.action == "assemble" and (not args.review or not args.bundle_id):
        parser.error("assemble needs --review and --bundle-id")
    try:
        result = prepare(args) if args.action == "review-request" else assemble(args)
        if args.action == "review-request":
            result = {"request": result, "request_hash": digest(result)}
        print(json.dumps(result, ensure_ascii=False))
    except (ValueError, OSError, KeyError, TypeError) as exc:
        status = exc.result["status"] if isinstance(exc, AssemblyGateRejected) else "BLOCKED"
        if not getattr(args, "json", False):
            print(status + ": " + str(exc), file=sys.stderr)
        elif isinstance(exc, AssemblyGateRejected):
            emit_json(exc.result)
        else:
            emit_error("decompose_assemble", str(exc))
        return 1 if status == "FAIL" else 2
    return 0


def main() -> int:
    parser = build_parser()
    return run(parser.parse_args(), parser)


if __name__ == "__main__":
    sys.exit(main())
