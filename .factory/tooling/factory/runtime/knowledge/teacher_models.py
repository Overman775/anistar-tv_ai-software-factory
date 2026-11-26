"""Teacher queue events and their persisted evidence contracts."""

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field
from typing_extensions import TypedDict

from factory.runtime.contracts import (
    Adapter,
    AppliedCase,
    AppliedLesson,
    CardChange,
    Model,
    Nonblank,
    Profile,
    ReportRef,
    RetroNote,
)
from factory.runtime.knowledge.lesson_models import Entry, Key
from factory.runtime.knowledge.lesson_trace_repository import SearchHit
from factory.runtime.workflow_core import digest, graph_identity, require


class TeacherProfile(TypedDict):
    profile_name: str
    profile: Profile
    model: Model
    adapter: Adapter


class TeacherAttempt(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid")
    dispatch_id: Nonblank
    status: Literal["reserved", "running", "stopped"] = "reserved"
    handle: Nonblank | None = None
    evidence: Nonblank | None = None


class TeacherAssignment(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid")
    profile: TeacherProfile | None = None
    attempts: list[TeacherAttempt] = Field(default_factory=list)
    waiting_for: Nonblank | None = None
    done: bool = False


class IncidentEvidence(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid")
    reports: list[ReportRef] = Field(default_factory=list)
    accepted_reports: dict[str, ReportRef] = Field(default_factory=dict)
    applied_cases: list[AppliedCase] = Field(default_factory=list)
    applied_lessons: list[AppliedLesson] = Field(default_factory=list)
    retro: list[RetroNote] = Field(default_factory=list)


class OwnerReply(TypedDict):
    question: Nonblank
    reference: Nonblank
    answer: Nonblank


class TeacherJob(TeacherAssignment):
    model_config = ConfigDict(strict=True, extra="forbid", hide_input_in_errors=True)
    kind: Literal["accept", "retro", "user"]
    incident: Nonblank
    source: Nonblank
    reports: list[ReportRef] = Field(default_factory=list)
    incidents: dict[str, IncidentEvidence] | None = None
    user_instructions: str = ""
    user_sha256: str | None = None
    applied_cases: list[AppliedCase] | None = None
    observation: str = ""
    checkout: str | None = None
    delete_target: Key | None = None
    delete_snapshot: Entry | None = None
    cancelled_by: Nonblank | None = None
    new_observation: Literal[True] | None = None
    operation: Literal["capture", "edit", "audit"] = "capture"
    edit_target: Key | None = None
    changes: list[CardChange] = Field(default_factory=list)
    resolution: Nonblank | None = None
    graph_entry: str = "teacher"
    definitions: dict[str, str] = Field(default_factory=dict)
    handlers: dict[str, str] = Field(default_factory=dict)
    owner_replies: list[OwnerReply] = Field(default_factory=list)

    def check_dispatch(self, dispatch: str | None) -> None:
        if self.incidents is not None or self.attempts or dispatch is not None:
            require(
                self.attempts
                and self.attempts[-1].status == "running"
                and self.attempts[-1].dispatch_id == dispatch,
                "Teacher operation requires the bound dispatch",
            )

    def wait_for_owner(self, question: str) -> None:
        require(not self.done and question.strip(), "Need an open event and an owner question")
        self.waiting_for = question.strip()

    def route(self) -> str:
        if self.delete_target:
            return "delete"
        return self.operation

    def key(self) -> str:
        transient = {
            "attempts",
            "graph_entry",
            "definitions",
            "handlers",
            "owner_replies",
            "changes",
            "resolution",
            "done",
            "waiting_for",
            "user_instructions",
            "user_sha256",
            "delete_snapshot",
            "cancelled_by",
        }
        return graph_identity(self.model_dump(exclude=transient, exclude_none=True))


Event = TeacherJob


class SearchEvidence(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid")
    search_id: int
    node_id: str
    dispatch_id: str
    status: Literal["hit", "miss", "error"]
    query: str | None
    same_catalog: bool | None
    matches: list[SearchHit]


def decode_event(key: str, raw: object) -> TeacherJob:
    event = TeacherJob.model_validate(raw)
    require("operation" in event.model_fields_set, "Missing Teacher operation")
    require(event.key() == key, "Teacher event identity mismatch")
    require(
        digest(event.user_instructions.encode()) == event.user_sha256,
        "Teacher user instructions digest mismatch",
    )
    return event
