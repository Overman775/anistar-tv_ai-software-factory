"""Author-owned material can arrive in any order; the current candidate gates transfer."""

from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path
from typing import cast

from pydantic_graph import Graph, StepContext
from pydantic_graph.step import StepFunction

from factory.dependency_graph import run_program
from factory.graphs.definition import parse
from factory.graphs.program import Operations, compile_program
from factory.runtime.contracts import (
    Dispatch,
    Node,
    Report,
    State,
    WriteDelivery,
    WriteOffer,
    WriteProof,
)
from factory.runtime.run_journal import RunJournal
from factory.runtime.workflow_core import require, snapshot


def capture(root: Path, state: State, node: Node, offer: WriteOffer) -> WriteProof:
    task = state["graph"]["tasks"][node["task"]]
    owned = set(node.get("owns", []))
    scope = set(task["scope"])
    code, tests, docs = (
        set(offer.get("code", [])),
        set(offer.get("tests", [])),
        set(offer.get("docs", [])),
    )
    require(
        not (docs and "docs_current" in offer),
        "Choose updated documents or a current-document rationale",
    )
    require(code <= owned and docs <= owned, "Write evidence outside assignment ownership")
    checks = {check["id"] for check in task["required_checks"]}
    test_files = tests - checks
    require(
        test_files <= scope, "Regression evidence needs a scoped test file or assigned check ID"
    )
    files = snapshot(root, sorted(code | test_files | docs))
    require(
        all(files[path] != "DELETED" for path in docs | test_files),
        "Missing document or regression file",
    )
    interfaces = state["config"]["_project"]["data"].get("public_contracts", {})
    basis = (
        snapshot(root, sorted(set(interfaces) & scope)) if docs or "docs_current" in offer else {}
    )
    return {"offer": offer, "files": files, "basis": basis}


def evidence_gaps(
    root: Path, state: State, node: Node, dispatch: Dispatch, last: WriteProof | None = None
) -> dict[str, str]:
    proofs = [delivery["proof"] for delivery in dispatch.get("write_deliveries", [])]
    if last:
        proofs.append(last)
    code: dict[str, str] = {}
    tests: dict[str, str | None] = {}
    documentation = None
    for proof in proofs:
        offer = proof["offer"]
        code.update((p, proof["files"][p]) for p in offer.get("code", []))
        tests.update((p, proof["files"].get(p)) for p in offer.get("tests", []))
        if "docs_current" in offer or offer.get("docs"):
            documentation = proof
    gaps = {}
    if not code or code != snapshot(root, list(code)):
        gaps["code"] = "current code evidence"
    test_files = {k: v for k, v in tests.items() if v is not None}
    if not tests or test_files != snapshot(root, list(test_files)):
        gaps["tests"] = "current regression file or assigned check ID"
    if documentation is None:
        return {**gaps, "docs": "documentation or applicability reason"}
    basis = documentation["basis"]
    docs = documentation["offer"].get("docs", [])
    current = snapshot(root, list(basis))
    required = {
        doc
        for path, value in current.items()
        if state["contract_baseline"][path] != value
        for doc in state["config"]["_project"]["data"]["public_contracts"][path]
    }
    doc_bytes = snapshot(root, docs)
    if (
        current != basis
        or not required.issubset(docs)
        or any(doc_bytes[d] == state["contract_baseline"][d] for d in required if d in doc_bytes)
        or any(doc_bytes[d] != documentation["files"][d] for d in docs)
    ):
        gaps["docs"] = "updated documentation for the current public contract"
    return gaps


@dataclass
class Assessment:
    gaps: dict[str, str]
    steps: dict[str, str] = field(default_factory=dict)


async def assess_assignment(ctx: StepContext) -> Assessment:
    return cast(Assessment, ctx.inputs)


def check_material(kind: str) -> StepFunction:
    async def evaluate(ctx: StepContext) -> Assessment:
        assessment = cast(Assessment, ctx.inputs)
        assessment.steps[kind] = assessment.gaps.get(kind, "current")
        return assessment

    return evaluate


def unavailable(value: Assessment, reason: str) -> Assessment:
    value.gaps["route"] = reason
    return value


@lru_cache(maxsize=16)
def assignment_program(documents: tuple[tuple[str, str], ...]) -> Graph:
    definitions = dict(documents)
    name = parse("implement", definitions["implement"]).assignments.get("implementer")
    require(name in definitions, "Implement needs an Implementer assignment binding")
    assert name is not None
    actions = {
        "assess_assignment": assess_assignment,
        **{"check_" + key: check_material(key) for key in ("code", "tests", "docs")},
    }
    return compile_program(
        name,
        definitions,
        Operations(actions, {}, unavailable, inputs=dict.fromkeys(actions, Assessment)),
        batch=False,
    )


def assess(
    root: Path, state: State, node: Node, dispatch: Dispatch, last: WriteProof | None = None
) -> Assessment:
    facts = Assessment(evidence_gaps(root, state, node, dispatch, last))
    return cast(
        Assessment,
        run_program(assignment_program(tuple(sorted(state["definitions"].items()))), inputs=facts),
    )


def validate(root: Path, state: State, node: Node, dispatch: Dispatch, report: Report) -> None:
    offer = report.get("write_result")
    proof = capture(root, state, node, offer) if offer else None
    gaps = assess(root, state, node, dispatch, proof).gaps
    require(not gaps, "Implementer handoff needs " + ", ".join(gaps.values()))


def exchange(
    journal: RunJournal,
    node_id: str,
    ticket: str,
    request: str | None,
    offer: WriteOffer,
    *,
    dry_run: bool = False,
) -> dict[str, object]:
    with journal.locked(wait=True):
        state = journal.read()
        node = next((n for n in state["graph"]["nodes"] if n["id"] == node_id), None)
        require(node is not None, "Unknown assignment")
        assert node is not None
        dispatch = state["nodes"][node_id]
        require(
            dispatch.get("dispatch_id") == ticket and dispatch.get("role") == "implementer",
            "Wrong Implementer assignment",
        )
        deliveries = dispatch.get("write_deliveries", [])
        for delivery in deliveries:
            if request == delivery["request_id"]:
                require(
                    offer == delivery["proof"]["offer"],
                    "Request ID already bound to different evidence",
                )
                return {"dispatch_id": ticket, **delivery}
        require(
            dispatch["status"] == "running" and state["status"] == "active",
            "Need an active bound assignment",
        )
        require(
            bool(request) == bool(offer),
            "Supply both a delivery request ID and evidence, or neither for status",
        )
        if request:
            require(not state.get("pause_reason"), "Run is paused by user")
            from factory.runtime.workflow_config import check_config

            check_config(state)
            proof = capture(journal.root, state, node, offer)
            assessment = assess(journal.root, state, node, dispatch, proof)
            receipt: WriteDelivery = {"request_id": request, "proof": proof}
            if assessment.steps:
                receipt["steps"] = assessment.steps
            if not dry_run:
                dispatch.setdefault("write_deliveries", []).append(receipt)
                journal.save(
                    state,
                    "write_material_received",
                    node=node_id,
                    dispatch_id=ticket,
                    evidence=request,
                )
            return {"dispatch_id": ticket, **receipt}
        assessment = assess(journal.root, state, node, dispatch)
        return {
            "dispatch_id": ticket,
            "requests": [d["request_id"] for d in deliveries],
            "missing": list(assessment.gaps.values()),
            "steps": assessment.steps,
        }
