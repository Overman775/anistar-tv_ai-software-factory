"""Offline checks share one entry point with CI; dependency auditing is explicit."""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
import subprocess
import sys
import tempfile
import tomllib
from dataclasses import dataclass
from pathlib import Path
from typing import Literal, NotRequired, TypedDict

from factory import file_reader
from factory.cli_output import emit_json
from factory.environment import settings
from factory.paths import FACTORY_ROOT, TOOLS

OFFLINE = ("lint", "format", "types", "imports", "yaml-lint", "yaml-contracts", "tests")


class StageReport(TypedDict):
    stage: str
    status: Literal["PASS", "BLOCKED", "FAIL"]
    exit_code: int | None
    commands: list[list[str]]
    log: str | None
    diagnostics: NotRequired[list[str]]


class CheckerReport(TypedDict):
    status: Literal["PASS", "FAIL"]
    python: str
    executable: str
    source: str
    source_sha256: str
    source_unchanged: bool
    stages: list[StageReport]


@dataclass(frozen=True)
class StageResult:
    stage: str
    status: Literal["PASS", "BLOCKED", "FAIL"]
    exit_code: int | None
    commands: list[list[str]]
    log: str
    diagnostics: list[str]


def source_files() -> list[Path]:
    """Enumerate owned files explicitly, including hidden paths and unexecuted code."""
    roots = [
        TOOLS,
        FACTORY_ROOT / "gates",
        FACTORY_ROOT / "project/gates",
        FACTORY_ROOT / "project/examples/gates",
    ]
    roots += sorted((FACTORY_ROOT / "skills").glob("factory-*/scripts"))
    roots += sorted((FACTORY_ROOT / "skills").glob("factory-*/tests"))
    return sorted(
        {
            p
            for root in roots
            for p in root.rglob("*.py")
            if not {
                ".venv",
                ".python",
                "__pycache__",
                ".mypy_cache",
                ".ruff_cache",
                ".pytest_cache",
                "htmlcov",
            }.intersection(p.parts)
        }
    )


def source_digest() -> str:
    digest = hashlib.sha256()
    files: list[Path] = []
    for directory, dirs, names in FACTORY_ROOT.walk():
        dirs[:] = [
            name
            for name in dirs
            if name not in {".venv", ".python"}
            and not (directory == FACTORY_ROOT and name == "diagnostics")
        ]
        parts = directory.relative_to(FACTORY_ROOT).parts
        if parts == ("memory",):
            dirs[:] = [d for d in dirs if d == "lessons"]
            names = [n for n in names if n == "USER.md"]
        elif parts == ("memory", "lessons"):
            dirs[:] = [d for d in dirs if d in {"project", "factory"}]
            names = []
        elif parts[:2] == ("memory", "lessons"):
            dirs.clear()
            names = [n for n in names if n == ".gitkeep" or n.endswith(".md")]
        files.extend(directory / name for name in names)
    for file in sorted(files):
        parts = file.relative_to(FACTORY_ROOT).parts
        if {
            ".venv",
            ".python",
            ".venv.setup.lock",
            "__pycache__",
            ".mypy_cache",
            ".ruff_cache",
            ".pytest_cache",
            ".DS_Store",
            "htmlcov",
        }.intersection(parts):
            continue
        if parts == (".env",):
            continue
        if file.name.startswith(".coverage") or file.suffix in {".pyc", ".pyo"}:
            continue
        if not file.is_file() and not file.is_symlink():
            continue
        digest.update(str(file.relative_to(FACTORY_ROOT)).encode())
        digest.update(b"\0")
        digest.update(
            str(file.readlink()).encode() if file.is_symlink() else file_reader.read_bytes(file)
        )
        digest.update(b"\0")
    return digest.hexdigest()


def prepare_coverage(reports: Path) -> Path:
    configuration = tomllib.loads(
        file_reader.read_text(TOOLS / "pyproject.toml", encoding="utf-8")
    )["tool"]["coverage"]
    configuration["run"]["source"] = [
        str((TOOLS / source).resolve()) for source in configuration["run"]["source"]
    ]
    data_file = Path(tempfile.mkdtemp(prefix="coverage-", dir=reports)) / ".coverage"
    configuration["run"]["data_file"] = str(data_file)
    lines = []
    for section, values in configuration.items():
        lines.append(f"[tool.coverage.{section}]")
        lines += [f"{key} = {json.dumps(value)}" for key, value in values.items()]
    (reports / "coverage.toml").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return data_file


def verify_subprocess_coverage(reports: Path) -> None:
    """The bootstrap CLI dispatch branch runs only in launcher subprocesses."""
    source = TOOLS / "bootstrap.py"
    tree = ast.parse(file_reader.read_text(source, encoding="utf-8"))
    line = next(
        node.body[0].lineno
        for node in ast.walk(tree)
        if isinstance(node, ast.If) and ast.unparse(node.test) == "args and args[0] == 'cli'"
    )
    report = json.loads(file_reader.read_text(reports / "coverage.json", encoding="utf-8"))
    covered = next(
        (
            value
            for name, value in report["files"].items()
            if (FACTORY_ROOT / name).resolve() == source.resolve()
        ),
        None,
    )
    if covered is None or line not in covered["executed_lines"]:
        raise ValueError("Coverage missed the unified CLI launcher subprocess")


def commands(stage: str, reports: Path, files: list[str]) -> list[list[str]]:
    python = [sys.executable, "-E", "-s", "-B", "-m"]
    config = str(TOOLS / "pyproject.toml")
    if stage == "lint":
        return [[*python, "ruff", "check", "--no-cache", "--config", config, *files]]
    if stage == "format":
        return [[*python, "ruff", "format", "--check", "--no-cache", "--config", config, *files]]
    if stage == "types":
        base = [*python, "mypy", "--config-file", config, "--cache-dir", str(reports / "mypy")]
        # Standalone installed entrypoints may share a basename (for example check.py).
        # Check each outside the package separately rather than excluding any source.
        package_files = [file for file in files if Path(file).is_relative_to(FACTORY_ROOT)]
        standalone = [file for file in files if not Path(file).is_relative_to(FACTORY_ROOT)]
        return [[*base, *package_files], *[[*base, file] for file in standalone]]
    if stage == "imports":
        return [
            [
                sys.executable,
                "-E",
                "-s",
                "-B",
                "-c",
                "from importlinter.cli import lint_imports_command; lint_imports_command()",
                "--config",
                str(TOOLS / "imports.ini"),
                "--no-cache",
            ]
        ]
    if stage == "yaml-lint":
        from factory.yaml_checks import source_files as yaml_files

        return [
            [
                *python,
                "yamllint",
                "--strict",
                "--format",
                "parsable",
                "--config-file",
                str(TOOLS / "yamllint.yaml"),
                *[str(file) for file in yaml_files(FACTORY_ROOT)],
            ]
        ]
    if stage == "yaml-contracts":
        return [[*python, "factory.yaml_checks"]]
    if stage == "tests":
        config = str(reports / "coverage.toml")
        return [
            [*python, "coverage", "run", "--rcfile", config, "-m", "factory.test_suite"],
            [*python, "coverage", "combine", "--rcfile", config],
            [*python, "coverage", "report", "--rcfile", config],
            [*python, "coverage", "json", "--rcfile", config, "-o", str(reports / "coverage.json")],
        ]
    if stage == "audit":
        return [
            [
                *python,
                "pip_audit",
                "--disable-pip",
                "--no-deps",
                "--progress-spinner",
                "off",
                "-r",
                str(TOOLS / name),
            ]
            for name in ("requirements.txt", "requirements-dev.txt")
        ]
    raise ValueError(f"Unknown stage: {stage}")


def run_stage(stage: str, reports: Path, files: list[str]) -> StageResult:
    coverage_file = prepare_coverage(reports) if stage == "tests" else reports / ".coverage"
    log = reports / f"{stage}.log"
    try:
        planned = commands(stage, reports, files)
    except (OSError, ValueError) as exc:
        log.write_text(f"FAIL: {exc}\n", encoding="utf-8")
        return StageResult(stage, "FAIL", 1, [], str(log), [f"FAIL: {exc}"])
    environment = dict(
        settings(),
        OTEL_SDK_DISABLED="true",
        COVERAGE_FILE=str(coverage_file),
        COVERAGE_RCFILE=str(reports / "coverage.toml"),
    )
    environment.pop("MYPYPATH", None)
    code: int | None = 0
    diagnostics: list[str] = []
    with log.open("wb") as output:
        for command in planned:
            command_text = json.dumps(command)
            command_excerpt = command_text[:3000] + (
                " ... [truncated]" if len(command_text) > 3000 else ""
            )
            output.write((command_text + "\n").encode("utf-8"))
            output.flush()
            start = output.tell()
            try:
                completed = subprocess.run(
                    command,
                    cwd=FACTORY_ROOT,
                    env=environment,
                    stdout=output,
                    stderr=subprocess.STDOUT,
                    check=False,
                )
            except OSError as exc:
                output.write(f"BLOCKED: {exc}\n".encode())
                code = None
                diagnostics.append(f"Command: {command_excerpt}\nBLOCKED: {exc}")
                break
            if completed.returncode:
                output.flush()
                end = output.tell()
                with file_reader.open_binary(log) as source:
                    source.seek(max(start, end - 16000))
                    excerpt = source.read(end - source.tell()).decode("utf-8", errors="replace")
                excerpt = "\n".join(excerpt.splitlines()[-80:])
                diagnostics.append(f"Command: {command_excerpt}\n{excerpt}")
                code = completed.returncode
                # Keep test coverage even when tests fail, and audit both dependency sets.
                if stage not in {"tests", "audit", "types"}:
                    break
        if stage == "tests" and code == 0:
            try:
                verify_subprocess_coverage(reports)
                output.write(b"PASS: coverage includes the real launcher subprocess\n")
            except (OSError, ValueError, KeyError) as exc:
                output.write(f"FAIL: {exc}\n".encode())
                diagnostics.append(f"FAIL: {exc}")
                code = 1
    return StageResult(
        stage,
        "PASS" if code == 0 else "BLOCKED" if code is None else "FAIL",
        code,
        planned,
        str(log),
        diagnostics,
    )


def check(stages: list[str], reports: Path, *, as_json: bool = False, retain: bool = True) -> int:
    reports.mkdir(parents=True, exist_ok=True)
    before = source_digest()
    files = [str(p) for p in source_files()] if set(stages) & {"lint", "format", "types"} else []
    results = []
    progress = sys.stderr if as_json else sys.stdout
    for stage in stages:
        result = run_stage(stage, reports, files)
        results.append(result)
        print(f"{stage}: {result.status} ({result.log})", flush=True, file=progress)
        if result.status != "PASS":
            print("\n".join(result.diagnostics), flush=True, file=progress)
    after = source_digest()
    passed = before == after and all(result.status == "PASS" for result in results)
    summary: CheckerReport = {
        "status": "PASS" if passed else "FAIL",
        "python": sys.version,
        "executable": sys.executable,
        "source": str(FACTORY_ROOT),
        "source_sha256": before,
        "source_unchanged": before == after,
        "stages": [
            {
                "stage": result.stage,
                "status": result.status,
                "exit_code": result.exit_code,
                "commands": result.commands,
                "log": result.log,
            }
            for result in results
        ],
    }
    report = reports / "result.json"
    report.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    if as_json:
        for stage_report, result in zip(summary["stages"], results, strict=True):
            if not retain:
                stage_report["log"] = None
            if result.status != "PASS":
                stage_report["diagnostics"] = result.diagnostics
        emit_json({**summary, "report": str(report) if retain else None})
    else:
        print(json.dumps({"status": summary["status"], "report": str(report)}), flush=True)
    return 0 if passed else 1


def build_parser(
    parser: argparse.ArgumentParser | None = None,
) -> argparse.ArgumentParser:
    parser = parser or argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stage", action="append", choices=(*OFFLINE, "audit"))
    parser.add_argument(
        "--report-dir", type=Path, help="Explicit destination for logs and coverage"
    )
    return parser


def run(args: argparse.Namespace, parser: argparse.ArgumentParser) -> int:
    stages = args.stage or list(OFFLINE)
    as_json = getattr(args, "json", False)
    if args.report_dir:
        reports = args.report_dir.resolve()
        if reports.is_relative_to(FACTORY_ROOT) or FACTORY_ROOT.is_relative_to(reports):
            parser.error("Reports must not overlap the installed factory")
        return check(stages, reports, as_json=as_json)
    with tempfile.TemporaryDirectory(prefix="factory-checks-") as directory:
        return check(stages, Path(directory), as_json=as_json, retain=False)


def main() -> int:
    parser = build_parser()
    return run(parser.parse_args(), parser)


if __name__ == "__main__":
    raise SystemExit(main())
