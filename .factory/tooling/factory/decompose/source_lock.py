"""Prepare a Decompose source lock from a plan and selected project policy."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

from pydantic import ValidationError

from factory import file_reader
from factory.decompose.contracts import SourceLock
from factory.decompose.graph.task_data import SOURCE_LOCK, normalized_plan_hash
from factory.planning.plan_document import declared_capabilities, parse_metadata, parse_revision
from factory.planning.validate_plan import validate
from factory.project.profile_io import load_profile
from factory.project.project import configured_profile
from factory.tasks.criteria import plan_criteria


def prepare(plan: Path, config: Path) -> SourceLock:
    content = file_reader.read_bytes(plan)
    text = content.decode("utf-8")
    errors = validate(text, phase="approved")
    if errors:
        raise ValueError("Approved plan validation failed: " + str(errors))
    metadata, _ = parse_metadata(text)
    lock = {
        "plan_id": metadata["plan_id"],
        "plan_revision": parse_revision(metadata["revision"]),
        "plan_path": str(plan),
        "plan_hash": normalized_plan_hash(text),
        "plan_content_hash": "sha256:" + hashlib.sha256(content).hexdigest(),
        "capability_ids": sorted(declared_capabilities(text)),
        "acceptance_ids": sorted(c["id"] for c in plan_criteria(text)),
        "project_policy_sha256": load_profile(configured_profile(config))["hash"],
    }
    return SOURCE_LOCK.validate_python(lock)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plan", type=Path, required=True)
    parser.add_argument("--config", type=Path, default=Path(".factory/factory.yaml"))
    args = parser.parse_args()
    try:
        lock = prepare(args.plan, args.config)
    except (OSError, ValueError, KeyError, ValidationError) as exc:
        print(f"Cannot prepare source lock: {exc}", file=sys.stderr)
        return 1
    print(json.dumps(lock, ensure_ascii=False, indent=2))
    return 0
