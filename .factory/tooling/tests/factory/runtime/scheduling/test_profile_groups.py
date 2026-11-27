"""Grouped YAML is one input format; runtime profiles remain independent and flat."""

from __future__ import annotations

import unittest
from collections.abc import Callable
from copy import deepcopy
from typing import Any

import yaml

from factory.runtime.workflow_config import expand_profiles, load_config
from factory.runtime.workflow_core import Invalid
from tests.factory.runtime import workflow_fixture

ROOT = workflow_fixture.ROOT


class ProfileGroupTests(unittest.TestCase):
    def setUp(self) -> None:
        self.raw = yaml.safe_load((ROOT / "factory.yaml").read_text())

    def test_expansion_preserves_variants_and_copies_mutable_policy(self) -> None:
        original = deepcopy(self.raw["agent_workers"])
        profiles, defaults = expand_profiles(original)
        self.assertEqual(original, self.raw["agent_workers"])
        self.assertEqual("middle-implementer", defaults["roles/implementer.md"])
        self.assertEqual("terra", profiles["middle-implementer"]["model"])
        self.assertEqual("luna", profiles["junior-implementer"]["model"])
        self.assertEqual("zcode", profiles["middle-implementer-zcode"]["adapter"])
        profiles["middle-implementer"]["capabilities"]["edit"] = False
        profiles["middle-implementer"]["mcp"].clear()
        policy = profiles["middle-implementer"]["escalation"]
        assert policy is not None
        policy["to"] = "human"
        self.assertTrue(profiles["junior-implementer"]["capabilities"]["edit"])
        self.assertTrue(profiles["junior-implementer"]["mcp"])
        self.assertEqual(original, self.raw["agent_workers"])

    def test_omitted_paths_preserve_profiles_and_defaults(self) -> None:
        original = deepcopy(self.raw["agent_workers"])
        expected = expand_profiles(original)
        for omitted in (("role", "contract"), ("role",), ("contract",)):
            groups = deepcopy(original)
            for group in groups.values():
                for field in omitted:
                    group.pop(field, None)
            with self.subTest(omitted=omitted):
                self.assertEqual(expected, expand_profiles(groups))

    def test_single_variant_uses_existing_default_resolution(self) -> None:
        config = load_config(ROOT / "factory.yaml")
        self.assertEqual("reviewer", config["_defaults"]["reviewer"])
        self.assertEqual("middle-implementer", config["_defaults"]["implementer"])
        groups = deepcopy(self.raw["agent_workers"])
        groups["reviewer"]["default"] = "reviewer"
        self.assertEqual("reviewer", expand_profiles(groups)[1]["roles/reviewer.md"])

    def test_group_boundaries_reject_overrides_duplicates_and_bad_defaults(self) -> None:
        changes: list[Callable[[Any], object]] = [
            lambda g: g["implementer"].pop("default"),
            lambda g: g["implementer"].update(default="reviewer"),
            lambda g: g["implementer"].update(default=[]),
            lambda g: g["implementer"].update(variants={}),
            lambda g: g["implementer"].update(role=None),
            lambda g: g["implementer"].update(contract=None),
            lambda g: g["implementer"].update(role="roles/reviewer.md"),
            lambda g: g["implementer"].update(contract="contracts/reviewer.md"),
            lambda g: g["implementer"]["variants"]["middle-implementer"].update(
                capabilities={"edit": False}
            ),
            lambda g: g["implementer"]["variants"]["middle-implementer"].update(mcp=[]),
            lambda g: g["implementer"]["variants"]["middle-implementer"].update(
                enforcement="required"
            ),
            lambda g: g["implementer"]["variants"]["middle-implementer"].update(model=[]),
            lambda g: g["reviewer"].update(
                variants={"middle-implementer": {"model": "sol", "adapter": "codex"}}
            ),
        ]
        for change in changes:
            groups = deepcopy(self.raw["agent_workers"])
            change(groups)
            with self.subTest(change=change), self.assertRaises(Invalid):
                expand_profiles(groups)
        flat, _ = expand_profiles(self.raw["agent_workers"])
        with self.assertRaises(Invalid):
            expand_profiles(flat)

    def test_unknown_fields_rejected_before_runtime_use(self) -> None:
        fixture = workflow_fixture.WorkflowFixture(self.addCleanup)
        path = fixture.config_file(lambda c: None)
        original = yaml.safe_load(path.read_text())
        changes: list[Callable[[Any], object]] = [
            lambda c: c.update(routing={"defaults": {}}),
            lambda c: c.update(profiles={}),
            lambda c: c.update(profiles=c.pop("agent_workers")),
            lambda c: c["agent_workers"]["implementer"].update(defualt="middle-implementer"),
            lambda c: c["agent_workers"]["implementer"]["variants"]["middle-implementer"].update(
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
