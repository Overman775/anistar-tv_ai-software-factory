"""Command declaration validation; no execution or acceptance policy."""

from typing import NotRequired, TypedDict, cast


class Execution(TypedDict):
    argv: list[str]
    cwd: str
    timeout_seconds: int
    inputs: NotRequired[list[str]]
    outputs: NotRequired[list[str]]
    stages: NotRequired[list[str]]
    mode: NotRequired[str]


def require(condition: object, message: str) -> None:
    if not condition:
        raise ValueError(message)


def validate_execution(execution: object) -> Execution:
    """Validate a declared command independently of acceptance coverage."""
    require(isinstance(execution, dict), "Required command needs execution")
    if not isinstance(execution, dict):
        raise ValueError("Required command needs execution")
    require(
        set(execution) <= {"argv", "cwd", "timeout_seconds", "inputs", "outputs", "stages", "mode"},
        "Unknown execution field",
    )
    if not isinstance(execution, dict):
        raise ValueError("Required command needs execution")
    for field in ("inputs", "outputs"):
        paths = execution.get(field, [])
        require(
            isinstance(paths, list)
            and all(isinstance(x, str) and x for x in paths)
            and len(set(paths)) == len(paths),
            "Invalid execution " + field,
        )
    require(execution.get("mode", "full") in {"full", "filtered", "update"}, "Invalid check mode")
    stages = execution.get("stages")
    if stages is not None:
        require(
            isinstance(stages, list)
            and stages
            and all(isinstance(x, str) and x for x in stages)
            and len(set(stages)) == len(stages)
            and not execution.get("outputs"),
            "Invalid composite execution stages",
        )
        require(execution.get("argv") == [], "Composite execution has no independent argv")
    argv = execution.get("argv")
    require(
        isinstance(argv, list)
        and (argv or stages)
        and all(isinstance(x, str) and x and "\0" not in x for x in argv),
        "Invalid execution argv",
    )
    require(
        isinstance(execution.get("cwd"), str) and execution["cwd"] and "\0" not in execution["cwd"],
        "Invalid execution cwd",
    )
    require(
        type(execution.get("timeout_seconds")) is int and 0 < execution["timeout_seconds"] <= 86400,
        "Invalid execution timeout",
    )
    return cast(Execution, execution)
