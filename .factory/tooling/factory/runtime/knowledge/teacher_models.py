"""Teacher queue events and their persisted evidence contracts."""

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from factory.runtime.contracts import (
    AppliedCase,
    AppliedLesson,
    CardChange,
    Nonblank,
    ReportRef,
    RetroNote,
)
from factory.runtime.knowledge.lesson_models import Entry, Key
from factory.runtime.knowledge.lesson_trace_repository import SearchHit
from factory.runtime.workflow_core import digest, require


class IncidentEvidence(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid")
    reports: list[ReportRef] = Field(default_factory=list)
    applied_cases: list[AppliedCase] = Field(default_factory=list)
    applied_lessons: list[AppliedLesson] = Field(default_factory=list)
    retro: list[RetroNote] = Field(default_factory=list)


class TeacherJob(BaseModel):
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
    waiting_for: Nonblank | None = None
    done: bool = False
    changes: list[CardChange] = Field(default_factory=list)
    resolution: Nonblank | None = None

    def wait_for_owner(self, question: str) -> None:
        require(not self.done and question.strip(), "Need an open event and an owner question")
        self.waiting_for = question.strip()

    def route(self) -> str:
        if self.delete_target:
            return "delete"
        return self.operation

    def key(self) -> str:
        transient = {
            "changes",
            "resolution",
            "done",
            "waiting_for",
            "user_instructions",
            "user_sha256",
            "delete_snapshot",
            "cancelled_by",
        }
        return digest(self.model_dump_json(exclude=transient, exclude_none=True).encode())


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


def decode_event(key: str, raw: str) -> TeacherJob:
    event = TeacherJob.model_validate_json(raw)
    require("operation" in event.model_fields_set, "Missing Teacher operation")
    require(event.key() == key, "Teacher event identity mismatch")
    require(
        digest(event.user_instructions.encode()) == event.user_sha256,
        "Teacher user instructions digest mismatch",
    )
    return event
