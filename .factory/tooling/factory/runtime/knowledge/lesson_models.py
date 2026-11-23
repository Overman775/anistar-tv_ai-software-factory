"""Git lesson identity, card and revision."""

from pydantic import AliasChoices, BaseModel, ConfigDict, Field

from factory.runtime.contracts import LessonId, LessonScope, Nonblank

Key = LessonId
Scope = LessonScope

SCOPES: tuple[Scope, ...] = ("factory", "project")


class Lesson(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid", hide_input_in_errors=True)

    id: Key
    scope: Scope
    title: Nonblank
    applies_when: Nonblank
    observed: Nonblank
    action: Nonblank
    roles: list[Nonblank] = Field(default_factory=list)
    tags: list[Nonblank] = Field(
        default_factory=list, validation_alias=AliasChoices("tags", "terms")
    )
    allowed_case: Nonblank | None = None
    implementation: Nonblank | None = None
    replaced_by: Key | None = None
    edits: list[Nonblank] = Field(default_factory=list)
    sources: dict[Nonblank, list[Nonblank]] = Field(default_factory=dict)


class Entry(BaseModel):
    lesson: Lesson
    revision: str
    path: str
