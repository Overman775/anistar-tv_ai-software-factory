"""Quote copyable factory commands for the workspace's native shell."""

from __future__ import annotations

import base64
import json
import platform
import re
import shlex
from pathlib import Path, PureWindowsPath

from factory.paths import FACTORY_ROOT
from factory.runtime.commands.execution import CheckExecution


def command_shell() -> str:
    return "PowerShell" if platform.system() == "Windows" else "POSIX shell"


_CMD_UNSAFE = re.compile(r'[&|<>^%!"()\t\r\n\u2018-\u201f]')


def _powershell_quote(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def _encode_argv(argv: list[str]) -> str:
    payload = json.dumps(argv, ensure_ascii=False, separators=(",", ":")).encode()
    return base64.b64encode(payload).decode()


def _windows_command(launcher: str, argv: list[str], trailing: tuple[str, ...]) -> str:
    quote = _powershell_quote
    suffix = "".join(" " + quote(value) for value in trailing)
    if _CMD_UNSAFE.search(launcher):
        # Expand the executable path once within cmd's double quotes. Environment
        # expansion leaves percent characters within the variable's value literal.
        launcher_token = base64.b64encode(launcher.encode()).decode()
        argv_token = _encode_argv(argv)
        source = (
            "$previous = $env:OVERFACTORY_COMMAND_LAUNCHER; "
            "try { "
            "$env:OVERFACTORY_COMMAND_LAUNCHER = "
            f"[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('{launcher_token}')); "
            f"$bound = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('{argv_token}')); "
            "$argv = @(ConvertFrom-Json -InputObject $bound) + $args; "
            "$json = ConvertTo-Json -InputObject $argv -Compress; "
            "$token = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json)); "
            "& $env:ComSpec /d /s /v:off /c "
            "('\"\"%OVERFACTORY_COMMAND_LAUNCHER%\" --argv-base64 ' + $token + '\"') "
            "} finally { $env:OVERFACTORY_COMMAND_LAUNCHER = $previous }"
        )
        return "& { " + source + " }" + suffix
    if any(
        not value or value != value.strip() or _CMD_UNSAFE.search(value) or value.endswith("\\")
        for value in argv
    ):
        argv = ["--argv-base64", _encode_argv(argv)]
    return "& " + " ".join(map(quote, (launcher, *argv))) + suffix


def factory_command(
    root: Path,
    config: str,
    family: str,
    *args: str,
    shell: str | None = None,
    trailing: tuple[str, ...] = (),
) -> str:
    shell = command_shell() if shell is None else shell
    argv = [family, "--workspace", str(root), "--config", config, "--json", *args]
    if shell == "PowerShell":
        launcher = str(PureWindowsPath(FACTORY_ROOT) / "tooling/bin/cli.cmd")
        return _windows_command(launcher, argv, trailing)
    return shlex.join(["sh", str(FACTORY_ROOT / "tooling/bin/cli"), *argv, *trailing])


def check_commands(
    root: Path, config: str, run: str, node: str, dispatch: str, check: str
) -> dict[str, str]:
    # Scope the stable default request to this attempt and registered check.
    request = check
    execution = CheckExecution.request_key(run, node, dispatch, request)
    shell = command_shell()
    return {
        "check_id": check,
        "request_id": request,
        "dispatch_id": dispatch,
        "execution_id": execution,
        "shell": shell,
        "run_command": factory_command(
            root,
            config,
            "checks",
            "run",
            node,
            check,
            "--request",
            request,
            "--dispatch",
            dispatch,
            shell=shell,
        ),
        "results_command": factory_command(
            root, config, "checks", "results", execution, shell=shell
        ),
        "reconcile_command": factory_command(
            root, config, "checks", "reconcile", execution, shell=shell
        ),
    }
