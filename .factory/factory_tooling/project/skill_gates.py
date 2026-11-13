"""Project checks for Decompose; executed only after the common graph validator."""

from __future__ import annotations

import json
import sys
import uuid
from pathlib import Path

from pydantic import ConfigDict, TypeAdapter, ValidationError, with_config
from typing_extensions import TypedDict

from factory_tooling.decompose.contracts import Envelope, LoadedTask
from factory_tooling.gates.gate_contract import (
    EvidenceText,
    GateCheck,
    GateResult,
    GateStatus,
    conclude,
    evidence,
)
from factory_tooling.project.contracts import (
    Policy,
)
from factory_tooling.project.profile_io import check_frozen, fingerprint, safe_path, sha
from factory_tooling.runtime.check_process import run_process
from factory_tooling.runtime.workflow_core import atomic_json
from factory_tooling.validation import validation_message


@with_config(ConfigDict(strict=True, extra="forbid"))
class SkillCheckResult(TypedDict):
    status: GateStatus
    message: EvidenceText
    evidence: list[EvidenceText]


SKILL_CHECK_RESULT = TypeAdapter[SkillCheckResult](SkillCheckResult)


def artifact_hash(staging: str | Path, source_lock: str | Path) -> str:
    root = Path(staging)
    paths = sorted(p for p in root.rglob("*") if p.is_file()) + [Path(source_lock)]
    lock = json.loads(Path(source_lock).read_text())
    if lock.get("plan_path"):
        paths.append(Path(lock["plan_path"]))
    if any(p.is_symlink() for p in root.rglob("*")) or any(p.is_symlink() for p in paths):
        raise ValueError("Symlink in decomposition artifacts")
    return fingerprint({str(p.absolute()): sha(p.read_bytes()) for p in paths})


def check_decomposition_gates(
    policy: Policy,
    tasks: dict[str, LoadedTask],
    envelopes: list[Envelope],
    staging: str | Path,
    source_lock: str | Path,
    output_dir: str | Path,
) -> list[GateResult]:
    """Execute independent checks; preserve both violations and execution blockers."""
    root = Path(policy["workspace"])
    gates = [g for g in policy["data"].get("gates", []) if "decompose.complete" in g["at"]]
    receipt = Path(output_dir) / "decomposition-gates.json"
    receipt.parent.mkdir(parents=True, exist_ok=True)
    receipt.unlink(missing_ok=True)
    if not gates:
        return []
    before = artifact_hash(staging, source_lock)
    checks = [c for g in gates for c in g["checks"]]
    records: dict[str, GateCheck] = {}
    details: dict[str, dict[str, object]] = {}
    payload = json.dumps({"tasks": tasks, "envelopes": envelopes}, ensure_ascii=False)
    while len(records) < len(checks):
        ready = [
            c for c in checks if c["id"] not in records and set(c.get("after", [])) <= set(records)
        ]
        if not ready:
            raise ValueError("Unresolved project check dependency")
        for check in ready:
            cid = check["id"]
            references = [str(receipt), cid]
            if any(records[k]["status"] != "PASS" for k in check.get("after", [])):
                records[cid] = evidence(
                    cid, "BLOCKED", "Prerequisite check did not pass", references
                )
                continue
            try:
                check_frozen(policy["files"])
                if artifact_hash(staging, source_lock) != before:
                    raise ValueError("Decomposition artifacts changed during checks")
                if check["kind"] == "observation":
                    raise ValueError("Decomposition check must be a command")
                execution = check["execution"]
                argv = [
                    sys.executable,
                    str(safe_path(root, execution["argv"][1])),
                    *execution["argv"][2:],
                ]
                for rel in execution["inputs"]:
                    safe_path(root, rel)
                cwd = safe_path(root, execution["cwd"], exists=False)
                if not cwd.is_dir():
                    raise ValueError("Missing gate working directory")
                prefix = Path(output_dir) / (cid + "-" + uuid.uuid4().hex)
                stdout, stderr = Path(str(prefix) + ".stdout"), Path(str(prefix) + ".stderr")
                result = run_process(
                    execution | {"argv": argv},
                    cwd,
                    stdout,
                    stderr=stderr,
                    input_bytes=payload.encode("utf-8"),
                )
                details[cid] = {
                    "argv": argv,
                    "cwd": str(cwd),
                    **result,
                    "stdout": stdout.read_text(encoding="utf-8", errors="replace"),
                    "stderr": stderr.read_text(encoding="utf-8", errors="replace"),
                    "stdout_path": str(stdout),
                    "stderr_path": str(stderr),
                }
                if result["error"]:
                    raise ValueError(result["error"])
                check_frozen(policy["files"])
                if artifact_hash(staging, source_lock) != before:
                    raise ValueError("Decomposition artifacts changed during project checks")
                answer = SKILL_CHECK_RESULT.validate_json(stdout.read_bytes())
                status = answer["status"]
                if result["exit_code"] != {"PASS": 0, "FAIL": 1, "BLOCKED": 2}[status]:
                    raise ValueError("Check status/exit code mismatch")
                records[cid] = evidence(
                    cid, status, answer["message"], answer["evidence"] + references
                )
            except ValidationError as exc:
                records[cid] = evidence(
                    cid,
                    "BLOCKED",
                    validation_message("Invalid skill gate result", exc, SKILL_CHECK_RESULT),
                    references,
                )
            except (ValueError, TypeError, OSError) as exc:
                records[cid] = evidence(cid, "BLOCKED", str(exc), references)
    results = [
        conclude(
            g["id"],
            "decompose.complete",
            str(Path(source_lock).absolute()),
            policy["hash"],
            before,
            [c["id"] for c in g["checks"]],
            [records[c["id"]] for c in g["checks"]],
        )
        for g in gates
    ]
    statuses = {r["status"] for r in results}
    atomic_json(
        receipt,
        {
            "status": "FAIL"
            if "FAIL" in statuses
            else "BLOCKED"
            if "BLOCKED" in statuses
            else "PASS",
            "policy_hash": policy["hash"],
            "artifact_hash": before,
            "gates": results,
            "results": [{"id": key, **value} for key, value in details.items()],
        },
    )
    return results


def run_decomposition_gates(
    policy: Policy,
    tasks: dict[str, LoadedTask],
    envelopes: list[Envelope],
    staging: str | Path,
    source_lock: str | Path,
    output_dir: str | Path,
) -> list[str]:
    return [
        f"{gate['gate_id']}: {c['id']}: {c['status']}: {c['message']}"
        for gate in check_decomposition_gates(
            policy, tasks, envelopes, staging, source_lock, output_dir
        )
        for c in gate["checks"]
        if c["status"] != "PASS"
    ]
