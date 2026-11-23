#!/usr/bin/env python3
"""Local Review lifecycle. No model calls, remote writes, or Implement graph."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
from collections.abc import Iterable, Iterator
from contextlib import contextmanager
from hashlib import sha256
from pathlib import Path
from typing import Any

from pydantic import TypeAdapter, ValidationError

from factory import file_reader
from factory.paths import FACTORY_ROOT
from factory.review.protocol.contracts import IDENTITY_FIELDS, validate_manifest
from factory.review.protocol.diff import load_diff_context
from factory.review.protocol.evidence import validate_tool_results
from factory.review.protocol.lenses import validate_lens
from factory.review.protocol.plan import prepare, questions
from factory.review.protocol.shapes import InputLock, ReviewAssignment
from factory.review.render_review_report import render_report
from factory.review.run_tool_checks import collect_results
from factory.review.validate_review_protocol import validate_protocol
from factory.runtime.workflow_config import default_profile
from factory.runtime.workflow_core import atomic_json, lock
from factory.validation import validation_message

INPUT_LOCK = TypeAdapter[InputLock](InputLock)
REVIEW_ASSIGNMENT = TypeAdapter[ReviewAssignment](ReviewAssignment)


def read(path: str | Path) -> dict[str, Any]:
    return decode_artifact(path, file_reader.read_bytes(Path(path)))


def decode_artifact(path: str | Path, raw: bytes) -> dict[str, Any]:
    try:
        value = json.loads(raw.decode("utf-8"))
    except (ValueError, UnicodeError) as exc:
        raise ValueError(f"{path}: invalid JSON: {exc}") from None
    if not isinstance(value, dict):
        raise ValueError(f"{path}: Review artifact must be a JSON object")
    return value


def write(path: str | Path, data: object) -> None:
    # Immutable attempt files; callers may never replace a healthy result.
    with Path(path).open("x", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")


@contextmanager
def locked(run: Path, legacy_owner_pid: int | None = None) -> Iterator[None]:
    if not (run / "inputs.json").is_file():
        raise ValueError("review run is not initialized")
    with lock(run / ".review.lock", create_parents=False):
        marker = run / ".busy"
        if marker.exists() or marker.is_symlink():
            if legacy_owner_pid is None:
                raise ValueError(
                    "legacy .busy has no owner identity; verify the old operation stopped"
                )
            if marker.is_symlink() or not marker.is_dir() or any(marker.iterdir()):
                raise ValueError("legacy .busy is not an empty directory")
        if legacy_owner_pid is not None:
            if os.name == "nt" or legacy_owner_pid <= 0:
                raise ValueError("legacy owner PID verification requires a positive POSIX PID")
            try:
                os.kill(legacy_owner_pid, 0)
            except ProcessLookupError:
                pass
            else:
                raise ValueError("legacy owner PID is still active")
        yield
        if legacy_owner_pid is not None and marker.is_dir():
            marker.rmdir()


def hashes(paths: Iterable[str]) -> dict[str, str | None]:
    return {
        p: sha256(file_reader.read_bytes(Path(p))).hexdigest() if Path(p).is_file() else None
        for p in sorted(set(paths))
    }


def fresh(run: Path, *, upgrade_legacy: bool = False) -> dict[str, Any]:
    manifest_path = run / "manifest.json"
    manifest_bytes = file_reader.read_bytes(manifest_path)
    try:
        lock = INPUT_LOCK.validate_python(read(run / "inputs.json"))
    except ValidationError as exc:
        raise ValueError(validation_message("Invalid review input lock", exc, INPUT_LOCK)) from None
    if sha256(manifest_bytes).hexdigest() != lock["manifest_sha256"]:
        raise ValueError("review manifest drift")
    manifest = decode_artifact(manifest_path, manifest_bytes)
    if Path.cwd().resolve() != Path(lock["workspace"]):
        raise ValueError("run must be used from its reviewed workspace")
    actual = hashes(lock["files"])
    changed = {p for p in actual if actual[p] != lock["files"][p]}
    if changed:
        # Lock-only migration from the three exact files present in dfe5cfba.
        legacy = {
            str(
                (FACTORY_ROOT / "tooling/factory/runtime/command_worker.py").resolve()
            ): "1f3d94ab067ff89e744fc518901a31fb35f9792bc5596599c65cea0adb095e22",
            str(
                (FACTORY_ROOT / "tooling/factory/review/review_run.py").resolve()
            ): "f8fbac0a730eb92908f0da6fea92fc6097785de4441fe677dff2fcf3b98916ec",
            str(
                (FACTORY_ROOT / "skills/factory-code-review/references/run-contract.md").resolve()
            ): "5296c319ffd9af0d04f21e2265d4549a522de0dc4d96b1ea76fcd6295fd5afa2",
        }
        reviewed = set(manifest["scope_files"]) | set(manifest["source_evidence"])
        reviewed.update(p for c in manifest["checks"] for p in c["execution"].get("inputs", []))
        if manifest.get("diff_file"):
            reviewed.add(manifest["diff_file"])
        reviewed_paths = {str(Path(p).resolve()) for p in reviewed}
        if (
            not upgrade_legacy
            or not changed <= legacy.keys()
            or any(lock["files"].get(p) != digest for p, digest in legacy.items())
            or any(str(Path(p).resolve()) in reviewed_paths for p in changed)
            or any(actual[p] is None for p in changed)
        ):
            if upgrade_legacy:
                raise ValueError(
                    "review source drift outside the supported lock-only upgrade; "
                    "start a new run and retain this run"
                )
            raise ValueError("review source drift; start a new run")
    if (
        manifest["mode"] in {"pr", "branch"}
        and subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
        != manifest["head_sha"]
    ):
        raise ValueError("review HEAD changed; new intake required")
    if manifest["mode"] in {"pr", "branch"} and subprocess.check_output(
        ["git", "status", "--porcelain", "--untracked-files=no"], text=True
    ):
        raise ValueError("review checkout changed; new intake required")
    errors = validate_manifest(manifest)
    if errors:
        raise ValueError("; ".join(errors))
    if changed:
        lock["files"] = actual
        atomic_json(run / "inputs.json", INPUT_LOCK.validate_python(lock))
    return manifest


def attempts(run: Path, kind: str, key: str) -> list[tuple[int, Path]]:
    """Enumerate only this exact ID's numbered attempt files."""
    prefix = f"{kind}-{key}-"
    pattern = re.compile(re.escape(prefix) + r"([1-9][0-9]*)\.json")
    found = []
    for path in run.glob(prefix + "*.json"):
        match = pattern.fullmatch(path.name)
        if match:
            found.append((int(match.group(1)), path))
    return sorted(found)


def current(run: Path, kind: str, key: str) -> Path | None:
    paths = attempts(run, kind, key)
    return paths[-1][1] if paths else None


def tools(run: Path, manifest: dict[str, Any]) -> list[Path]:
    return [p for c in manifest["checks"] if (p := current(run, "check", c["id"]))]


def inspect(run: Path, manifest: dict[str, Any]) -> dict[str, Any]:
    diff, errors = load_diff_context(manifest)
    _, counts, tool_errors, _ = validate_tool_results(tools(run, manifest), manifest)
    registry = {a["id"]: a["criteria"] for a in manifest["assignments"]}
    result = {}
    for a in manifest["assignments"]:
        path = current(run, "reviewer", a["id"])
        if path is None:
            result[a["id"]] = {"status": "PENDING", "errors": []}
            continue
        try:
            _, _, failures, _ = validate_lens(read(path), manifest, diff, counts, registry)
            result[a["id"]] = {"status": "FAILED" if failures else "COMPLETE", "errors": failures}
        except (ValueError, KeyError, TypeError) as exc:
            result[a["id"]] = {"status": "FAILED", "errors": [str(exc)]}
    return {
        "reviewers": result,
        "source_errors": errors,
        "check_errors": tool_errors,
        "checks": {
            c["id"]: read(p)["status"] if (p := current(run, "check", c["id"])) else "PENDING"
            for c in manifest["checks"]
        },
    }


def attempt_path(run: Path, kind: str, key: str) -> Path:
    paths = attempts(run, kind, key)
    if len(paths) >= 2 or (paths and paths[-1][0] >= 2):
        raise ValueError("recovery exhausted; retain partial results")
    return run / f"{kind}-{key}-{paths[-1][0] + 1 if paths else 1}.json"


def reconcile_check(run: Path, manifest: dict[str, Any]) -> None:
    marker = run / ".check-in-progress"
    if not marker.exists():
        return
    pending = read(marker)
    check_id, attempt = pending.get("id"), pending.get("attempt")
    path = current(run, "check", check_id) if isinstance(check_id, str) else None
    results, _, errors, _ = validate_tool_results([path] if path else [], manifest)
    relevant = [
        e
        for e in errors
        if not e.endswith(": missing result") and ": command unavailable: " not in e
    ]
    value = results.get(check_id) if isinstance(check_id, str) else None
    legacy_complete = attempt is None and value is not None and value["status"] in {"PASS", "FAIL"}
    if path is None or (path.name != attempt and not legacy_complete) or value is None or relevant:
        raise ValueError(
            f"{marker}: interrupted check has unknown outcome; inspect the command and logs before starting a new review"
        )
    marker.unlink()


def initialize(request: Path, run: Path) -> dict[str, Any]:
    manifest = prepare(read(request), default_profile(FACTORY_ROOT / "factory.yaml", "reviewer"))
    errors = validate_manifest(manifest)
    _, diff_errors = load_diff_context(manifest)
    if errors or diff_errors:
        raise ValueError("; ".join(errors + diff_errors))
    if manifest["mode"] in {"pr", "branch"}:
        head = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
        dirty = subprocess.check_output(
            ["git", "status", "--porcelain", "--untracked-files=no"], text=True
        )
        if head != manifest["head_sha"] or dirty:
            raise ValueError(
                "review needs clean checkout at pinned head; preserve user work and use a separate checkout"
            )
    if manifest["mode"] in {"pr", "branch"}:
        actual = subprocess.check_output(
            [
                "git",
                "diff",
                "--no-ext-diff",
                "--no-color",
                manifest["base_sha"] + "..." + manifest["head_sha"],
            ]
        )
        if actual != file_reader.read_bytes(Path(manifest["diff_file"])):
            raise ValueError(
                "diff differs from reviewed Git comparison; capture canonical git diff"
            )
    for p, value in manifest["source_evidence"].items():
        if (
            not Path(p).is_file()
            or file_reader.read_text(Path(p), encoding="utf-8") != value["content"]
        ):
            raise ValueError("source evidence does not match reviewed checkout")
    paths = list(manifest["scope_files"]) + list(manifest["source_evidence"])
    for c in manifest["checks"]:
        for p in c["execution"].get("inputs", []):
            if not Path(p).is_file():
                raise ValueError(f"missing check input: {p}")
            paths.append(p)
    paths += [str(p.resolve()) for p in (FACTORY_ROOT / "gates/skills/code-review").glob("*.py")]
    paths += [
        str(p.resolve())
        for directory, pattern in [
            ("tooling/bin", "project.py"),
            ("contracts/common", "*.md"),
            ("skills/factory-code-review/references", "*.md"),
        ]
        for p in (FACTORY_ROOT / directory).glob(pattern)
    ]
    paths += [
        str((FACTORY_ROOT / p).resolve())
        for p in [
            "factory.yaml",
            "roles/reviewer.md",
            "contracts/reviewer.md",
            "gates/roles/reviewer.md",
            "gates/common/verification-rules.md",
            "tooling/factory/context/context.py",
            "tooling/factory/checks/command.py",
            "tooling/factory/runtime/commands/process.py",
            "skills/factory-code-review/SKILL.md",
        ]
    ]
    paths += [str(p.resolve()) for p in (FACTORY_ROOT / "tooling/factory").rglob("*.py")]
    paths.append(str(FACTORY_ROOT / "skills/factory-code-review/scripts/review_run.py"))
    paths.append(str(Path(__file__).resolve()))
    if manifest.get("diff_file"):
        paths.append(manifest["diff_file"])
    run.mkdir(parents=True, exist_ok=False)
    write(run / "manifest.json", manifest)
    inputs_pending = run / ".inputs-pending.json"
    write(
        inputs_pending,
        INPUT_LOCK.validate_python(
            {
                "workspace": str(Path.cwd().resolve()),
                "files": hashes(paths),
                "manifest_sha256": sha256(
                    file_reader.read_bytes(run / "manifest.json")
                ).hexdigest(),
            }
        ),
    )
    os.replace(inputs_pending, run / "inputs.json")
    return inspect(run, manifest)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "action",
        choices=["init", "status", "assignment", "check", "submit", "finish", "recover-legacy"],
    )
    parser.add_argument("--run", type=Path, required=True)
    parser.add_argument("--input", type=Path)
    parser.add_argument("--id")
    parser.add_argument("--legacy-owner-pid", type=int)
    args = parser.parse_args()
    run = args.run.resolve()
    if args.action == "init":
        print(json.dumps(initialize(args.input, run), ensure_ascii=False))
        return
    if args.action == "recover-legacy" and args.legacy_owner_pid is None:
        raise ValueError("recover-legacy requires --legacy-owner-pid")
    if args.action != "recover-legacy" and args.legacy_owner_pid is not None:
        raise ValueError("--legacy-owner-pid requires recover-legacy")
    with locked(run, args.legacy_owner_pid):
        m = fresh(run, upgrade_legacy=args.action == "recover-legacy")
        state = inspect(run, m)
        reconcile_check(run, m)
        if args.action in {"status", "recover-legacy"}:
            result = state
        elif args.action == "assignment":
            a = next(a for a in m["assignments"] if a["id"] == args.id)
            result = dict(
                REVIEW_ASSIGNMENT.validate_python(
                    {
                        **{k: m[k] for k in IDENTITY_FIELDS},
                        "name": a["name"],
                        "profile": a["profile"],
                        "lens": a["id"],
                        "source": {"kind": "review", "target": m["target"]},
                        "task": {"scope": m["scope_files"]},
                        "project_policy": m["project_policy"],
                        "manifest": str(run / "manifest.json"),
                        "context": m["context"],
                        "owned_gates": questions(m, a["id"]),
                        "parent_evidence": [str(p) for p in tools(run, m)],
                    }
                )
            )
        elif args.action == "check":
            c = next(c for c in m["checks"] if c["id"] == args.id)
            previous = current(run, "check", c["id"])
            if previous and read(previous)["status"] not in {"BLOCKED", "NOT_RUN"}:
                raise ValueError("completed command cannot be rerun inside this review identity")
            if any(state["checks"][dep] != "PASS" for dep in c.get("after", [])):
                raise ValueError("dependency has no current PASS")
            path = attempt_path(run, "check", c["id"])
            from functools import partial

            from factory.review.run_tool_checks import run_command

            execution = {
                k: v for k, v in c["execution"].items() if k in {"argv", "cwd", "timeout_seconds"}
            }
            marker = run / ".check-in-progress"
            write(marker, {"id": c["id"], "attempt": path.name})
            result = collect_results(
                m, c["id"], [json.dumps(execution)], run=partial(run_command, log_dir=run / "logs")
            )
            write(path, result)
            fresh(run)  # A command changing reviewed input never leaves acceptable evidence.
            marker.unlink()
        elif args.action == "submit":
            if args.id not in state["reviewers"]:
                raise ValueError("unknown assignment")
            if state["reviewers"][args.id]["status"] == "COMPLETE":
                raise ValueError("healthy assignment cannot be replaced")
            value = read(args.input)
            if not isinstance(value, dict):
                value = {"lens": args.id, "malformed_result": value}
            if value.get("lens") != args.id:
                raise ValueError("wrong assignment")
            previous = current(run, "reviewer", args.id)
            if previous:
                diff, _ = load_diff_context(m)
                _, counts, _, _ = validate_tool_results(tools(run, m), m)
                registry = {a["id"]: a["criteria"] for a in m["assignments"]}
                _, retained, _, _ = validate_lens(read(previous), m, diff, counts, registry)
                supplied = value.get("findings", [])
                if not isinstance(supplied, list):
                    supplied = []
                for finding in retained:
                    original = {
                        k: v for k, v in finding.items() if k not in {"found_by", "source_ids"}
                    }
                    matches = [
                        f
                        for f in supplied
                        if isinstance(f, dict) and f.get("finding_id") == finding["finding_id"]
                    ]
                    if matches and any(f != original for f in matches):
                        raise ValueError(
                            "recovery cannot rewrite a validated finding; use QA with evidence"
                        )
                    if not matches:
                        supplied.append(original)
                value["findings"] = supplied
            write(attempt_path(run, "reviewer", args.id), value)
            result = inspect(run, m)
        else:
            # Immutable final attempts preserve QA decisions and partial reports.
            folder = run / f"final-{len(list(run.glob('final-*'))) + 1}"
            folder.mkdir()
            write(folder / "qa.json", read(args.input))
            final_result, _ = validate_protocol(
                argparse.Namespace(
                    manifest=run / "manifest.json",
                    lens_output=[
                        p for a in m["assignments"] if (p := current(run, "reviewer", a["id"]))
                    ],
                    tool_result=tools(run, m),
                    qa_output=folder / "qa.json",
                )
            )
            fresh(run)
            write(folder / "result.json", final_result)
            render_report(folder / "report.md", final_result)
            print(json.dumps(final_result, ensure_ascii=False, indent=2))
            return
        print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, StopIteration, TypeError) as exc:
        raise SystemExit(f"Review blocked: {exc}") from exc
