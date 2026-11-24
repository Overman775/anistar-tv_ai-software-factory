"""Versioned JSON contracts for CLI help publication."""

from typing import Annotated, Literal, TypedDict

from pydantic import (
    BeforeValidator,
    ConfigDict,
    Field,
    FiniteFloat,
    TypeAdapter,
    ValidationError,
    with_config,
)

from factory.cli_metadata.model import OutputFormat
from factory.validation import validation_message

HELP_RECORD = ConfigDict(strict=True, extra="forbid")


def _integer_version(value: object) -> object:
    # Literal[1] alone also accepts True and 1.0.
    if type(value) is not int:
        raise ValueError("Expected an integer schema version")
    return value


type SchemaVersion = Annotated[Literal[1], BeforeValidator(_integer_version)]
type JsonValue = None | bool | int | FiniteFloat | str | list[JsonValue] | dict[str, JsonValue]
type ArgumentCount = Annotated[int, Field(ge=0)] | Literal["?", "*", "+", "...", "A..."] | None


@with_config(HELP_RECORD)
class HelpArgument(TypedDict):
    name: str
    flags: list[str]
    required: bool
    nargs: ArgumentCount
    metavar: str | list[str] | None
    choices: list[JsonValue] | None
    default: JsonValue
    value_type: str | None
    repeatable: bool
    description: str


@with_config(HELP_RECORD)
class HelpArgumentGroup(TypedDict):
    path: list[str]
    arguments: list[HelpArgument]


@with_config(HELP_RECORD)
class HelpExclusiveGroup(TypedDict):
    required: bool
    members: list[str]


@with_config(HELP_RECORD)
class HelpEffects(TypedDict):
    description: str
    may_write: list[str]
    may_contact_or_run: list[str]


@with_config(HELP_RECORD)
class HelpOutput(TypedDict):
    default: OutputFormat
    json: Literal["json"]


@with_config(HELP_RECORD)
class HelpCommand(TypedDict):
    path: list[str]
    usage: str
    description: str
    arguments: list[HelpArgument]
    group_arguments: list[HelpArgumentGroup]
    exclusive_groups: list[HelpExclusiveGroup]
    subcommands: list[str]
    aliases: list[str]
    requirements: str
    effects: HelpEffects
    examples: list[str]
    supports_dry_run: bool
    output: HelpOutput


@with_config(HELP_RECORD)
class HelpCatalog(TypedDict):
    schema_version: SchemaVersion
    program: Literal["cli"]
    topics: list[str]
    commands: list[HelpCommand]


@with_config(HELP_RECORD)
class HelpTopic(TypedDict):
    schema_version: SchemaVersion
    topic: list[str]
    text: str


HELP_CATALOG = TypeAdapter[HelpCatalog](HelpCatalog)
HELP_TOPIC = TypeAdapter[HelpTopic](HelpTopic)


def validate_catalog(value: object) -> HelpCatalog:
    try:
        return HELP_CATALOG.validate_python(value, strict=True)
    except ValidationError as exc:
        raise ValueError(
            validation_message("Invalid CLI help catalog", exc, HELP_CATALOG)
        ) from None


def validate_topic(value: object) -> HelpTopic:
    try:
        return HELP_TOPIC.validate_python(value, strict=True)
    except ValidationError as exc:
        raise ValueError(validation_message("Invalid CLI help topic", exc, HELP_TOPIC)) from None
