#!/usr/bin/env python3
import argparse
import glob
import html
import json
import os
import re
import sys


VALID_PURPOSES = {"functionality", "technical_preparation", "research"}
VALID_CONTRACT_TYPES = {
    "backend_api",
    "platform_plugin_api",
    "storage",
    "local_contract",
    "external_contract",
    "none",
}
VALID_AFFECTED_LAYERS = {
    "domain",
    "data",
    "presentation",
    "navigation",
    "di",
    "api",
    "tests",
}
VALID_COVERAGE = {"complete", "external", "out_of_scope"}
CAPABILITY_ID_RE = re.compile(r"^CAP-\d{2,}$")
SCOPE_RE = re.compile(r"^[a-z0-9][a-z0-9_-]*$")
TASK_ID_SEQUENCE_RE = re.compile(r"-(\d{2})$")
TASK_FILENAME_RE = re.compile(r"^(\d{2})-[a-z0-9][a-z0-9_-]*\.md$")
V2_REQUIRED_FIELDS = (
    "filename",
    "title",
    "purpose",
    "scope",
    "outcome",
    "affected_layers",
    "contract_type",
    "implemented",
    "deferred",
    "parent_task",
    "depends_on",
    "blocked_by",
    "estimate",
)
RAW_TRACKED_FIELDS = (
    "id",
    "outcome",
    "affected_layers",
    "implemented",
    "consumers",
    "research_question",
    "timebox_hours",
    "expected_result",
)


def parse_args():
    parser = argparse.ArgumentParser(
        description="Проверить JSON задач и построить Mermaid-граф зависимостей."
    )
    parser.add_argument(
        "--staging-dir",
        default=".ai-pipeline/staging/tasks",
        help="Каталог с подготовленными задачами.",
    )
    parser.add_argument(
        "--output",
        default=".ai-pipeline/staging/mermaid_graph.txt",
        help="Файл для Mermaid-блока.",
    )
    parser.add_argument(
        "--source-lock",
        default=".ai-pipeline/staging/decomposition-source.json",
        help="Зафиксированный источник декомпозиции.",
    )
    return parser.parse_args()


def _as_list(value):
    return value if isinstance(value, list) else []


def _relation_ids(value):
    return [item for item in _as_list(value) if _is_nonempty_text(item)]


def _graph_scope(task):
    scope = task.get("scope")
    return scope.strip() if _is_nonempty_text(scope) else "не указан"


def _to_number(value):
    if value is None or isinstance(value, bool):
        return None
    try:
        return float(str(value).replace(",", "."))
    except (TypeError, ValueError):
        return None


def _format_hours(value):
    if value is None:
        return "0"
    return str(int(value)) if float(value).is_integer() else str(value).rstrip("0").rstrip(".")


def normalize_estimate(task):
    estimate = task.get("estimate")
    min_hours = None
    max_hours = None

    if isinstance(estimate, dict):
        min_hours = _to_number(estimate.get("min_hours"))
        max_hours = _to_number(estimate.get("max_hours"))
        if min_hours is None:
            min_hours = max_hours
        if max_hours is None:
            max_hours = min_hours

    min_hours = 0.0 if min_hours is None else min_hours
    max_hours = min_hours if max_hours is None else max_hours
    if min_hours == max_hours:
        label = f"{_format_hours(max_hours)} ч"
    else:
        label = f"{_format_hours(min_hours)}–{_format_hours(max_hours)} ч"
    return label, min_hours, max_hours


def find_markdown_file(task, json_filepath):
    task_dir = os.path.dirname(json_filepath)
    filename = task.get("filename")
    if _is_nonempty_text(filename):
        candidate = os.path.join(task_dir, filename)
        if os.path.isfile(candidate):
            return candidate
    return None


def load_tasks(
    staging_dir,
    *,
    include_load_violations=False,
    include_envelopes=False,
):
    all_tasks = {}
    envelopes = []
    load_violations = []
    task_files = sorted(
        glob.glob(os.path.join(staging_dir, "**", "task_result.json"), recursive=True)
    )
    if not task_files:
        load_violations.append(
            "🚨 Не найден ни один строгий envelope '**/task_result.json'."
        )

    for filepath in task_files:
        relative_file = os.path.relpath(filepath, staging_dir)
        try:
            with open(filepath, "r", encoding="utf-8") as file:
                data = json.load(file)
            if not isinstance(data, dict):
                load_violations.append(
                    f"🚨 Файл '{relative_file}': envelope должен быть объектом schema v2."
                )
                continue
            envelope_schema_version = data.get("schema_version")
            if envelope_schema_version != 2:
                load_violations.append(
                    f"🚨 Файл '{relative_file}': schema_version должен быть равен 2."
                )
            tasks_list = data.get("tasks")
            if not isinstance(tasks_list, list):
                load_violations.append(
                    f"🚨 Файл '{relative_file}': поле tasks должно быть списком."
                )
                continue
            if not tasks_list:
                load_violations.append(
                    f"🚨 Файл '{relative_file}': поле tasks не должно быть пустым."
                )
            envelopes.append(
                {
                    "file": filepath,
                    "relative_file": relative_file,
                    "schema_version": envelope_schema_version,
                    "source_plan": data.get("source_plan"),
                    "capability_coverage": data.get("capability_coverage"),
                    "summary": data.get("summary"),
                    "total_min_hours": data.get("total_min_hours"),
                    "total_max_hours": data.get("total_max_hours"),
                }
            )

            for task_index, task in enumerate(tasks_list):
                if not isinstance(task, dict):
                    load_violations.append(
                        f"🚨 Файл '{relative_file}': элемент tasks #{task_index + 1} "
                        "должен быть объектом."
                    )
                    continue
                source_task_id = task.get("id")
                if _is_nonempty_text(source_task_id):
                    task_id = source_task_id
                    if task_id in all_tasks:
                        first_file = os.path.relpath(
                            all_tasks[task_id]["file"], staging_dir
                        )
                        load_violations.append(
                            f"🚨 Задача '{task_id}': ID повторяется в "
                            f"'{first_file}' и '{relative_file}'."
                        )
                        continue
                else:
                    task_id = (
                        f"<invalid-id:{relative_file.replace(os.sep, ':')}"
                        f"#{task_index + 1}>"
                    )

                schema_version = task.get("schema_version", envelope_schema_version)
                purpose = task.get("purpose")
                affected_layers = task.get("affected_layers")
                dependency_value = task.get("depends_on")
                blocked_by = task.get("blocked_by")
                estimate_label, estimate_min, estimate_max = normalize_estimate(task)
                deferred = task.get("deferred")
                if "deferred" not in task or deferred is None:
                    deferred = []
                scope = task.get("scope")
                parent_task = task.get("parent_task")

                estimate_value = task.get("estimate")
                estimate_confidence = (
                    estimate_value.get("confidence")
                    if isinstance(estimate_value, dict)
                    else None
                )
                tracked_fields = set(V2_REQUIRED_FIELDS) | set(RAW_TRACKED_FIELDS)
                raw_presence = {field: field in task for field in tracked_fields}
                raw_values = {field: task.get(field) for field in tracked_fields}
                raw_presence["schema_version"] = (
                    "schema_version" in task or "schema_version" in data
                )
                raw_values["schema_version"] = schema_version
                raw_presence["estimate.confidence"] = (
                    isinstance(estimate_value, dict)
                    and "confidence" in estimate_value
                )
                raw_values["estimate.confidence"] = estimate_confidence
                all_tasks[task_id] = {
                    "id": task_id,
                    "source_id": source_task_id,
                    "filename": task.get("filename"),
                    "title": task.get("title"),
                    "name": task.get("title")
                    or task.get("outcome")
                    or "Без названия",
                    "outcome": task.get("outcome"),
                    "scope": scope,
                    "affected_layers": affected_layers,
                    "contract_type": task.get("contract_type"),
                    "purpose": purpose,
                    "schema_version": schema_version,
                    "implemented": task.get("implemented"),
                    "consumers": task.get("consumers"),
                    "research_question": task.get("research_question"),
                    "timebox_hours": task.get("timebox_hours"),
                    "expected_result": task.get("expected_result"),
                    "estimate_raw": estimate_value,
                    "estimate_confidence": estimate_confidence,
                    "estimate": estimate_label,
                    "estimate_min_hours": estimate_min,
                    "estimate_max_hours": estimate_max,
                    "depends_on": dependency_value,
                    "blocked_by": blocked_by,
                    "parent_task": parent_task,
                    "deferred": deferred,
                    "raw_presence": raw_presence,
                    "raw_values": raw_values,
                    "file": filepath,
                    "markdown_file": find_markdown_file(task, filepath),
                }
                if all_tasks[task_id]["markdown_file"] is None:
                    load_violations.append(
                        f"🚨 Задача '{task_id}': Markdown-файл из поля filename "
                        f"не найден рядом с '{relative_file}'."
                    )
        except Exception as error:
            load_violations.append(
                f"🚨 Файл '{relative_file}': не удалось прочитать JSON задач: {error}"
            )

    if include_envelopes and include_load_violations:
        return all_tasks, envelopes, load_violations
    if include_envelopes:
        return all_tasks, envelopes
    if include_load_violations:
        return all_tasks, load_violations
    return all_tasks


def _is_nonempty_text(value):
    return isinstance(value, str) and bool(value.strip())


def _is_number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def _validate_v2_task(task_id, task, tasks):
    messages = []
    presence = task.get("raw_presence", {})
    for field in V2_REQUIRED_FIELDS:
        if not presence.get(field, False):
            if field == "purpose":
                messages.append(
                    f"🚨 Задача '{task_id}': не указано назначение; "
                    "отсутствует обязательное поле 'purpose'."
                )
            elif field == "scope":
                messages.append(
                    f"🚨 Задача '{task_id}': не указан scope; "
                    "отсутствует обязательное поле 'scope'."
                )
            else:
                messages.append(
                    f"🚨 Задача '{task_id}': отсутствует обязательное поле '{field}'."
                )

    for field in ("filename", "title", "scope", "outcome", "contract_type"):
        if presence.get(field) and not _is_nonempty_text(task.get(field)):
            messages.append(
                f"🚨 Задача '{task_id}': поле {field} должно быть непустой строкой."
            )

    scope = task.get("scope")
    if _is_nonempty_text(scope) and SCOPE_RE.fullmatch(scope) is None:
        messages.append(
            f"🚨 Задача '{task_id}': scope должен соответствовать "
            "[a-z0-9][a-z0-9_-]*."
        )

    contract_type = task.get("contract_type")
    if (
        _is_nonempty_text(contract_type)
        and contract_type not in VALID_CONTRACT_TYPES
    ):
        messages.append(
            f"🚨 Задача '{task_id}': неизвестный contract_type "
            f"'{contract_type}'."
        )

    sequence = TASK_ID_SEQUENCE_RE.search(task_id)
    filename = task.get("filename")
    filename_match = TASK_FILENAME_RE.fullmatch(filename) if isinstance(filename, str) else None
    if not sequence:
        messages.append(
            f"🚨 Задача '{task_id}': ID должен оканчиваться на порядковый номер -NN."
        )
    elif filename_match is None or filename_match.group(1) != sequence.group(1):
        messages.append(
            f"🚨 Задача '{task_id}': filename должен иметь формат "
            f"'{sequence.group(1)}-slug.md'."
        )

    for field in (
        "affected_layers",
        "implemented",
        "deferred",
        "depends_on",
        "blocked_by",
    ):
        if presence.get(field) and not isinstance(task.get(field), list):
            messages.append(
                f"🚨 Задача '{task_id}': поле {field} должно быть списком."
            )

    for field in ("affected_layers", "implemented", "depends_on", "blocked_by"):
        value = task.get(field)
        if presence.get(field) and isinstance(value, list):
            for item in value:
                if not _is_nonempty_text(item):
                    messages.append(
                        f"🚨 Задача '{task_id}': элементы поля {field} "
                        "должны быть непустыми строками."
                    )
                    break

    affected_layers = task.get("affected_layers")
    if isinstance(affected_layers, list):
        unknown_layers = sorted(set(affected_layers) - VALID_AFFECTED_LAYERS)
        if unknown_layers:
            messages.append(
                f"🚨 Задача '{task_id}': неизвестные affected_layers: "
                f"{', '.join(unknown_layers)}."
            )

    implemented = task.get("implemented")
    if isinstance(implemented, list) and not implemented:
        messages.append(
            f"🚨 Задача '{task_id}': implemented не должен быть пустым."
        )

    parent_task = task.get("parent_task")
    if presence.get("parent_task") and not (
        parent_task is None or _is_nonempty_text(parent_task)
    ):
        messages.append(
            f"🚨 Задача '{task_id}': поле parent_task должно быть null "
            "или непустой строкой."
        )

    estimate = task.get("estimate_raw")
    if presence.get("estimate"):
        if not isinstance(estimate, dict):
            messages.append(
                f"🚨 Задача '{task_id}': поле estimate должно быть объектом."
            )
        else:
            min_hours = estimate.get("min_hours")
            max_hours = estimate.get("max_hours")
            if not _is_number(min_hours) or not _is_number(max_hours):
                messages.append(
                    f"🚨 Задача '{task_id}': estimate.min_hours и max_hours "
                    "должны быть числами."
                )
            else:
                if min_hours < 0:
                    messages.append(
                        f"🚨 Задача '{task_id}': estimate.min_hours не может "
                        "быть отрицательным."
                    )
                if min_hours > max_hours:
                    messages.append(
                        f"🚨 Задача '{task_id}': estimate.min_hours не может "
                        "быть больше max_hours."
                    )
                if max_hours > 16:
                    messages.append(
                        f"🚨 Задача '{task_id}' оценена в "
                        f"{_format_hours(max_hours)} ч. Максимум — 16 ч."
                    )

    purpose = task.get("purpose")
    if purpose == "technical_preparation":
        consumers = task.get("consumers")
        if not isinstance(consumers, list) or not consumers:
            messages.append(
                f"🚨 Задача '{task_id}': technical_preparation требует "
                "непустой список consumers."
            )
        else:
            for consumer_id in consumers:
                if not _is_nonempty_text(consumer_id) or consumer_id not in tasks:
                    messages.append(
                        f"🚨 Задача '{task_id}': consumer '{consumer_id}' "
                        "не найден среди задач декомпозиции."
                    )

    if purpose == "research":
        if not _is_nonempty_text(task.get("research_question")):
            messages.append(
                f"🚨 Задача '{task_id}': research_question должен быть непустой строкой."
            )
        timebox_hours = task.get("timebox_hours")
        if not _is_number(timebox_hours) or timebox_hours <= 0:
            messages.append(
                f"🚨 Задача '{task_id}': timebox_hours должен быть положительным числом."
            )
        if not _is_nonempty_text(task.get("expected_result")):
            messages.append(
                f"🚨 Задача '{task_id}': expected_result должен быть непустой строкой."
            )

    return messages


def validate_dependencies(tasks):
    messages = []
    filename_owners = {}

    for task_id, task in tasks.items():
        filename = task.get("filename")
        if _is_nonempty_text(filename):
            previous_owner = filename_owners.get(filename)
            if previous_owner is not None:
                messages.append(
                    f"🚨 Задачи '{previous_owner}' и '{task_id}' используют "
                    f"одинаковый filename '{filename}'."
                )
            else:
                filename_owners[filename] = task_id

        is_v2 = task.get("schema_version") == 2
        raw_id = task.get("raw_values", {}).get("id")
        if not _is_nonempty_text(raw_id):
            if not task.get("raw_presence", {}).get("id"):
                messages.append(
                    f"🚨 Задача '{task_id}': отсутствует обязательное поле 'id'."
                )
            else:
                messages.append(
                    f"🚨 Задача '{task_id}': поле id должно быть непустой строкой."
                )
        if not is_v2:
            messages.append(
                f"🚨 Задача '{task_id}': schema_version должен быть равен 2 "
                "для новой схемы задачи."
            )
        if is_v2:
            messages.extend(_validate_v2_task(task_id, task, tasks))

        purpose = task.get("purpose")
        purpose_missing = is_v2 and not task.get("raw_presence", {}).get("purpose")
        if (
            (not isinstance(purpose, str) or purpose not in VALID_PURPOSES)
            and not purpose_missing
        ):
            messages.append(
                f"🚨 Задача '{task_id}': неизвестное назначение '{purpose}'. "
                "Допустимы functionality, technical_preparation и research."
            )

        for dependency_id in _relation_ids(task.get("depends_on")):
            if dependency_id not in tasks:
                messages.append(
                    f"🚨 Задача '{task_id}' зависит от отсутствующей задачи "
                    f"'{dependency_id}'."
                )

        parent_task = task.get("parent_task")
        if _is_nonempty_text(parent_task) and parent_task not in tasks:
            messages.append(
                f"🚨 Задача '{task_id}': родительская задача '{parent_task}' "
                "не найдена в текущей декомпозиции."
            )

        deferred = task.get("deferred", [])
        if not isinstance(deferred, list):
            if not is_v2:
                messages.append(
                    f"🚨 Задача '{task_id}': поле deferred должно быть списком."
                )
            continue
        for item in deferred:
            if not isinstance(item, dict):
                messages.append(
                    f"🚨 Задача '{task_id}': элемент отложенного поведения должен быть объектом."
                )
                continue
            completed_by = item.get("completed_by")
            behavior = item.get("behavior")
            temporary_behavior = item.get("temporary_behavior")
            if not _is_nonempty_text(behavior):
                messages.append(
                    f"🚨 Задача '{task_id}': deferred.behavior должен быть "
                    "непустой строкой."
                )
            if not _is_nonempty_text(temporary_behavior):
                messages.append(
                    f"🚨 Задача '{task_id}': deferred.temporary_behavior должен "
                    "быть непустой строкой."
                )
            if not _is_nonempty_text(completed_by) or completed_by not in tasks:
                messages.append(
                    f"🚨 Задача '{task_id}': отложенное поведение "
                    f"'{behavior or 'без названия'}' "
                    f"ссылается на отсутствующую закрывающую задачу '{completed_by}'."
                )
            elif completed_by == task_id:
                messages.append(
                    f"🚨 Задача '{task_id}': отложенное поведение "
                    f"'{behavior or 'без названия'}' не может закрываться этой же задачей."
                )

    return messages


def load_source_lock(path):
    messages = []
    if not os.path.isfile(path):
        return None, [f"🚨 Source lock '{path}' не найден."]
    try:
        with open(path, "r", encoding="utf-8") as file:
            source_lock = json.load(file)
    except Exception as error:
        return None, [f"🚨 Source lock '{path}' не читается: {error}"]

    if not isinstance(source_lock, dict):
        return None, [f"🚨 Source lock '{path}' должен быть JSON-объектом."]

    for field in ("plan_id", "plan_hash", "plan_path"):
        if not _is_nonempty_text(source_lock.get(field)):
            messages.append(
                f"🚨 Source lock '{path}': поле {field} должно быть "
                "непустой строкой."
            )
    revision = source_lock.get("plan_revision")
    if not isinstance(revision, int) or isinstance(revision, bool) or revision < 1:
        messages.append(
            f"🚨 Source lock '{path}': plan_revision должен быть "
            "положительным целым числом."
        )

    capability_ids = source_lock.get("capability_ids")
    if not isinstance(capability_ids, list):
        messages.append(
            f"🚨 Source lock '{path}': capability_ids должен быть списком."
        )
    else:
        if not capability_ids:
            messages.append(
                f"🚨 Source lock '{path}': capability_ids не должен быть пустым."
            )
        invalid_ids = [
            value
            for value in capability_ids
            if not isinstance(value, str) or CAPABILITY_ID_RE.fullmatch(value) is None
        ]
        if invalid_ids:
            messages.append(
                f"🚨 Source lock '{path}': capability_ids содержит "
                "некорректные значения."
            )
        if len(capability_ids) != len(set(capability_ids)):
            messages.append(
                f"🚨 Source lock '{path}': capability_ids содержит дубли."
            )
    return source_lock, messages


def validate_envelopes(envelopes, tasks, source_lock):
    messages = []
    if not envelopes:
        return ["🚨 Не найден ни один валидный task_result envelope."]

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
            messages.append(
                f"🚨 Файл '{relative_file}': source_plan должен быть объектом."
            )
        elif expected_source is not None and source_plan != expected_source:
            messages.append(
                f"🚨 Файл '{relative_file}': source_plan не совпадает с source lock."
            )

        if not _is_nonempty_text(envelope.get("summary")):
            messages.append(
                f"🚨 Файл '{relative_file}': summary должен быть непустой строкой."
            )

        envelope_tasks = [
            task for task in tasks.values() if task.get("file") == envelope["file"]
        ]
        expected_min = sum(task["estimate_min_hours"] for task in envelope_tasks)
        expected_max = sum(task["estimate_max_hours"] for task in envelope_tasks)
        for field, expected_total in (
            ("total_min_hours", expected_min),
            ("total_max_hours", expected_max),
        ):
            value = envelope.get(field)
            if not _is_number(value):
                messages.append(
                    f"🚨 Файл '{relative_file}': {field} должен быть числом."
                )
            elif float(value) != float(expected_total):
                messages.append(
                    f"🚨 Файл '{relative_file}': {field}={value}, "
                    f"ожидалось {_format_hours(expected_total)}."
                )

        coverage = envelope.get("capability_coverage")
        if not isinstance(coverage, list):
            messages.append(
                f"🚨 Файл '{relative_file}': capability_coverage должен быть списком."
            )
            continue
        for index, item in enumerate(coverage, start=1):
            if not isinstance(item, dict):
                messages.append(
                    f"🚨 Файл '{relative_file}': capability_coverage #{index} "
                    "должен быть объектом."
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
                    f"🚨 Файл '{relative_file}': некорректный capability_id "
                    f"'{capability_id}'."
                )
                continue
            if capability_id in coverage_by_capability:
                messages.append(
                    f"🚨 Capability '{capability_id}' имеет больше одного disposition."
                )
                continue
            coverage_by_capability[capability_id] = disposition
            if disposition not in VALID_COVERAGE:
                messages.append(
                    f"🚨 Capability '{capability_id}': неизвестный coverage "
                    f"'{disposition}'."
                )
            if not isinstance(task_ids, list):
                messages.append(
                    f"🚨 Capability '{capability_id}': task_ids должен быть списком."
                )
                continue
            if disposition == "complete" and not task_ids:
                messages.append(
                    f"🚨 Capability '{capability_id}': complete требует task_ids."
                )
            if disposition in {"external", "out_of_scope"} and task_ids:
                messages.append(
                    f"🚨 Capability '{capability_id}': {disposition} не должен "
                    "ссылаться на задачи."
                )
            for task_id in task_ids:
                if not _is_nonempty_text(task_id) or task_id not in tasks:
                    messages.append(
                        f"🚨 Capability '{capability_id}' ссылается на "
                        f"отсутствующую задачу '{task_id}'."
                    )
                elif disposition == "complete":
                    covered_task_ids.add(task_id)

    actual_capabilities = set(coverage_by_capability)
    if has_capability_lock and actual_capabilities != expected_capabilities:
        missing = sorted(expected_capabilities - actual_capabilities)
        extra = sorted(actual_capabilities - expected_capabilities)
        messages.append(
            "🚨 Capability coverage не совпадает с source lock: "
            f"missing={missing or '—'}, extra={extra or '—'}."
        )
    if expected_capabilities:
        uncovered_tasks = sorted(set(tasks) - covered_task_ids)
        if uncovered_tasks:
            messages.append(
                "🚨 Задачи без complete capability coverage: "
                f"{', '.join(uncovered_tasks)}."
            )
    return messages


def _markdown_field(text, label):
    pattern = re.compile(
        rf"(?m)^-\s+\*\*{re.escape(label)}:\*\*\s*(.*?)\s*$"
    )
    match = pattern.search(text)
    return match.group(1).strip() if match else None


def _plain_markdown_value(value):
    return value.replace("`", "").strip().rstrip(".") if isinstance(value, str) else value


def validate_markdown_files(tasks, envelopes):
    messages = []
    source_by_file = {
        envelope["file"]: envelope.get("source_plan") for envelope in envelopes
    }
    capabilities_by_task = {task_id: set() for task_id in tasks}
    for envelope in envelopes:
        coverage = envelope.get("capability_coverage")
        if not isinstance(coverage, list):
            continue
        for item in coverage:
            if not isinstance(item, dict) or item.get("coverage") != "complete":
                continue
            capability_id = item.get("capability_id")
            for task_id in item.get("task_ids", []):
                if task_id in capabilities_by_task and _is_nonempty_text(capability_id):
                    capabilities_by_task[task_id].add(capability_id)

    purpose_labels = {
        "functionality": "Функциональность",
        "technical_preparation": "Техническая подготовка",
        "research": "Исследование",
    }
    for task_id, task in tasks.items():
        markdown_file = task.get("markdown_file")
        if markdown_file is None:
            continue
        try:
            with open(markdown_file, "r", encoding="utf-8") as file:
                content = file.read()
        except Exception as error:
            messages.append(
                f"🚨 Задача '{task_id}': Markdown не читается: {error}"
            )
            continue

        visible_id = _plain_markdown_value(_markdown_field(content, "ID"))
        if visible_id != task_id:
            messages.append(
                f"🚨 Задача '{task_id}': видимый ID '{visible_id}' не совпадает "
                "с envelope."
            )
        visible_scope = _plain_markdown_value(_markdown_field(content, "Модуль"))
        if visible_scope != task.get("scope"):
            messages.append(
                f"🚨 Задача '{task_id}': видимый модуль '{visible_scope}' не "
                "совпадает с envelope."
            )
        visible_purpose = _plain_markdown_value(
            _markdown_field(content, "Назначение")
        )
        expected_purpose = purpose_labels.get(task.get("purpose"))
        if visible_purpose != expected_purpose:
            messages.append(
                f"🚨 Задача '{task_id}': видимое назначение '{visible_purpose}' "
                "не совпадает с envelope."
            )
        visible_estimate = _plain_markdown_value(_markdown_field(content, "Оценка"))
        if visible_estimate != task.get("estimate"):
            messages.append(
                f"🚨 Задача '{task_id}': видимая оценка '{visible_estimate}' не "
                f"совпадает с '{task.get('estimate')}'."
            )

        visible_capabilities = _markdown_field(content, "Покрывает возможности")
        visible_capability_ids = set(
            re.findall(r"\bCAP-\d{2,}\b", visible_capabilities or "")
        )
        if visible_capability_ids != capabilities_by_task[task_id]:
            messages.append(
                f"🚨 Задача '{task_id}': видимые CAP-* не совпадают с envelope."
            )

        source_plan = source_by_file.get(task.get("file"))
        visible_source = _markdown_field(content, "Источник плана") or ""
        if isinstance(source_plan, dict):
            plan_id = source_plan.get("plan_id")
            revision = source_plan.get("revision")
            if str(plan_id) not in visible_source or str(revision) not in visible_source:
                messages.append(
                    f"🚨 Задача '{task_id}': видимый источник плана не совпадает "
                    "с envelope."
                )
    return messages


def check_circular_dependencies(tasks):
    state = {}
    stack = []
    cycles = []

    def dfs(task_id):
        if state.get(task_id) == 1:
            cycle_start = stack.index(task_id)
            cycles.append(" -> ".join(stack[cycle_start:] + [task_id]))
            return
        if state.get(task_id) == 2:
            return

        state[task_id] = 1
        stack.append(task_id)
        for dependency_id in _relation_ids(
            tasks.get(task_id, {}).get("depends_on")
        ):
            if dependency_id in tasks:
                dfs(dependency_id)
        stack.pop()
        state[task_id] = 2

    for task_id in tasks:
        if not state.get(task_id):
            dfs(task_id)
    return cycles


def check_parent_task_cycles(tasks):
    state = {}
    stack = []
    cycles = []

    def dfs(task_id):
        if state.get(task_id) == 1:
            cycle_start = stack.index(task_id)
            cycles.append(" -> ".join(stack[cycle_start:] + [task_id]))
            return
        if state.get(task_id) == 2:
            return

        state[task_id] = 1
        stack.append(task_id)
        parent_task = tasks.get(task_id, {}).get("parent_task")
        if _is_nonempty_text(parent_task) and parent_task in tasks:
            dfs(parent_task)
        stack.pop()
        state[task_id] = 2

    for task_id in tasks:
        if not state.get(task_id):
            dfs(task_id)
    return cycles


def check_deferred_cycles(tasks):
    state = {}
    stack = []
    cycles = []

    def dfs(task_id):
        if state.get(task_id) == 1:
            cycle_start = stack.index(task_id)
            cycles.append(" -> ".join(stack[cycle_start:] + [task_id]))
            return
        if state.get(task_id) == 2:
            return

        state[task_id] = 1
        stack.append(task_id)
        deferred = tasks.get(task_id, {}).get("deferred")
        if isinstance(deferred, list):
            for item in deferred:
                if not isinstance(item, dict):
                    continue
                completed_by = item.get("completed_by")
                if _is_nonempty_text(completed_by) and completed_by in tasks:
                    dfs(completed_by)
        stack.pop()
        state[task_id] = 2

    for task_id in tasks:
        if not state.get(task_id):
            dfs(task_id)
    return cycles


def build_relation_graph(tasks):
    relations = {}
    for task_id in sorted(tasks, key=str):
        task = tasks[task_id]
        task_relations = []
        seen_targets = set()
        for dependency_id in sorted(_relation_ids(task.get("depends_on")), key=str):
            if dependency_id in tasks and dependency_id not in seen_targets:
                task_relations.append((dependency_id, "depends_on"))
                seen_targets.add(dependency_id)

        parent_task = task.get("parent_task")
        if (
            _is_nonempty_text(parent_task)
            and parent_task in tasks
            and parent_task not in seen_targets
        ):
            task_relations.append((parent_task, "parent_task"))
            seen_targets.add(parent_task)
        for blocker_id in sorted(_relation_ids(task.get("blocked_by")), key=str):
            if blocker_id in tasks and blocker_id not in seen_targets:
                task_relations.append((blocker_id, "blocked_by"))
                seen_targets.add(blocker_id)
        relations[task_id] = task_relations
    return relations


def check_mixed_relation_cycles(tasks):
    relations = build_relation_graph(tasks)
    state = {}
    node_stack = []
    edge_stack = []
    cycles = []
    seen_cycles = set()

    def dfs(task_id):
        state[task_id] = 1
        node_stack.append(task_id)
        for target_id, relation_type in relations.get(task_id, []):
            if state.get(target_id) == 1:
                cycle_start = node_stack.index(target_id)
                relation_types = edge_stack[cycle_start:] + [relation_type]
                relation_types = set(relation_types)
                if (
                    "blocked_by" in relation_types
                    or {"depends_on", "parent_task"}.issubset(relation_types)
                ):
                    cycle_nodes = node_stack[cycle_start:] + [target_id]
                    cycle_key = tuple(sorted(set(cycle_nodes), key=str))
                    if cycle_key not in seen_cycles:
                        seen_cycles.add(cycle_key)
                        cycles.append(" -> ".join(cycle_nodes))
            elif state.get(target_id) != 2:
                edge_stack.append(relation_type)
                dfs(target_id)
                edge_stack.pop()
        node_stack.pop()
        state[task_id] = 2

    for task_id in sorted(tasks, key=str):
        if not state.get(task_id):
            dfs(task_id)
    return cycles


def _escape_mermaid_label(value):
    text = str(value).replace("\r", " ").replace("\n", " ")
    return html.escape(text, quote=True)


def _aliases(values, prefix):
    return {
        value: f"{prefix}_{index:03d}"
        for index, value in enumerate(sorted(values, key=lambda item: str(item)))
    }


def generate_mermaid_graph(tasks):
    lines = ["```mermaid", "flowchart TD", "  %% Стили назначений задач"]
    lines.append("  classDef functionality fill:#bbf,stroke:#333,stroke-width:1px;")
    lines.append(
        "  classDef technical_preparation fill:#6f9,stroke:#333,stroke-width:1px;"
    )
    lines.append("  classDef research fill:#f9f,stroke:#333,stroke-width:1px;")
    lines.append(
        "  classDef backend fill:#ff9,stroke:#333,stroke-width:1px,stroke-dasharray: 5 5;"
    )

    task_aliases = _aliases(tasks.keys(), "task")
    scopes = {_graph_scope(task) for task in tasks.values()}
    scope_aliases = _aliases(scopes, "scope")
    blocker_ids = {
        blocker_id
        for task in tasks.values()
        for blocker_id in _relation_ids(task.get("blocked_by"))
        if (
            blocker_id
            and blocker_id != "[TBD_BACKEND]"
            and blocker_id not in tasks
        )
    }
    blocker_aliases = _aliases(blocker_ids, "blocker")

    for scope in sorted(scopes, key=lambda item: str(item)):
        lines.append(
            f'\n  subgraph {scope_aliases[scope]} ["Модуль: '
            f'{_escape_mermaid_label(scope)}"]'
        )
        scope_tasks = sorted(
            (task for task in tasks.values() if _graph_scope(task) == scope),
            key=lambda task: str(task["id"]),
        )
        for task in scope_tasks:
            clean_name = str(task["name"])
            if len(clean_name) > 30:
                clean_name = clean_name[:27] + "..."
            label = (
                f'{_escape_mermaid_label(task["id"])}<br/>'
                f'{_escape_mermaid_label(clean_name)} '
                f'({_escape_mermaid_label(task["estimate"])})'
            )
            lines.append(f'    {task_aliases[task["id"]]}["{label}"]')
        lines.append("  end")

    lines.append("")
    for task_id in sorted(tasks, key=str):
        task = tasks[task_id]
        purpose = task.get("purpose")
        if isinstance(purpose, str) and purpose in VALID_PURPOSES:
            lines.append(f"  class {task_aliases[task_id]} {purpose};")

    lines.append("\n  %% Зависимости задач")
    relations = build_relation_graph(tasks)
    for task_id in sorted(tasks, key=str):
        task_alias = task_aliases[task_id]
        for related_id, relation_type in relations[task_id]:
            related_alias = task_aliases[related_id]
            if relation_type == "depends_on":
                lines.append(f"  {related_alias} --> {task_alias}")
            elif relation_type == "parent_task":
                lines.append(
                    f'  {related_alias} -. "стек веток" .-> {task_alias}'
                )
            else:
                lines.append(
                    f'  {related_alias} -. "блокирует" .-> {task_alias}'
                )

    for blocker_id in sorted(blocker_ids, key=str):
        blocker_alias = blocker_aliases[blocker_id]
        blocker_label = _escape_mermaid_label(blocker_id)
        lines.append(f'  {blocker_alias}["Блокер: {blocker_label}"]')
        lines.append(f"  class {blocker_alias} backend;")

    for task_id in sorted(tasks, key=str):
        task_alias = task_aliases[task_id]
        for blocker_id in sorted(
            _relation_ids(tasks[task_id].get("blocked_by")), key=str
        ):
            if blocker_id in blocker_aliases:
                lines.append(f"  {blocker_aliases[blocker_id]} -.-> {task_alias}")

    lines.append("```")
    return "\n".join(lines)


def _ensure_directory(path):
    if path:
        os.makedirs(path, exist_ok=True)


def _write_violations_json(
    output_dir,
    messages,
    dependency_cycles=None,
    parent_task_cycles=None,
    deferred_cycles=None,
    mixed_relation_cycles=None,
):
    _ensure_directory(output_dir)
    violations_file = os.path.join(output_dir, "violations.json")
    with open(violations_file, "w", encoding="utf-8") as file:
        json.dump(
            {
                "cycles": dependency_cycles or [],
                "parent_task_cycles": parent_task_cycles or [],
                "deferred_cycles": deferred_cycles or [],
                "mixed_relation_cycles": mixed_relation_cycles or [],
                "violations": messages,
            },
            file,
            indent=2,
            ensure_ascii=False,
        )


def main():
    args = parse_args()
    output_dir = os.path.dirname(args.output)
    tasks, envelopes, load_violations = load_tasks(
        args.staging_dir,
        include_load_violations=True,
        include_envelopes=True,
    )
    source_lock, source_lock_violations = load_source_lock(args.source_lock)

    scope_count = len({_graph_scope(task) for task in tasks.values()})
    print(f"Загружено задач: {len(tasks)}; модулей: {scope_count}.", file=sys.stderr)

    messages = (
        load_violations
        + source_lock_violations
        + validate_dependencies(tasks)
        + validate_envelopes(envelopes, tasks, source_lock)
        + validate_markdown_files(tasks, envelopes)
    )
    dependency_cycles = check_circular_dependencies(tasks)
    parent_task_cycles = check_parent_task_cycles(tasks)
    deferred_cycles = check_deferred_cycles(tasks)
    mixed_relation_cycles = check_mixed_relation_cycles(tasks)
    has_cycles = bool(
        dependency_cycles
        or parent_task_cycles
        or deferred_cycles
        or mixed_relation_cycles
    )
    if messages or has_cycles:
        if dependency_cycles:
            print("🚨 Обнаружен цикл зависимостей задач.", file=sys.stderr)
        for cycle in dependency_cycles:
            print(f"  Цикл: {cycle}", file=sys.stderr)
        if parent_task_cycles:
            print("🚨 Обнаружен цикл стека веток parent_task.", file=sys.stderr)
        for cycle in parent_task_cycles:
            print(f"  Цикл стека: {cycle}", file=sys.stderr)
        if deferred_cycles:
            print("🚨 Обнаружен цикл отложенного поведения.", file=sys.stderr)
        for cycle in deferred_cycles:
            print(f"  Цикл deferred: {cycle}", file=sys.stderr)
        if mixed_relation_cycles:
            print(
                "🚨 Обнаружен смешанный цикл зависимостей и стека веток.",
                file=sys.stderr,
            )
        for cycle in mixed_relation_cycles:
            print(f"  Смешанный цикл: {cycle}", file=sys.stderr)
        for message in messages:
            print(f"  - {message}", file=sys.stderr)
        _write_violations_json(
            output_dir,
            messages,
            dependency_cycles,
            parent_task_cycles,
            deferred_cycles,
            mixed_relation_cycles,
        )
        violations_md_file = os.path.join(output_dir, "dependency_violations.md")
        _ensure_directory(output_dir)
        with open(violations_md_file, "w", encoding="utf-8") as file:
            file.write("# Нарушения декомпозиции\n\n")
            for message in messages:
                file.write(f"- {message}\n")
            for cycle in dependency_cycles:
                file.write(f"- 🚨 Цикл depends_on: {cycle}\n")
            for cycle in parent_task_cycles:
                file.write(f"- 🚨 Цикл parent_task: {cycle}\n")
            for cycle in deferred_cycles:
                file.write(f"- 🚨 Цикл deferred: {cycle}\n")
            for cycle in mixed_relation_cycles:
                file.write(f"- 🚨 Смешанный цикл: {cycle}\n")
        if os.path.exists(args.output):
            os.remove(args.output)
        print(
            "🚨 Graph gate: FAIL. Граф и финальная сборка заблокированы.",
            file=sys.stderr,
        )
        sys.exit(1)

    violations_file = os.path.join(output_dir, "violations.json")
    violations_md_file = os.path.join(output_dir, "dependency_violations.md")
    for stale_file in (violations_file, violations_md_file):
        if os.path.exists(stale_file):
            os.remove(stale_file)

    mermaid_block = generate_mermaid_graph(tasks)
    _ensure_directory(output_dir)
    with open(args.output, "w", encoding="utf-8") as output:
        output.write(mermaid_block)
    print(f"Graph gate: PASS. Граф записан в {args.output}.", file=sys.stderr)
    sys.exit(0)


if __name__ == "__main__":
    main()
