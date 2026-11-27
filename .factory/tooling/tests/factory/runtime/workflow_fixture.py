from __future__ import annotations

import sys
import tempfile
from collections.abc import Callable
from copy import deepcopy
from pathlib import Path
from typing import Any, cast
from unittest.mock import patch

from examples.example_workflow import proposal

from factory.runtime.contracts import State, agent_key
from factory.runtime.scheduling.assignment import ImplementPacket, validate_packet
from factory.runtime.scheduling.orchestrator_graph import assignment_ticket
from factory.runtime.workflow import Ledger
from factory.runtime.workflow_config import load_config
from factory.runtime.workflow_core import digest, snapshot
from tests.fixture_bundle import ROOT as ROOT


def bound_teacher(root: Path, key: str) -> str | None:
    """Bind the final run reviewer before exercising its worker-side commands."""
    from factory.database.provider import current_database
    from factory.runtime import teacher
    from factory.runtime.scheduling.teacher_dispatch import deliver

    event = teacher.read_event(root, key)
    if event.incidents is None:
        return None
    if event.attempts:
        return event.attempts[-1].dispatch_id
    jobs = current_database().teacher
    token = str(deliver(root, key, None, None, None, jobs)["dispatch_id"])
    deliver(root, key, None, [token, "fixture-teacher"], None, jobs)
    return token


class WorkflowFixture:
    def __init__(self, add_cleanup: Callable[[Callable[[], object]], object]) -> None:
        acpx = patch(
            "factory.runtime.observability.acpx_usage.acpx_session_probe",
            side_effect=FileNotFoundError,
        )
        acpx.start()
        add_cleanup(acpx.stop)
        self.temp = tempfile.TemporaryDirectory(prefix="factory-workflow-test-")
        add_cleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "lib").mkdir()
        (self.root / "lib/example.dart").write_text("before")
        (self.root / "AGENTS.md").write_text("Fixture workspace. No real external calls.")
        self.config = load_config(ROOT / "factory.yaml")
        from factory.project.profile_io import load_profile

        self.fixture_policy = "id: unit-fixture\n"
        self.fixture_profile = self.root / "fixture-project.yaml"
        self.fixture_profile.write_text(self.fixture_policy)
        self.config["_project"] = load_profile(self.fixture_profile)
        self.config["_files"].update(self.config["_project"]["files"])
        self.config["profiles"]["implementer"] = deepcopy(
            self.config["profiles"]["middle-implementer"]
        )
        self.config["profiles"]["implementer"].pop("escalation", None)
        self.config["_roles"]["implementer"].append("implementer")
        self.config["_defaults"]["implementer"] = "implementer"
        self.g: Any = cast(dict[str, Any], deepcopy(proposal()))
        self.g["agents"]["author"]["profile"] = "implementer"
        self.g["tasks"]["label"].pop("project_check_inputs", None)
        self.g["tasks"]["label"].pop("policy_decisions", None)
        for node in self.g["nodes"]:
            if node["stage"] == "work":
                node["resources"] = []
        self.g["tasks"]["label"]["required_checks"] = [
            c for c in self.g["tasks"]["label"]["required_checks"] if c["category"] == "acceptance"
        ]
        self.g["tasks"]["label"]["required_checks"][0]["execution"] = {
            "argv": [sys.executable, "-c", "print('fixture check')"],
            "cwd": ".",
            "timeout_seconds": 10,
        }
        self.ledger = Ledger(self.root)

    def init(self) -> State:
        return self.ledger.init(self.g, self.config)

    def claim(self, node: str) -> dict[str, object]:
        state = self.ledger.read()
        ticket = assignment_ticket(
            state["run_id"], state["revision"], node, state["nodes"][node]["attempt"] + 1
        )
        return self.ledger.claim(node, ticket=ticket)

    def stored_packet(self, node: str) -> ImplementPacket:
        ref = self.ledger.read()["nodes"][node]["packet_file"]
        return validate_packet(
            self.ledger.history.document(
                self.root, ref["run_id"], ref["path"], ref["sha256"], "packet"
            )
        )

    def report(self, node: str, outcome: str = "PASS", **extra: Any) -> dict[str, Any]:
        s = self.ledger.read()
        n = next(n for n in s["graph"]["nodes"] if n["id"] == node)
        task = s["graph"]["tasks"][n["task"]]
        assigned = self.ledger.finish_requirements(s, n)["required_checks"]
        check = assigned[0] if assigned else task["required_checks"][0]
        return {
            "run_id": s["run_id"],
            "dispatch_id": s["nodes"][node]["dispatch_id"],
            "node_id": node,
            "task_id": n["task"],
            "slice_id": task["slice"],
            "source_hash": s["graph"]["sources"][task["source"]]["hash"],
            "terminal": True,
            "outcome": outcome,
            "summary": "Fixture result",
            **(
                {
                    "write_result": {
                        "code": list(n["owns"]),
                        "tests": [check["id"]],
                        "docs_current": "The fixture edits an internal label with no public contract change.",
                    }
                }
                if n.get("owns")
                and s["nodes"][node].get("role") == "implementer"
                and outcome == "PASS"
                else {}
            ),
            "files": snapshot(self.root, task["scope"]),
            "stage_result": "WRITES_READY" if n.get("owns") else "VERIFIED",
            "checks": (
                (
                    [self.ledger.run_check(node, check["id"])]
                    if check["kind"] != "observation"
                    else [
                        {
                            **check,
                            "result": "PASS",
                            "evidence": "fixture observation",
                        }
                    ]
                )
                if "checks" not in extra
                and n["stage"] == "verify"
                and "project-checks" in n.get("resources", [])
                else []
            ),
            "not_applicable": {
                kind: "Fixture lacks this evidence kind"
                for kind in ("static", "tests", "docs")
                if n["stage"] == "verify"
                and kind not in {c["kind"] for c in task["required_checks"]}
            },
            **(
                {"evidence": "Fixture inspected the reported behavior"} if outcome != "PASS" else {}
            ),
            **extra,
        }

    def start(self, node: str, handle: str | None = None) -> None:
        self.claim(node)
        state = self.ledger.read()
        n = next(n for n in state["graph"]["nodes"] if n["id"] == node)
        profile = state["config"]["profiles"][state["graph"]["agents"][agent_key(n)]["profile"]]
        self.ledger.bind(
            node,
            handle or "handle-" + agent_key(n),
            state["config"]["models"][profile["model"]]["id"] or "fixture-default",
        )

    def complete(self) -> None:
        self.start("write-label")
        self.ledger.finish("write-label", self.report("write-label"))
        self.start("verify-label")
        self.ledger.finish("verify-label", self.report("verify-label"))
        self.ledger.accept("accept-label")

    def config_file(self, mutate: Callable[[dict[str, Any]], object]) -> Path:
        import yaml

        raw = yaml.safe_load((ROOT / "factory.yaml").read_text())
        raw["agent_workers"]["implementer"]["variants"]["implementer"] = dict(
            raw["agent_workers"]["implementer"]["variants"]["middle-implementer"]
        )
        raw["agent_workers"]["implementer"]["variants"]["implementer"].pop("escalation", None)
        raw["agent_workers"]["implementer"]["default"] = "implementer"
        mutate(raw)
        # Use absolute existing canonical file paths via a fixture bundle copy.
        import shutil

        dest = self.root / "bundle"
        shutil.copytree(
            ROOT,
            dest,
            ignore=shutil.ignore_patterns(
                "__pycache__", ".venv", ".python", ".mypy_cache", ".ruff_cache"
            ),
            symlinks=True,
        )
        raw["project"] = "project/fixture.yaml"
        (dest / "project/fixture.yaml").write_text(self.fixture_policy)
        (dest / "factory.yaml").write_text(yaml.safe_dump(raw))
        return dest / "factory.yaml"

    def require_fixture_review(self) -> None:
        self.g["tasks"]["label"]["independent_review"] = True
        self.g["agents"]["fixture-judge"] = {"role": "judge", "profile": "judge"}
        self.g["nodes"].append(
            {
                "id": "review-label",
                "task": "label",
                "stage": "review",
                "agent": "fixture-judge",
                "depends_on": ["verify-label"],
                "owns": [],
                "resources": [],
            }
        )
        next(n for n in self.g["nodes"] if n["id"] == "accept-label")["depends_on"] = [
            "review-label"
        ]

    def parallel_graph(self) -> None:
        self.config["_defaults"]["implementer"] = "middle-implementer-zcode"
        template = deepcopy(self.g["tasks"]["label"])
        scope = [f"docs/file{i}.txt" if i < 4 else f"lib/file{i}.txt" for i in range(8)]
        works = []
        tails = []
        tasks = {}
        for i in range(8):
            aid = f"worker{i}"
            tid = f"task{i}"
            self.g["agents"][aid] = {
                "role": "implementer" if i >= 4 else "doc-writer",
                "profile": "middle-implementer-zcode" if i >= 4 else "doc-writer",
            }
            tasks[tid] = {**deepcopy(template), "scope": scope, "independent_review": False}
            works.append(
                {
                    "id": aid,
                    "task": tid,
                    "stage": "work",
                    "agent": aid,
                    "depends_on": [],
                    "owns": [scope[i]],
                    "resources": [],
                }
            )
            tails.extend(
                [
                    {
                        "id": f"verify-{aid}",
                        "task": tid,
                        "stage": "verify",
                        "agent": "tester",
                        "depends_on": [aid],
                        "owns": [],
                        "resources": ["project-checks"],
                    },
                    {
                        "id": f"accept-{aid}",
                        "task": tid,
                        "stage": "accept",
                        "agent": None,
                        "depends_on": [f"verify-{aid}"],
                        "owns": [],
                        "resources": [],
                    },
                ]
            )
        tasks["integrated"] = {
            **deepcopy(template),
            "scope": scope,
            "kind": "integration",
            "independent_review": True,
            "depends_on": list(tasks),
        }
        self.g["agents"]["parallel-judge"] = {"role": "judge", "profile": "judge"}
        tails.extend(
            [
                {
                    "id": "verify-all",
                    "task": "integrated",
                    "stage": "verify",
                    "agent": "tester",
                    "depends_on": [f"accept-worker{i}" for i in range(8)],
                    "owns": [],
                    "resources": ["project-checks"],
                },
                {
                    "id": "review-all",
                    "task": "integrated",
                    "stage": "review",
                    "agent": "parallel-judge",
                    "depends_on": ["verify-all"],
                    "owns": [],
                    "resources": [],
                },
                {
                    "id": "accept-all",
                    "task": "integrated",
                    "stage": "accept",
                    "agent": None,
                    "depends_on": ["review-all"],
                    "owns": [],
                    "resources": [],
                },
            ]
        )
        self.g["tasks"] = tasks
        self.g["nodes"] = works + tails

    def fake_acp(self, code: int = 0) -> Path:
        self.config["_defaults"]["implementer"] = "middle-implementer-zcode"
        binary = Path(sys.executable)
        self.transport_exit_code = code
        self.config["acpx"]["command"] = str(binary)
        self.config["acpx"]["connections"]["zcode"]["command"] = str(binary)
        self.g["agents"]["author"] = {"role": "implementer", "profile": "middle-implementer-zcode"}
        self.require_fixture_review()
        return binary

    def external_source(self) -> dict[str, Any]:
        content = b"# External plan\nCorrect label; verify visible text.\n"
        (self.root / "external.md").write_bytes(content)
        return {
            "acceptance": self.g["sources"]["request"]["acceptance"],
            "path": "external.md",
            "kind": "approved_plan",
            "selected_scope": "correct label",
            "approval_evidence": "explicit_external_hash_approval",
            "external_approval": {
                "state": "approved",
                "source_path": "external.md",
                "content_sha256": digest(content),
                "selected_scope": "correct label",
                "approved_by": "user",
                "evidence_ref": "fixture-message-42",
            },
        }

    def batch(self) -> None:
        first = self.g["tasks"]["label"]
        self.g["tasks"]["second"] = {
            **deepcopy(first),
            "outcome": "Related next outcome",
            "depends_on": ["label"],
        }
        self.g["tasks"]["integrated"] = {
            **deepcopy(first),
            "outcome": "Both outcomes work together",
            "kind": "integration",
            "independent_review": True,
            "depends_on": ["label", "second"],
        }
        self.g["agents"]["integration-judge"] = {"role": "judge", "profile": "judge"}
        self.g["nodes"] += [
            {
                "id": "write-second",
                "task": "second",
                "stage": "work",
                "agent": "author",
                "depends_on": ["accept-label"],
                "owns": ["lib/example.dart"],
                "resources": [],
            },
            {
                "id": "verify-second",
                "task": "second",
                "stage": "verify",
                "agent": "tester",
                "depends_on": ["write-second"],
                "owns": [],
                "resources": ["project-checks"],
            },
            {
                "id": "accept-second",
                "task": "second",
                "stage": "accept",
                "agent": None,
                "depends_on": ["verify-second"],
                "owns": [],
                "resources": [],
            },
            {
                "id": "verify-all",
                "task": "integrated",
                "stage": "verify",
                "agent": "tester",
                "depends_on": ["accept-label", "accept-second"],
                "owns": [],
                "resources": ["project-checks"],
            },
            {
                "id": "accept-all",
                "task": "integrated",
                "stage": "accept",
                "agent": None,
                "depends_on": ["review-all"],
                "owns": [],
                "resources": [],
            },
        ]
        self.g["nodes"].append(
            {
                "id": "review-all",
                "task": "integrated",
                "stage": "review",
                "agent": "integration-judge",
                "depends_on": ["verify-all"],
                "owns": [],
                "resources": [],
            }
        )
