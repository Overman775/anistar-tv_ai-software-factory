"""Task loading exposes diagnostics alongside usable tasks in one result."""

from __future__ import annotations

import shutil
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from factory.decompose.graph.task_data import load_tasks
from factory.decompose.staging.metadata import envelope_paths
from tests.factory.decompose.fixture_task_graph import TaskGraphFixture


class LoadResultTests(unittest.TestCase):
    def test_empty_or_malformed_inputs_keep_fixed_result_and_diagnostics(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual([], envelope_paths(Path(tmp)))
            for content in (None, "{broken json", "[]"):
                with self.subTest(content=content):
                    if content is not None:
                        (Path(tmp) / "task_result.json").write_text(content)
                    loaded = load_tasks(tmp)
                    self.assertEqual({"tasks", "envelopes", "errors"}, set(loaded))
                    self.assertEqual({}, loaded["tasks"])
                    self.assertEqual([], loaded["envelopes"])
                    self.assertTrue(loaded["errors"])

    def test_literal_directory_matches_normal_and_excludes_neighbor(self) -> None:
        fixture = TaskGraphFixture(self.addCleanup)
        fixture.write_tasks([fixture.task()])
        literal = fixture.root / "tasks [draft]"
        shutil.copytree(fixture.tasks_dir, literal)
        neighbor = fixture.root / "tasks d"
        shutil.copytree(fixture.tasks_dir, neighbor)
        (neighbor / "generated" / "task_result.json").write_text("{}", encoding="utf-8")

        normal = load_tasks(fixture.tasks_dir)
        bracketed = load_tasks(literal)
        self.assertEqual([], normal["errors"])
        self.assertEqual([], bracketed["errors"])
        self.assertEqual(set(normal["tasks"]), set(bracketed["tasks"]))
        for task_id, task in normal["tasks"].items():
            other = bracketed["tasks"][task_id]
            normal_data = dict(task)
            literal_data = dict(other)
            for key in ("file", "markdown_file"):
                normal_data.pop(key)
                literal_data.pop(key)
            self.assertEqual(normal_data, literal_data)
        self.assertEqual(
            [path.relative_to(fixture.tasks_dir) for path in envelope_paths(fixture.tasks_dir)],
            [path.relative_to(literal) for path in envelope_paths(literal)],
        )
        self.assertEqual(
            [Path("generated/task_result.json")],
            [path.relative_to(literal) for path in envelope_paths(literal)],
        )

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
            "factory.decompose.graph.task_data.find_markdown_file",
            side_effect=RuntimeError("unexpected resolver failure"),
        ):
            with self.assertRaisesRegex(RuntimeError, "unexpected resolver failure"):
                load_tasks(fixture.tasks_dir)
