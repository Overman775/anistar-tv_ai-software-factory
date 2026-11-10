"""Pure project policy validation and selection; no files, tools or model calls."""

from __future__ import annotations

import re
from copy import deepcopy
from pathlib import PurePosixPath
from typing import Any, cast

from factory_tooling.decisions.decision_contract import validate_answers, validate_definition
from factory_tooling.project.contracts import (
    BoundaryGate,
    ProjectCheck,
    ProjectData,
    ReviewCriterion,
    Rule,
    Selector,
)
from factory_tooling.runtime.command_contract import validate_execution
from factory_tooling.runtime.contracts import Check, Task

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


def fields(value: Any, allowed: set[str], label: str) -> None:
    if not (isinstance(value, dict)):
        raise ValueError("Project policy: " + f"{label} must be a mapping")
    require(set(value) <= set(allowed), f"unknown {label} fields: {set(value) - set(allowed)}")


def strings(value: Any, label: str, *, empty: bool = False) -> None:
    if not (isinstance(value, list) and (empty or value)):
        raise ValueError("Project policy: " + f"{label} must be a nonempty list")
    if not (all(isinstance(x, str) and x.strip() for x in value)):
        raise ValueError("Project policy: " + f"invalid {label}")
    require(len(set(value)) == len(value), f"duplicate {label}")


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


def validate_selector(selector: Any) -> None:
    fields(selector, {"processes", "roles", "stages", "paths_any", "path_regex"}, "selector")
    for name, allowed in [("processes", PROCESSES), ("roles", ROLES), ("stages", STAGES)]:
        if name in selector:
            strings(selector[name], name)
            require(set(selector[name]) <= allowed, f"unknown {name}")
    require(not ("paths_any" in selector and "path_regex" in selector), "choose glob or regex")
    if "paths_any" in selector:
        strings(selector["paths_any"], "paths_any")
        for pattern in selector["paths_any"]:
            glob_pattern(pattern)
    if "path_regex" in selector:
        if not (isinstance(selector["path_regex"], str) and selector["path_regex"]):
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
    groups = profile.get("rules", {})
    fields(groups, {"coordinator", "worker"}, "rules")
    for audience, entries in groups.items():
        if not (isinstance(entries, list)):
            raise ValueError("Project policy: " + f"rules.{audience} must be list")
    return groups


def validate(profile: Any) -> ProjectData:
    fields(
        profile,
        {
            "id",
            "documents",
            "rules",
            "gates",
            "decisions",
        },
        "profile",
    )
    if not (isinstance(profile.get("id"), str) and re.fullmatch("[a-z][a-z0-9-]*", profile["id"])):
        raise ValueError("Project policy: " + "invalid id")
    documents = profile.get("documents", {})
    if not (isinstance(documents, dict)):
        raise ValueError("Project policy: " + "documents must be mapping")
    for key, value in documents.items():
        if not (isinstance(key, str) and key):
            raise ValueError("Project policy: " + "invalid document name")
        fields(value, {"path", "category"}, "document")
        relative(value.get("path"))
        if "category" in value:
            if not (isinstance(value["category"], str) and value["category"].strip()):
                raise ValueError("Project policy: " + "invalid document category")
    validate_gate_containers(profile)
    groups = rule_groups(profile)
    all_rules = [item for entries in groups.values() for item in entries]
    for group, entries in [
        ("rules", all_rules),
        ("decisions", profile.get("decisions", [])),
        ("checks", project_checks(profile)),
        ("review criteria", review_criteria(profile)),
    ]:
        if not (isinstance(entries, list)):
            raise ValueError("Project policy: " + f"{group} must be list")
        seen = set()
        for item in entries:
            if not (
                isinstance(item, dict)
                and isinstance(item.get("id"), str)
                and re.fullmatch("[A-Za-z0-9][A-Za-z0-9_-]*", item["id"])
            ):
                raise ValueError("Project policy: " + f"invalid {group} id")
            require(item["id"] not in seen, f"duplicate {group} id: {item['id']}")
            seen.add(item["id"])
            validate_selector(item.get("for", {}))
    decisions = {x["id"] for x in profile.get("decisions", [])}
    for item in profile.get("decisions", []):
        validate_definition(item)
    for audience, entries in groups.items():
        for item in entries:
            fields(item, {"id", "for", "file", "project_file", "documents", "usage"}, "rule")
            require(
                not (audience == "coordinator" and "roles" in item.get("for", {})),
                "coordinator rules cannot require a worker role",
            )
            choices = set(item) & {"file", "project_file", "documents"}
            require(len(choices) == 1, "rule needs exactly one file/project_file/documents")
            if "documents" in choices:
                strings(item["documents"], "rule documents")
                require(set(item["documents"]) <= set(documents), "unknown document ID")
            else:
                relative(item["file"] if "file" in item else item["project_file"])
            require(item.get("usage", "policy") in {"policy", "reference"}, "unknown rule usage")
    checks = {x["id"] for x in project_checks(profile)}
    for item in project_checks(profile):
        fields(
            item,
            {
                "id",
                "for",
                "level",
                "decision",
                "kind",
                "method",
                "execution",
                "after",
                "approval_action",
                "approval_path_regex",
            },
            "check",
        )
        require(
            set(item.get("for", {})) <= {"paths_any", "path_regex"},
            "check selectors use paths only",
        )
        require(item.get("level") in {"slice", "final"}, "check needs slice/final level")
        if not (item.get("decision") is None or item["decision"] in decisions):
            raise ValueError("Project policy: " + "unknown check decision")
        if item.get("decision"):
            definition = next(d for d in profile["decisions"] if d["id"] == item["decision"])
            require(
                definition.get("type", "predicate") == "predicate",
                "check decision must be predicate",
            )
        require(
            item.get("kind") in {"tests", "static", "build", "docs", "codegen", "observation"},
            "unknown check kind",
        )
        if not (isinstance(item.get("method"), str) and item["method"].strip()):
            raise ValueError("Project policy: " + "check needs method")
        if "approval_action" in item:
            action = item["approval_action"]
            require(
                item["kind"] != "observation" and isinstance(action, str) and action.strip(),
                "approval action needs a named command check",
            )
        if "approval_path_regex" in item:
            pattern = item["approval_path_regex"]
            require(
                "approval_action" in item and isinstance(pattern, str) and pattern.strip(),
                "approval paths require an action and a regular expression",
            )
            try:
                re.compile(pattern)
            except re.error as exc:
                raise ValueError("Project policy: invalid approval path expression") from exc
        strings(item.get("after", []), "after", empty=True)
        require(
            set(item.get("after", [])) <= checks and item["id"] not in item.get("after", []),
            "unknown/self check dependency",
        )
        if item["kind"] != "observation":
            execution = validate_execution(item.get("execution"))
            relative(execution["cwd"])
            strings(execution.get("inputs", []), "inputs", empty=True)
            for path in execution.get("inputs", []):
                relative(path)
        else:
            require("execution" not in item, "observation cannot execute commands")
    done: set[str] = set()
    while done != checks:
        ready = {x["id"] for x in project_checks(profile) if set(x.get("after", [])) <= done} - done
        require(ready, "check dependency cycle")
        done |= ready
    for item in review_criteria(profile):
        fields(item, {"id", "lens", "for", "question"}, "review gate")
        require(item.get("lens") in LENSES, "unknown review lens")
        from factory_tooling.project.review_definition import CORE_CRITERIA

        require(
            item["id"] not in {x[0] for x in CORE_CRITERIA}, "cannot replace universal review gate"
        )
        require(
            set(item.get("for", {})) <= {"paths_any", "path_regex"},
            "review gate selectors use paths only",
        )
        if not (isinstance(item.get("question"), str) and item["question"].strip()):
            raise ValueError("Project policy: " + "gate needs question")
    return cast(ProjectData, profile)


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


def required_checks(profile: ProjectData, task: Any, *, final: bool = False) -> list[Check]:
    result: list[Check] = []
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
        result.append(
            cast(
                Check,
                {k: deepcopy(item[k]) for k in ("id", "kind", "method", "execution") if k in item}
                | {"category": "project", "criteria": []},
            )
        )
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
        if "execution" in expected and isinstance(candidate, dict):
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


def validate_gate_containers(profile: Any) -> None:
    gates = profile.get("gates", [])
    if not (isinstance(gates, list)):
        raise ValueError("Project policy: " + "gates must be list")
    seen = set()
    for gate in gates:
        fields(gate, {"id", "at", "checks", "criteria"}, "gate")
        gid = gate.get("id")
        if not (
            isinstance(gid, str)
            and re.fullmatch("[A-Za-z0-9][A-Za-z0-9_-]*", gid)
            and (gid not in seen)
        ):
            raise ValueError("Project policy: " + "invalid/duplicate gate id")
        require(not gid.startswith("factory-"), "factory gate IDs are reserved")
        seen.add(gid)
        strings(gate.get("at"), "gate boundaries")
        choices = set(gate) & {"checks", "criteria"}
        require(len(choices) == 1, "gate needs exactly one checks/criteria collection")
        key = next(iter(choices))
        if not (isinstance(gate[key], list) and gate[key]):
            raise ValueError("Project policy: " + "empty gate requirements")
        allowed = CHECK_BOUNDARIES if key == "checks" else REVIEW_BOUNDARIES
        require(set(gate["at"]) <= allowed, "unsupported gate boundary/type")
        if "code-review.complete" in gate["at"] and key == "checks":
            require(
                gate["at"] == ["code-review.complete"], "review commands need their own boundary"
            )
            require(
                all(c.get("kind") != "observation" and "decision" not in c for c in gate[key]),
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
                execution = check.get("execution", {})
                argv = execution.get("argv", [])
                if not (
                    check.get("kind") != "observation"
                    and len(argv) >= 2
                    and (argv[0] == "{python}")
                    and (argv[1] in execution.get("inputs", []))
                    and isinstance(execution.get("cwd"), str)
                ):
                    raise ValueError(
                        "Project policy: "
                        + "decomposition check needs {python}, pinned script input and workspace cwd"
                    )
        if key == "checks" and set(gate["at"]) - {"implement.verify"}:
            if not (all(isinstance(c, dict) and c.get("level") == "slice" for c in gate[key])):
                raise ValueError(
                    "Project policy: " + "final checks belong to verification boundary"
                )
    # Dependency receipts are local to one node: every boundary that requires a
    # dependent check must require its prerequisite there too.
    for boundary in CHECK_BOUNDARIES:
        checks = [c for g in gates if boundary in g["at"] for c in g.get("checks", [])]
        ids = {c.get("id") for c in checks if isinstance(c, dict)}
        if not (
            all(
                isinstance(c, dict)
                and isinstance(c.get("after", []), list)
                and all(isinstance(x, str) for x in c.get("after", []))
                and (set(c.get("after", [])) <= ids)
                for c in checks
            )
        ):
            raise ValueError("Project policy: " + "check dependency missing at boundary")


def boundary_gates(profile: ProjectData, boundary: str, task: Task) -> list[BoundaryGate]:
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
