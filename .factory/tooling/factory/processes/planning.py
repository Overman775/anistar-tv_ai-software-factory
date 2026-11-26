"""Planning operations retain one architect candidate until a separately evidenced approval."""

from pathlib import Path
from typing import Any

from factory import file_reader
from factory.decompose.graph.task_data import normalized_plan_hash
from factory.dependency_graph import compile_dependencies
from factory.graphs.program import Operations
from factory.planning.plan_revision import PlanRevision
from factory.planning.validate_plan import validate
from factory.processes import publication
from factory.processes.engine import Offer, active, offer, register
from factory.processes.records import ProcessRun
from factory.project.contracts import Selection
from factory.project.profile_io import freeze_materials, load_profile
from factory.project.project import configured_profile
from factory.runtime.workflow_core import digest, graph_identity, relative, require
from factory.tasks.criteria import plan_criteria


def policy_basis(config: Path, root: Path) -> str:
    policy = load_profile(configured_profile(config))
    selections: list[Selection] = [{"process": "planning", "audience": "coordinator"}]
    selections.extend(
        {"process": "planning", "audience": "worker", "role": role}
        for role in ("architect", "code-explorer")
    )
    materials = freeze_materials(policy, root, selections)
    rules = root / "AGENTS.md"
    if rules.is_file():
        materials[str(rules)] = digest(file_reader.read_bytes(rules))
    return graph_identity([policy["hash"], materials, digest(file_reader.read_bytes(config))])


def fresh(run: ProcessRun) -> None:
    config = Path(run.subject["config"])
    root = Path(run.subject["workspace"])
    require(
        policy_basis(config, root) == run.subject["policy_hash"],
        "Planning policy or selected project instructions changed; start a fresh intake",
    )


def operations() -> Operations:
    return register(
        (
            "intake",
            "needs_exploration",
            "analysis_ready",
            "needs_user_decision",
            "blocked_requirements",
            "blocked_external_source",
            "answer_received",
            "plan_ready",
            "needs_work",
            "approved",
            "install_ready",
            "published",
        ),
        "planning_outcome",
        {
            "plan_assignment": offer("architect", "architect"),
            "explore_assignment": offer("explore", "code-explorer"),
            "wait_for_input": offer("answer"),
            "review_candidate": offer("review"),
            "publish_approved": offer("prepare-publication"),
            "install_plan": offer("publish"),
            "finish_process": offer("finish"),
        },
    )


def candidate(text: str, phase: str, previous: str | None) -> PlanRevision:
    errors = validate(text, phase=phase, previous_text=previous)
    require(not errors, f"Plan gate: {errors}")
    return PlanRevision(text)


def citations(root: Path, refs: list[str]) -> list[dict[str, Any]]:
    records = []
    for ref in refs:
        path, sep, number = ref.rpartition(":")
        require(
            sep and number.isdecimal() and int(number) > 0, "Cite a file and positive line number"
        )
        raw = file_reader.read_bytes(relative(root, path))
        lines = raw.decode().splitlines()
        require(
            int(number) <= len(lines) and lines[int(number) - 1].strip(),
            "Citation outside source lines",
        )
        records.append(
            {
                "file": path,
                "line": int(number),
                "text": lines[int(number) - 1],
                "sha256": digest(raw),
            }
        )
    return records


def perform(
    root: Path, run: ProcessRun, selected: Offer, action: str, data: dict[str, Any]
) -> dict[str, Any]:
    state = run.state
    facts = state.facts
    message = data.get("evidence", "")
    if action == "question":
        require(
            selected.action == "architect" and message.strip(),
            "Need an open planning assignment and an addressable question",
        )
        state.phase = "needs_exploration"
        facts["question"] = message
        return {"question": message, "role": "code-explorer"}
    if action in {"note", "report"}:
        worker = active(run, selected.action, data.get("dispatch"))
        require(worker.status == "running", "A bound live worker must deliver the result")
        require(message.strip(), "Supply the observed evidence or blocking question")
        outcome = data.get("outcome", "").lower()
        allowed = (
            {"analysis_ready", "blocked_external_source"}
            if selected.role == "code-explorer"
            else {"plan_ready", "needs_user_decision", "blocked_requirements"}
        )
        require(action == "note" or outcome in allowed, "Outcome is outside this role's assignment")
        refs = citations(root, data.get("cite", []))
        entry: dict[str, Any] = {"observation": message, "citations": refs}
        if action == "note":
            worker.evidence.append(entry)
            return entry
        if outcome == "analysis_ready":
            require(refs, "Analysis needs a verifiable source line")
            facts["analysis"] = {**entry, "question": facts["question"]}
        if outcome == "blocked_external_source":
            require(data.get("source"), "Name the unavailable required source")
            entry["source"] = data["source"]
        if outcome == "plan_ready":
            text = data.get("content", "")
            plan = candidate(text, "draft", run.subject.get("previous_text"))
            sketch = data.get("sketch", {})
            require(
                isinstance(sketch, dict)
                and all(
                    isinstance(v, list) and all(p in sketch for p in v) for v in sketch.values()
                ),
                "Invalid planning sketch references",
            )
            if sketch:
                compile_dependencies(sketch)
            facts["candidate"] = {
                "text": text,
                "sha256": digest(text.encode()),
                "plan_id": plan.metadata["plan_id"],
                "revision": plan.number,
                "sketch": sketch,
                "architect": worker.handle,
            }
        worker.evidence.append(entry)
        worker.outcome = outcome
        # An unanswered question keeps the same Architect or Explorer ticket alive.
        if outcome in {"analysis_ready", "plan_ready"}:
            worker.status = "done"
        facts["reason"] = message
        state.phase = outcome
        return {
            "dispatch": worker.dispatch,
            "outcome": outcome,
            "evidence": entry,
            "candidate": facts.get("candidate", {}).get("sha256"),
        }
    if action == "answer":
        require(
            selected.action == "answer" and message.strip() and data.get("reference"),
            "Need the cited answer to this open question",
        )
        facts.setdefault("answers", []).append(
            {"question": facts["reason"], "answer": message, "reference": data["reference"]}
        )
        state.phase = (
            "needs_exploration" if state.phase == "blocked_external_source" else "answer_received"
        )
        facts.pop("reason", None)
        return {"phase": state.phase, "reference": data["reference"]}
    if action == "review":
        require(selected.action == "review", "No plan candidate awaits independent review")
        current = facts["candidate"]
        require(
            data.get("basis") == current["sha256"]
            and data.get("actor")
            and data["actor"] != current["architect"]
            and message.strip(),
            "Independent reviewer, current plan hash and evidence required",
        )
        verdict = data.get("outcome", "").lower()
        require(verdict in {"approved", "needs_work"}, "Expected APPROVED or NEEDS_WORK")
        if verdict == "approved":
            require(data.get("reference"), "Cite the owner's approval or delegated authority")
            text = data.get("content", "")
            plan = candidate(text, "approved", current["text"])
            require(
                plan.approval_content == PlanRevision(current["text"]).approval_content,
                "Approval applies to the exact reviewed candidate",
            )
            facts["approved"] = {
                "text": text,
                "plan_id": plan.metadata["plan_id"],
                "revision": plan.number,
                "plan_hash": normalized_plan_hash(text),
                "content_hash": digest(text.encode()),
                "acceptance_ids": [c["id"] for c in plan_criteria(text)],
                "reference": data["reference"],
            }
        facts["review"] = {
            "verdict": verdict,
            "actor": data["actor"],
            "basis": current["sha256"],
            "evidence": message,
        }
        state.phase = verdict
        return dict(facts["review"])
    if action == "prepare-publication":
        require(
            selected.action == action and state.phase == "approved",
            "Publication requires an approved candidate",
        )
        facts["publication"] = publication.prepare(
            root,
            run.subject["destination"],
            {"content": facts["approved"]["text"]},
            run.subject.get("previous_identity"),
            directory=False,
        )
        state.phase = "install_ready"
        return dict(facts["publication"])
    if action == "publish":
        require(
            selected.action == action and state.phase == "install_ready",
            "Missing prepared plan publication",
        )
        proof = publication.install(root, facts["publication"])
        state.phase = "published"
        state.terminal = "completed"
        return {
            **proof,
            "plan_id": facts["approved"]["plan_id"],
            "revision": facts["approved"]["revision"],
            "continuation": run.subject["continuation"],
            "authorization": run.subject.get("authorization"),
        }
    raise ValueError("Unsupported planning action")
