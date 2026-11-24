#!/usr/bin/env python3
"""Prepare or use the factory-owned venv; setup is explicit, run is offline."""

from __future__ import annotations

import base64
import hashlib
import json
import os
import subprocess
import sys
from collections.abc import Callable, Mapping, Sequence
from itertools import takewhile
from pathlib import Path

if __name__ == "__main__" and sys.version_info[:2] != (3, 14):
    message = "Python 3.14 required. Select an installed Python 3.14 with FACTORY_SETUP_PYTHON."
    if "--json" in takewhile(lambda arg: arg != "--", sys.argv[1:]):
        print(
            json.dumps(
                {"ok": False, "error": {"code": "environment_not_ready", "message": message}}
            )
        )
        sys.exit(1)
    sys.exit("BLOCKED: " + message)

from typing import NotRequired, TypedDict

from factory.cli_output import (
    LAUNCHER,
    configure_process_io,
    emit_error,
    emit_json,
    json_requested,
    output_mode,
)

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


def clean_environment(environ: Mapping[str, str] | None = None) -> dict[str, str]:
    env = dict(os.environ if environ is None else environ)
    for key in ("PYTHONPATH", "PYTHONHOME", "VIRTUAL_ENV", "PIP_TARGET", "PIP_PREFIX", "PIP_USER"):
        env.pop(key, None)
    # Do not inherit pip configuration that can redirect installs outside the venv.
    env["PIP_CONFIG_FILE"] = os.devnull
    return env


def identity(
    development: bool = False, *, read_bytes: Callable[[Path], bytes] = Path.read_bytes
) -> EnvironmentIdentity:
    result: EnvironmentIdentity = {
        "requirements": hashlib.sha256(read_bytes(REQUIREMENTS)).hexdigest(),
        "environment": str(ENV),
        "python": list(sys.version_info[:3]),
        "development": development,
    }
    if development:
        result["dev_requirements"] = hashlib.sha256(
            read_bytes(TOOLS / "requirements-dev.txt")
        ).hexdigest()
    return result


def check_bundle(*, read_bytes: Callable[[Path], bytes] = Path.read_bytes) -> None:
    import sysconfig

    registration = Path(sysconfig.get_path("purelib")) / "factory-bundle.pth"
    if not registration.is_file() or read_bytes(registration).decode("ascii").replace(
        "\r\n", "\n"
    ) != bundle_site_line(TOOLS):
        raise RuntimeError("Factory package missing or from another bundle; rerun setup")
    expected = (TOOLS / "factory/__init__.py").resolve()
    origin = subprocess.check_output(
        [
            sys.executable,
            "-E",
            "-s",
            "-B",
            "-P",
            "-c",
            "import importlib.util,json; s=importlib.util.find_spec('factory'); print(json.dumps(s.origin if s else None))",
        ],
        text=True,
        env=clean_environment(),
    )
    origin = json.loads(origin)
    if not origin or Path(origin).resolve() != expected:
        raise RuntimeError("Factory package missing or from another bundle; rerun setup")


def bundle_site_line(bundle: Path) -> str:
    return f"import sys; sys.path.append({ascii(str(bundle.resolve()))})\n"


def check(*, read_bytes: Callable[[Path], bytes] = Path.read_bytes) -> None:
    if (AGENTS / ".venv.setup.lock").exists():
        raise RuntimeError("Python setup in progress; wait for it to finish")
    if sys.version_info[:2] != (3, 14):
        raise RuntimeError("Python 3.14 required; recreate the venv with Python 3.14")
    if (
        ENV.is_symlink()
        or Path(sys.prefix).resolve() != ENV.resolve()
        or sys.prefix == sys.base_prefix
    ):
        raise RuntimeError(
            "Use the project launcher at .factory/tooling/bin/cli (Windows: cli.cmd)"
        )
    marker = json.loads(read_bytes(MARKER).decode("utf-8")) if MARKER.is_file() else {}
    if not isinstance(marker, dict) or marker != identity(
        marker.get("development", False), read_bytes=read_bytes
    ):
        raise RuntimeError(f"Factory environment missing/stale/moved; run {LAUNCHER} setup")
    import yaml

    if not Path(yaml.__file__).resolve().is_relative_to(ENV.resolve()):
        raise RuntimeError("PyYAML must come from the factory venv")
    check_bundle(read_bytes=read_bytes)


def setup(
    development: bool = False,
    *,
    has_active_workflow: Callable[[Path], bool] | None = None,
    json_mode: bool = False,
) -> None:
    import venv

    if sys.version_info[:2] != (3, 14):
        raise RuntimeError(
            "Python 3.14 required; install a supported Python using official OS instructions"
        )
    if has_active_workflow is None:
        from factory.database.provider import current_database

        has_active_workflow = current_database().has_active_workflow
    if has_active_workflow(AGENTS):
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
        if ENV.exists():
            version = subprocess.check_output(
                [
                    str(interpreter()),
                    "-E",
                    "-s",
                    "-c",
                    "import sys; print(sys.version_info[:2] == (3, 14))",
                ],
                text=True,
                env=clean_environment(),
            ).strip()
            if version != "True":
                raise RuntimeError(
                    "Venv Python must be 3.14; recreate .factory/.venv with Python 3.14"
                )
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
        site = json.loads(
            subprocess.check_output(
                [
                    str(python),
                    "-E",
                    "-s",
                    "-c",
                    "import json,sysconfig; print(json.dumps(sysconfig.get_path('purelib')))",
                ],
                text=True,
                env=env,
            )
        )
        (Path(site) / "factory-bundle.pth").write_text(bundle_site_line(TOOLS), encoding="ascii")
        for command in commands:
            subprocess.run(command, check=True, env=env, stdout=sys.stderr if json_mode else None)
    finally:
        lock.unlink()


def _cli_args(args: list[str]) -> list[str]:
    """Recover Windows arguments that cmd.exe would expand or split."""
    if not args or args[0] != "--argv-base64":
        return args
    if len(args) < 2:
        raise ValueError("Missing encoded launcher arguments")
    token = args[1]
    payload = json.loads(base64.b64decode(token + "=" * (-len(token) % 4), b"-_", validate=True))
    if not isinstance(payload, list) or not all(
        isinstance(arg, str) and "\x00" not in arg for arg in payload
    ):
        raise ValueError("Invalid encoded launcher arguments")
    return [*payload, *args[2:]]


def main(argv: Sequence[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    # The platform launcher forwards the original argv, including leading flags.
    if args[:1] == ["--json"]:
        while args[:1] == ["--json"]:
            args.pop(0)
        args.insert(1, "--json")
    as_json = json_requested(args)
    try:
        if args and args[0] == "setup":
            from factory.cli_help import setup_parser

            with output_mode(as_json):
                options = setup_parser().parse_args(args[1:])
            setup(options.dev, json_mode=as_json)
            if as_json:
                emit_json(
                    {
                        "ok": True,
                        "result": {
                            "environment": str(ENV),
                            "python": str(interpreter()),
                            "development": options.dev,
                        },
                    }
                )
            else:
                print(f"Factory Python ready. Run `{LAUNCHER} help agents`.")
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

            if sys.version_info[:2] != (3, 14):
                raise RuntimeError(
                    "Venv Python must be 3.14; recreate .factory/.venv with Python 3.14"
                )
            if not Path(yaml.__file__).resolve().is_relative_to(ENV.resolve()):
                raise RuntimeError("PyYAML must be installed in the factory venv")
            check_bundle()
            MARKER.write_text(json.dumps(identity("--dev" in args)) + "\n", encoding="utf-8")
            # Setup still owns its lock; ordinary run/check is blocked until release.
            return 0
        if args and args[0] == "cli":
            forwarded = _cli_args(args[1:])
            as_json = json_requested(forwarded)
            check()
            return subprocess.run(
                [sys.executable, "-E", "-s", "-B", "-P", "-m", "factory.cli", *forwarded],
                env=clean_environment(),
                check=False,
            ).returncode
        raise RuntimeError(f"Run the project launcher at {LAUNCHER}")
    except (OSError, ValueError, RuntimeError, ImportError, subprocess.CalledProcessError) as exc:
        next_action = f"Run {LAUNCHER} setup --help from the project root for setup options."
        if as_json:
            code = "setup_failed" if args[:1] == ["setup"] else "environment_not_ready"
            emit_error(code, str(exc), next_action=next_action)
            return 1
        print(f"BLOCKED: {exc}\n{next_action}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    configure_process_io(sys.argv[1:])
    sys.exit(main())
