#!/usr/bin/env python3
"""ACP transport helper. Reservation/acceptance remain in workflow.py."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess

# Direct CLI execution and import-by-path use the same tool modules.
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import IO, Any, Literal, NotRequired, Protocol, TypedDict

from factory.logging_config import (
    error_code,
    event,
    failure_context,
    finish,
    initialize,
)
from factory.paths import FACTORY_ROOT
from factory.runtime.contracts import (
    Acpx,
    Config,
    Connection,
    Node,
    Profile,
    State,
    agent_key,
)
from factory.runtime.packet_io import freeze_packet, read_packet_bytes
from factory.runtime.workflow import Ledger
from factory.runtime.workflow_config import (
    check_capabilities,
    check_config,
    load_config,
)
from factory.runtime.workflow_core import (
    Invalid,
    atomic_json,
    read_json,
    require,
)
from factory.runtime.workflow_core import relative as relative


class TransportResult(Protocol):
    @property
    def returncode(self) -> int: ...


class TransportRunner(Protocol):
    def __call__(
        self,
        args: list[str],
        /,
        *,
        cwd: Path,
        stdout: IO[str],
        stderr: IO[str],
        check: Literal[False],
    ) -> TransportResult: ...


def executable(command: str, config_dir: str | Path) -> str:
    if "/" in command or "\\" in command:
        p = Path(command).expanduser()
        p = p if p.is_absolute() else Path(config_dir) / p
        require(p.is_file() and os.access(p, os.X_OK), f"Executable unavailable: {p}")
        return str(p.resolve())
    found = shutil.which(command)
    if found is None:
        raise Invalid(f"Executable unavailable on PATH: {command}")
    return found


def install_connection(config: Config, workspace: str | Path, alias: str) -> dict[str, Any]:
    """Explicit setup only. Preserve unrelated configuration; reject conflicts."""
    conn = config["acpx"]["connections"][alias]
    argv = [executable(conn["command"], Path(config["_path"]).parent), *conn.get("args", [])]
    target = Path(workspace) / ".acpxrc.json"
    require(not target.is_symlink(), "Symlink acpx config")
    current = read_json(target) if target.exists() else {}
    agents = current.setdefault("agents", {})
    require(
        alias not in agents or agents[alias] == {"argv": argv},
        "Existing ACP alias differs; reconcile explicitly",
    )
    agents[alias] = {"argv": argv}
    atomic_json(target, current)
    return {"path": str(target), "agent": alias, "argv": argv}


def assignment(state: State, node_id: str) -> tuple[Node, Profile, Connection, str]:
    node = next(n for n in state["graph"]["nodes"] if n["id"] == node_id)
    agent = state["graph"]["agents"][agent_key(node)]
    profile = state["config"]["profiles"][agent["profile"]]
    require(profile["runner"] == "acpx", "Node is not assigned to ACP")
    conn = state["config"]["acpx"]["connections"][profile["connection"]]
    epoch = state.get("epochs", {}).get(agent_key(node), 0)
    session = f"{state['run_id']}-{node['agent']}-e{epoch}"
    return node, profile, conn, session


def build_command(
    state: State, node_id: str, operation: str, prompt: str | Path | None = None
) -> list[str]:
    node, profile, conn, session = assignment(state, node_id)
    c = state["config"]
    if operation in {"create", "prompt"}:
        check_capabilities(profile, node)
    model = c["models"][profile["model"]]
    effort = model.get("effort")
    require(
        not effort or profile["harness"] == "opencode",
        "ACP effort needs a confirmed backend-specific mapping; not silently ignored",
    )
    base = [
        c["acpx"]["command"],
        "--cwd",
        state["workspace"],
        "--format",
        "json",
        "--" + conn.get("permissions", "approve-reads"),
        "--non-interactive-permissions",
        "fail",
    ]
    model_id = model["id"]
    if model_id:
        base += ["--model", model_id]
    base += [profile["connection"]]
    tails = {
        "create": ["sessions", "new", "--name", session],
        "show": ["sessions", "show", session],
        "status": ["status", "-s", session],
        "prompt": ["prompt", "-s", session, "--file", str(prompt)],
        "cancel": ["cancel", "-s", session],
        "close": ["sessions", "close", session],
    }
    if operation == "set-effort":
        require(bool(effort), "No ACP effort configured")
        return base + ["set", "effort", str(effort), "-s", session]
    return base + tails[operation]


def prepare_prompt(ledger: Ledger, node_id: str) -> dict[str, Any]:
    with ledger.locked():
        s = ledger.read()
        n, v = ledger.packet_dispatch(s, node_id, runner="acpx")
        _, _, _, session = assignment(s, node_id)
        require(not v.get("prompt_submitted"), "Prompt already submitted")
        meta = freeze_packet(ledger.root, ledger.dir, s, n, v)
        p = ledger.root / meta["path"]
        expected_report = ledger.dir / f"{s['run_id']}-{node_id}-{v['dispatch_id']}.report.json"
        artifacts = s.setdefault("transport_artifacts", [])
        report = str(expected_report.relative_to(ledger.root))
        if report not in artifacts:
            artifacts.append(report)
        ledger.save(s, "prompt_prepared", node=node_id, session=session)
        return {
            "prompt": str(p),
            "session": session,
            "report": str(expected_report),
            "create": build_command(s, node_id, "create"),
            "show": build_command(s, node_id, "show"),
            "prompt_argv": build_command(s, node_id, "prompt", p),
        }


@dataclass(frozen=True)
class TransportAttempt:
    node_id: str
    operation: str
    expected_run: str
    expected_dispatch: str
    task_id: str
    session: str
    argv: list[str]
    effort_argv: list[str] | None
    out: Path
    err: Path


def _prepare_operation(ledger: Ledger, node_id: str, operation: str) -> TransportAttempt:
    with ledger.locked():
        s = ledger.read()
        if operation in {"create", "prompt"}:
            check_config(s)
        n, profile, conn, session = assignment(s, node_id)
        v = s["nodes"][node_id]
        expected_run, expected_dispatch = s["run_id"], v["dispatch_id"]
        require(
            v["status"] in {"reserved", "running", "unknown", "done", "blocked"},
            "Node not dispatched",
        )
        config_dir = Path(s["config"]["_path"]).parent
        registry = read_json(ledger.root / ".acpxrc.json")
        expected_argv = [executable(conn["command"], config_dir), *conn.get("args", [])]
        require(
            registry.get("agents", {}).get(profile["connection"]) == {"argv": expected_argv},
            "ACP registry drift; run setup/reconcile",
        )
        executable_path = executable(s["config"]["acpx"]["command"], config_dir)
        prompt_path = None
        if operation == "create":
            require(v["status"] == "reserved", "Create requires reservation")
            require(
                session not in s.get("acp_created", {}),
                "Session creation already attempted; reconcile instead of creating again",
            )
            s.setdefault("acp_created", {})[session] = "requested"
        if operation == "prompt":
            require(
                v["status"] == "running", "Confirm session/model with workflow bind before prompt"
            )
            require(
                not v.get("prompt_submitted"),
                "Prompt already submitted; never resend an uncertain turn",
            )
            ledger.packet_dispatch(s, node_id, runner="acpx")
            meta = v.get("packet_file")
            if meta is None:
                raise Invalid("Prepare JSON packet before prompt")
            read_packet_bytes(ledger.root, s, n, meta, meta)
            prompt_path = ledger.root / meta["path"]
            bound = s["sessions"].get(agent_key(n))
            require(
                bound is not None and bound["handle"] == session,
                "Bound handle must equal prepared ACP session name",
            )
            v["prompt_submitted"] = True
        argv = build_command(s, node_id, operation, prompt_path)
        argv[0] = executable_path
        effort_argv = None
        if operation == "prompt" and s["config"]["models"][profile["model"]].get("effort"):
            effort_argv = build_command(s, node_id, "set-effort")
            effort_argv[0] = executable_path
        prefix = ledger.dir / f"{s['run_id']}-{node_id}-{v['dispatch_id']}-{operation}"
        out, err = Path(str(prefix) + ".stdout"), Path(str(prefix) + ".stderr")
        for p in (out, err):
            require(not p.is_symlink(), "Symlink transport output")
            s.setdefault("transport_artifacts", []).append(str(p.relative_to(ledger.root)))
        ledger.save(
            s,
            "transport_requested",
            node=node_id,
            operation=operation,
            argv=argv,
            **({"effort_argv": effort_argv} if effort_argv else {}),
        )
    return TransportAttempt(
        node_id,
        operation,
        expected_run,
        expected_dispatch,
        n["task"],
        session,
        argv,
        effort_argv,
        out,
        err,
    )


def _execute_operation(
    ledger: Ledger,
    attempt_context: TransportAttempt,
    run: TransportRunner,
) -> TransportResult:
    node_id, operation = attempt_context.node_id, attempt_context.operation
    expected_run, expected_dispatch = (
        attempt_context.expected_run,
        attempt_context.expected_dispatch,
    )
    argv, effort_argv = attempt_context.argv, attempt_context.effort_argv
    out, err = attempt_context.out, attempt_context.err
    try:
        with out.open("w") as stdout, err.open("w") as stderr:
            result = (
                run(effort_argv, cwd=ledger.root, stdout=stdout, stderr=stderr, check=False)
                if effort_argv
                else None
            )
            if result is None or result.returncode == 0:
                result = run(argv, cwd=ledger.root, stdout=stdout, stderr=stderr, check=False)
    except BaseException:
        if operation in {"create", "prompt"}:
            with ledger.locked():
                current = ledger.read()
                attempt = current["nodes"].get(node_id)
                if (
                    current["run_id"] == expected_run
                    and attempt is not None
                    and attempt.get("dispatch_id") == expected_dispatch
                ):
                    attempt["status"] = "unknown"
                    ledger.save(current, "transport_interrupted", node=node_id, operation=operation)
        raise
    return result


def _reconcile_operation(
    ledger: Ledger, attempt_context: TransportAttempt, result: TransportResult
) -> dict[str, Any]:
    node_id, operation = attempt_context.node_id, attempt_context.operation
    expected_run, expected_dispatch = (
        attempt_context.expected_run,
        attempt_context.expected_dispatch,
    )
    session, out, err = attempt_context.session, attempt_context.out, attempt_context.err
    with ledger.locked():
        s = ledger.read()
        attempt = s["nodes"].get(node_id)
        if (
            s["run_id"] != expected_run
            or attempt is None
            or attempt.get("dispatch_id") != expected_dispatch
        ):
            event(
                "transport_returned",
                run_id=expected_run,
                node_id=node_id,
                task_id=attempt_context.task_id,
                dispatch_id=expected_dispatch,
                transport_operation=operation,
                outcome="stale",
            )
            return {
                "stale": True,
                "exit_code": result.returncode,
                "stdout": str(out),
                "stderr": str(err),
                "dispatch_id": expected_dispatch,
                "gate": "NOT_EVALUATED",
            }
        if operation == "create" and result.returncode == 0:
            s["acp_created"][session] = "created"
        if operation in {"create", "prompt"} and result.returncode != 0:
            s["nodes"][node_id]["status"] = "unknown"
        ledger.save(
            s,
            "transport_returned",
            node=node_id,
            operation=operation,
            exit_code=result.returncode,
            stdout=str(out),
            stderr=str(err),
        )
    # Zero exit is transport only. Parent validates effective model, role output and evidence.
    return {
        "exit_code": result.returncode,
        "stdout": str(out),
        "stderr": str(err),
        "session": session,
        "gate": "NOT_EVALUATED",
    }


def run_operation(
    ledger: Ledger,
    node_id: str,
    operation: str,
    *,
    run: TransportRunner | None = None,
) -> dict[str, Any]:
    # Journal before transport, then reconcile only the same dispatch.
    attempt = _prepare_operation(ledger, node_id, operation)
    result = _execute_operation(ledger, attempt, subprocess.run if run is None else run)
    return _reconcile_operation(ledger, attempt, result)


class DoctorConfig(TypedDict):
    _path: str
    acpx: NotRequired[Acpx]


def doctor(config: DoctorConfig, connection: str | None = None) -> dict[str, Any]:
    """Resolve exactly as dispatch does; report each unavailable executable."""
    base = Path(config["_path"]).parent
    connections = config["acpx"]["connections"]
    if not (connection is None or connection in connections):
        raise ValueError("Unknown ACP connection")
    if connection is not None:
        connections = {connection: connections[connection]}
    errors = {}

    def resolve(key: str, command: str) -> str | None:
        try:
            return executable(command, base)
        except (Invalid, OSError) as exc:
            errors[key] = str(exc)
            return None

    result: dict[str, object] = {
        "acpx": resolve("acpx", config["acpx"]["command"]),
        "connections": {key: resolve(key, value["command"]) for key, value in connections.items()},
        "live_handshake": "NOT_RUN",
    }
    result["errors"] = errors
    return result


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--workspace", default=".")
    p.add_argument("--config", default=str(FACTORY_ROOT / "factory.yaml"))
    sub = p.add_subparsers(dest="action", required=True)
    sub.add_parser("doctor").add_argument(
        "--connection", help="Check only this connection and the acpx client"
    )
    sub.add_parser("setup").add_argument("connection")
    sub.add_parser("prepare").add_argument("node")
    r = sub.add_parser("run")
    r.add_argument("node")
    r.add_argument("operation", choices=["create", "show", "status", "prompt", "cancel", "close"])
    args = p.parse_args()
    handler = initialize(args.workspace, "acp_" + args.action)
    failed = False
    ledger = Ledger(args.workspace)
    try:
        if args.action == "doctor":
            c = load_config(args.config)
            result = doctor(c, args.connection)
        elif args.action == "setup":
            result = install_connection(load_config(args.config), ledger.root, args.connection)
        elif args.action == "prepare":
            result = prepare_prompt(ledger, args.node)
        else:
            result = run_operation(ledger, args.node, args.operation)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        if args.action == "doctor" and result["errors"]:
            failed = True
            event("operation_failed", error_code="executable_unavailable")
            return 1
        return 0
    except BaseException as exc:
        failed = True
        event(
            "operation_failed",
            error_code=error_code(exc),
            **(
                failure_context(ledger, getattr(args, "node", None))
                if args.action not in {"doctor", "setup", "run"}
                else {}
            ),
        )
        if isinstance(exc, (Invalid, KeyError, OSError, ValueError)):
            p.exit(1, f"BLOCKED: {exc}\n")
        raise
    finally:
        finish(handler, failed=failed)


if __name__ == "__main__":
    sys.exit(main())
