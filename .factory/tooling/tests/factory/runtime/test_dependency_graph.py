"""Regressions for checkpoint-driven execution with overlapping Pydantic forks."""

import asyncio
import unittest
from graphlib import CycleError

from pydantic_graph.join import Join

from factory.dependency_graph import DependencyGraph, compile_dependencies
from factory.runtime.scheduling.attempt_graph import advance
from factory.runtime.workflow_core import Invalid


class DependencyGraphTests(unittest.TestCase):
    def test_single_ancestor_query_only_reads_its_predecessors(self) -> None:
        dependencies = {"root": [], "near": ["root"], "unrelated": ["root"]}
        compiled = compile_dependencies(dependencies)
        reads: list[str] = []

        class TrackedParents(dict[str, tuple[str, ...]]):
            def __getitem__(self, key: str) -> tuple[str, ...]:
                reads.append(key)
                return super().__getitem__(key)

        graph = DependencyGraph(compiled.program, TrackedParents(compiled.parents))
        self.assertEqual(graph.ancestors("near"), {"root"})
        self.assertEqual(reads, ["near", "root"])

    def test_nested_branches_pin_the_first_fork_after_the_common_prefix(self) -> None:
        spec: dict[str, list[str]] = {"root": [], "prefix": ["root"], "spine0": ["prefix"]}
        for i in range(200):
            spec[f"spine{i + 1}"] = [f"spine{i}"]
            spec[f"leaf{i}"] = [f"spine{i}"]
        visits: list[str] = []
        for roots in (spec, {**spec, "other": []}):
            visits.clear()
            graph = compile_dependencies(dict(reversed(roots.items())))
            join = next(node for node in graph.program.nodes.values() if isinstance(node, Join))
            self.assertEqual(join.parent_fork_id, "outer_fork")
            graph.run(lambda key, _: visits.append(key))
            self.assertCountEqual(visits, roots)

    def test_display_aliases_preserve_arbitrary_business_keys(self) -> None:
        key = 'orders/list "core"-01'
        graph = compile_dependencies({key: [], "second": [], "joined": ["second", key]})
        self.assertEqual(graph.ready(frozenset({key, "second"})), {"joined"})
        rendered = graph.program.render()
        self.assertIn("node_0", rendered)
        self.assertNotIn(key, rendered)
        self.assertIn("also waits for orders#47;list #34;core#34;-01", rendered)

    def test_crossing_forks_wait_for_all_parents_and_visit_once(self) -> None:
        dependencies = {"a": [], "b": [], "c": ["b"], "d": ["a", "b"], "e": ["a", "d"]}
        graph = compile_dependencies(dependencies)
        visits: list[str] = []

        def check(key: str, parents: frozenset[str]) -> None:
            self.assertEqual(parents, set(dependencies[key]))
            self.assertTrue(parents <= set(visits))
            visits.append(key)

        graph.run(check)
        self.assertCountEqual(visits, dependencies)
        self.assertEqual(graph.ready(frozenset({"b"})), {"a", "c"})
        self.assertEqual(graph.ancestors("e"), {"a", "b", "d"})
        self.assertEqual(graph.affected_by({"b"}), {"b", "c", "d", "e"})
        self.assertEqual(graph.affected_by({"a", "c"}), {"a", "c", "d", "e"})
        self.assertEqual(graph.layers, (("a", "b"), ("c", "d"), ("e",)))
        self.assertIn("also waits for d", graph.program.render())

    def test_revised_topology_and_retry_recompute_eligibility(self) -> None:
        spec = {"write": [], "verify": ["write"]}
        old = compile_dependencies(spec)
        completed = frozenset({"write"})
        self.assertEqual(old.ready(completed), {"verify"})
        spec["diagnose"] = []
        spec["verify"].append("diagnose")
        new = compile_dependencies(spec)
        self.assertEqual(new.ready(completed), {"diagnose"})
        self.assertEqual(new.ready(frozenset()), {"write", "diagnose"})
        self.assertEqual(old.ready(completed), {"verify"})
        with self.assertRaises(CycleError):
            compile_dependencies({"write": ["verify"], "verify": ["write"]})

    def test_failure_does_not_release_downstream_or_poison_next_run(self) -> None:
        graph = compile_dependencies({"a": [], "b": [], "join": ["a", "b"]})
        visits: list[str] = []

        def fail(key: str, parents: frozenset[str]) -> None:
            visits.append(key)
            if key == "a":
                raise ValueError("failed")

        with self.assertRaisesRegex(ValueError, "failed"):
            graph.run(fail)
        self.assertNotIn("join", visits)
        visits.clear()
        graph.run(lambda key, parents: visits.append(key))
        self.assertCountEqual(visits, ("a", "b", "join"))

    def test_unknown_work_requires_reconciliation_before_claim(self) -> None:
        with self.assertRaisesRegex(Invalid, "Cannot claim"):
            advance({"status": "unknown", "attempt": 1}, "claim")
        self.assertEqual(advance({"status": "unknown", "attempt": 1}, "recover_running"), "running")


class AsyncCallerTests(unittest.IsolatedAsyncioTestCase):
    async def test_sync_ledger_graph_from_existing_loop(self) -> None:
        loop = asyncio.get_running_loop()
        graph = compile_dependencies({"first": [], "second": ["first"]})
        self.assertEqual(graph.ready(frozenset({"first"})), {"second"})
        self.assertEqual(advance({"status": "reserved", "attempt": 1}, "bind"), "running")
        self.assertIs(asyncio.get_running_loop(), loop)
