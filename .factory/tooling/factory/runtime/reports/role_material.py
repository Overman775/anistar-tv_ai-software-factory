"""Persist research and document evidence with its originating assignment."""

import posixpath
import re
from pathlib import Path
from urllib.parse import unquote, urlsplit

from factory import file_reader
from factory.project.profile_rules import registered_check
from factory.runtime.commands.evidence import check_receipts
from factory.runtime.contracts import Dispatch, Node, Report, RoleMaterial, RoleRecord, State
from factory.runtime.run_journal import RunJournal
from factory.runtime.workflow_config import check_config
from factory.runtime.workflow_core import (
    acceptance_guard,
    graph_identity,
    relative,
    require,
    snapshot,
)
from factory.runtime.workflow_graph import validate_graph

MATERIAL = {
    "bug-hunter": {"reproduction", "observation", "request-check", "cause"},
    "doc-writer": {"documents", "document-review", "analysis"},
    "code-explorer": {"analysis"},
}


def targets(root: Path, paths: list[str]) -> dict[str, str]:
    """Read local inline Markdown destinations in the assigned documents."""
    destinations = set()
    for path in paths:
        if not path.lower().endswith((".md", ".markdown")):
            continue
        raw = file_reader.read_text(relative(root, path), encoding="utf-8")
        for link in re.findall(r"\]\(<?([^\s)>]+)>?(?:\s+[^)]*)?\)", raw):
            url = urlsplit(unquote(link))
            if url.scheme or url.netloc:
                continue
            target = (
                posixpath.normpath(posixpath.join(posixpath.dirname(path), url.path))
                if url.path
                else path
            )
            file = relative(root, target)
            require(file.is_file(), f"Broken document link: {path} -> {link}")
            if url.fragment and file.suffix.lower() in {".md", ".markdown"}:
                content = file_reader.read_text(file, encoding="utf-8")
                headings = re.findall(r"^#{1,6}\s+(.+?)\s*#*\s*$", content, re.M)
                seen: dict[str, int] = {}
                anchors = set(re.findall(r'(?:id|name)=["\']([^"\']+)', content))
                for heading in headings:
                    key = re.sub(r"[^\w -]", "", heading.lower()).replace(" ", "-")
                    count = seen.get(key, 0)
                    anchors.add(f"{key}-{count}" if count else key)
                    seen[key] = count + 1
                require(url.fragment in anchors, f"Broken document anchor: {path} -> {link}")
            destinations.add(target)
    return snapshot(root, sorted(destinations))


def capture(
    root: Path, state: State, node: Node, dispatch: Dispatch, key: str, material: RoleMaterial
) -> RoleRecord:
    role = dispatch["role"]
    kind, paths = material["kind"], material["paths"]
    require(kind in MATERIAL.get(role, set()), f"{role} cannot publish {kind}")
    task = state["graph"]["tasks"][node["task"]]
    require(
        material["observation"].strip() and set(paths) <= set(task["scope"]),
        "Need a scoped observation",
    )
    files = snapshot(root, paths)
    require("DELETED" not in files.values(), "Missing evidence file")
    if kind in {"cause", "analysis"}:
        require(paths or material.get("receipts"), "Need cited source or returned receipt")
    requested = material.get("checks", [])
    require(
        bool(requested) == (kind == "request-check"), "Only a check request names assigned commands"
    )
    known = {c["id"]: c for c in task["required_checks"]}
    for name in requested:
        check = known.get(name) or acceptance_guard(
            registered_check, state["config"]["_project"]["data"], name, task["scope"]
        )
        require(
            check["kind"] not in {"observation", "codegen"},
            "Investigation requests read-only commands",
        )
    for execution in material.get("receipts", []):
        receipt = state.get("executions", {}).get(execution)
        require(
            receipt is not None
            and receipt["node_id"]
            in {r.get("verification_node") for r in dispatch.get("role_records", [])},
            "Receipt belongs to a different investigation",
        )
        assert receipt is not None
        result = receipt.get("result")
        require(result is not None, "Requested check still running")
        assert result is not None
        check_receipts(
            root, state, receipt["node_id"], [result], complete=False, require_pass=False
        )
    if kind in {"documents", "document-review"}:
        require(paths and set(paths) <= set(node.get("owns", [])), "Need assigned documents")
    return {
        "request_id": key,
        "material": material,
        "files": files,
        "links": targets(root, paths) if kind == "document-review" else {},
    }


def progress(root: Path, state: State, dispatch: Dispatch) -> dict[str, object]:
    notes = dispatch.get("role_records", [])
    verifications = {r["verification_node"] for r in notes if "verification_node" in r}
    return {
        "dispatch_id": dispatch["dispatch_id"],
        "source_hash": dispatch["assignment"]["source"]["hash"],
        "scope": dispatch["assignment"]["node"].get("owns", []),
        "records": notes,
        "missing_document_reviews": sorted(
            {path for r in notes if r["material"]["kind"] == "documents" for path in r["files"]}
            - {
                path
                for r in notes
                if r["material"]["kind"] == "document-review"
                and r["links"] == snapshot(root, list(r["links"]))
                for path, value in r["files"].items()
                if snapshot(root, [path])[path] == value
            }
        ),
        "requested_verification": {
            node: {
                "status": state["nodes"][node]["status"],
                "receipts": [
                    key
                    for key, rec in state.get("executions", {}).items()
                    if rec["node_id"] == node
                    and rec["dispatch_id"] == state["nodes"][node].get("dispatch_id")
                    and "result" in rec
                ],
            }
            for node in sorted(verifications)
        },
    }


def note(
    journal: RunJournal, node_id: str, ticket: str, key: str | None, material: RoleMaterial | None
) -> dict[str, object]:
    with journal.locked(wait=True):
        state = journal.read()
        dispatch = state["nodes"][node_id]
        require(
            dispatch.get("dispatch_id") == ticket and dispatch.get("role") in MATERIAL,
            "Wrong specialist assignment",
        )
        if material is None:
            require(key is None, "Provide evidence with the request ID")
            return progress(journal.root, state, dispatch)
        require(key and key.strip(), "Need a stable request ID")
        assert key is not None
        for record in dispatch.get("role_records", []):
            if record["request_id"] == key:
                require(record["material"] == material, "Request already binds different evidence")
                return dict(record)
        require(
            state["status"] == "active"
            and not state.get("pause_reason")
            and dispatch["status"] == "running",
            "Need active bound specialist",
        )
        check_config(state)
        record = capture(
            journal.root, state, dispatch["assignment"]["node"], dispatch, key, material
        )
        dispatch.setdefault("role_records", []).append(record)
        journal.save(
            state, "specialist_observation", node=node_id, dispatch_id=ticket, evidence=key
        )
        return dict(record)


def authorize_check(journal: RunJournal, node_id: str, ticket: str, request: str) -> dict[str, str]:
    with journal.locked(wait=True):
        state = journal.read()
        dispatch = state["nodes"][node_id]
        require(
            dispatch.get("dispatch_id") == ticket and dispatch.get("role") == "bug-hunter",
            "Wrong investigation",
        )
        record = next(
            (r for r in dispatch.get("role_records", []) if r["request_id"] == request), None
        )
        require(
            record is not None and record["material"]["kind"] == "request-check",
            "Need a recorded investigation request",
        )
        assert record is not None
        if "verification_node" in record:
            return {"tester_node": record["verification_node"], "investigation_dispatch": ticket}
        require(
            state["status"] == "active"
            and not state.get("pause_reason")
            and dispatch["status"] == "running",
            "Investigation is not active",
        )
        check_config(state)
        require(
            record["files"] == snapshot(journal.root, list(record["files"])),
            "Investigation request refers to an older candidate",
        )
        original = dispatch["assignment"]["node"]
        key = "diagnostic-check-" + graph_identity([ticket, request])[:20]
        graph = state["graph"]
        require(
            key not in state["nodes"] and key not in graph["agents"],
            "Conflicting verification assignment",
        )
        profile = state["config"]["_defaults"]["tester"]
        graph["agents"][key] = {"role": "tester", "profile": profile}
        for n in graph["nodes"]:
            if n["task"] == original["task"] and n["stage"] in {"review", "accept"}:
                require(state["nodes"][n["id"]]["status"] == "pending", "Review already started")
                n["depends_on"].append(key)
        graph["nodes"].append(
            {
                "id": key,
                "stage": "verify",
                "task": original["task"],
                "agent": key,
                "depends_on": list(original["depends_on"]),
                "required_check_ids": record["material"]["checks"],
                "owns": [],
                "resources": ["project-checks"],
            }
        )
        validate_graph(graph, state["config"], journal.root)
        state["nodes"][key] = {"status": "pending", "attempt": 0}
        record["verification_node"] = key
        journal.save(
            state, "diagnostic_check_authorized", node=node_id, dispatch_id=ticket, evidence=key
        )
        return {"tester_node": key, "investigation_dispatch": ticket}


def validate(root: Path, state: State, node: Node, dispatch: Dispatch, report: Report) -> None:
    inline = report.get("role_material", [])
    records = [
        *dispatch.get("role_records", []),
        *[capture(root, state, node, dispatch, str(i), m) for i, m in enumerate(inline)],
    ]
    stage = report["stage_result"]
    role = dispatch["role"]
    if role == "bug-hunter":
        require(
            stage in {"ROOT_CAUSE_FOUND", "BLOCKED_USER_INPUT", "BLOCKED_TOOL_ERROR"},
            "Need a confirmed cause or a named diagnostic blocker",
        )
        if stage.startswith("BLOCKED"):
            require(
                report.get("evidence") and report["outcome"] == "BLOCKED",
                "Name the missing input or failed tool",
            )
        else:
            require(report["outcome"] == "PASS", "Confirmed cause needs a successful diagnosis")
    if role == "bug-hunter" and stage == "ROOT_CAUSE_FOUND":
        current = {
            r["material"]["kind"] for r in records if r["files"] == snapshot(root, list(r["files"]))
        }
        require(
            {"reproduction", "cause"} <= current,
            "Diagnosis needs reproduction conditions and confirmed cause evidence",
        )
        for r in records:
            if r["material"]["kind"] == "cause" and r["material"].get("receipts"):
                capture(root, state, node, dispatch, r["request_id"], r["material"])
        unresolved = [
            r
            for r in records
            if r["material"]["kind"] == "request-check"
            and (
                "verification_node" not in r
                or state["nodes"][r["verification_node"]]["status"] != "done"
            )
        ]
        require(not unresolved, "Investigation is waiting for requested Tester evidence")
        cited = {
            key
            for r in records
            if r["material"]["kind"] in {"observation", "cause"}
            for key in r["material"].get("receipts", [])
        }
        for request in records:
            if target := request.get("verification_node"):
                checked = state["nodes"][target].get("report")
                require(
                    checked
                    and all(
                        row.get("execution_id") in cited
                        for row in checked["checks"]
                        if row["id"] in request["material"]["checks"]
                    ),
                    "Assess the returned receipt before confirming a cause",
                )

    if role == "doc-writer" and node.get("owns") and report["outcome"] == "PASS":
        require(stage == "DOCS_UPDATED", "Document assignment needs DOCS_UPDATED")
        docs = {
            p: v
            for r in records
            if r["material"]["kind"] == "documents"
            for p, v in r["files"].items()
        }
        baseline = dispatch.get("document_baseline", {})
        changed = {p for p, value in snapshot(root, list(baseline)).items() if value != baseline[p]}
        require(set(docs) == changed, "Declare every changed document in the assignment")
        reviewed_files = {
            p: v
            for r in records
            if r["material"]["kind"] == "document-review"
            and r["links"] == snapshot(root, list(r["links"]))
            for p, v in r["files"].items()
        }
        require(
            docs
            and docs == snapshot(root, list(docs))
            and all(reviewed_files.get(p) == v for p, v in docs.items()),
            "Missing current document content and reference review",
        )
