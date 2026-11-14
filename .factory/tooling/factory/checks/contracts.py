"""Shared declarations for checks selected by policy and used by runtime."""

from typing import Annotated, Literal

from pydantic import ConfigDict, Field, StringConstraints, with_config
from typing_extensions import TypedDict

from factory.checks.command import CommandExecution, CommandKind

Nonblank = Annotated[str, StringConstraints(pattern=r"\S")]


CheckId = Annotated[str, StringConstraints(pattern=r"^[A-Za-z0-9][A-Za-z0-9_-]*$")]


@with_config(ConfigDict(strict=True, extra="forbid"))
class CheckDeclaration(TypedDict):
    id: CheckId
    category: Literal["acceptance", "project"]
    criteria: list[Nonblank]
    method: Nonblank


@with_config(ConfigDict(strict=True, extra="forbid"))
class ObservationCheck(CheckDeclaration):
    kind: Literal["observation"]


@with_config(ConfigDict(strict=True, extra="forbid"))
class ExecutableCheck(CheckDeclaration):
    kind: CommandKind
    execution: CommandExecution


CheckSpec = Annotated[ObservationCheck | ExecutableCheck, Field(discriminator="kind")]
