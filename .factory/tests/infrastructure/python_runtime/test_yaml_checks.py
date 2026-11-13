"""YAML checks reject malformed policy without running its configured commands."""

from __future__ import annotations

import contextlib
import io
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import yaml

from factory_tooling import yaml_checks

GATE = """gates:
  - id: fixture-review
    at: [implement.review]
    criteria:
      - id: CUSTOM-1
        lens: system-design
        question: Is the fixture correct?
"""


class YamlTests(unittest.TestCase):
    def setUp(self) -> None:
        directory = tempfile.TemporaryDirectory(prefix="factory YAML ")
        self.addCleanup(directory.cleanup)
        self.agents = Path(directory.name).resolve() / ".factory"
        self.project = self.agents / "project"
        self.project.mkdir(parents=True)
        self.profile = self.project / "project.yaml"
        self.profile.write_text("id: fixture\n", encoding="utf-8")

    def check(self) -> tuple[int, str]:
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = yaml_checks.check(self.agents)
        return code, output.getvalue()

    def test_duplicate_keys_and_unknown_fields_fail(self) -> None:
        for data, message in (
            ("id: fixture\nid: duplicate\n", "duplicate"),
            ("id: fixture\nrulse: {}\n", "Extra inputs are not permitted"),
            ("id: [", "invalid YAML"),
        ):
            with self.subTest(data=data):
                self.profile.write_text(data, encoding="utf-8")
                code, output = self.check()
                self.assertNotEqual(0, code)
                self.assertIn(message, output)

    def test_missing_definition_and_orphan_definition_fail(self) -> None:
        self.profile.write_text("id: fixture\ngate_files: [gates/review.yaml]\n")
        self.assertNotEqual(0, self.check()[0])
        self.profile.write_text("id: fixture\n")
        gate = self.project / "gates/review.yaml"
        gate.parent.mkdir()
        gate.write_text(GATE, encoding="utf-8")
        code, output = self.check()
        self.assertNotEqual(0, code)
        self.assertIn("owning project profile", output)

    def test_composed_gate_contract_checks_values_and_preserves_source(self) -> None:
        gate = self.project / "gates/review.yaml"
        gate.parent.mkdir()
        gate.write_text(GATE, encoding="utf-8")
        self.profile.write_text("id: fixture\ngate_files: [gates/review.yaml]\n")
        before = {file: file.read_bytes() for file in self.agents.rglob("*") if file.is_file()}
        with (
            patch("subprocess.Popen", side_effect=AssertionError("No project command")),
            patch("socket.create_connection", side_effect=AssertionError("No network")),
        ):
            self.assertEqual(0, self.check()[0])
        self.assertEqual(
            before, {file: file.read_bytes() for file in self.agents.rglob("*") if file.is_file()}
        )
        gate.write_text(GATE.replace("system-design", "invented-lens"), encoding="utf-8")
        code, output = self.check()
        self.assertNotEqual(0, code)
        self.assertIn(".lens: Input should be", output)

    def test_configured_commands_are_validated_without_execution(self) -> None:
        data = {
            "id": "fixture",
            "gates": [
                {
                    "id": "fixture-work",
                    "at": ["implement.work"],
                    "checks": [
                        {
                            "id": "fixture-command",
                            "level": "slice",
                            "kind": "static",
                            "method": "Validate only",
                            "execution": {
                                "argv": ["must-not-execute", "--flag"],
                                "cwd": ".",
                                "timeout_seconds": 1,
                            },
                        }
                    ],
                }
            ],
        }
        self.profile.write_text(yaml.safe_dump(data), encoding="utf-8")
        with patch("subprocess.Popen", side_effect=AssertionError("No configured command")):
            self.assertEqual(0, self.check()[0])

    def test_hidden_yml_discovery_includes_owned_and_excludes_vendor(self) -> None:
        owned = self.agents / "skills/factory-fixture/agents/openai.yml"
        vendor = self.agents / "skills/vendor/agents/openai.yaml"
        for file in (owned, vendor):
            file.parent.mkdir(parents=True)
            file.write_text("interface: {}\n")
        self.assertIn(owned, yaml_checks.source_files(self.agents))
        self.assertNotIn(vendor, yaml_checks.source_files(self.agents))

    def test_empty_discovery_is_a_failure(self) -> None:
        self.profile.unlink()
        self.assertNotEqual(0, self.check()[0])

    def test_rule_provenance_does_not_count_as_definition_validation(self) -> None:
        gate = self.project / "gate.yaml"
        gate.write_text("gates: definitely-not-a-list\n", encoding="utf-8")
        self.profile.write_text(
            "id: fixture\nrules:\n  worker:\n    - id: opaque\n      file: gate.yaml\n",
            encoding="utf-8",
        )
        code, output = self.check()
        self.assertNotEqual(0, code)
        self.assertIn("owning project profile", output)

    def test_directory_symlink_cannot_hide_owned_yaml(self) -> None:
        external = self.agents.parent / "external"
        external.mkdir()
        (external / "invalid.yaml").write_text("gates: [", encoding="utf-8")
        (self.project / "gates").symlink_to(external, target_is_directory=True)
        code, output = self.check()
        self.assertNotEqual(0, code)
        self.assertIn("symlink", output)

    def test_harness_exemption_is_limited_to_owned_skill_metadata(self) -> None:
        disguised = self.project / "agents/openai.yaml"
        disguised.parent.mkdir()
        disguised.write_text("gates: not-a-list\n", encoding="utf-8")
        code, output = self.check()
        self.assertNotEqual(0, code)
        self.assertNotIn("harness metadata", output)
        disguised.unlink()
        metadata = self.agents / "skills/factory-fixture/agents/openai.yml"
        metadata.parent.mkdir(parents=True)
        metadata.write_text("interface: {}\n", encoding="utf-8")
        code, output = self.check()
        self.assertEqual(0, code)
        self.assertIn("harness metadata", output)

    def test_fixture_overlay_cannot_write_through_a_runtime_symlink(self) -> None:
        for name in (
            "roles",
            "contracts",
            "gates",
            "workflow",
            "adapters",
            "tools",
            "factory_tooling",
        ):
            (self.agents / name).mkdir(exist_ok=True)
        for name in ("planning", "implement", "decompose", "code-review"):
            (self.agents / "skills" / f"factory-{name}").mkdir(parents=True)
        external = self.agents.parent / "sentinel.py"
        external.write_text("original sentinel\n", encoding="utf-8")
        (self.agents / "gates/helper.py").symlink_to(external)
        fixtures = self.agents / "tests/data"
        (fixtures / "project").mkdir(parents=True)
        (fixtures / "project/project.yaml").write_text("id: fixture\n", encoding="utf-8")
        (fixtures / "gates").mkdir()
        (fixtures / "gates/helper.py").write_text("replacement\n", encoding="utf-8")
        code, output = self.check()
        self.assertEqual("original sentinel\n", external.read_text())
        self.assertNotEqual(0, code)
        self.assertIn("symlink", output)
