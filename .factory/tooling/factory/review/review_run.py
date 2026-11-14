#!/usr/bin/env python3
"""Local Review lifecycle. No model calls, remote writes, or Implement graph."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from collections.abc import Iterable, Iterator
from contextlib import contextmanager
from hashlib import sha256
from pathlib import Path
from typing import Any

from pydantic import TypeAdapter, ValidationError

from factory.paths import FACTORY_ROOT
from factory.review.render_review_report import render_report
from factory.review.review_contracts import IDENTITY_FIELDS, validate_manifest
from factory.review.review_diff import load_diff_context
from factory.review.review_evidence import validate_tool_results
from factory.review.review_lenses import validate_lens
from factory.review.review_plan import prepare, questions
from factory.review.review_shapes import InputLock, ReviewAssignment
from factory.review.run_tool_checks import collect_results
from factory.review.validate_review_protocol import validate_protocol
from factory.validation import validation_message

INPUT_LOCK = TypeAdapter[InputLock](InputLock)
REVIEW_ASSIGNMENT = TypeAdapter[ReviewAssignment](ReviewAssignment)


def read(path: str | Path) -> dict[str, Any]:
    value = json.loads(Path(path).read_text())
    if not isinstance(value, dict):
        raise ValueError("Review artifact must be a JSON object")
    return value


def write(path: str | Path, data: object) -> None:
    # Immutable attempt files; callers may never replace a healthy result.
    with Path(path).open("x") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")


@contextmanager
def locked(run: Path) -> Iterator[None]:
    lock = run / ".busy"
    lock.mkdir()  # Exclusive local owner, also for simultaneous background invocations.
    try:
        yield
    finally:
        lock.rmdir()


def hashes(paths: Iterable[str]) -> dict[str, str | None]:
    return {
        p: sha256(Path(p).read_bytes()).hexdigest() if Path(p).is_file() else None
        for p in sorted(set(paths))
    }


def fresh(run: Path) -> dict[str, Any]:
    manifest = read(run / "manifest.json")
    try:
        lock = INPUT_LOCK.validate_python(read(run / "inputs.json"))
    except ValidationError as exc:
        raise ValueError(validation_message("Invalid review input lock", exc, INPUT_LOCK)) from None
    if Path.cwd().resolve() != Path(lock["workspace"]):
        raise ValueError("run must be used from its reviewed workspace")
    if hashes(lock["files"]) != lock["files"]:
        raise ValueError("review source drift; start a new run")
    if sha256((run / "manifest.json").read_bytes()).hexdigest() != lock["manifest_sha256"]:
        raise ValueError("review manifest drift")
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


def initialize(request: Path, run: Path) -> dict[str, Any]:
    manifest = prepare(read(request))
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
        if actual != Path(manifest["diff_file"]).read_bytes():
            raise ValueError(
                "diff differs from reviewed Git comparison; capture canonical git diff"
            )
    for p, value in manifest["source_evidence"].items():
        if not Path(p).is_file() or Path(p).read_text() != value["content"]:
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
            "tooling/factory/runtime/check_process.py",
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
    write(
        run / "inputs.json",
        INPUT_LOCK.validate_python(
            {
                "workspace": str(Path.cwd().resolve()),
                "files": hashes(paths),
                "manifest_sha256": sha256((run / "manifest.json").read_bytes()).hexdigest(),
            }
        ),
    )
    return inspect(run, manifest)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "action", choices=["init", "status", "assignment", "check", "submit", "finish"]
    )
    parser.add_argument("--run", type=Path, required=True)
    parser.add_argument("--input", type=Path)
    parser.add_argument("--id")
    args = parser.parse_args()
    run = args.run.resolve()
    if args.action == "init":
        print(json.dumps(initialize(args.input, run), ensure_ascii=False))
        return
    with locked(run):
        m = fresh(run)
        state = inspect(run, m)
        if args.action == "status":
            result = state
        elif args.action == "assignment":
            a = next(a for a in m["assignments"] if a["id"] == args.id)
            result = dict(
                REVIEW_ASSIGNMENT.validate_python(
                    {
                        **{k: m[k] for k in IDENTITY_FIELDS},
                        "name": a["name"],
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
            result = collect_results(
                m, c["id"], [json.dumps(execution)], run=partial(run_command, log_dir=run / "logs")
            )
            write(path, result)
            fresh(run)  # A command changing reviewed input never leaves acceptable evidence.
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
