"""Verify delivered bytes in an isolated workspace and retain the evidence in the process."""

import argparse
import json
import tempfile
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path
from typing import Any

from factory.decompose.assemble import policy_binding
from factory.decompose.generate_task_graph import _write_graph
from factory.decompose.graph.task_data import _relation_ids, load_tasks
from factory.decompose.source_lock import prepare
from factory.decompose.staging.manifest import staged_manifest
from factory.processes.records import ProcessRun
from factory.runtime import upstream as source_fields
from factory.runtime.workflow_core import digest, graph_identity, relative, require


def fresh(run: ProcessRun) -> None:
    subject = run.subject
    source = subject["source_lock"]
    current = prepare(Path(source["plan_path"]), Path(subject["config"]))
    require(
        policy_binding(subject["config"]) == subject["policy_binding"],
        "Selected decomposition instructions changed; new intake required",
    )
    require(current == source, "Approved plan or project policy changed; start a new intake")


@contextmanager
def materialize(files: dict[str, str]) -> Iterator[Path]:
    with tempfile.TemporaryDirectory(prefix="factory-decompose-gates-") as tmp:
        stage = Path(tmp) / "tasks"
        for name, content in files.items():
            path = relative(stage, name)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content.encode())
        yield stage


def check(run: ProcessRun) -> dict[str, Any]:
    facts = run.state.facts
    source = run.subject["source_lock"]
    manifest = facts["manifest"]
    with materialize(facts["files"]) as stage:
        work = stage.parent
        hashes, count = staged_manifest(stage)
        require(
            hashes == manifest["files"] and count == manifest["task_count"],
            "Delivered bytes differ from the task manifest",
        )
        lock = work / "source"
        lock.write_text(json.dumps(source))
        output = work / "evidence/dependencies.md"
        result = _write_graph(
            argparse.Namespace(
                config=run.subject["config"],
                staging_dir=stage,
                source_lock=lock,
                output=str(output),
                core_only=False,
                view="dependencies",
            )
        )
        fresh(run)
        require(staged_manifest(stage) == (hashes, count), "Candidate changed during checks")
        receipts = output.with_name("decomposition-gates.json")
        record: dict[str, Any] = {
            "status": result["status"],
            "diagnostics": result["diagnostics"],
            "basis": graph_identity([source, hashes]),
            "files": hashes,
            "checks": json.loads(receipts.read_bytes()) if receipts.exists() else [],
        }
        if result["status"] != "PASS":
            return record
        tasks = load_tasks(stage)["tasks"]
        public = {}
        upstream = {}
        for key, task in tasks.items():
            filename = str(task["filename"])
            require(
                filename not in public and filename != "epic.md",
                "Duplicate or reserved published task filename",
            )
            card = Path(str(task["markdown_file"])).read_bytes()
            text = card.decode()
            require(
                set(source_fields.identifiers(text, "Depends on"))
                == set(_relation_ids(task.get("depends_on"))),
                "Task dependency differs between reviewed card and envelope",
            )
            public[filename] = text
            parents = [task["parent_task"]] if task["parent_task"] else []
            deps = list(
                dict.fromkeys(
                    [
                        *_relation_ids(task.get("depends_on")),
                        *parents,
                        *(k for k in _relation_ids(task.get("blocked_by")) if k in tasks),
                    ]
                )
            )
            upstream[key] = {
                "path": run.subject["destination"] + "/" + filename,
                "content_hash": digest(card),
                "snapshot": card.decode(),
                "depends_on": deps,
                **{k: task[k] for k in ("blocked_by", "outcome", "acceptance_ids")},
                "contributes_to_acceptance_ids": task.get("contributes_to_acceptance_ids", []),
                "local_acceptance_criteria": task.get("local_acceptance_criteria", []),
            }
        if len(tasks) > 1:
            name = Path(run.subject["destination"]).name
            epic = {
                "kind": "epic",
                "id": name,
                "title": name,
                "outcome": "Tasks from approved plan " + source["plan_id"],
                "tasks": [{"id": key, "file": card["path"]} for key, card in upstream.items()],
            }
            listing = "\n".join(
                f"- [{key}]({Path(card['path']).name})" for key, card in upstream.items()
            )
            public["epic.md"] = (
                f"# {name}\n\nSource: {source['plan_id']} revision {source['plan_revision']}\n\n"
                + listing
                + "\n\n"
                + output.read_text()
                + "\n\n```json\n"
                + json.dumps(epic, ensure_ascii=False, indent=2)
                + "\n```\n"
            )
        return {**record, "public": public, "tasks": upstream, "diagram": output.read_text()}
