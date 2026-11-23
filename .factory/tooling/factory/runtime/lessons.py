"""Git-owned lessons, optimistic publication and checkout-local full-text search."""

import json
import os
import re
import time
from collections.abc import Callable, Iterable
from pathlib import Path
from tempfile import NamedTemporaryFile
from typing import Literal

import yaml
from pydantic import BaseModel

from factory import file_reader
from factory.database.provider import current_database
from factory.paths import MEMORY
from factory.project.profile_io import parse_yaml
from factory.runtime.knowledge.lesson_index import LessonIndex, LessonIndexError, search_terms
from factory.runtime.knowledge.lesson_models import SCOPES as SCOPES
from factory.runtime.knowledge.lesson_models import Entry as Entry
from factory.runtime.knowledge.lesson_models import Key as Key
from factory.runtime.knowledge.lesson_models import Lesson as Lesson
from factory.runtime.knowledge.lesson_models import Scope as Scope
from factory.runtime.knowledge.lesson_trace_repository import LessonTraceRepository
from factory.runtime.observability import lesson_telemetry
from factory.runtime.workflow_core import digest, lock, relative, require

BASE = MEMORY


def _documents(root: Path) -> dict[str, bytes]:
    files: dict[str, bytes] = {}
    for scope in SCOPES:
        folder = relative(root, f"{BASE}/lessons/{scope}")
        try:
            paths = sorted(folder.iterdir())
        except FileNotFoundError:
            continue
        for path in paths:
            if path.suffix != ".md":
                continue
            name = path.relative_to(root).as_posix()
            files[name] = file_reader.read_bytes(relative(root, name))
    return files


def _entry(name: str, raw: bytes) -> Entry:
    text = raw.decode("utf-8").replace("\r\n", "\n")
    header, separator, body = text.removeprefix("---\n").partition("\n---\n")
    require(text.startswith("---\n") and separator, f"Missing lesson front matter: {name}")
    meta = parse_yaml(header)
    require(isinstance(meta, dict) and "action" not in meta, f"Invalid lesson: {name}")
    card = Lesson.model_validate({**meta, "action": body.strip()})
    require(
        name == f"{BASE}/lessons/{card.scope}/{card.id}.md", f"Lesson identity mismatch: {name}"
    )
    return Entry(lesson=card, revision=digest(raw), path=name)


def _entries(files: dict[str, bytes]) -> list[Entry]:
    seen: set[str] = set()
    entries = []
    for name, raw in files.items():
        entry = _entry(name, raw)
        require(entry.lesson.id not in seen, f"Duplicate lesson ID: {entry.lesson.id}")
        seen.add(entry.lesson.id)
        entries.append(entry)
    return entries


def catalog(root: Path) -> list[Entry]:
    return _entries(_documents(root))


def lookup(root: Path, lesson_id: Key) -> list[Entry]:
    files = {}
    for scope in SCOPES:
        name = f"{BASE}/lessons/{scope}/{lesson_id}.md"
        try:
            files[name] = file_reader.read_bytes(relative(root, name))
        except FileNotFoundError:
            continue
    return _entries(files)


def publish(
    root: Path,
    card: Lesson,
    revision: str | None,
    incident: str,
    event: str,
    *,
    editorial_update: bool = False,
    before_write: Callable[[Literal["created", "updated"], str], None] | None = None,
) -> Entry:
    """Call under the Teacher lock. Never trust provenance supplied by the model."""
    require(not card.sources and not card.edits, "Sources are assigned by the runtime")
    card = card.model_copy(update={"action": card.action.replace("\r\n", "\n").strip()})
    for tag in card.tags:
        require(
            re.fullmatch(r"[\w-]+(?:/[\w-]+)*", tag) and not tag.isdecimal(),
            f"Invalid lesson tag: {tag}. Use words, hyphens, underscores or nested tags.",
        )
    inventory = {entry.lesson.id: entry for entry in catalog(root)}
    old = inventory.get(card.id)
    name = f"{BASE}/lessons/{card.scope}/{card.id}.md"
    require(not old or old.path == name, "Lesson scope conflict")
    if old and (event in old.lesson.sources.get(incident, []) or event in old.lesson.edits):
        require(
            card.model_dump(exclude={"sources", "edits"})
            == old.lesson.model_dump(exclude={"sources", "edits"}),
            "This event already published different content for the same lesson",
        )
        return old
    require(revision == (old.revision if old else None), "Lesson changed; reread catalog")
    if card.replaced_by:
        target = inventory.get(card.replaced_by)
        require(
            target and target.lesson.id != card.id and not target.lesson.replaced_by,
            "Replacement must be a different active lesson",
        )
    sources = dict(old.lesson.sources) if old else {}
    edits = list(old.lesson.edits) if old else []
    if old and editorial_update:
        edits.append(event)
    else:
        sources[incident] = sorted({*sources.get(incident, []), event})
    updated = card.model_copy(update={"sources": sources, "edits": edits})
    header = yaml.safe_dump(
        updated.model_dump(exclude={"action"} if edits else {"action", "edits"}, exclude_none=True),
        allow_unicode=True,
        sort_keys=False,
    )
    raw = f"---\n{header}---\n{updated.action}\n".encode()
    if before_write is not None:
        before_write("updated" if old else "created", digest(raw))
    path = relative(root, name)
    path.parent.mkdir(parents=True, exist_ok=True)
    with NamedTemporaryFile(dir=path.parent, delete=False) as output:
        tmp = Path(output.name)
        try:
            output.write(raw)
            output.flush()
            os.fsync(output.fileno())
        except BaseException:
            output.close()
            tmp.unlink(missing_ok=True)
            raise
    try:
        os.replace(tmp, path)
    finally:
        tmp.unlink(missing_ok=True)
    return Entry(lesson=updated, revision=digest(raw), path=name)


class Match(BaseModel):
    source_type: Literal["lesson"] = "lesson"
    revision: str
    id: str
    scope: Scope
    applies_when: str
    action: str
    path: str


def catalog_digest(revisions: Iterable[tuple[str, str]]) -> str:
    return digest(json.dumps(sorted(revisions), separators=(",", ":")).encode())


def search_lessons(
    root: Path,
    query: str,
    *,
    run_id: str | None = None,
    dispatch_id: str | None = None,
    index: LessonIndex | None = None,
    traces: LessonTraceRepository | None = None,
) -> list[Match]:
    index = current_database().lessons if index is None else index
    require(bool(run_id) == bool(dispatch_id), "Supply run and dispatch together")
    start = time.monotonic()
    try:
        matches, stamp = _search(root, query, capture_catalog=run_id is not None, index=index)
    except (OSError, ValueError) as exc:
        lesson_telemetry.record_search(
            root,
            run_id,
            dispatch_id,
            query,
            start,
            [],
            exc.error_type if isinstance(exc, LessonIndexError) else type(exc).__name__,
            store=traces,
        )
        raise
    hits: list[lesson_telemetry.SearchHit] = [
        {"id": m.id, "scope": m.scope, "revision": m.revision} for m in matches
    ]
    lesson_telemetry.record_search(
        root, run_id, dispatch_id, query, start, hits, None, stamp, store=traces
    )
    return matches


def _index_document(path: str, raw: bytes) -> tuple[str, str] | None:
    card = _entry(path, raw).lesson
    if card.replaced_by:
        return None
    return card.id, " ".join(
        (card.title, card.applies_when, card.observed, card.action, *card.roles, *card.tags)
    )


def _search(
    root: Path, query: str, *, capture_catalog: bool, index: LessonIndex
) -> tuple[list[Match], str | None]:
    terms = search_terms(query)
    if not terms:
        return [], None
    with lock(relative(root, f"{BASE}/cache/lessons.lock"), wait=True):
        files = _documents(root)
        paths, revisions = index.search(root, files, terms, _index_document)
        matches = []
        for name in paths:
            entry = _entry(name, files[name])
            c = entry.lesson
            matches.append(
                Match(
                    revision=entry.revision,
                    id=c.id,
                    scope=c.scope,
                    applies_when=c.applies_when,
                    action=c.action,
                    path=name,
                )
            )
        return matches, catalog_digest(revisions.items()) if capture_catalog else None
