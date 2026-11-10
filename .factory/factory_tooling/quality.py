"""Offline checks share one entry point with CI; dependency auditing is explicit."""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import tomllib
from dataclasses import asdict, dataclass
from pathlib import Path

from factory_tooling.paths import FACTORY_ROOT, TOOLS

OFFLINE = ("lint", "format", "types", "imports", "yaml-lint", "yaml-contracts", "tests", "dry-run")


@dataclass(frozen=True)
class StageResult:
    stage: str
    status: str
    exit_code: int | None
    commands: list[list[str]]
    log: str


def source_files() -> list[Path]:
    """Enumerate owned files explicitly, including hidden paths and unexecuted code."""
    roots = [
        TOOLS,
        FACTORY_ROOT / "factory_tooling",
        FACTORY_ROOT / "tests",
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
    for file in sorted(FACTORY_ROOT.rglob("*")):
        parts = file.relative_to(FACTORY_ROOT).parts
        if parts[0] == "memory" or {
            ".venv",
            ".venv.setup.lock",
            "__pycache__",
            ".mypy_cache",
            ".ruff_cache",
            ".pytest_cache",
            ".DS_Store",
            "htmlcov",
        }.intersection(parts):
            continue
        if file.name.startswith(".coverage") or file.suffix in {".pyc", ".pyo"}:
            continue
        if not file.is_file() and not file.is_symlink():
            continue
        digest.update(str(file.relative_to(FACTORY_ROOT)).encode())
        digest.update(b"\0")
        digest.update(str(file.readlink()).encode() if file.is_symlink() else file.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()


def prepare_coverage(reports: Path) -> Path:
    configuration = tomllib.loads((TOOLS / "pyproject.toml").read_text(encoding="utf-8"))["tool"][
        "coverage"
    ]
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
    """The launcher --check branch runs only in test subprocesses, never in the parent."""
    source = TOOLS / "python_runtime.py"
    tree = ast.parse(source.read_text(encoding="utf-8"))
    line = next(
        node.body[0].lineno
        for node in ast.walk(tree)
        if isinstance(node, ast.If) and ast.unparse(node.test) == "args[1:] == ['--check']"
    )
    report = json.loads((reports / "coverage.json").read_text(encoding="utf-8"))
    covered = next(
        (
            value
            for name, value in report["files"].items()
            if (FACTORY_ROOT / name).resolve() == source.resolve()
        ),
        None,
    )
    if covered is None or line not in covered["executed_lines"]:
        raise ValueError("Coverage missed the real python.sh/python.cmd --check subprocess")


def commands(stage: str, reports: Path) -> list[list[str]]:
    python = [sys.executable, "-E", "-s", "-B", "-m"]
    config = str(TOOLS / "pyproject.toml")
    files = [str(p) for p in source_files()]
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
        from factory_tooling.yaml_checks import source_files as yaml_files

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
        return [[*python, "factory_tooling.yaml_checks"]]
    if stage == "tests":
        config = str(reports / "coverage.toml")
        return [
            [*python, "coverage", "run", "--rcfile", config, "-m", "factory_tooling.test_suite"],
            [*python, "coverage", "combine", "--rcfile", config],
            [*python, "coverage", "report", "--rcfile", config],
            [*python, "coverage", "json", "--rcfile", config, "-o", str(reports / "coverage.json")],
        ]
    if stage == "dry-run":
        return [[*python, "factory_tooling.diagnostics.dry_run"]]
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


def run_stage(stage: str, reports: Path) -> StageResult:
    coverage_file = prepare_coverage(reports) if stage == "tests" else reports / ".coverage"
    log = reports / f"{stage}.log"
    try:
        planned = commands(stage, reports)
    except (OSError, ValueError) as exc:
        log.write_text(f"FAIL: {exc}\n", encoding="utf-8")
        return StageResult(stage, "FAIL", 1, [], str(log))
    environment = dict(
        os.environ,
        COVERAGE_FILE=str(coverage_file),
        COVERAGE_RCFILE=str(reports / "coverage.toml"),
    )
    environment.pop("MYPYPATH", None)
    code: int | None = 0
    with log.open("w", encoding="utf-8") as output:
        for command in planned:
            output.write(json.dumps(command) + "\n")
            output.flush()
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
                output.write(f"BLOCKED: {exc}\n")
                code = None
                break
            if completed.returncode:
                code = completed.returncode
                # Keep test coverage even when tests fail, and audit both dependency sets.
                if stage not in {"tests", "audit", "types"}:
                    break
        if stage == "tests" and code == 0:
            try:
                verify_subprocess_coverage(reports)
                output.write("PASS: coverage includes the real launcher subprocess\n")
            except (OSError, ValueError, KeyError) as exc:
                output.write(f"FAIL: {exc}\n")
                code = 1
    return StageResult(
        stage,
        "PASS" if code == 0 else "BLOCKED" if code is None else "FAIL",
        code,
        planned,
        str(log),
    )


def check(stages: list[str], reports: Path) -> int:
    reports.mkdir(parents=True, exist_ok=True)
    before = source_digest()
    results = []
    for stage in stages:
        result = run_stage(stage, reports)
        results.append(result)
        print(f"{stage}: {result.status} ({result.log})", flush=True)
        if result.status != "PASS":
            diagnostic = [
                line
                for line in Path(result.log).read_text(encoding="utf-8").splitlines()
                if not line.startswith('["')
            ]
            print("\n".join(diagnostic[-80:]), flush=True)
    after = source_digest()
    passed = before == after and all(result.status == "PASS" for result in results)
    summary = {
        "status": "PASS" if passed else "FAIL",
        "python": sys.version,
        "executable": sys.executable,
        "source": str(FACTORY_ROOT),
        "source_sha256": before,
        "source_unchanged": before == after,
        "stages": [asdict(result) for result in results],
    }
    (reports / "result.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(
        json.dumps({"status": summary["status"], "report": str(reports / "result.json")}),
        flush=True,
    )
    return 0 if passed else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stage", action="append", choices=(*OFFLINE, "audit"))
    parser.add_argument(
        "--report-dir", type=Path, help="Explicit destination for logs and coverage"
    )
    args = parser.parse_args()
    stages = args.stage or list(OFFLINE)
    if args.report_dir:
        reports = args.report_dir.resolve()
        if reports.is_relative_to(FACTORY_ROOT) or FACTORY_ROOT.is_relative_to(reports):
            parser.error("Reports must not overlap the installed factory")
        return check(stages, reports)
    with tempfile.TemporaryDirectory(prefix="factory-checks-") as directory:
        return check(stages, Path(directory))


if __name__ == "__main__":
    raise SystemExit(main())
