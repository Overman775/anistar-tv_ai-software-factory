from __future__ import annotations

import sys
import tempfile
from collections.abc import Callable
from copy import deepcopy
from pathlib import Path
from typing import Any
from unittest.mock import patch

from factory.runtime.contracts import State, agent_key
from factory.runtime.workflow import Ledger
from factory.runtime.workflow_config import load_config
from factory.runtime.workflow_core import digest, read_json, snapshot
from tests.fixture_bundle import ROOT as ROOT


class WorkflowFixture:
    def __init__(self, add_cleanup: Callable[[Callable[[], object]], object]) -> None:
        acpx = patch("factory.runtime.telemetry._show", side_effect=FileNotFoundError)
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
        self.g = read_json(ROOT / "tooling/examples/example.workflow.json")
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

    def report(self, node: str, outcome: str = "PASS", **extra: Any) -> dict[str, Any]:
        s = self.ledger.read()
        n = next(n for n in s["graph"]["nodes"] if n["id"] == node)
        task = s["graph"]["tasks"][n["task"]]
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
            "files": snapshot(self.root, task["scope"]),
            "stage_result": "WRITES_READY" if n.get("owns") else "VERIFIED",
            "checks": (
                (
                    [self.ledger.run_check(node, task["required_checks"][0]["id"])]
                    if task["required_checks"][0]["kind"] != "observation"
                    else [
                        {
                            **task["required_checks"][0],
                            "result": "PASS",
                            "evidence": "fixture observation",
                        }
                    ]
                )
                if "checks" not in extra and "project-checks" in n.get("resources", [])
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

    def start(self, node: str, handle: str = "handle-author") -> None:
        self.ledger.claim(node)
        state = self.ledger.read()
        n = next(n for n in state["graph"]["nodes"] if n["id"] == node)
        profile = state["config"]["profiles"][state["graph"]["agents"][agent_key(n)]["profile"]]
        self.ledger.bind(
            node,
            handle,
            state["config"]["models"][profile["model"]]["id"]
            or "fixture-default"
            or "fixture-default",
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
        mutate(raw)
        # Use absolute existing canonical file paths via a fixture bundle copy.
        import shutil

        dest = self.root / "bundle"
        shutil.copytree(
            ROOT,
            dest,
            ignore=shutil.ignore_patterns("__pycache__", ".venv", ".mypy_cache", ".ruff_cache"),
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
                "resources": ["project-checks"],
            }
        )
        next(n for n in self.g["nodes"] if n["id"] == "accept-label")["depends_on"] = [
            "review-label"
        ]

    def parallel_graph(self) -> None:
        self.config["_defaults"]["test-writer"] = "middle-test-writer-zcode"
        works = []
        for i in range(8):
            acp = i >= 4
            aid = f"worker{i}"
            self.g["agents"][aid] = {
                "role": "test-writer" if acp else "generalist",
                "profile": "middle-test-writer-zcode" if acp else "generalist",
            }
            scope = f"lib/file{i}.txt"
            self.g["tasks"]["label"]["scope"].append(scope)
            works.append(
                {
                    "id": aid,
                    "task": "label",
                    "stage": "work",
                    "agent": aid,
                    "depends_on": [],
                    "owns": [scope],
                    "resources": [],
                }
            )
        self.g["nodes"] = works + self.g["nodes"][1:]
        self.g["nodes"][-2]["depends_on"] = [w["id"] for w in works]
        self.require_fixture_review()

    def fake_acp(self, code: int = 0) -> Path:
        self.config["_defaults"]["test-writer"] = "middle-test-writer-zcode"
        binary = Path(sys.executable)
        self.transport_exit_code = code
        self.config["acpx"]["command"] = str(binary)
        self.config["acpx"]["connections"]["zcode"]["command"] = str(binary)
        self.g["agents"]["author"] = {"role": "test-writer", "profile": "middle-test-writer-zcode"}
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
                "agent": "author",
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
                "agent": "integration-judge",
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
                "resources": ["project-checks"],
            }
        )
