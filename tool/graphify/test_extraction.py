"""Regression tests for the graphify 0.9.85 producer fixes (not graph filters)."""
import tempfile
import unittest
from pathlib import Path

from graphify.extract import extract, extract_dart, extract_kotlin


class ExtractionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cache = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.cache.cleanup)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.addCleanup(self.temp.cleanup)

    def file(self, name, text):
        path = self.root / name
        path.write_text(text, encoding="utf-8")
        return path

    def test_html_literal_is_not_code(self):
        path = self.file("fixture.dart", '''const html = """
<input name="sort">
<div class="card">
class Bogus extends Imaginary {}
import 'bogus.dart';
ref.watch(bogusProvider);
""";
RealType value;
''')
        result = extract_dart(path)
        labels = {n["label"] for n in result["nodes"]}
        self.assertTrue({"html", "value", "RealType"} <= labels)
        self.assertFalse({"", "name", "Bogus", "Imaginary", "bogus.dart", "bogusProvider"} & labels)
        self.assertTrue(all(e["source"] and e["target"] for e in result["edges"]))
        edge = next(e for e in result["edges"] if e.get("context") == "variable_type")
        self.assertEqual(edge["source_location"], "L8")

    def test_imports_routes_comments_and_line_locations_survive(self):
        path = self.file("navigation.dart", '''/* first
   second */
import 'https://example.invalid/library.dart';
export 'stub.dart' if (dart.library.io == 'true') 'native.dart';
void navigate() {
  context.go('/anime');
  final text = "context.go('/fake')";
  ref.watch(realProvider);
}
''')
        result = extract_dart(path)
        labels = {n["label"] for n in result["nodes"]}
        self.assertTrue({"https://example.invalid/library.dart", "stub.dart", "native.dart", "Route /anime", "realProvider"} <= labels)
        self.assertNotIn("Route /fake", labels)
        self.assertNotIn("true", labels)
        edges = result["edges"]
        self.assertEqual(next(e for e in edges if e["relation"] == "imports")["source_location"], "L3")
        self.assertEqual(next(e for e in edges if e.get("context") == "route_path")["source_location"], "L6")
        self.assertEqual(next(e for e in edges if e.get("context") == "riverpod_reference")["source_location"], "L8")

    def test_dollar_mixin_is_distinct_from_class_in_full_resolution(self):
        path = self.file("routes.dart", "class Route with $Route {}\n")
        result = extract([path], root=self.root, cache_root=Path(self.cache.name), parallel=False)
        mixin = next(e for e in result["edges"] if e["relation"] == "mixes_in")
        self.assertNotEqual(mixin["source"], mixin["target"])
        nodes = {n["id"]: n for n in result["nodes"]}
        self.assertEqual(nodes[mixin["target"]]["label"], "$Route")
        self.assertIsNone(nodes[mixin["target"]]["source_file"])

    def test_dollar_mixin_definition_resolves_across_part_files(self):
        library = self.file("routes.dart", "part 'routes.g.dart';\nclass Route with $Route {}\n")
        part = self.file("routes.g.dart", "part of 'routes.dart';\nmixin $Route {}\n")
        result = extract([library, part], root=self.root, cache_root=Path(self.cache.name), parallel=False)
        mixin = next(e for e in result["edges"] if e["relation"] == "mixes_in")
        nodes = {n["id"]: n for n in result["nodes"]}
        self.assertNotEqual(mixin["source"], mixin["target"])
        self.assertEqual(nodes[mixin["target"]]["label"], "$Route")
        self.assertEqual(nodes[mixin["target"]]["source_file"], "routes.g.dart")
        self.assertEqual(nodes[mixin["target"]]["source_location"], "L2")

    def test_kotlin_super_calls_base_and_this_keeps_real_recursion(self):
        path = self.file("Base.kt", '''open class Base {
 open fun run() {}
}
class Child: Base() {
 override fun run() {
 super.run()
 this.run()
 run()
 }
}
''')
        result = extract_kotlin(path)
        calls = [e for e in result["edges"] if e["relation"] == "calls"]
        super_call = next(e for e in calls if e["source_location"] == "L6")
        self.assertNotEqual(super_call["source"], super_call["target"])
        self.assertIn("base_run", super_call["target"])
        self.assertTrue(any(e["source"] == e["target"] for e in calls))

    def test_external_super_does_not_bind_to_override_or_unrelated_function(self):
        path = self.file("Child.kt", '''fun run() {}
class Child: ExternalBase() {
 override fun run() {
 super.run()
 }
}
''')
        result = extract_kotlin(path)
        self.assertFalse([e for e in result["edges"] if e["relation"] == "calls"])
        unresolved = next(c for c in result["raw_calls"] if c["callee"] == "run")
        self.assertTrue(unresolved["is_member_call"])

    def test_actual_problem_files_have_no_empty_endpoints_or_false_loops(self):
        repo = Path(__file__).resolve().parents[2]
        paths = [repo / p for p in (
            "test/infrastructure/anistar/anistar_sort_test.dart",
            "test/mocks/anistar/anistar_fixtures.dart",
            "lib/app/app_routes.dart",
            "android/app/src/main/kotlin/com/anistar/anistar_tv/MainActivity.kt",
        )]
        result = extract(paths, root=repo, cache_root=Path(self.cache.name), parallel=False)
        self.assertTrue(all(n["id"] for n in result["nodes"]))
        self.assertTrue(all(e["source"] and e["target"] for e in result["edges"]))
        self.assertFalse([e for e in result["edges"] if e["source"] == e["target"]])
        self.assertEqual(len([e for e in result["edges"] if e["relation"] == "mixes_in"]), 6)


if __name__ == "__main__":
    unittest.main()
