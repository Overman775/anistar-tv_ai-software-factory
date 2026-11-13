"""Task, envelope and Markdown consistency rules."""

from __future__ import annotations

import re
from typing import Any

from factory_tooling.decompose.contracts import Envelope, LoadedTask
from factory_tooling.decompose.task_data import (
    CAPABILITY_ID_RE,
    PURPOSE_LABELS,
    TASK_FILENAME_RE,
    TASK_ID_SEQUENCE_RE,
    VALID_COVERAGE,
    _format_hours,
    _is_nonempty_text,
    _is_number,
    _relation_ids,
    capabilities_by_task,
)
from factory_tooling.runtime.acceptance import criteria_map, plan_criteria
from factory_tooling.runtime.acceptance import ids as acceptance_ids


def _validate_task(task_id: str, task: LoadedTask, tasks: dict[str, LoadedTask]) -> list[str]:
    messages = list(task.get("structural_errors", []))
    sequence = TASK_ID_SEQUENCE_RE.search(task_id)
    filename = task.get("filename")
    filename_match = TASK_FILENAME_RE.fullmatch(filename) if isinstance(filename, str) else None
    if not sequence:
        messages.append(f"🚨 Task '{task_id}': ID must end with sequence number -NN.")
    elif filename_match is None or filename_match.group(1) != sequence.group(1):
        messages.append(
            f"🚨 Task '{task_id}': filename must use format '{sequence.group(1)}-slug.md'."
        )

    estimate = task.get("estimate_raw")
    if isinstance(estimate, dict):
        min_hours, max_hours = estimate.get("min_hours"), estimate.get("max_hours")
        if _is_number(min_hours) and _is_number(max_hours) and min_hours > max_hours:
            messages.append(f"🚨 Task '{task_id}': estimate.min_hours cannot exceed max_hours.")

    purpose = task.get("purpose")
    if purpose == "technical_preparation":
        consumers = task.get("consumers")
        if not isinstance(consumers, list) or not consumers:
            messages.append(
                f"🚨 Task '{task_id}': technical_preparation requires non-empty list consumers."
            )
        else:
            for consumer_id in consumers:
                if not _is_nonempty_text(consumer_id) or consumer_id not in tasks:
                    messages.append(
                        f"🚨 Task '{task_id}': consumer '{consumer_id}' "
                        "not found among decomposition tasks."
                    )

    if purpose == "research":
        if not _is_nonempty_text(task.get("research_question")):
            messages.append(f"🚨 Task '{task_id}': research_question must be a non-empty string.")
        if "timebox_hours" not in task or task["timebox_hours"] is None:
            messages.append(f"🚨 Task '{task_id}': timebox_hours is required for research.")
        if not _is_nonempty_text(task.get("expected_result")):
            messages.append(f"🚨 Task '{task_id}': expected_result must be a non-empty string.")

    return messages


def validate_dependencies(tasks: dict[str, LoadedTask]) -> list[str]:
    messages = []
    filename_owners: dict[str, str] = {}

    for task_id, task in tasks.items():
        filename = task.get("filename")
        if _is_nonempty_text(filename):
            previous_owner = filename_owners.get(filename)
            if previous_owner is not None:
                messages.append(
                    f"🚨 Tasks '{previous_owner}' and '{task_id}' use "
                    f"the same filename '{filename}'."
                )
            else:
                filename_owners[filename] = task_id

        messages.extend(_validate_task(task_id, task, tasks))

        for dependency_id in _relation_ids(task.get("depends_on")):
            if dependency_id not in tasks:
                messages.append(f"🚨 Task '{task_id}' depends on missing task '{dependency_id}'.")

        parent_task = task.get("parent_task")
        if _is_nonempty_text(parent_task) and parent_task not in tasks:
            messages.append(
                f"🚨 Task '{task_id}': parent task '{parent_task}' "
                "not found in the current decomposition."
            )

        deferred = task.get("deferred", [])
        if not isinstance(deferred, list):
            continue
        for item in deferred:
            if not isinstance(item, dict):
                messages.append(f"🚨 Task '{task_id}': deferred behavior item must be an object.")
                continue
            completed_by = item.get("completed_by")
            behavior = item.get("behavior")
            if not _is_nonempty_text(completed_by) or completed_by not in tasks:
                messages.append(
                    f"🚨 Task '{task_id}': deferred behavior "
                    f"'{behavior or 'untitled'}' "
                    f"references missing closing task '{completed_by}'."
                )
            elif completed_by == task_id:
                messages.append(
                    f"🚨 Task '{task_id}': deferred behavior "
                    f"'{behavior or 'untitled'}' cannot be closed by the same task."
                )

    return messages


def validate_envelopes(
    envelopes: list[Envelope], tasks: dict[str, LoadedTask], source_lock: dict[str, Any] | None
) -> list[str]:
    messages = []
    if not envelopes:
        return ["🚨 No valid task_result envelope."]

    try:
        expected = acceptance_ids(
            (source_lock or {}).get("acceptance_ids"), "source acceptance_ids"
        )
        assigned = set()
        closers: dict[str, set[str]] = {}
        contributors: dict[str, set[str]] = {}
        for task_id, task in tasks.items():
            closing = acceptance_ids(task.get("acceptance_ids"), "task acceptance_ids", empty=True)
            contribution = acceptance_ids(
                task.get("contributes_to_acceptance_ids", []),
                "task contributes_to_acceptance_ids",
                empty=True,
            )
            if not (closing | contribution) <= expected:
                raise ValueError("Unknown parent acceptance criterion")
            if task.get("purpose") == "functionality" and not (closing | contribution):
                raise ValueError("Functional task needs parent acceptance closure or contribution")
            local = task.get("local_acceptance_criteria", [])
            if local or (not closing and task.get("purpose") == "functionality"):
                criteria_map(local)
            if not isinstance(local, list):
                raise ValueError("Invalid local_acceptance_criteria")
            assigned |= closing
            for cid in closing:
                closers.setdefault(cid, set()).add(task_id)
            for cid in contribution:
                contributors.setdefault(cid, set()).add(task_id)
        if assigned != expected:
            raise ValueError("Acceptance closer coverage differs from source lock")

        def predecessors(task_id: str, seen: set[str] | None = None) -> set[str]:
            seen = set() if seen is None else seen
            for dependency in _relation_ids(tasks[task_id].get("depends_on")):
                if dependency in tasks and dependency not in seen:
                    seen.add(dependency)
                    predecessors(dependency, seen)
            return seen

        for cid, producers in contributors.items():
            if not any(
                producers <= predecessors(closer) | {closer} for closer in closers.get(cid, set())
            ):
                raise ValueError(f"Acceptance closer must depend on all contributors: {cid}")
    except ValueError as error:
        messages.append(f"🚨 {error}")

    expected_source = None
    expected_capabilities = set()
    has_capability_lock = False
    if isinstance(source_lock, dict):
        expected_source = {
            "plan_id": source_lock.get("plan_id"),
            "revision": source_lock.get("plan_revision"),
            "hash": source_lock.get("plan_hash"),
        }
        capability_ids = source_lock.get("capability_ids")
        if isinstance(capability_ids, list):
            has_capability_lock = True
            expected_capabilities = set(capability_ids)

    coverage_by_capability = {}
    covered_task_ids = set()
    for envelope in envelopes:
        relative_file = envelope["relative_file"]
        source_plan = envelope.get("source_plan")
        if not isinstance(source_plan, dict):
            messages.append(f"🚨 File '{relative_file}': source_plan must be an object.")
        elif expected_source is not None and source_plan != expected_source:
            messages.append(f"🚨 File '{relative_file}': source_plan does not match source lock.")

        if not _is_nonempty_text(envelope.get("summary")):
            messages.append(f"🚨 File '{relative_file}': summary must be a non-empty string.")

        envelope_tasks = [task for task in tasks.values() if task.get("file") == envelope["file"]]
        expected_min = sum(task["estimate_min_hours"] for task in envelope_tasks)
        expected_max = sum(task["estimate_max_hours"] for task in envelope_tasks)
        for field, expected_total in (
            ("total_min_hours", expected_min),
            ("total_max_hours", expected_max),
        ):
            value = envelope.get(field)
            if not _is_number(value):
                messages.append(f"🚨 File '{relative_file}': {field} must be a number.")
            elif float(value) != float(expected_total):
                messages.append(
                    f"🚨 File '{relative_file}': {field}={value}, "
                    f"expected {_format_hours(expected_total)}."
                )

        coverage = envelope.get("capability_coverage")
        if not isinstance(coverage, list):
            messages.append(f"🚨 File '{relative_file}': capability_coverage must be a list.")
            continue
        for index, item in enumerate(coverage, start=1):
            if not isinstance(item, dict):
                messages.append(
                    f"🚨 File '{relative_file}': capability_coverage #{index} must be an object."
                )
                continue
            capability_id = item.get("capability_id")
            disposition = item.get("coverage")
            task_ids = item.get("task_ids")
            if (
                not isinstance(capability_id, str)
                or CAPABILITY_ID_RE.fullmatch(capability_id) is None
            ):
                messages.append(
                    f"🚨 File '{relative_file}': invalid capability_id '{capability_id}'."
                )
                continue
            if capability_id in coverage_by_capability:
                messages.append(f"🚨 Capability '{capability_id}' has more than one disposition.")
                continue
            coverage_by_capability[capability_id] = disposition
            if disposition not in VALID_COVERAGE:
                messages.append(
                    f"🚨 Capability '{capability_id}': unknown coverage '{disposition}'."
                )
            if not isinstance(task_ids, list):
                messages.append(f"🚨 Capability '{capability_id}': task_ids must be a list.")
                continue
            if disposition == "complete" and not task_ids:
                messages.append(f"🚨 Capability '{capability_id}': complete requires task_ids.")
            if disposition in {"external", "out_of_scope"} and task_ids:
                messages.append(
                    f"🚨 Capability '{capability_id}': {disposition} must not reference tasks."
                )
            for task_id in task_ids:
                if not _is_nonempty_text(task_id) or task_id not in tasks:
                    messages.append(
                        f"🚨 Capability '{capability_id}' references missing task '{task_id}'."
                    )
                elif disposition == "complete":
                    covered_task_ids.add(task_id)

    actual_capabilities = set(coverage_by_capability)
    if has_capability_lock and actual_capabilities != expected_capabilities:
        missing = sorted(expected_capabilities - actual_capabilities)
        extra = sorted(actual_capabilities - expected_capabilities)
        messages.append(
            "🚨 Capability coverage does not match source lock: "
            f"missing={missing or '—'}, extra={extra or '—'}."
        )
    if expected_capabilities:
        uncovered_tasks = sorted(set(tasks) - covered_task_ids)
        if uncovered_tasks:
            messages.append(
                f"🚨 Tasks without complete capability coverage: {', '.join(uncovered_tasks)}."
            )
    return messages


def _markdown_field(text: str, label: str) -> str | None:
    pattern = re.compile(rf"(?m)^-[^\S\n]+\*\*{re.escape(label)}:\*\*[^\S\n]*(.*?)[^\S\n]*$")
    match = pattern.search(text)
    return match.group(1).strip() if match else None


def _plain_markdown_value(value: str | None) -> str | None:
    return value.replace("`", "").strip().rstrip(".") if isinstance(value, str) else value


def validate_markdown_files(tasks: dict[str, LoadedTask], envelopes: list[Envelope]) -> list[str]:
    messages = []
    source_by_file = {envelope["file"]: envelope.get("source_plan") for envelope in envelopes}
    task_capabilities = capabilities_by_task(tasks, envelopes)
    for task_id, task in tasks.items():
        markdown_file = task.get("markdown_file")
        if markdown_file is None:
            continue
        try:
            with open(markdown_file, encoding="utf-8") as file:
                content = file.read()
        except Exception as error:
            messages.append(f"🚨 Task '{task_id}': Markdown cannot be read: {error}")
            continue

        visible_id = _plain_markdown_value(_markdown_field(content, "ID"))
        if visible_id != task_id:
            messages.append(
                f"🚨 Task '{task_id}': visible ID '{visible_id}' does not match the envelope."
            )
        visible_scope = _plain_markdown_value(_markdown_field(content, "Scope"))
        if visible_scope != task.get("scope"):
            messages.append(
                f"🚨 Task '{task_id}': visible scope '{visible_scope}' does not match the envelope."
            )
        visible_purpose = _plain_markdown_value(_markdown_field(content, "Purpose"))
        expected_purpose = PURPOSE_LABELS.get(str(task.get("purpose")))
        if visible_purpose != expected_purpose:
            messages.append(
                f"🚨 Task '{task_id}': visible purpose '{visible_purpose}' does not match envelope."
            )
        visible_estimate = _plain_markdown_value(_markdown_field(content, "Estimate"))
        if visible_estimate != task.get("estimate"):
            messages.append(
                f"🚨 Task '{task_id}': visible estimate '{visible_estimate}' does not "
                f"match '{task.get('estimate')}'."
            )

        visible_acceptance = set(
            re.findall(r"\bAC-\d{2,}\b", _markdown_field(content, "Acceptance criteria") or "")
        )
        if visible_acceptance != set(_relation_ids(task.get("acceptance_ids"))):
            messages.append(f"🚨 Task '{task_id}': visible AC-* do not match envelope.")
        visible_contributions = set(
            re.findall(
                r"\bAC-\d{2,}\b", _markdown_field(content, "Contribution to plan criteria") or ""
            )
        )
        if visible_contributions != set(_relation_ids(task.get("contributes_to_acceptance_ids"))):
            messages.append(
                f"🚨 Task '{task_id}': visible contribution to AC-* does not match envelope."
            )
        local = task.get("local_acceptance_criteria", [])
        if local:
            try:
                # Same table schema; separate heading prevents local IDs being parent closure claims.
                local_text = content.split("### Local acceptance criteria", 1)[1]
                rendered = plan_criteria("### Acceptance criteria" + local_text)
                if criteria_map(rendered) != criteria_map(local):
                    raise ValueError("Local acceptance Markdown differs from envelope")
            except (ValueError, IndexError) as error:
                messages.append(f"🚨 Task '{task_id}': local_acceptance_criteria: {error}")
        visible_capabilities = _markdown_field(content, "Covers capabilities")
        visible_capability_ids = set(re.findall(r"\bCAP-\d{2,}\b", visible_capabilities or ""))
        if visible_capability_ids != task_capabilities[task_id]:
            messages.append(f"🚨 Task '{task_id}': visible CAP-* do not match envelope.")

        source_plan = source_by_file.get(task["file"])
        visible_source = _markdown_field(content, "Plan source") or ""
        if isinstance(source_plan, dict):
            plan_id = source_plan.get("plan_id")
            revision = source_plan.get("revision")
            if str(plan_id) not in visible_source or str(revision) not in visible_source:
                messages.append(
                    f"🚨 Task '{task_id}': visible plan source does not match the envelope."
                )
    return messages
