"""Pure project policy validation and selection; no files, tools or model calls."""

from __future__ import annotations

import re
from copy import deepcopy
from pathlib import PurePosixPath
from typing import Any, cast

from pydantic import ConfigDict, TypeAdapter, ValidationError

from factory_tooling.decisions.decision_contract import validate_answers, validate_definition
from factory_tooling.project.contracts import (
    BoundaryGate,
    Nonblank,
    ProjectCheck,
    ProjectData,
    ReviewCriterion,
    Rule,
    Selector,
)
from factory_tooling.runtime.contracts import CheckSpec, Task, TaskSelection
from factory_tooling.validation import validation_message

PROCESSES = {
    "planning",
    "decompose",
    "implement",
    "code-review",
    "code-audit",
    "code-debt",
    "meta-retro",
    "pr",
    "install",
}
ROLES = {
    "architect",
    "code-explorer",
    "task-decomposer",
    "task-reviewer",
    "developer",
    "test-writer",
    "generalist",
    "judge",
    "reviewer",
    "doc-writer",
    "bug-hunter",
}
STAGES = {"work", "docs", "explore", "verify", "review", "accept"}
LENSES = {"system-design", "runtime-safety", "verification-quality"}


def require(condition: object, message: str) -> None:
    if not condition:
        raise ValueError("Project policy: " + message)


PROJECT = TypeAdapter[ProjectData](ProjectData)
CHECK_SPEC = TypeAdapter[CheckSpec](CheckSpec)
STRINGS = TypeAdapter[list[str]](list[Nonblank], config=ConfigDict(strict=True))


def strings(value: object, label: str, *, empty: bool = False) -> list[str]:
    try:
        entries = STRINGS.validate_python(value)
    except ValidationError as exc:
        raise ValueError(validation_message(f"Project policy: {label}", exc, STRINGS)) from None
    require(empty or entries, f"{label} must be a nonempty list")
    require(len(set(entries)) == len(entries), f"duplicate {label}")
    return entries


def relative(value: Any, *, glob: bool = False) -> str:
    if not (isinstance(value, str) and value and ("\\" not in value) and ("\x00" not in value)):
        raise ValueError("Project policy: " + "invalid relative path")
    p = PurePosixPath(value)
    require(
        not p.is_absolute() and ".." not in p.parts and str(p) == value,
        f"unsafe relative path: {value}",
    )
    require(glob or not any(c in value for c in "*?[]"), f"path must be literal: {value}")
    return value


def glob_pattern(pattern: str) -> str:
    """Full relative path: * stays in a directory, ** crosses directories."""
    relative(pattern, glob=True)
    require(not any(c in pattern for c in "?[]"), "only * and ** glob syntax is supported")
    parts, i = [], 0
    while i < len(pattern):
        if pattern[i : i + 3] == "**/":
            parts.append("(?:.*/)?")
            i += 3
        elif pattern[i : i + 2] == "**":
            parts.append(".*")
            i += 2
        elif pattern[i] == "*":
            parts.append("[^/]*")
            i += 1
        else:
            parts.append(re.escape(pattern[i]))
            i += 1
    return "".join(parts)


def validate_selector(selector: Selector) -> None:
    for name, entries, allowed in [
        ("processes", selector.get("processes"), PROCESSES),
        ("roles", selector.get("roles"), ROLES),
        ("stages", selector.get("stages"), STAGES),
    ]:
        if entries is not None:
            strings(entries, name)
            require(set(entries) <= allowed, f"unknown {name}")
    require(not ("paths_any" in selector and "path_regex" in selector), "choose glob or regex")
    if "paths_any" in selector:
        strings(selector["paths_any"], "paths_any")
        for pattern in selector["paths_any"]:
            glob_pattern(pattern)
    if "path_regex" in selector:
        if not selector["path_regex"]:
            raise ValueError("Project policy: " + "invalid path_regex")
        try:
            re.compile(selector["path_regex"])
        except re.error as exc:
            raise ValueError(f"Project policy: invalid regex: {exc}") from exc


def matches(
    selector: Selector,
    *,
    process: str,
    role: str | None = None,
    stage: str | None = None,
    scope: list[str] | None = None,
) -> bool:
    for choices, value in [
        (selector.get("processes"), process),
        (selector.get("roles"), role),
        (selector.get("stages"), stage),
    ]:
        if choices is not None and value not in choices:
            return False
    # Unknown scope conservatively includes path-dependent obligations.
    if scope is None:
        return True
    if "paths_any" in selector:
        return any(re.fullmatch(glob_pattern(p), f) for p in selector["paths_any"] for f in scope)
    if "path_regex" in selector:
        return any(re.search(selector["path_regex"], f) for f in scope)
    return True


def rule_groups(profile: ProjectData) -> dict[str, list[Rule]]:
    """Explicit recipients; no audience inference or legacy list conversion."""
    return {audience: entries for audience, entries in profile.get("rules", {}).items()}


def validate(raw: object) -> ProjectData:
    try:
        profile = PROJECT.validate_python(raw)
    except ValidationError as exc:
        raise ValueError(validation_message("Project policy", exc, PROJECT)) from None
    documents = profile.get("documents", {})
    for value in documents.values():
        relative(value["path"])
    validate_gate_containers(profile)
    groups = rule_groups(profile)
    all_rules = [item for entries in groups.values() for item in entries]
    for group, entries in [
        ("rules", all_rules),
        ("decisions", profile.get("decisions", [])),
        ("checks", project_checks(profile)),
        ("review criteria", review_criteria(profile)),
    ]:
        seen = set()
        for entry in cast(list[dict[str, Any]], entries):
            require(entry["id"] not in seen, f"duplicate {group} id: {entry['id']}")
            seen.add(entry["id"])
            if group != "decisions":
                validate_selector(cast(Selector, entry.get("for", {})))
    decisions = {x["id"] for x in profile.get("decisions", [])}
    for definition in profile.get("decisions", []):
        validate_definition(definition)
    for audience, entries in groups.items():
        for rule in entries:
            require(
                not (audience == "coordinator" and "roles" in rule.get("for", {})),
                "coordinator rules cannot require a worker role",
            )
            choices = set(rule) & {"file", "project_file", "documents"}
            require(len(choices) == 1, "rule needs exactly one file/project_file/documents")
            if "documents" in choices:
                strings(rule["documents"], "rule documents")
                require(set(rule["documents"]) <= set(documents), "unknown document ID")
            else:
                relative(rule["file"] if "file" in rule else rule["project_file"])
    checks = {x["id"] for x in project_checks(profile)}
    for check in project_checks(profile):
        require(
            set(check.get("for", {})) <= {"paths_any", "path_regex"},
            "check selectors use paths only",
        )
        if not (check.get("decision") is None or check["decision"] in decisions):
            raise ValueError("Project policy: " + "unknown check decision")
        if check.get("decision"):
            definition = next(d for d in profile["decisions"] if d["id"] == check["decision"])
            require(
                definition.get("type", "predicate") == "predicate",
                "check decision must be predicate",
            )
        if "approval_action" in check:
            require(
                check["kind"] != "observation",
                "approval action needs a named command check",
            )
        if "approval_path_regex" in check:
            pattern = check["approval_path_regex"]
            require(
                "approval_action" in check,
                "approval paths require an action and a regular expression",
            )
            try:
                re.compile(pattern)
            except re.error as exc:
                raise ValueError("Project policy: invalid approval path expression") from exc
        strings(check.get("after", []), "after", empty=True)
        require(
            set(check.get("after", [])) <= checks and check["id"] not in check.get("after", []),
            "unknown/self check dependency",
        )
        if check["kind"] != "observation":
            execution = check["execution"]
            relative(execution["cwd"])
            strings(execution.get("inputs", []), "inputs", empty=True)
            outputs = execution.get("outputs", [])
            require(
                not outputs or check["kind"] == "codegen",
                "Only code generation can declare outputs",
            )
            for path in execution.get("inputs", []) + outputs:
                relative(path)
    done: set[str] = set()
    while done != checks:
        ready = {x["id"] for x in project_checks(profile) if set(x.get("after", [])) <= done} - done
        require(ready, "check dependency cycle")
        done |= ready
    for criterion in review_criteria(profile):
        from factory_tooling.project.review_definition import CORE_CRITERIA

        require(
            criterion["id"] not in {x[0] for x in CORE_CRITERIA},
            "cannot replace universal review gate",
        )
        require(
            set(criterion.get("for", {})) <= {"paths_any", "path_regex"},
            "review gate selectors use paths only",
        )
    return profile


def select_rules(
    profile: ProjectData,
    *,
    process: str,
    audience: str,
    role: str | None = None,
    stage: str | None = None,
    scope: list[str] | None = None,
) -> list[Rule]:
    require(
        process in PROCESSES and audience in {"worker", "coordinator"}, "unknown process/audience"
    )
    if not (role is None or role in ROLES):
        raise ValueError("Project policy: " + "unknown role")
    require(audience != "worker" or role in ROLES, "worker selection needs an explicit role")
    if not (stage is None or stage in STAGES):
        raise ValueError("Project policy: " + "unknown stage")
    if scope is not None:
        strings(scope, "scope")
        for path in scope:
            relative(path)
    return [
        r
        for r in rule_groups(profile).get(audience, [])
        if matches(r.get("for", {}), process=process, role=role, stage=stage, scope=scope)
    ]


def required_checks(profile: ProjectData, task: Any, *, final: bool = False) -> list[CheckSpec]:
    result: list[CheckSpec] = []
    if not (isinstance(task, dict)):
        raise ValueError("Project policy: " + "task must be mapping")
    strings(task.get("scope"), "known check scope")
    for path in task["scope"]:
        relative(path)
    decisions = validate_answers(profile.get("decisions", []), task.get("policy_decisions", {}))
    for item in project_checks(profile, all_processes=False):
        if item["level"] == "final" and not final:
            continue
        if not matches(item.get("for", {}), process="implement", scope=task.get("scope")):
            continue
        if item.get("decision"):
            decision = decisions.get(item["decision"])
            if not (decision is not None):
                raise ValueError("Project policy: " + f"UNKNOWN applicability: {item['decision']}")
            require(decision["type"] == "predicate", "check decision must be predicate")
            if not decision["value"]:
                continue
        try:
            spec: dict[str, object] = {
                "id": item["id"],
                "kind": item["kind"],
                "method": item["method"],
                "category": "project",
                "criteria": [],
            }
            if item["kind"] != "observation":
                spec["execution"] = item["execution"]
            result.append(CHECK_SPEC.validate_python(spec))
        except ValidationError as exc:
            raise ValueError(
                validation_message("Invalid required project check", exc, CHECK_SPEC)
            ) from None
    selected = {c["id"] for c in result}
    for item in project_checks(profile, all_processes=False):
        if item["id"] in selected:
            require(set(item.get("after", [])) <= selected, f"inactive dependency of {item['id']}")
    return result


def check_task(profile: ProjectData, task: Any, *, final: bool = False) -> None:
    actual = {x["id"]: x for x in task["required_checks"]}
    for expected in required_checks(profile, task, final=final):
        candidate = deepcopy(actual.get(expected["id"]))
        message = f"missing/changed mandatory check: {expected['id']}"
        if expected["kind"] != "observation" and isinstance(candidate, dict):
            execution = candidate.get("execution")
            if not (isinstance(execution, dict)):
                raise ValueError("Project policy: " + message)
            inputs = execution.get("inputs", [])
            strings(inputs, "check inputs", empty=True)
            for path in inputs:
                relative(path)
            require(set(expected["execution"].get("inputs", [])) <= set(inputs), message)
            # Task-specific inputs strengthen freshness without changing the command.
            if "inputs" in expected["execution"]:
                execution["inputs"] = expected["execution"]["inputs"]
            else:
                execution.pop("inputs", None)
        require(candidate == expected, message)


def document_paths(profile: ProjectData, rule: Rule) -> list[str]:
    """Resolve exact workspace paths; categories never select or expand documents."""
    if "project_file" in rule:
        return [rule["project_file"]]
    return list(dict.fromkeys(profile["documents"][key]["path"] for key in rule["documents"]))


# Project policy supplements only implemented boundaries. Skill-owned plan/graph
# publication gates remain in those skills; no arbitrary expression evaluator.
CHECK_BOUNDARIES = {
    "implement.work",
    "implement.docs",
    "implement.verify",
    "decompose.complete",
    "code-review.complete",
}
REVIEW_BOUNDARIES = {"implement.review", "code-review.complete"}


def project_checks(profile: ProjectData, *, all_processes: bool = True) -> list[ProjectCheck]:
    return [
        check
        for gate in profile.get("gates", [])
        if all_processes or any(at.startswith("implement.") for at in gate["at"])
        for check in gate.get("checks", [])
    ]


def local_policy_files(profile: ProjectData, profile_root: str = ".") -> list[str]:
    paths = [r["file"] for entries in rule_groups(profile).values() for r in entries if "file" in r]
    for gate in profile.get("gates", []):
        if "decompose.complete" in gate["at"]:
            for check in gate["checks"]:
                if check["kind"] == "observation":
                    raise ValueError("Project policy: decomposition check must be a command")
                for path in check["execution"]["inputs"]:
                    try:
                        local = str(PurePosixPath(path).relative_to(profile_root))
                    except ValueError as exc:
                        raise ValueError(
                            "Project policy: gate code inputs must remain inside profile directory"
                        ) from exc
                    relative(local)
                    paths.append(local)
    return list(dict.fromkeys(paths))


def review_criteria(profile: ProjectData, boundary: str | None = None) -> list[ReviewCriterion]:
    return [
        criterion
        for gate in profile.get("gates", [])
        if boundary is None or boundary in gate["at"]
        for criterion in gate.get("criteria", [])
    ]


def validate_gate_containers(profile: ProjectData) -> None:
    gates = profile.get("gates", [])
    seen = set()
    for gate in gates:
        gid = gate["id"]
        require(gid not in seen, "duplicate gate id")
        require(not gid.startswith("factory-"), "factory gate IDs are reserved")
        seen.add(gid)
        strings(gate.get("at"), "gate boundaries")
        choices = set(gate) & {"checks", "criteria"}
        require(len(choices) == 1, "gate needs exactly one checks/criteria collection")
        key = next(iter(choices))
        allowed = CHECK_BOUNDARIES if key == "checks" else REVIEW_BOUNDARIES
        require(set(gate["at"]) <= allowed, "unsupported gate boundary/type")
        if "code-review.complete" in gate["at"] and key == "checks":
            require(
                gate["at"] == ["code-review.complete"], "review commands need their own boundary"
            )
            require(
                all(
                    c.get("kind") != "observation" and "decision" not in c
                    for c in gate.get("checks", [])
                ),
                "review commands require execution; decision routing is not enabled",
            )
        if "decompose.complete" in gate["at"]:
            require(
                gate["at"] == ["decompose.complete"], "skill gate cannot mix process boundaries"
            )
            for check in gate["checks"]:
                require(
                    not any(k in check for k in ("decision", "for")),
                    "decomposition checks apply to the full artifact set",
                )
                if check["kind"] == "observation":
                    raise ValueError("Project policy: decomposition check must be a command")
                execution = check["execution"]
                argv = execution["argv"]
                require(
                    len(argv) >= 2
                    and argv[0] == "{python}"
                    and argv[1] in execution.get("inputs", []),
                    "decomposition check needs {python}, pinned script input and workspace cwd",
                )
        if key == "checks" and set(gate["at"]) - {"implement.verify"}:
            if not (all(c["level"] == "slice" for c in gate.get("checks", []))):
                raise ValueError(
                    "Project policy: " + "final checks belong to verification boundary"
                )
    # Dependency receipts are local to one node: every boundary that requires a
    # dependent check must require its prerequisite there too.
    for boundary in CHECK_BOUNDARIES:
        checks = [c for g in gates if boundary in g["at"] for c in g.get("checks", [])]
        ids = {c["id"] for c in checks}
        require(
            all(set(c.get("after", [])) <= ids for c in checks),
            "check dependency missing at boundary",
        )


def boundary_gates(
    profile: ProjectData, boundary: str, task: Task | TaskSelection
) -> list[BoundaryGate]:
    """Select exact evidence IDs from an already validated task/profile."""
    declared = {c["id"] for c in task.get("required_checks", [])}
    result: list[BoundaryGate] = []
    for gate in profile.get("gates", []):
        if boundary not in gate["at"]:
            continue
        if "checks" in gate:
            ids = [c["id"] for c in gate["checks"] if c["id"] in declared]
            key = "checks"
        else:
            ids = [
                c["id"]
                for c in gate["criteria"]
                if matches(
                    c.get("for", {}), process=boundary.split(".")[0], scope=task.get("scope")
                )
            ]
            key = "criteria"
        if ids:
            selected: BoundaryGate = {"id": gate["id"], "at": boundary}
            if key == "checks":
                selected["checks"] = ids
            else:
                selected["criteria"] = ids
            result.append(selected)
    return result
