"""Run the installer against isolated copies of the installed distribution."""

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

import graphify


HERE = Path(__file__).resolve().parent
MANIFEST = json.loads((HERE / "patch-manifest.json").read_text())


class InstallerTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory(prefix="anistar-graphify-installer-")
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.package = self.root / "graphify"
        shutil.copytree(Path(graphify.__file__).resolve().parent, self.package)
        self.metadata = self.root / "graphifyy-0.9.92.dist-info"
        self.metadata.mkdir()
        self.set_version(MANIFEST["version"])
        self.env = dict(os.environ, PYTHONPATH=str(self.root), PYTHONDONTWRITEBYTECODE="1")
        self.run_installer("--check")
        subprocess.run(
            ["patch", "--batch", "--reverse", "-p1", "-i", str(HERE / f"graphify-{MANIFEST['version']}.patch")],
            cwd=self.package, check=True, capture_output=True,
        )
        self.assert_hashes("original")

    def set_version(self, version):
        (self.metadata / "METADATA").write_text(f"Metadata-Version: 2.1\nName: graphifyy\nVersion: {version}\n")

    def hashes(self):
        return {name: hashlib.sha256((self.package / name).read_bytes()).hexdigest() for name in MANIFEST["files"]}

    def assert_hashes(self, state):
        self.assertEqual(self.hashes(), {name: values[state] for name, values in MANIFEST["files"].items()})

    def run_installer(self, *args, expected=0):
        result = subprocess.run(
            [sys.executable, str(HERE / "patch_graphify.py"), *args],
            cwd=self.root, env=self.env, capture_output=True, text=True, check=False,
        )
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result

    def assert_rejected_unchanged(self, message, *args):
        before = self.hashes()
        result = self.run_installer(*args, expected=2)
        self.assertIn(message, result.stderr)
        self.assertEqual(self.hashes(), before)

    def test_apply_check_and_reapply_match_reviewed_hashes(self):
        self.run_installer()
        self.assert_hashes("patched")
        self.run_installer("--check")
        self.run_installer()
        self.assert_hashes("patched")

    def test_check_rejects_unpatched_without_writing(self):
        self.assert_rejected_unchanged("Producer patch is not installed", "--check")

    def test_unknown_version_is_rejected_without_writing(self):
        self.set_version("0.9.93")
        self.assert_rejected_unchanged("Expected graphify 0.9.92, found 0.9.93")

    def test_unknown_source_hash_is_rejected_before_any_write(self):
        # Corrupt the last checked file: earlier original files must stay intact.
        path = self.package / list(MANIFEST["files"])[-1]
        path.write_bytes(path.read_bytes() + b"\n# unknown upstream source\n")
        self.assert_rejected_unchanged("Unrecognized installed source")

    def test_partial_installation_is_rejected_without_writing(self):
        self.run_installer()
        patched = (self.package / "extractors/dart.py").read_bytes()
        subprocess.run(
            ["patch", "--batch", "--reverse", "-p1", "-i", str(HERE / f"graphify-{MANIFEST['version']}.patch")],
            cwd=self.package, check=True, capture_output=True,
        )
        (self.package / "extractors/dart.py").write_bytes(patched)
        self.assert_rejected_unchanged("Partially patched installation")


if __name__ == "__main__":
    unittest.main()
