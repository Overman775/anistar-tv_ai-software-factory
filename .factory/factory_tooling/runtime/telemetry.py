"""Best-effort ACPX session usage projection for a terminal archive."""

import subprocess
import time
from pathlib import Path
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, ValidationError

from factory_tooling.runtime.contracts import Config, Dispatch, State


class ExternalModel(BaseModel):
    model_config = ConfigDict(strict=True, extra="ignore", allow_inf_nan=False)


class Usage(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid", allow_inf_nan=False)
    input_tokens: Annotated[int, Field(ge=0)] | None = None
    output_tokens: Annotated[int, Field(ge=0)] | None = None
    cache_creation_input_tokens: Annotated[int, Field(ge=0)] | None = None
    cache_read_input_tokens: Annotated[int, Field(ge=0)] | None = None
    thought_tokens: Annotated[int, Field(ge=0)] | None = None
    total_tokens: Annotated[int, Field(ge=0)] | None = None


class ExternalCost(ExternalModel):
    amount: Annotated[int | float, Field(ge=0)] | None = None
    currency: str | None = None


class ExternalUsage(Usage):
    model_config = ConfigDict(strict=True, extra="ignore", allow_inf_nan=False)


class Record(ExternalModel):
    name: str
    cwd: str
    acpxRecordId: str
    acpSessionId: str
    agentSessionId: str | None = None
    request_token_usage: dict[str, ExternalUsage] | None = None
    cumulative_cost: ExternalCost | None = None


class Owned(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid", allow_inf_nan=False)


class Cost(ExternalCost):
    model_config = ConfigDict(strict=True, extra="forbid", allow_inf_nan=False)


class Attempt(Owned):
    node_id: str
    dispatch_id: str
    agent: str
    role: str
    harness: str | None = None
    transport: Literal["acp"]
    requested_model: str | None = None
    requested_effort: str | None = None
    effective_model: str | None = None


class Session(Owned):
    name: str
    connection: str
    cwd: str
    acpx_record_id: str | None = None
    acp_session_id: str | None = None
    agent_session_id: str | None = None
    attempts: list[Attempt] = Field(default_factory=list)
    request_token_usage: dict[str, Usage] | None = None
    cumulative_cost: Cost | None = None
    collection: Literal["ok", "unavailable"] = "unavailable"


class ArchiveUsage(Owned):
    run_id: str
    project_id: str
    sessions: list[Session]


def _dispatches(state: State) -> dict[str, Dispatch]:
    result: dict[str, Dispatch] = {}
    for dispatch in state["nodes"].values():
        if dispatch.get("dispatch_id"):
            result[dispatch["dispatch_id"]] = dispatch
    for event in state["events"]:
        previous = event.get("previous")
        if isinstance(previous, dict) and "dispatch_id" in previous:
            # The discriminated history is validated as part of the ledger state.
            from typing import cast

            dispatch = cast(Dispatch, previous)
            if dispatch.get("dispatch_id"):
                result[dispatch["dispatch_id"]] = dispatch
        for dispatch in event.get("previous_nodes", {}).values():
            if dispatch.get("dispatch_id"):
                result[dispatch["dispatch_id"]] = dispatch
    return result


def _show(argv: list[str], timeout: float) -> subprocess.CompletedProcess[str]:
    return subprocess.run(argv, capture_output=True, text=True, check=True, timeout=timeout)


def collect(state: State) -> dict[str, object]:
    """Capture observed sessions once each, with 2 s per call and 10 s total."""
    dispatches = _dispatches(state)
    commands: dict[tuple[str, str, str], str] = {}
    active: dict[str, str] = {}
    sessions: dict[tuple[str, str, str], Session] = {}
    bound_models: dict[tuple[str, str], str] = {}
    historical: list[Config] = []
    config = state["config"]
    for event in reversed(state["events"]):
        historical.append(config)
        if "previous_config" in event:
            config = event["previous_config"]
    for event, config in zip(state["events"], reversed(historical), strict=True):
        node = event.get("node")
        if event["event"] == "reserved" and node and event.get("dispatch_id"):
            active[node] = event["dispatch_id"]
        if (
            event["event"] == "bound"
            and node
            and node in active
            and event.get("model")
            and event.get("handle")
        ):
            bound_models[(active[node], event["handle"])] = event["model"]
        if event["event"] != "transport_requested" or not node:
            continue
        argv = event.get("argv", [])
        try:
            cwd = argv[argv.index("--cwd") + 1]
            operation = event["operation"]
            if operation == "create":
                alias, name = argv[-5], argv[-1]
                if argv[-4:-1] != ["sessions", "new", "--name"]:
                    continue
            elif operation in {"show", "close"}:
                alias, name = argv[-4], argv[-1]
                if argv[-3:-1] != ["sessions", operation]:
                    continue
            elif operation in {"prompt", "cancel", "status"}:
                marker = -6 if operation == "prompt" else -4
                alias, name = argv[marker], argv[marker + 3]
                if argv[marker + 1 : marker + 3] != [operation, "-s"]:
                    continue
            else:
                continue
            acpx = config.get("acpx")
            if acpx is None or alias not in acpx["connections"]:
                continue
            command = acpx["command"]
            if "/" in command or "\\" in command:
                executable = Path(command).expanduser()
                command = str(
                    executable
                    if executable.is_absolute()
                    else Path(config["_path"]).parent / executable
                )
        except (ValueError, IndexError):
            continue
        if cwd != state["workspace"]:
            continue
        key = (cwd, alias, name)
        session = sessions.setdefault(
            key,
            Session(
                name=name,
                connection=alias,
                cwd=cwd,
                attempts=[],
                collection="unavailable",
            ),
        )
        commands[key] = command
        dispatch_id = active.get(node)
        dispatch = dispatches.get(dispatch_id or "")
        if (
            not dispatch_id
            or not dispatch
            or "assignment" not in dispatch
            or dispatch.get("handle", name) != name
        ):
            continue
        assignment = dispatch["assignment"]
        agent = assignment["node"].get("agent")
        profile_name = assignment["agent"]["profile"]
        if not agent:
            continue
        profile = config["profiles"].get(profile_name)
        if profile is not None and profile.get("connection") != alias:
            profile = None
        model = (
            argv[argv.index("--model") + 1]
            if "--model" in argv and argv.index("--model") + 1 < len(argv)
            else None
        )
        effort = config["models"][profile["model"]].get("effort") if profile else None
        attempt = Attempt(
            transport="acp",
            node_id=node,
            dispatch_id=dispatch_id,
            agent=agent,
            role=assignment["agent"]["role"],
            harness=profile.get("harness") if profile else None,
            requested_model=model,
            requested_effort=effort,
        )
        previous = next((a for a in session.attempts if a.dispatch_id == dispatch_id), None)
        if previous is None:
            session.attempts.append(attempt)
        elif effort is not None:
            previous.requested_effort = effort
    for session in sessions.values():
        for attempt in session.attempts:
            bound_key = (attempt.dispatch_id, session.name)
            if bound_key in bound_models:
                attempt.effective_model = bound_models[bound_key]
    deadline = time.monotonic() + 10.0
    for key, session in sessions.items():
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            break
        try:
            response = _show(
                [
                    commands[key],
                    "--cwd",
                    session.cwd,
                    "--format",
                    "json",
                    session.connection,
                    "sessions",
                    "show",
                    session.name,
                ],
                timeout=min(2.0, remaining),
            )
            record = Record.model_validate_json(response.stdout)
            if record.name != session.name or Path(record.cwd) != Path(session.cwd):
                continue
            session.acpx_record_id = record.acpxRecordId
            session.acp_session_id = record.acpSessionId
            session.agent_session_id = record.agentSessionId
            if record.request_token_usage is not None:
                session.request_token_usage = {
                    key: Usage.model_validate(value.model_dump(exclude_unset=True))
                    for key, value in record.request_token_usage.items()
                }
            if record.cumulative_cost is not None:
                session.cumulative_cost = Cost.model_validate(
                    record.cumulative_cost.model_dump(exclude_unset=True)
                )
            session.collection = "ok"
        except (OSError, subprocess.SubprocessError, ValidationError, ValueError, UnicodeError):
            continue
    return ArchiveUsage(
        run_id=state["run_id"],
        project_id=state["config"]["_project"]["data"]["id"],
        sessions=list(sessions.values()),
    ).model_dump(exclude_unset=True)
