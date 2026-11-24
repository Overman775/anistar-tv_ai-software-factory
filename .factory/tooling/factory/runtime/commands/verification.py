"""Capture bounded machine evidence while command-owned artifacts are current."""

from __future__ import annotations

import json
import re
import xml.etree.ElementTree as ET
from datetime import datetime
from pathlib import Path
from typing import Literal, NotRequired
from urllib.parse import unquote, urlparse

from pydantic import ConfigDict, with_config
from typing_extensions import TypedDict


@with_config(ConfigDict(strict=True, extra="forbid"))
class Failure(TypedDict):
    name: str
    diagnostic: str
    path: NotRequired[str]
    location: NotRequired[str]
    check_id: NotRequired[str]


@with_config(ConfigDict(strict=True, extra="forbid"))
class Verification(TypedDict):
    suite: str
    scope: str
    phase: str
    result: Literal["PASS", "FAIL", "BLOCKED"]
    counts: dict[str, int]
    failures: list[Failure]
    diagnostics: list[str]
    complete: NotRequired[bool]


def read_artifact(path: Path) -> str:
    if path.is_symlink() or not path.is_file() or path.stat().st_size > 8_000_000:
        raise ValueError("Invalid or oversized verification artifact")
    return path.read_text(encoding="utf-8", errors="replace")


def short(text: str) -> str:
    return " ".join(text.split())[:500]


def _failures(directory: Path, started: float) -> list[Failure]:
    path = directory / "junit.xml"
    if not path.is_file():
        return []
    if path.stat().st_mtime < started:
        raise ValueError("JUnit predates command")
    failures = []
    for case in ET.fromstring(read_artifact(path)).iter("testcase"):
        problem = case.find("failure")
        if problem is None:
            problem = case.find("error")
        if problem is None:
            continue
        text = problem.text or problem.get("message", "") or ""
        failure: Failure = {"name": case.get("name", "unnamed"), "diagnostic": short(text)}
        location = re.search(r"(?:file://)?([^\s()]+\.(?:dart|py|js|ts)):(\d+)(?::\d+)?", text)
        if location:
            failure["location"] = location.group(0)
        failures.append(failure)
    return failures


def _event_message(failure: Failure, text: str) -> None:
    locations = re.findall(r"(?:file://)?([^\s()]+\.dart):(\d+)(?::(\d+))?", text)
    project = next(
        (item for item in locations if "/test/" in item[0] or item[0].startswith("test/")), None
    )
    if project is not None:
        failure["location"] = ":".join(part for part in project if part)
    lines = text.splitlines()
    useful = [
        line.strip()
        for line in lines
        if line.strip()
        and not line.startswith(
            (
                "═",
                "#",
                "<",
                "When the exception",
                "This was caught",
                "The test description",
                "The following",
            )
        )
    ]
    if any(
        marker in text
        for marker in ("Expected:", "Actual:", "TestFailure", "Golden", "Exception", "Error:")
    ):
        failure["diagnostic"] = short(" ".join(useful[:7]))


def _enrich_failures(directory: Path, failures: list[Failure], started: float) -> None:
    """Stream protocol messages for failing identities only; never retain passing cases."""
    path = directory / "flutter-events.jsonl"
    if not failures or not path.is_file():
        return
    if path.is_symlink() or path.stat().st_mtime < started:
        raise ValueError("Invalid or stale Flutter event artifact")
    names = {failure["name"] for failure in failures}
    by_id: dict[int, Failure] = {}
    failed_ids: set[int] = set()
    reused_ids: set[int] = set()
    suites: dict[int, str] = {}
    with path.open(encoding="utf-8", errors="replace") as stream:
        for line in iter(lambda: stream.readline(1_000_001), ""):
            if len(line) > 1_000_000:
                continue
            try:
                event = json.loads(line)
            except ValueError:
                continue
            if not isinstance(event, dict):
                continue
            if event.get("type") == "suite":
                suite = event.get("suite", {})
                if (
                    isinstance(suite, dict)
                    and type(suite.get("id")) is int
                    and isinstance(suite.get("path"), str)
                ):
                    suites[suite["id"]] = suite["path"]
            elif event.get("type") == "testStart":
                test = event.get("test", {})
                if (
                    not isinstance(test, dict)
                    or not isinstance(test.get("name"), str)
                    or test["name"] not in names
                    or type(test.get("id")) is not int
                ):
                    continue
                if test["id"] in by_id:
                    reused_ids.add(test["id"])
                    continue
                failure: Failure = {
                    "name": test["name"],
                    "diagnostic": "Failure observed in Flutter protocol; see retained log",
                }
                by_id[test["id"]] = failure
                url = test.get("root_url") or test.get("url")
                suite_id = test.get("rootSuiteID", test.get("suiteID"))
                file = (
                    unquote(urlparse(url).path)
                    if isinstance(url, str) and url.startswith("file:")
                    else suites.get(suite_id)
                    if type(suite_id) is int
                    else None
                )
                if file:
                    failure["path"] = file
                    number = test.get("root_line") if test.get("root_url") else test.get("line")
                    failure.setdefault(
                        "location", file + (":" + str(number) if type(number) is int else "")
                    )
            elif type(event.get("testID")) is int and event["testID"] in by_id:
                failure = by_id[event["testID"]]
                if event.get("type") == "print" and isinstance(event.get("message"), str):
                    _event_message(failure, event["message"])
                elif event.get("type") == "testDone" and event.get("result") in {
                    "failure",
                    "error",
                }:
                    failed_ids.add(event["testID"])
                elif event.get("type") == "error":
                    failed_ids.add(event["testID"])
                    if (
                        failure["diagnostic"]
                        == "Failure observed in Flutter protocol; see retained log"
                    ):
                        failure["diagnostic"] = short(str(event.get("error", "")))
                    _event_message(
                        failure,
                        str(event.get("error", "")) + "\n" + str(event.get("stackTrace", "")),
                    )

    _commit_failed_events(failures, by_id, failed_ids, reused_ids)


def _commit_failed_events(
    failures: list[Failure], by_id: dict[int, Failure], failed_ids: set[int], reused_ids: set[int]
) -> None:
    for name in {failure["name"] for failure in failures}:
        indexes = [index for index, failure in enumerate(failures) if failure["name"] == name]
        observed = [
            failure
            for test_id, failure in by_id.items()
            if failure["name"] == name and test_id in failed_ids and test_id not in reused_ids
        ]
        if len(observed) != len(indexes):
            continue
        for index, observed_failure in zip(indexes, observed, strict=True):
            if (
                len(indexes) == 1
                and observed_failure["diagnostic"]
                == "Failure observed in Flutter protocol; see retained log"
            ):
                observed_failure["diagnostic"] = failures[index]["diagnostic"]
            failures[index] = observed_failure


def _unittest_failures(lines: list[str]) -> list[Failure]:
    failures = []
    for index, line in enumerate(lines):
        match = re.match(r"(?:FAIL|ERROR): (.+)", line)
        if not match:
            continue
        block = []
        for detail in lines[index + 1 :]:
            if detail.startswith(("======", "Ran ", "FAIL:", "ERROR:")):
                break
            block.append(detail)
        text = "\n".join(block)
        diagnostic = next(
            (detail for detail in reversed(block) if re.search(r"Error:|Exception:", detail)),
            "See retained command log",
        )
        failure: Failure = {"name": match[1], "diagnostic": short(diagnostic)}
        locations = re.findall(r'File "([^"\n]+)", line (\d+)', text)
        if locations:
            failure["location"] = ":".join(locations[-1])
        failures.append(failure)
    return failures


def _report(directory: Path, started: float) -> Verification:
    data = json.loads(read_artifact(directory / "summary.json"))
    if "runs" in data:
        runs = data["runs"]
        if not isinstance(runs, list) or not runs:
            raise ValueError("Missing aggregate child reports")
        data = {
            "suite": "e2e",
            "scope": data["scope"],
            "phase": "e2e",
            "started_at": min(item["started_at"] for item in runs),
            "exit_code": 0 if data["status"] == "passed" else 1,
            **{
                key: sum(item.get(key, 0) for item in runs)
                for key in (
                    "completed_test_count",
                    "skipped_test_count",
                    "passed",
                    "failures",
                    "errors",
                )
            },
            "event_stream_complete": all(
                item.get("event_stream_complete") is True for item in runs
            ),
            "event_stream_issues": [
                issue for item in runs for issue in item.get("event_stream_issues", [])
            ],
        }
    if (
        not all(
            isinstance(data.get(key), str) and data[key].strip()
            for key in ("suite", "scope", "phase", "started_at")
        )
        or type(data.get("exit_code")) is not int
    ):
        raise ValueError("Invalid report identity or exit status")
    # Printed paths alone cannot authorize stale build artifacts from earlier attempts.
    if (
        not started
        <= datetime.fromisoformat(data["started_at"]).timestamp()
        <= datetime.now().timestamp()
    ):
        raise ValueError("Report predates command")
    counts = {
        key: data[key]
        for key in ("completed_test_count", "skipped_test_count", "passed", "failures", "errors")
        if type(data.get(key)) is int and data[key] >= 0
    }
    diagnostics = [
        short(item) for item in data.get("event_stream_issues", []) if isinstance(item, str)
    ]
    if data.get("event_stream_complete") is False:
        diagnostics.append("Incomplete test event stream")
    is_tests = data["suite"] in {"unit", "goldens", "e2e"} or str(data["suite"]).startswith("e2e:")
    if is_tests and not (
        type(data.get("completed_test_count")) is int and data["completed_test_count"] > 0
    ):
        diagnostics.append("Missing nonzero completed test count")
    completed = counts.get("completed_test_count")
    if (
        completed is not None
        and "passed" in counts
        and completed != sum(counts.get(key, 0) for key in ("passed", "failures", "errors"))
    ):
        diagnostics.append("Inconsistent completed/pass/failure/error counts")
    failures = _failures(directory, started)
    _enrich_failures(directory, failures, started)
    if counts.get("failures", 0) + counts.get("errors", 0) > len(failures):
        diagnostics.append("Some failed test identities unavailable; inspect retained log")
    if is_tests and data.get("event_stream_complete") is not True:
        diagnostics.append("Missing complete test event stream evidence")
    if is_tests and not {"completed_test_count", "passed", "failures", "errors"} <= counts.keys():
        diagnostics.append("Missing required test counts")
    if data["exit_code"] == 0 and (
        failures or counts.get("failures", 0) or counts.get("errors", 0)
    ):
        diagnostics.append("Successful exit contradicts reported test failures/errors")
    result: Verification = {
        "suite": str(data["suite"]),
        "scope": str(data["scope"]),
        "phase": str(data["phase"]),
        "result": "BLOCKED"
        if diagnostics and data["exit_code"] == 0
        else "PASS"
        if data["exit_code"] == 0
        else "FAIL",
        "counts": counts,
        "failures": failures,
        "diagnostics": diagnostics,
    }
    if is_tests:
        result["complete"] = (
            data.get("event_stream_complete") is True
            and {"completed_test_count", "skipped_test_count", "passed", "failures", "errors"}
            <= counts.keys()
            and counts.get("completed_test_count", 0) > 0
            and counts.get("completed_test_count")
            == sum(counts.get(key, 0) for key in ("passed", "failures", "errors"))
            and all(
                issue == "Flutter JSONL final done event reported failure."
                for issue in data.get("event_stream_issues", [])
            )
        )
    log = directory / "stage.log"
    if result["result"] != "PASS" and log.is_file():
        if log.stat().st_mtime < started:
            raise ValueError("Stage log predates command")
        result["diagnostics"].extend(
            short(line)
            for line in read_artifact(log).splitlines()
            if re.search(
                r"error|warning|exception|failed|not found|info [•:]|^Changed ", line, re.IGNORECASE
            )
        )
        result["diagnostics"] = result["diagnostics"][:8]
    return result


def capture(
    log: Path,
    root: Path,
    started: float,
    exit_code: int | None = None,
    *,
    result_format: str | None = None,
) -> list[Verification]:
    """Only inspect reports explicitly emitted by this physical command, within its root."""
    results = []
    seen = set()
    try:
        lines = read_artifact(log).splitlines()
    except OSError, ValueError:
        return (
            [
                {
                    "suite": "unknown",
                    "scope": "unknown",
                    "phase": "report-validation",
                    "result": "BLOCKED",
                    "counts": {},
                    "failures": [],
                    "diagnostics": ["Command log unavailable or exceeds artifact read limit"],
                }
            ]
            if result_format
            else []
        )
    for line in lines:
        match = (
            re.match(
                r"(?:OK|FAIL|PARTIAL PASS) suite=\S+ .*? report=(.+?)(?: log=| \(does not satisfy|$)",
                line,
            )
            if result_format == "anistar-quality"
            else None
        )
        if not match or match[1] in seen:
            continue
        seen.add(match[1])
        directory = Path(match[1])
        if not directory.is_absolute():
            directory = root / directory
        if (
            not any(
                directory.resolve().is_relative_to(root.resolve() / part)
                for part in ("build/quality", "build/e2e")
            )
            or directory.is_symlink()
        ):
            continue
        try:
            results.append(_report(directory, started))
        except OSError, ValueError, KeyError, TypeError, ET.ParseError:
            results.append(
                {
                    "suite": "unknown",
                    "scope": "unknown",
                    "phase": "report-validation",
                    "result": "BLOCKED",
                    "counts": {},
                    "failures": [],
                    "diagnostics": ["Current structured report unavailable or invalid"],
                }
            )
    if not results:
        diagnostics = [
            short(line)
            for line in lines
            if re.search(
                r"(?:Error:|Exception:|error [•:]|FAILED |No tests ran|No tests found|command not found)",
                line,
            )
        ][:8]
        counts = {}
        for line in lines:
            match = re.match(r"Ran (\d+) tests? in ", line)
            if match:
                counts["selected"] = int(match[1])
            match = re.match(r"(?:FAILED|OK) \((.+)\)", line)
            if match:
                for key, value in re.findall(r"(failures|errors|skipped)=(\d+)", match[1]):
                    counts[key] = int(value)
        incomplete = "selected" in counts and not any(
            re.match(r"(?:OK(?: \(.*\))?|FAILED \(.*\))$", line) for line in lines
        )
        if incomplete:
            diagnostics.append("Incomplete unittest result footer")
        if "selected" in counts:
            counts["skipped_test_count"] = counts.pop("skipped", 0)
            counts["completed_test_count"] = max(
                0, counts["selected"] - counts["skipped_test_count"]
            )
            counts["passed"] = max(
                0,
                counts["completed_test_count"]
                - sum(counts.get(key, 0) for key in ("failures", "errors")),
            )
        if result_format:
            diagnostics.append("Expected current structured command report unavailable")
        empty = counts.get("completed_test_count") == 0 or any(
            re.search(r"No tests (?:ran|found)", line, re.IGNORECASE) for line in lines
        )
        if empty:
            diagnostics.append("Zero executed tests")
        generic_failures = _unittest_failures(lines)
        contradictory = exit_code == 0 and bool(
            generic_failures or counts.get("failures", 0) or counts.get("errors", 0)
        )
        if contradictory:
            diagnostics.append("Successful exit contradicts unittest failures/errors")
        results.append(
            {
                "suite": "unknown",
                "scope": "unknown",
                "phase": "command",
                "result": "BLOCKED"
                if exit_code is None
                or empty
                or contradictory
                or incomplete
                or result_format is not None
                else "PASS"
                if exit_code == 0
                else "FAIL",
                "counts": counts,
                "failures": generic_failures,
                "diagnostics": [
                    "Structured diagnostics unavailable; inspect retained log",
                    *diagnostics,
                ],
            }
        )
    if any(item["suite"] == "e2e" for item in results):
        results = [item for item in results if not item["suite"].startswith("e2e:")]
    return results
