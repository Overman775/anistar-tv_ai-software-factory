import tempfile
from pathlib import Path
import unittest

from app_version import proposed, read_version, set_version


class AppVersionTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        (self.root / "pubspec.yaml").write_text("name: app\nversion: 1.1.1+4\n# preserved\n")
        (self.root / "README.md").write_text("# Test app\n\nSetup and documentation.\n")
        (self.root / "package.yaml").write_text("version: 0.0.1\n")

    def test_read_and_check(self):
        self.assertEqual(read_version(self.root), ((1, 1, 1), 4))

    def test_plans_reset_lower_components(self):
        for bump, expected in (("patch", (1, 1, 2)), ("minor", (1, 2, 0)),
                               ("major", (2, 0, 0)), ("build", (1, 1, 1))):
            self.assertEqual(proposed((1, 1, 1), bump), expected)

    def test_default_dry_run_changes_nothing(self):
        before = {p.name: p.read_bytes() for p in self.root.iterdir()}
        self.assertEqual(set_version(self.root, "1.2.0", 5), "1.2.0+5")
        self.assertEqual(before, {p.name: p.read_bytes() for p in self.root.iterdir()})

    def test_explicit_write_updates_only_app_manifest(self):
        readme = (self.root / "README.md").read_bytes()
        set_version(self.root, "1.2.0", 5, write=True)
        self.assertEqual(read_version(self.root), ((1, 2, 0), 5))
        self.assertIn("# preserved", (self.root / "pubspec.yaml").read_text())
        self.assertEqual((self.root / "README.md").read_bytes(), readme)
        self.assertEqual((self.root / "package.yaml").read_text(), "version: 0.0.1\n")

    def test_rejects_decrease_or_non_increasing_build_before_write(self):
        before = (self.root / "pubspec.yaml").read_bytes()
        for version, build in (("1.0.0", 5), ("1.2.0", 4), ("1.2.0", 0)):
            with self.assertRaises(ValueError):
                set_version(self.root, version, build, write=True)
        self.assertEqual((self.root / "pubspec.yaml").read_bytes(), before)

    def test_rejects_prerelease_and_leading_zeros(self):
        for version in ("01.2.0", "1.2.0-beta", "1.2", "1.2.0+5"):
            with self.assertRaises(ValueError):
                set_version(self.root, version, 5)

    def test_version_commands_do_not_require_readme(self):
        (self.root / "README.md").unlink()
        self.assertEqual(read_version(self.root), ((1, 1, 1), 4))
        self.assertEqual(set_version(self.root, "1.2.0", 5, write=True), "1.2.0+5")
        self.assertEqual(read_version(self.root), ((1, 2, 0), 5))
        self.assertFalse((self.root / "README.md").exists())

    def test_rejects_missing_or_duplicate_app_version(self):
        for text in ("version: 1.1.1\n", "version: 1.1.1+4\nversion: 1.1.2+5\n"):
            (self.root / "pubspec.yaml").write_text(text)
            with self.assertRaises(ValueError):
                read_version(self.root)


if __name__ == "__main__":
    unittest.main()
