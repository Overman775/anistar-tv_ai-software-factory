"""Exercise the same installed graph across four independent project profiles."""

import hashlib
import json
import subprocess
import sys
import unittest
from copy import deepcopy
from pathlib import Path
from typing import Any

import yaml

from factory.runtime import graph_inputs
from factory.runtime.workflow_core import Invalid
from tests import CLI
from tests.factory.runtime.workflow_fixture import WorkflowFixture


class ProjectRouteTests(unittest.TestCase):
    def test_project_and_consumer_receipts_on_one_graph(self) -> None:
        surfaces = {"mobile": "mobile/view.dart", "web": "web/app.ts", "backend": "api/service.py"}
        api, guide = "shared/contract.txt", "shared/guide.md"
        signatures = set()
        for profile, change in [*[(k, k) for k in surfaces], ("mixed", "web"), ("mixed", "api")]:
            with self.subTest(profile=profile, change=change):
                f = WorkflowFixture(self.addCleanup)
                chosen = list(surfaces) if profile == "mixed" else [profile]
                checks = []
                for key in chosen:
                    file = surfaces[key]
                    for name in (file, api, guide):
                        path = f.root / name
                        path.parent.mkdir(exist_ok=True)
                        path.write_text("stable")
                    inputs = [file, api]
                    checks.append(
                        {
                            "id": key,
                            "level": "slice",
                            "kind": "static",
                            "method": f"Inspect {key} contract",
                            "for": {"paths_any": [file, api]},
                            "execution": {
                                "argv": [
                                    sys.executable,
                                    "-c",
                                    "from pathlib import Path; import sys; assert all(Path(p).read_text() in ('stable','changed') for p in sys.argv[1:]); print('contract checked')",
                                    *inputs,
                                ],
                                "inputs": inputs,
                                "cwd": ".",
                                "timeout_seconds": 10,
                            },
                        }
                    )
                (f.root / "profile.md").write_text(f"{profile} project verification instructions")
                f.fixture_policy = yaml.safe_dump(
                    {
                        "id": profile,
                        "public_contracts": {api: [guide]},
                        "documents": {"profile-guide": {"path": "profile.md"}},
                        "rules": {"worker": [{"id": "read-guide", "documents": ["profile-guide"]}]},
                        "gates": [
                            {"id": "consumer-checks", "at": ["implement.verify"], "checks": checks}
                        ],
                    }
                )
                config = f.config_file(lambda c: c["execution"].update(workspace="shared"))
                g = deepcopy(f.g)
                g.update(nodes=[], agents={})
                scope = [api, guide] if change == "api" else [surfaces[change]]
                task = g["tasks"]["label"]
                task.update(write_scope=scope, scope=scope, project_check_inputs={})
                plan = graph_inputs.propose(f.root, graph_inputs.PROPOSAL.validate_python(g))

                def call(
                    group: str, *args: str, f: WorkflowFixture = f, config: Path = config
                ) -> Any:
                    result = subprocess.run(
                        [
                            *CLI,
                            group,
                            "--workspace",
                            str(f.root),
                            "--config",
                            str(config),
                            *args,
                            "--json",
                        ],
                        capture_output=True,
                        text=True,
                    )
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    return json.loads(result.stdout)["result"]

                call("workflow", "init", plan)
                definitions = f.ledger.read()["definitions"]
                signatures.add(
                    tuple(
                        (key, hashlib.sha256(raw.encode()).hexdigest())
                        for key, raw in sorted(definitions.items())
                    )
                )
                f.start("work-label")
                for name in scope:
                    (f.root / name).write_text("changed")
                offer = (
                    {"code": [scope[0]], "tests": ["behavior"], "docs": [guide]}
                    if change == "api"
                    else {
                        "code": scope,
                        "tests": ["behavior"],
                        "docs_current": "Local client detail",
                    }
                )
                f.ledger.finish("work-label", f.report("work-label", write_result=offer))
                f.start("verify-label")
                packet = f.ledger.packet("verify-label")
                self.assertIn(
                    f"{profile} project verification instructions",
                    [doc["content"] for doc in packet["instructions"]],
                )
                state = f.ledger.read()
                ticket = state["nodes"]["verify-label"]["dispatch_id"]
                expected = set(chosen) if change == "api" else {change}
                ids = set(call("workflow", "status")["verification"]["verify-label"]["checks"])
                self.assertEqual({"behavior", *expected}, ids)
                results = [
                    call(
                        "checks",
                        "run",
                        "verify-label",
                        key,
                        "--request",
                        "verify-" + key,
                        "--dispatch",
                        ticket,
                    )
                    for key in sorted(ids)
                ]
                records = f.ledger.read()["executions"]
                for row in results:
                    self.assertEqual("PASS", row["result"])
                    if row["id"] in surfaces:
                        self.assertTrue(
                            set((api, surfaces[row["id"]]))
                            <= set(records[row["execution_id"]]["files"])
                        )
                if change == "api":
                    with self.assertRaises(Invalid):
                        f.ledger.finish(
                            "verify-label", f.report("verify-label", checks=results[:-1])
                        )
                    self.assertEqual("running", f.ledger.read()["nodes"]["verify-label"]["status"])
                f.ledger.finish("verify-label", f.report("verify-label", checks=results))
                if change == "api":
                    f.start("review-label")
                    f.ledger.finish(
                        "review-label", f.report("review-label", verdict="APPROVE", findings=[])
                    )
                call("workflow", "accept", "accept-label")
        self.assertEqual(1, len(signatures))
