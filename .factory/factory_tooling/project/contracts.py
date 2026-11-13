"""Validated project policy, selected documents and portable review inputs."""

from __future__ import annotations

from typing import Annotated, Literal, NotRequired, Required

from pydantic import ConfigDict, Field, StringConstraints, with_config
from typing_extensions import TypedDict

from factory_tooling.decisions.decision_contract import DefinitionData
from factory_tooling.runtime.command_contract import CommandExecution, CommandKind

Nonblank = Annotated[str, StringConstraints(pattern=r"\S")]
Identifier = Annotated[str, StringConstraints(pattern=r"^[A-Za-z0-9][A-Za-z0-9_-]*$")]
Hash = Annotated[str, StringConstraints(pattern=r"^[0-9a-f]{64}$")]


@with_config(ConfigDict(strict=True, extra="forbid"))
class Selector(TypedDict, total=False):
    processes: list[str]
    roles: list[str]
    stages: list[str]
    paths_any: list[str]
    path_regex: str


Rule = TypedDict(
    "Rule",
    {
        "id": Required[Identifier],
        "for": Selector,
        "file": str,
        "project_file": str,
        "documents": list[str],
        "usage": Literal["policy", "reference"],
    },
    total=False,
)
with_config(ConfigDict(strict=True, extra="forbid"))(Rule)
ProjectCheckFields = TypedDict(
    "ProjectCheckFields",
    {
        "id": Required[Identifier],
        "for": Selector,
        "level": Required[Literal["slice", "final"]],
        "decision": Identifier,
        "method": Required[Nonblank],
        "after": list[str],
        "approval_action": Nonblank,
        "approval_path_regex": Nonblank,
    },
    total=False,
)
with_config(ConfigDict(strict=True, extra="forbid"))(ProjectCheckFields)


@with_config(ConfigDict(strict=True, extra="forbid"))
class ProjectObservation(ProjectCheckFields):
    kind: Literal["observation"]


@with_config(ConfigDict(strict=True, extra="forbid"))
class ProjectCommand(ProjectCheckFields):
    kind: CommandKind
    execution: CommandExecution


ProjectCheck = Annotated[ProjectObservation | ProjectCommand, Field(discriminator="kind")]


ReviewCriterion = TypedDict(
    "ReviewCriterion",
    {
        "id": Required[Identifier],
        "lens": Required[Literal["system-design", "runtime-safety", "verification-quality"]],
        "for": Selector,
        "question": Required[Nonblank],
    },
    total=False,
)
with_config(ConfigDict(strict=True, extra="forbid"))(ReviewCriterion)


@with_config(ConfigDict(strict=True, extra="forbid"))
class Document(TypedDict):
    path: str
    category: NotRequired[Nonblank]


@with_config(ConfigDict(strict=True, extra="forbid"))
class Gate(TypedDict):
    id: Identifier
    at: list[str]
    checks: NotRequired[Annotated[list[ProjectCheck], Field(min_length=1)]]
    criteria: NotRequired[Annotated[list[ReviewCriterion], Field(min_length=1)]]


@with_config(ConfigDict(strict=True, extra="forbid"))
class ProjectData(TypedDict):
    id: Annotated[str, StringConstraints(pattern=r"^[a-z][a-z0-9-]*$")]
    documents: NotRequired[dict[Annotated[str, Field(min_length=1)], Document]]
    rules: NotRequired[dict[Literal["coordinator", "worker"], list[Rule]]]
    gates: NotRequired[list[Gate]]
    decisions: NotRequired[list[DefinitionData]]


@with_config(ConfigDict(strict=True, extra="forbid"))
class Policy(TypedDict):
    data: ProjectData
    path: str
    workspace: str
    profile_root: str
    files: dict[str, str]
    hash: str


@with_config(ConfigDict(strict=True, extra="forbid"))
class Selection(TypedDict):
    process: str
    audience: str
    role: NotRequired[str | None]
    stage: NotRequired[str | None]
    scope: NotRequired[list[str] | None]


@with_config(ConfigDict(strict=True, extra="forbid"))
class AcceptedDocument(TypedDict):
    content: str
    sha256: Hash


@with_config(ConfigDict(strict=True, extra="forbid"))
class Snapshot(TypedDict):
    profile: ProjectData
    profile_root: str
    manifest: str
    source: Nonblank
    files: Annotated[dict[str, Hash], Field(min_length=1)]
    contents: dict[str, str]
    documents: dict[str, AcceptedDocument]
    sha256: Hash


@with_config(ConfigDict(strict=True, extra="forbid"))
class MaterialEntry(TypedDict):
    path: str
    content: str
    sha256: str
    reason: str
    audience: str
    rules: NotRequired[list[Rule]]


@with_config(ConfigDict(strict=True, extra="forbid"))
class BoundaryGate(TypedDict):
    id: str
    at: str
    checks: NotRequired[list[str]]
    criteria: NotRequired[list[str]]
