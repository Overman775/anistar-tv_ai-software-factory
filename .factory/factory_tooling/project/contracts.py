"""Validated project policy, selected documents and portable review inputs."""

from __future__ import annotations

from typing import NotRequired, TypedDict

from factory_tooling.runtime.command_contract import Execution


class Selector(TypedDict, total=False):
    processes: list[str]
    roles: list[str]
    stages: list[str]
    paths_any: list[str]
    path_regex: str


Rule = TypedDict(
    "Rule",
    {
        "id": str,
        "for": Selector,
        "file": str,
        "project_file": str,
        "documents": list[str],
        "usage": str,
    },
    total=False,
)
ProjectCheck = TypedDict(
    "ProjectCheck",
    {
        "id": str,
        "for": Selector,
        "level": str,
        "decision": str,
        "kind": str,
        "method": str,
        "execution": Execution,
        "after": list[str],
        "approval_action": str,
        "approval_path_regex": str,
    },
    total=False,
)
ReviewCriterion = TypedDict(
    "ReviewCriterion", {"id": str, "lens": str, "for": Selector, "question": str}, total=False
)


class Document(TypedDict):
    path: str
    category: NotRequired[str]


class Gate(TypedDict):
    id: str
    at: list[str]
    checks: NotRequired[list[ProjectCheck]]
    criteria: NotRequired[list[ReviewCriterion]]


class ProjectData(TypedDict):
    id: str
    documents: NotRequired[dict[str, Document]]
    rules: NotRequired[dict[str, list[Rule]]]
    gates: NotRequired[list[Gate]]
    decisions: NotRequired[list[dict[str, object]]]


class Policy(TypedDict):
    data: ProjectData
    path: str
    workspace: str
    profile_root: str
    files: dict[str, str]
    hash: str


class Selection(TypedDict):
    process: str
    audience: str
    role: NotRequired[str | None]
    stage: NotRequired[str | None]
    scope: NotRequired[list[str] | None]


class AcceptedDocument(TypedDict):
    content: str
    sha256: str


class Snapshot(TypedDict):
    profile: ProjectData
    profile_root: str
    manifest: str
    source: str
    files: dict[str, str]
    contents: dict[str, str]
    documents: dict[str, AcceptedDocument]
    sha256: str


class MaterialEntry(TypedDict):
    path: str
    content: str
    sha256: str
    reason: str
    audience: str
    rules: NotRequired[list[Rule]]


class BoundaryGate(TypedDict):
    id: str
    at: str
    checks: NotRequired[list[str]]
    criteria: NotRequired[list[str]]
