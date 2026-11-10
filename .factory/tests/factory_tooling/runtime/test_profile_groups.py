"""Grouped YAML is one input format; runtime profiles remain independent and flat."""

from __future__ import annotations

import unittest
from collections.abc import Callable
from copy import deepcopy
from typing import Any

import yaml

from factory_tooling.runtime.workflow_config import expand_profiles, load_config
from factory_tooling.runtime.workflow_core import Invalid
from tests.factory_tooling.runtime import test_workflow

ROOT = test_workflow.ROOT


class ProfileGroupTests(unittest.TestCase):
    def setUp(self) -> None:
        self.raw = yaml.safe_load((ROOT / "factory.yaml").read_text())

    def test_expansion_preserves_variants_and_copies_mutable_policy(self) -> None:
        original = deepcopy(self.raw["profiles"])
        profiles, defaults = expand_profiles(original)
        self.assertEqual(original, self.raw["profiles"])
        self.assertEqual("middle-developer", defaults["roles/developer.md"])
        self.assertEqual("terra", profiles["middle-developer"]["model"])
        self.assertEqual("luna", profiles["junior-developer"]["model"])
        self.assertEqual("zcode", profiles["middle-test-writer-zcode"]["adapter"])
        profiles["middle-developer"]["capabilities"]["edit"] = False
        profiles["middle-developer"]["mcp"].clear()
        policy = profiles["middle-developer"]["escalation"]
        assert policy is not None
        policy["to"] = "human"
        self.assertTrue(profiles["junior-developer"]["capabilities"]["edit"])
        self.assertTrue(profiles["junior-developer"]["mcp"])
        self.assertEqual(original, self.raw["profiles"])

    def test_single_variant_uses_existing_default_resolution(self) -> None:
        config = load_config(ROOT / "factory.yaml")
        self.assertEqual("reviewer", config["_defaults"]["reviewer"])
        self.assertEqual("middle-developer", config["_defaults"]["developer"])
        groups = deepcopy(self.raw["profiles"])
        groups["reviewer"]["default"] = "reviewer"
        self.assertEqual("reviewer", expand_profiles(groups)[1]["roles/reviewer.md"])

    def test_group_boundaries_reject_overrides_duplicates_and_bad_defaults(self) -> None:
        changes: list[Callable[[Any], object]] = [
            lambda g: g["developer"].pop("default"),
            lambda g: g["developer"].update(default="reviewer"),
            lambda g: g["developer"].update(default=[]),
            lambda g: g["developer"].update(variants={}),
            lambda g: g["developer"].update(role="roles/reviewer.md"),
            lambda g: g["developer"].update(contract="contracts/reviewer.md"),
            lambda g: g["developer"]["variants"]["middle-developer"].update(
                capabilities={"edit": False}
            ),
            lambda g: g["developer"]["variants"]["middle-developer"].update(mcp=[]),
            lambda g: g["developer"]["variants"]["middle-developer"].update(enforcement="required"),
            lambda g: g["developer"]["variants"]["middle-developer"].update(model=[]),
            lambda g: g["reviewer"].update(
                variants={"middle-developer": {"model": "sol", "adapter": "codex"}}
            ),
        ]
        for change in changes:
            groups = deepcopy(self.raw["profiles"])
            change(groups)
            with self.subTest(change=change), self.assertRaises(Invalid):
                expand_profiles(groups)
        flat, _ = expand_profiles(self.raw["profiles"])
        with self.assertRaises(Invalid):
            expand_profiles(flat)

    def test_unknown_fields_rejected_before_runtime_use(self) -> None:
        fixture = test_workflow.WorkflowTests()
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        path = fixture.config_file(lambda c: None)
        original = yaml.safe_load(path.read_text())
        changes: list[Callable[[Any], object]] = [
            lambda c: c.update(routing={"defaults": {}}),
            lambda c: c.update(profliles={}),
            lambda c: c["profiles"]["developer"].update(defualt="middle-developer"),
            lambda c: c["profiles"]["developer"]["variants"]["middle-developer"].update(
                effort="high"
            ),
            lambda c: c["models"]["terra"].update(efort="high"),
            lambda c: c["adapters"]["codex"].update(runerr="native"),
            lambda c: c["native"].update(max_parallel=99),
            lambda c: c["execution"].update(retries=99),
            lambda c: c["acpx"].update(connections_extra={}),
        ]
        for change in changes:
            data = deepcopy(original)
            change(data)
            path.write_text(yaml.safe_dump(data))
            with self.subTest(change=change), self.assertRaises(Invalid):
                load_config(path)


if __name__ == "__main__":
    unittest.main()
