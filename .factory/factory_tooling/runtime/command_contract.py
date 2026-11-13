"""Command declaration validation; no execution or acceptance policy."""

from typing import Annotated, Literal, NotRequired

from pydantic import (
    AfterValidator,
    ConfigDict,
    Field,
    StringConstraints,
    TypeAdapter,
    ValidationError,
    with_config,
)
from pydantic_core import PydanticCustomError
from typing_extensions import TypedDict

from factory_tooling.validation import validation_message

Argument = Annotated[str, StringConstraints(min_length=1, pattern=r"^[^\x00]+$")]
Name = Annotated[str, StringConstraints(min_length=1)]
CommandKind = Literal["tests", "static", "docs", "build", "codegen"]


@with_config(ConfigDict(strict=True, extra="forbid"))
class Execution(TypedDict):
    argv: list[Argument]
    cwd: Argument
    timeout_seconds: Annotated[int, Field(ge=1, le=86400)]
    inputs: NotRequired[list[Name]]
    outputs: NotRequired[list[Name]]
    stages: NotRequired[Annotated[list[Name], Field(min_length=1)]]
    mode: NotRequired[Literal["full", "filtered", "update"]]


def execution_shape(value: Execution) -> Execution:
    for field, paths in (
        ("inputs", value.get("inputs", [])),
        ("outputs", value.get("outputs", [])),
        ("stages", value.get("stages", [])),
    ):
        if len(set(paths)) != len(paths):
            raise PydanticCustomError("duplicate_execution_field", f"Duplicate execution {field}")
    if "stages" in value:
        if value["argv"] or value.get("outputs"):
            raise PydanticCustomError(
                "composite_execution_fields",
                "Composite execution has no independent argv or outputs",
            )
    elif not value["argv"]:
        raise PydanticCustomError(
            "empty_execution_argv", "Execution argv needs at least one argument"
        )
    return value


CommandExecution = Annotated[Execution, AfterValidator(execution_shape)]
EXECUTION = TypeAdapter[Execution](CommandExecution)


def validate_execution(execution: object) -> Execution:
    """Validate a declared command independently of acceptance coverage."""
    try:
        return EXECUTION.validate_python(execution)
    except ValidationError as exc:
        raise ValueError(validation_message("Invalid execution", exc, EXECUTION)) from None
