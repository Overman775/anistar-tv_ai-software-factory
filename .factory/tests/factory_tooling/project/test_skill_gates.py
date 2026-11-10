from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from factory_tooling.project.contracts import Policy
from factory_tooling.project.profile_io import load_profile, snapshot, validate_snapshot
from factory_tooling.project.profile_rules import required_checks
from factory_tooling.project.skill_gates import run_decomposition_gates


class SkillGatesTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.staging = self.root / "tasks"
        self.staging.mkdir()
        (self.staging / "task.json").write_text("{}")
        self.lock = self.root / "source.json"
        self.lock.write_text("{}")
        self.script = self.root / "check.py"
        self.script.write_text(
            'import json,sys\nassert json.load(sys.stdin)["tasks"]\nprint(json.dumps({"status":"PASS","message":"ok","evidence":["stdin"]}))\n'
        )
        self.manifest = self.root / "project.yaml"
        self.manifest.write_text("""id: example
gates:
- id: tasks-ready
  at: [decompose.complete]
  checks:
  - id: custom
    kind: static
    level: slice
    method: Check project tasks.
    execution:
      argv: ['{python}', check.py]
      cwd: .
      timeout_seconds: 1
      inputs: [check.py]
""")

    def run_gate(self, policy: Policy | None = None) -> list[str]:
        return run_decomposition_gates(
            policy or load_profile(self.manifest),
            {"t": {}},
            [],
            self.staging,
            self.lock,
            self.root / "output",
        )

    def test_success_and_no_implement_leak(self) -> None:
        policy = load_profile(self.manifest)
        self.assertEqual([], required_checks(policy["data"], {"scope": ["app.py"]}))
        self.assertEqual([], self.run_gate(policy))
        receipt = json.loads((self.root / "output/decomposition-gates.json").read_text())
        self.assertEqual("PASS", receipt["status"])
        self.assertTrue(receipt["artifact_hash"])
        self.assertIn("ok", receipt["results"][0]["stdout"])

    def test_failed_check_replaces_prior_success(self) -> None:
        self.run_gate()
        self.script.write_text(
            'import json\nprint(json.dumps({"status":"FAIL","message":"invalid task","evidence":["stdin"]}))\nraise SystemExit(1)'
        )
        self.assertTrue(self.run_gate())
        receipt = json.loads((self.root / "output/decomposition-gates.json").read_text())
        self.assertEqual("FAIL", receipt["status"])

    def test_script_drift_and_snapshot_missing_dependency(self) -> None:
        policy = load_profile(self.manifest)
        pinned = snapshot(policy, source="test")
        validate_snapshot(pinned)
        self.script.write_text("raise SystemExit(0)")
        self.assertTrue(self.run_gate(policy))
        from factory_tooling.project.profile_io import fingerprint

        del pinned["files"]["check.py"]
        del pinned["contents"]["check.py"]
        pinned["sha256"] = fingerprint({k: v for k, v in pinned.items() if k != "sha256"})
        with self.assertRaisesRegex(ValueError, "missing pinned"):
            validate_snapshot(pinned)

    def test_timeout_and_artifact_mutation(self) -> None:
        self.script.write_text("import time\ntime.sleep(3)")
        self.assertTrue(self.run_gate())
        self.script.write_text(
            'from pathlib import Path\nPath("tasks/task.json").write_text("changed")'
        )
        self.assertTrue(self.run_gate())

    def test_nested_profile_uses_project_root_and_pins_script(self) -> None:
        folder = self.root / ".factory/custom/policy"
        folder.mkdir(parents=True)
        script = folder / "check.py"
        self.script.rename(script)
        script.write_text(
            'from pathlib import Path\nassert Path("tasks/task.json").is_file()\nprint(__import__("json").dumps({"status":"PASS","message":"root cwd","evidence":["tasks/task.json"]}))'
        )
        relative = ".factory/custom/policy/check.py"
        profile = folder / "project.yaml"
        profile.write_text(self.manifest.read_text().replace("check.py", relative))
        policy = load_profile(profile)
        self.assertEqual(str(self.root.resolve()), policy["workspace"])
        self.assertEqual([], self.run_gate(policy))
        pinned = snapshot(policy, source="test")
        self.assertEqual(".factory/custom/policy", pinned["profile_root"])
        validate_snapshot(pinned)
        script.write_text("raise SystemExit(0)")
        self.assertTrue(self.run_gate(policy))

    def test_crash_is_blocked_not_violation(self) -> None:
        self.script.write_text('raise RuntimeError("broken validator")')
        self.assertTrue(self.run_gate())
        receipt = json.loads((self.root / "output/decomposition-gates.json").read_text())
        self.assertEqual("BLOCKED", receipt["status"])

    def test_independent_failure_and_blocker_are_both_preserved(self) -> None:
        import yaml

        self.script.write_text(
            'import json\nprint(json.dumps({"status":"FAIL","message":"violation","evidence":["stdin"]}))\nraise SystemExit(1)'
        )
        (self.root / "broken.py").write_text('raise RuntimeError("crash")')
        data = yaml.safe_load(self.manifest.read_text())
        original = data["gates"][0]["checks"][0]
        second = json.loads(json.dumps(original))
        second["id"] = "second"
        second["execution"]["argv"][1] = "broken.py"
        second["execution"]["inputs"] = ["broken.py"]
        data["gates"][0]["checks"].append(second)
        self.manifest.write_text(yaml.safe_dump(data))
        self.assertTrue(self.run_gate())
        receipt = json.loads((self.root / "output/decomposition-gates.json").read_text())
        self.assertEqual("FAIL", receipt["status"])
        self.assertEqual(["FAIL", "BLOCKED"], [c["status"] for c in receipt["gates"][0]["checks"]])

    def test_no_project_gate(self) -> None:
        self.manifest.write_text("id: example\n")
        self.assertEqual([], self.run_gate())

    def test_mixed_boundaries_and_unpinned_script_rejected(self) -> None:
        text = self.manifest.read_text()
        for invalid in (
            text.replace("[decompose.complete]", "[decompose.complete, implement.work]"),
            text.replace("inputs: [check.py]", "inputs: []"),
        ):
            self.manifest.write_text(invalid)
            with self.assertRaises(ValueError):
                load_profile(self.manifest)
