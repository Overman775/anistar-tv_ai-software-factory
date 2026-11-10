"""Metadata projection must retain author prose and expose input mistakes."""

import unittest

from factory_tooling.decompose.contracts import LoadedTask
from factory_tooling.decompose.metadata import markdown_path, render_metadata


class MetadataTests(unittest.TestCase):
    def test_windows_separator_is_converted_for_markdown(self) -> None:
        self.assertEqual("../../../plans/plan.md", markdown_path(r"..\..\..\plans\plan.md", "\\"))

    def test_renders_structured_fields_without_rewriting_prose(self) -> None:
        labels = (
            "ID",
            "Plan source",
            "Covers capabilities",
            "Acceptance criteria",
            "Contribution to plan criteria",
            "Purpose",
            "Scope",
            "Estimate",
            "Parent task",
            "Depends on",
            "Blocked by",
        )
        header = "# Author title\n\n" + "".join(f"- **{label}:** old\n" for label in labels)
        prose = "\n## 1. Context\n\nAuthor's exact text.\n- **Scope:** leave this prose.\n"
        task: LoadedTask = {
            "id": "orders-01",
            "purpose": "functionality",
            "scope": "orders",
            "estimate": "2–3 h",
            "acceptance_ids": ["AC-01"],
            "depends_on": ["setup-01"],
            "blocked_by": [],
        }
        result = render_metadata(
            header + prose,
            task,
            {"plan_id": "orders", "revision": 2},
            ["CAP-01"],
            "docs/plans/orders.md",
        )
        self.assertIn("- **ID:** orders-01\n", result)
        self.assertIn("- **Estimate:** 2–3 h\n", result)
        self.assertIn("- **Covers capabilities:** CAP-01\n", result)
        self.assertTrue(result.endswith(prose))
        with self.assertRaisesRegex(ValueError, "header field"):
            render_metadata(
                header.replace("- **ID:** old\n", "") + prose,
                task,
                {"plan_id": "orders", "revision": 2},
                [],
                "plan.md",
            )
