"""Resume a direct Teacher assignment for an ordinary Retune invocation."""

import argparse
from pathlib import Path
from typing import Any, Literal, cast
from uuid import uuid4

from factory import file_reader
from factory.database.provider import current_database
from factory.dependency_graph import run_program
from factory.graphs.definition import load
from factory.paths import FACTORY_ROOT
from factory.processes import engine
from factory.processes.records import ProcessRun
from factory.runtime import teacher
from factory.runtime.knowledge.teacher_models import TeacherAssignment
from factory.runtime.scheduling import teacher_dispatch
from factory.runtime.workflow_config import load_config
from factory.runtime.workflow_core import digest, relative, require


def options(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "action",
        choices=["init", "status", "claim", "bind", "stopped", "trial", "result", "conclude"],
    )
    for name in (
        "run",
        "request",
        "dispatch",
        "handle",
        "case",
        "counterexample",
        "control",
        "baseline",
        "candidate",
        "instructions",
        "sample",
        "variant",
        "evidence",
        "worker",
        "ticket",
    ):
        parser.add_argument("--" + name)
    parser.add_argument("--config", type=Path, default=FACTORY_ROOT / "factory.yaml")
    parser.add_argument("--verdict", choices=["pass", "fail", "keep", "propose"])


def delivery(run: ProcessRun, args: argparse.Namespace, root: Path) -> dict[str, Any]:
    facts = run.state.facts
    assignment = TeacherAssignment.model_validate(
        facts.get("teacher", {"profile": run.subject["profile"]})
    )
    key = args.dispatch or teacher_dispatch.current_ticket(run.run_id, assignment)
    action: Literal["claim", "bind", "release"] = (
        "release" if args.action == "stopped" else "bind" if args.action == "bind" else "claim"
    )
    if action == "claim":
        require(
            len(assignment.attempts) < 3 or assignment.attempts[-1].status != "stopped",
            "Teacher attempt budget exhausted",
        )
    else:
        require(args.dispatch, "Supply the original Teacher ticket")
    req = teacher_dispatch.Request(
        action,
        assignment,
        run.run_id,
        key,
        args.handle if action == "bind" else args.evidence or "",
        root,
    )
    graph = engine.program("retune", tuple(sorted(run.definitions.items())))
    result = cast(dict[str, Any], run_program(graph, inputs=req))
    facts["teacher"] = assignment.model_dump()
    result.pop("event_id", None)
    return {**result, "assignment_id": run.run_id}


def start(root: Path, args: argparse.Namespace) -> dict[str, Any]:
    require(
        all(
            [
                args.request,
                args.case,
                args.counterexample,
                args.baseline,
                args.candidate,
                args.instructions,
            ]
        ),
        "Provide the cases, both procedures, owner instructions and stable request",
    )
    intake = {
        k: getattr(args, k)
        for k in ("case", "counterexample", "control", "baseline", "candidate", "instructions")
    }
    intake["config"] = str(args.config.resolve())
    repo = current_database().processes
    run_id = engine.identifier("retune", args.request)
    if repo.exists(root, run_id):
        saved = repo.get(root, run_id)
        require(
            saved.subject["intake"] == intake,
            "Retune request already belongs to another assignment",
        )
        return {
            "run_id": run_id,
            "source_cases": [
                k for k in saved.subject["inputs"] if k not in {"baseline", "candidate"}
            ],
        }
    sources = {}
    for name in ("case", "counterexample", "control", "baseline", "candidate"):
        path = getattr(args, name)
        if path:
            raw = file_reader.read_bytes(relative(root, path))
            sources[name] = {"path": path, "sha256": digest(raw), "text": raw.decode()}
    require(
        len({v["path"] for v in sources.values()}) == len(sources),
        "Use distinct cases and procedure inputs",
    )
    config = load_config(args.config)
    subject = {
        "intake": intake,
        "inputs": sources,
        "instructions": args.instructions,
        "profile": teacher.launch_profile(config),
    }
    graph = load(args.config.resolve().parent / "graphs", "teacher")
    run = engine.start(
        root, "retune", args.request, subject, args.config.parent / "graphs", definitions=graph
    )
    return {
        "run_id": run.run_id,
        "source_cases": [k for k in sources if k not in {"baseline", "candidate"}],
    }


def mutate(root: Path, args: argparse.Namespace, run: ProcessRun) -> dict[str, Any]:
    if args.action in {"claim", "bind", "stopped"}:
        return delivery(run, args, root)
    facts = run.state.facts
    teacher_state = TeacherAssignment.model_validate(facts.get("teacher", {}))
    require(
        teacher_state.attempts
        and teacher_state.attempts[-1].dispatch_id == args.dispatch
        and teacher_state.attempts[-1].status == "running",
        "Supply the bound Teacher assignment",
    )
    trials = facts.setdefault("trials", {})
    inputs = run.subject["inputs"]
    samples = [k for k in inputs if k not in {"baseline", "candidate"}]
    if args.action in {"trial", "result"}:
        require(
            args.sample in samples and args.variant in {"baseline", "candidate"} and args.worker,
            "Identify the trial case, procedure and independent worker",
        )
        slot = args.sample + "/" + args.variant
        if args.action == "trial":
            if slot not in trials:
                require(
                    args.worker != teacher_state.attempts[-1].handle
                    and all(a["worker"] != args.worker for a in trials.values()),
                    "Each trial needs a fresh independent worker",
                )
                trials[slot] = {"ticket": uuid4().hex, "worker": args.worker}
            require(args.worker == trials[slot]["worker"], "Resume the original trial worker")
            return {
                "ticket": trials[slot]["ticket"],
                "worker": args.worker,
                "task": inputs[args.sample]["text"],
                "procedure": inputs[args.variant]["text"],
                "recorded": "result" in trials[slot],
            }
        item = trials.get(slot, {})
        require(
            item
            and item["worker"] == args.worker
            and args.ticket == item["ticket"]
            and args.evidence
            and args.verdict in {"pass", "fail"},
            "The bound trial needs its ticket, observation and outcome",
        )
        value = {"verdict": args.verdict, "evidence": args.evidence}
        require(
            "result" not in item or item["result"] == value, "Trial already has a different result"
        )
        item["result"] = value
        return dict(item)
    require(
        args.action == "conclude" and args.evidence and args.verdict in {"keep", "propose"},
        "Teacher must supply a supported comparison",
    )
    if trials or args.verdict == "propose":
        require(
            all(
                "result" in trials.get(k + "/" + v, {})
                for k in samples
                for v in ("baseline", "candidate")
            ),
            "Complete the matched trials before concluding",
        )
        if args.verdict == "propose":
            require(
                all(trials[k + "/candidate"]["result"]["verdict"] == "pass" for k in samples),
                "Candidate regressed on a case or failed a trial",
            )
            require(
                any(trials[k + "/baseline"]["result"]["verdict"] == "fail" for k in samples),
                "No observed improvement",
            )
    baseline = inputs["baseline"]
    require(
        digest(file_reader.read_bytes(relative(root, baseline["path"]))) == baseline["sha256"],
        "Procedure changed during the comparison",
    )
    facts["comparison"] = {
        "decision": args.verdict,
        "evidence": args.evidence,
        "baseline": baseline["sha256"],
    }
    teacher_state.done = True
    facts["teacher"] = teacher_state.model_dump()
    run.state.terminal = "completed"
    return dict(facts["comparison"])


def operate(root: Path, args: argparse.Namespace) -> dict[str, Any]:
    if args.action == "init":
        return start(root, args)
    require(args.run, "Select the direct Retune assignment")
    current = current_database().processes.get(root, args.run)
    require(current.process == "retune", "Different assignment type")
    if args.action == "status":
        return {"run_id": current.run_id, "subject": current.subject, **current.state.model_dump()}
    require(args.request, "Use a stable --request for this transition")
    inputs = {
        k: getattr(args, k)
        for k in (
            "dispatch",
            "handle",
            "sample",
            "variant",
            "evidence",
            "worker",
            "ticket",
            "verdict",
        )
    }
    return engine.change(
        root,
        "retune",
        args.run,
        args.request,
        args.action,
        inputs,
        lambda run, _: mutate(root, args, run),
    )
