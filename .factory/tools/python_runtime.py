#!/usr/bin/env python3
"""Prepare or use the factory-owned venv; setup is explicit, run is offline."""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
from collections.abc import Sequence
from pathlib import Path
from typing import NotRequired, TypedDict

TOOLS = Path(__file__).resolve().parent
AGENTS = TOOLS.parent
ENV = AGENTS / ".venv"
MARKER = ENV / ".factory-ready.json"
REQUIREMENTS = TOOLS / "requirements.txt"


class EnvironmentIdentity(TypedDict):
    requirements: str
    environment: str
    python: list[int]
    development: bool
    dev_requirements: NotRequired[str]


def interpreter(environment: Path = ENV, platform: str = os.name) -> Path:
    return environment / ("Scripts/python.exe" if platform == "nt" else "bin/python")


def clean_environment() -> dict[str, str]:
    env = dict(os.environ)
    for key in ("PYTHONPATH", "PYTHONHOME", "VIRTUAL_ENV", "PIP_TARGET", "PIP_PREFIX", "PIP_USER"):
        env.pop(key, None)
    # Do not inherit pip configuration that can redirect installs outside the venv.
    env["PIP_CONFIG_FILE"] = os.devnull
    return env


def identity(development: bool = False) -> EnvironmentIdentity:
    result: EnvironmentIdentity = {
        "requirements": hashlib.sha256(REQUIREMENTS.read_bytes()).hexdigest(),
        "environment": str(ENV),
        "python": list(sys.version_info[:3]),
        "development": development,
    }
    if development:
        result["dev_requirements"] = hashlib.sha256(
            (TOOLS / "requirements-dev.txt").read_bytes()
        ).hexdigest()
    return result


def check() -> None:
    if (AGENTS / ".venv.setup.lock").exists():
        raise RuntimeError("Python setup in progress; wait for it to finish")
    if sys.version_info < (3, 11):  # noqa: UP036  # Bootstrap rejects unsupported host Python.
        raise RuntimeError("Python 3.11+ required; see tools/README.md")
    if (
        ENV.is_symlink()
        or Path(sys.prefix).resolve() != ENV.resolve()
        or sys.prefix == sys.base_prefix
    ):
        raise RuntimeError("Use the factory project venv via tools/python.sh or tools/python.cmd")
    marker = json.loads(MARKER.read_text()) if MARKER.is_file() else {}
    if not marker or marker != identity(marker.get("development", False)):
        raise RuntimeError("Factory environment missing/stale/moved; rerun python_runtime.py setup")
    import yaml

    if not Path(yaml.__file__).resolve().is_relative_to(ENV.resolve()):
        raise RuntimeError("PyYAML must come from the factory venv")


def setup(development: bool = False) -> None:
    import venv

    if sys.version_info < (3, 11):  # noqa: UP036  # Bootstrap rejects unsupported host Python.
        raise RuntimeError(
            "Python 3.11+ required; install a supported Python using official OS instructions"
        )
    state = AGENTS.parent / ".factory/memory/state/workflow.json"
    if state.exists() and json.loads(state.read_text()).get("status") != "completed":
        raise RuntimeError("Stop/archive the active workflow before changing Python dependencies")
    lock = AGENTS / ".venv.setup.lock"
    try:
        fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    except FileExistsError as exc:
        raise RuntimeError(
            "Python setup already locked; inspect the owner before removing a stale lock"
        ) from exc
    os.close(fd)
    try:
        if ENV.is_symlink() or (ENV.exists() and not (ENV / "pyvenv.cfg").is_file()):
            raise RuntimeError("Refusing to replace a symlink or non-venv .factory/.venv")
        if MARKER.is_symlink():
            raise RuntimeError("Refusing symlink readiness marker")
        # Once setup starts, failure must not leave an old success marker.
        MARKER.unlink(missing_ok=True)
        if not ENV.exists():
            venv.EnvBuilder(with_pip=True, symlinks=os.name != "nt").create(ENV)
        python = interpreter()
        env = clean_environment()
        commands = [
            [
                str(python),
                "-E",
                "-s",
                "-m",
                "pip",
                "install",
                "--disable-pip-version-check",
                "--no-user",
                "--require-hashes",
                "-r",
                str(TOOLS / "requirements-dev.txt" if development else REQUIREMENTS),
            ],
            [str(python), "-E", "-s", "-m", "pip", "check"],
            [
                str(python),
                "-E",
                "-s",
                "-B",
                str(Path(__file__).resolve()),
                "_ready",
                *(["--dev"] if development else []),
            ],
        ]
        site = subprocess.check_output(
            [str(python), "-E", "-s", "-c", "import site; print(site.getsitepackages()[0])"],
            text=True,
            env=env,
        ).strip()
        (Path(site) / "factory-bundle.pth").write_text(
            str(AGENTS.resolve()) + "\n", encoding="utf-8"
        )
        for command in commands:
            subprocess.run(command, check=True, env=env)
    finally:
        lock.unlink()


def main(argv: Sequence[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    try:
        if args in (["setup"], ["setup", "--dev"]):
            setup("--dev" in args)
            print("Factory Python ready. Use tools/python.sh (Unix) or tools/python.cmd (Windows).")
            return 0
        if args in (["_ready"], ["_ready", "--dev"]):
            if (
                ENV.is_symlink()
                or MARKER.is_symlink()
                or Path(sys.prefix).resolve() != ENV.resolve()
                or sys.prefix == sys.base_prefix
            ):
                raise RuntimeError("Readiness requires the project venv")
            import yaml

            if sys.version_info < (3, 11):  # noqa: UP036  # Bootstrap rejects unsupported host Python.
                raise RuntimeError("Venv Python is too old; recreate it with Python 3.11+")
            if not Path(yaml.__file__).resolve().is_relative_to(ENV.resolve()):
                raise RuntimeError("PyYAML must be installed in the factory venv")
            MARKER.write_text(json.dumps(identity("--dev" in args)) + "\n")
            # Setup still owns its lock; ordinary run/check is blocked until release.
            return 0
        if not args or args[0] != "run":
            raise RuntimeError("Usage: python_runtime.py setup | run [Python arguments]")
        check()
        if args[1:] == ["--check"]:
            print(json.dumps({"status": "PASS", "executable": sys.executable}))
            return 0
        if len(args) == 1:
            raise RuntimeError("Provide a script, -m module, or --check")
        return subprocess.run(
            [sys.executable, "-E", "-s", "-B", *args[1:]], env=clean_environment()
        ).returncode
    except (OSError, ValueError, RuntimeError, ImportError, subprocess.CalledProcessError) as exc:
        print(
            "BLOCKED: " + str(exc) + "\nSee .factory/tools/README.md (Python setup).",
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    sys.exit(main())
