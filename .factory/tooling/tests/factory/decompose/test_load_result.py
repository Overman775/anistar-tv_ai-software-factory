"""Task loading exposes diagnostics alongside usable tasks in one result."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from factory.decompose.task_data import load_tasks


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
