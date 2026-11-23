"""Deliver accepted-work and retrospective evidence to the harness-driven Teacher."""

from datetime import UTC, datetime
from pathlib import Path
from typing import Literal

from factory import file_reader
from factory.database.provider import current_database
from factory.runtime.contracts import (
    AppliedCase,
    AppliedLesson,
    Node,
    State,
)
from factory.runtime.contracts import (
    CardChange as CardChange,
)
from factory.runtime.history.history_repository import HistoryRepository
from factory.runtime.knowledge.case_reports import verified_case
from factory.runtime.knowledge.teacher_job_repository import TeacherJobRepository
from factory.runtime.knowledge.teacher_models import IncidentEvidence as IncidentEvidence
from factory.runtime.knowledge.teacher_models import SearchEvidence as SearchEvidence
from factory.runtime.knowledge.teacher_models import TeacherJob as TeacherJob
from factory.runtime.knowledge.teacher_models import decode_event as decode_event
from factory.runtime.lessons import (
    BASE,
    Lesson,
    catalog,
    catalog_digest,
    lookup,
    publish,
)
from factory.runtime.workflow_core import digest, lock, relative, require
from factory.runtime.workspace import checkout_ref

Event = TeacherJob


def read_event(root: Path, key: str, *, jobs: TeacherJobRepository | None = None) -> TeacherJob:
    jobs = current_database().teacher if jobs is None else jobs
    require(
        len(key) == 64 and all(c in "0123456789abcdef" for c in key), "Invalid Teacher event ID"
    )
    return decode_event(key, jobs.read(root, key))


def require_checkout(root: Path, event: TeacherJob) -> None:
    if event.checkout is not None:
        require(event.checkout == checkout_ref(root), f"Teacher event belongs to {event.checkout}")


def enqueue(root: Path, event: TeacherJob, *, jobs: TeacherJobRepository | None = None) -> str:
    jobs = current_database().teacher if jobs is None else jobs
    key = event.key()

    def prepare() -> TeacherJob:
        if event.delete_target:
            require_checkout(root, event)
            event.delete_snapshot = next(
                (e for e in catalog(root) if e.lesson.id == event.delete_target), None
            )
            require(event.delete_snapshot is not None, "Lesson not found at deletion intake")
        return event

    with lock(relative(root, f"{BASE}/teacher/write.lock"), wait=True):
        jobs.enqueue_once(root, key, prepare)
    return key


def owner_instructions(root: Path) -> str:
    user = relative(root, ".factory/memory/USER.md")
    return file_reader.read_bytes(user).decode() if user.exists() else ""


def capture_case(
    root: Path,
    reference: object,
    observation: str,
    *,
    history: HistoryRepository,
    jobs: TeacherJobRepository,
) -> str:
    """Queue a demonstrated reuse of a verified accepted report."""
    require(observation.strip(), "Explain the demonstrated reuse before requesting capture")
    case = verified_case(root, reference, history=history)
    return enqueue(
        root,
        TeacherJob(
            kind="retro",
            operation="capture",
            incident=case.incident,
            source=case.ref["path"],
            reports=[case.ref],
            observation=observation,
            checkout=case.checkout,
            user_instructions=owner_instructions(root),
        ),
        jobs=jobs,
    )


def update_event(
    root: Path, key: str, event: TeacherJob, *, jobs: TeacherJobRepository | None = None
) -> None:
    jobs = current_database().teacher if jobs is None else jobs
    jobs.update(root, key, event)


def acceptance_details(root: Path, state: State, node: Node) -> dict[str, object]:
    task_nodes = {n["id"] for n in state["graph"]["nodes"] if n["task"] == node["task"]}
    refs = {
        key: ref
        for key, ref in state.get("report_index", {}).items()
        if ref["node_id"] in task_nodes
    }
    applied: list[AppliedCase] = []
    lessons: list[AppliedLesson] = []
    for node_id in sorted(task_nodes):
        dispatch = state["nodes"][node_id]
        report = dispatch.get("report")
        if dispatch["status"] == "done" and report is not None and report["outcome"] == "PASS":
            for lesson in report.get("applied_lessons", []):
                if lesson not in lessons:
                    lessons.append(lesson)
            for case in report.get("applied_cases", []):
                if case not in applied:
                    applied.append(case)
        ref = dispatch.get("report_ref")
        if ref is not None:
            refs.setdefault(ref["dispatch_id"], ref)
    incident = f"{state['run_id']}/{node['id']}"
    for index, prior in enumerate(state["events"]):
        if prior.get("node") == node["id"] and "lesson_reports" in prior:
            incident = prior.get("lesson_incident", f"{incident}/{index}")
            break
    config = state["config"]
    user = Path(config["_path"]).parent / "memory/USER.md"
    branch = checkout_ref(root)
    require(state["lesson_run_checkout"] == branch, "Return to the run checkout")
    return {
        "lesson_incident": incident,
        "lesson_checkout": branch,
        "lesson_user": config.get("_documents", {}).get(str(user), ""),
        "lesson_reports": list(refs.values()),
        **({"lesson_applications": lessons} if lessons else {}),
        **({"lesson_applied_cases": applied} if applied else {}),
    }


def run_review_event(state: State) -> TeacherJob | None:
    if state["status"] != "completed":
        return None
    incidents: dict[str, IncidentEvidence] = {}
    for record in state["events"]:
        incident = record.get("lesson_incident")
        if incident is None:
            continue
        if "lesson_reports" in record and record.get("node") not in state["nodes"]:
            continue  # A graph revision can remove a previously accepted task.
        evidence = incidents.setdefault(incident, IncidentEvidence())
        if "lesson_reports" in record:
            # Reacceptance includes earlier attempts but replaces superseded claims of reuse.
            evidence.reports = record["lesson_reports"]
            evidence.applied_cases = record.get("lesson_applied_cases", [])
            evidence.applied_lessons = record.get("lesson_applications", [])
        if "lesson_retro" in record:
            evidence.retro.append(record["lesson_retro"])
    config = state["config"]
    user = Path(config["_path"]).parent / "memory/USER.md"
    return TeacherJob(
        kind="accept",
        operation="capture",
        incident=state["run_id"],
        source=state["archive_path"],
        checkout=state["lesson_run_checkout"],
        user_instructions=config.get("_documents", {}).get(str(user), ""),
        observation=state.get("summary", ""),
        incidents=incidents,
    )


def finalizer(
    root: Path, state: State, *, jobs: TeacherJobRepository | None = None
) -> dict[str, str]:
    """Resolve the planned run-level step against its durable job."""
    role = state["graph"].get("after_archive", "teacher")
    if state["status"] != "completed":
        return {"role": role, "status": "skipped" if state["status"] == "cancelled" else "planned"}
    key = state.get("final_teacher_event")
    if key is None:
        # Older completed snapshots have the same deterministic job, without its stored ID.
        review = run_review_event(state)
        assert review is not None
        key = review.key()
    event = read_event(root, key, jobs=jobs)
    status = "done" if event.done else "waiting" if event.waiting_for else "ready"
    if status == "ready" and event.checkout and event.checkout != checkout_ref(root):
        status = "wrong_checkout"
    return {"role": role, "status": status, "event_id": key}


def pending(
    root: Path, *, waiting: bool = False, jobs: TeacherJobRepository | None = None
) -> list[str]:
    jobs = current_database().teacher if jobs is None else jobs
    return jobs.pending(root, waiting, lambda: checkout_ref(root))


def park(root: Path, key: str, question: str, *, jobs: TeacherJobRepository | None = None) -> None:
    with lock(relative(root, f"{BASE}/teacher/write.lock"), wait=True):
        event = read_event(root, key, jobs=jobs)
        require_checkout(root, event)
        event.wait_for_owner(question)
        update_event(root, key, event, jobs=jobs)


def route(root: Path, key: str, *, jobs: TeacherJobRepository | None = None) -> dict[str, object]:
    event = read_event(root, key, jobs=jobs)
    require_checkout(root, event)
    return {
        "kind": event.kind,
        "operation": event.route(),
        "observation": event.observation,
        "user_instructions": event.user_instructions,
        "waiting_for": event.waiting_for,
        "done": event.done,
    }


def packet(root: Path, key: str, *, jobs: TeacherJobRepository | None = None) -> dict[str, object]:
    event = read_event(root, key, jobs=jobs)
    require_checkout(root, event)
    if event.edit_target:
        entries = lookup(root, event.edit_target)
    else:
        entries = catalog(root)
    return {"event": event.model_dump(), "catalog": [e.model_dump() for e in entries]}


def search_feedback(
    root: Path, key: str, incident: str, *, jobs: TeacherJobRepository | None = None
) -> list[SearchEvidence]:
    jobs = current_database().teacher if jobs is None else jobs
    event = read_event(root, key, jobs=jobs)
    require_checkout(root, event)
    require(
        event.kind == "accept" and event.incidents is not None and incident in event.incidents,
        "Select an accepted incident in this Teacher event",
    )
    assert event.incidents is not None
    refs = event.incidents[incident].reports
    current = catalog_digest((entry.path, entry.revision) for entry in catalog(root))
    return jobs.feedback(root, refs, event.incident, current)


def apply(
    root: Path,
    key: str,
    card: Lesson,
    revision: str | None,
    incident: str | None = None,
    *,
    jobs: TeacherJobRepository | None = None,
) -> dict[str, object]:
    with lock(relative(root, f"{BASE}/teacher/write.lock"), wait=True):
        event = read_event(root, key, jobs=jobs)
        require_checkout(root, event)
        require(not event.done, "Teacher event already complete")
        require(not event.waiting_for, "Awaiting owner reply")
        if event.operation == "edit":
            require(card.id == event.edit_target and revision, "Edit requires its existing target")
        if event.operation == "audit":
            require(revision, "Maintenance updates an existing lesson")
        require(event.delete_target is None, "Use refresh for a deletion request")
        if event.incidents is not None:
            if incident is None and len(event.incidents) == 1:
                incident = next(iter(event.incidents))
            require(incident in event.incidents, "Select a packet incident using --incident")
        else:
            require(incident in (None, event.incident), "Incident does not belong to event")
        source = f"{event.kind}:{event.source}#{key}"
        occurrence = incident or event.incident

        def preparing(action: Literal["created", "updated"], checksum: str) -> None:
            change = CardChange(
                id=card.id,
                scope=card.scope,
                action=action,
                revision=checksum,
                incident=occurrence,
                at=datetime.now(UTC).isoformat(),
            )
            if not any(c.revision == checksum and c.id == card.id for c in event.changes):
                event.changes.append(change)
                update_event(root, key, event, jobs=jobs)

        entry = publish(
            root,
            card,
            revision,
            incident or event.incident,
            source,
            editorial_update=event.kind == "user" and not event.new_observation,
            before_write=preparing,
        )
        for change in event.changes:
            if change.id == card.id and change.revision == entry.revision and not change.confirmed:
                change.confirmed = True
                update_event(root, key, event, jobs=jobs)
        return entry.model_dump()


def _record_deletion(
    root: Path, key: str, event: TeacherJob, *, jobs: TeacherJobRepository | None = None
) -> None:
    target = event.delete_snapshot
    assert target is not None
    if not event.changes:
        event.changes.append(
            CardChange(
                id=target.lesson.id,
                scope=target.lesson.scope,
                action="deleted",
                revision=target.revision,
                incident=event.incident,
                confirmed=True,
                at=datetime.now(UTC).isoformat(),
            )
        )
        update_event(root, key, event, jobs=jobs)


def delete(
    root: Path, key: str, revision: str, *, jobs: TeacherJobRepository | None = None
) -> None:
    with lock(relative(root, f"{BASE}/teacher/write.lock"), wait=True):
        event = read_event(root, key, jobs=jobs)
        require_checkout(root, event)
        require(event.kind == "user" and event.delete_target, "Explicit user deletion required")
        require(not event.done, "Teacher event already complete")
        require(not event.waiting_for, "Awaiting owner reply")
        # The rename is both removal and a receipt for retries before completion.
        receipt = relative(root, f"{BASE}/teacher/{key}.removed")
        if receipt.exists():
            require(
                digest(file_reader.read_bytes(receipt)) == revision, "Deletion revision mismatch"
            )
            _record_deletion(root, key, event, jobs=jobs)
            return
        require(
            event.delete_snapshot is not None and event.delete_snapshot.revision == revision,
            "Lesson changed or original revision unavailable; ask the owner about this version",
        )
        entries = catalog(root)
        target = next((e for e in entries if e.lesson.id == event.delete_target), None)
        require(target is not None, "Lesson not found")
        assert target is not None
        require(
            target.revision == revision,
            "Lesson changed since request; ask the owner about this version",
        )
        inbound = [e.lesson.id for e in entries if e.lesson.replaced_by == event.delete_target]
        require(not inbound, "Referenced by replaced_by: " + ", ".join(inbound))
        relative(root, target.path).replace(receipt)
        _record_deletion(root, key, event, jobs=jobs)


def complete(
    root: Path,
    key: str,
    cancelled_by: str | None = None,
    reason: str | None = None,
    *,
    jobs: TeacherJobRepository | None = None,
) -> None:
    with lock(relative(root, f"{BASE}/teacher/write.lock"), wait=True):
        event = read_event(root, key, jobs=jobs)
        require_checkout(root, event)
        if not event.done:
            if cancelled_by is not None:
                require(
                    (event.delete_target or event.waiting_for) and cancelled_by.strip(),
                    "Need owner cancellation reference",
                )
                require(
                    not relative(root, f"{BASE}/teacher/{key}.removed").exists(),
                    "Already deleted",
                )
                event.cancelled_by = cancelled_by
            elif event.waiting_for:
                raise ValueError("Awaiting owner reply")
            elif event.delete_target:
                require(
                    relative(root, f"{BASE}/teacher/{key}.removed").exists()
                    or all(e.lesson.id != event.delete_target for e in catalog(root)),
                    "Unresolved deletion; keep pending until owner decision",
                )
            if event.delete_target and relative(root, f"{BASE}/teacher/{key}.removed").is_file():
                _record_deletion(root, key, event, jobs=jobs)
            for change in event.changes:
                if not change.confirmed:
                    path = relative(root, f"{BASE}/lessons/{change.scope}/{change.id}.md")
                    change.confirmed = (
                        path.is_file() and digest(file_reader.read_bytes(path)) == change.revision
                    )
            if reason is not None:
                require(reason.strip(), "Give a nonblank completion reason")
                event.resolution = reason.strip()
            event.done = True
            update_event(root, key, event, jobs=jobs)
        if event.delete_target:
            relative(root, f"{BASE}/teacher/{key}.removed").unlink(missing_ok=True)
