"""Task loading exposes diagnostics alongside usable tasks in one result."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from factory.decompose.task_data import load_tasks
from tests.factory.decompose.fixture_task_graph import TaskGraphFixture


class LoadResultTests(unittest.TestCase):
    def test_empty_or_malformed_inputs_keep_fixed_result_and_diagnostics(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            for content in (None, "{broken json", "[]"):
                with self.subTest(content=content):
                    if content is not None:
                        (Path(tmp) / "task_result.json").write_text(content)
                    loaded = load_tasks(tmp)
                    self.assertEqual({"tasks", "envelopes", "errors"}, set(loaded))
                    self.assertEqual({}, loaded["tasks"])
                    self.assertEqual([], loaded["envelopes"])
                    self.assertTrue(loaded["errors"])

    def test_invalid_encoding_reports_read_failure(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "task_result.json").write_bytes(b"\xff")
            loaded = load_tasks(tmp)
            self.assertEqual({}, loaded["tasks"])
            self.assertEqual([], loaded["envelopes"])
            self.assertTrue(
                any(
                    "task_result.json" in error and "failed to read task JSON" in error
                    for error in loaded["errors"]
                )
            )

    def test_unexpected_resolver_failure_propagates(self) -> None:
        fixture = TaskGraphFixture(self.addCleanup)
        fixture.write_tasks([fixture.task()])
        with patch(
            "factory.decompose.task_data.find_markdown_file",
            side_effect=RuntimeError("unexpected resolver failure"),
        ):
            with self.assertRaisesRegex(RuntimeError, "unexpected resolver failure"):
                load_tasks(fixture.tasks_dir)
