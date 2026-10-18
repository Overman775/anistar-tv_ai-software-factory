"""Exercise flavor dispatch and Python preflight without building or releasing."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from app_version import read_version


ROOT = Path(__file__).resolve().parents[2]


class ToolingCommandsTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.temp = Path(self.directory.name)
        self.bin = self.temp / "bin"
        self.bin.mkdir()
        self.log = self.temp / "calls.jsonl"
        self.env = dict(os.environ, ANISTAR_FLUTTER_SDK=str(self.temp), CALLS=str(self.log))
        for name in ("flutter", "dart"):
            path = self.bin / name
            path.write_text("#!/usr/bin/env python3\nimport json, os, sys\n"
                            "with open(os.environ['CALLS'], 'a') as log:\n"
                            "    log.write(json.dumps(sys.argv[1:]) + '\\n')\n"
                            "if sys.argv[0].endswith('/dart'):\n"
                            "    sys.stdin.read()\n"
                            "print('{}')\n")
            path.chmod(0o755)

    def dispatch(self, *arguments):
        return subprocess.run(["bash", str(ROOT / "scripts/flutter_app.sh"), *arguments],
                              env=self.env, capture_output=True, text=True, check=False)

    def test_dev_run_preserves_flutter_arguments_and_defines(self):
        result = self.dispatch("run", "dev", "debug", "-d", "emulator-5554", "--no-resident")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        # Both ends of the SDK verification pipe can start first.
        self.assertCountEqual(calls[:2], [["--no-version-check", "--version", "--machine"],
                                        ["tool/quality/verify_sdk.dart"]])
        self.assertEqual(calls[-1], ["--no-version-check", "run", "--debug", "--flavor", "dev",
                                    "--target", "lib/main_dev.dart", "--dart-define-from-file=env/dev.json",
                                    "-d", "emulator-5554", "--no-resident"])

    def test_prod_bundle_keeps_pub_lifecycle_and_ordinary_entry_point(self):
        result = self.dispatch("bundle", "prod", "release")
        self.assertEqual(result.returncode, 0, result.stderr)
        call = json.loads(self.log.read_text().splitlines()[-1])
        self.assertEqual(call[:7], ["--no-version-check", "build", "appbundle", "--release",
                                  "--flavor", "prod", "--target"])
        self.assertIn("lib/main_prod.dart", call)
        self.assertNotIn("--no-pub", call)
        self.assertFalse(any("live-test" in argument for argument in call))

    def test_invalid_dispatch_fails_before_sdk_commands(self):
        for arguments in (("apk",), ("upload", "prod", "release"),
                          ("apk", "staging", "release"), ("apk", "dev", "invalid")):
            self.assertEqual(self.dispatch(*arguments).returncode, 64)
        self.assertFalse(self.log.exists())

    def test_bad_python_override_fails_before_child_command(self):
        env = dict(os.environ, ANISTAR_PYTHON="/nonexistent/anistar-python")
        result = subprocess.run(["bash", str(ROOT / "scripts/with_python.sh"),
                                 "touch", str(self.temp / "must-not-exist")],
                                env=env, capture_output=True, text=True, check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Python 3.10+ required", result.stderr)
        self.assertFalse((self.temp / "must-not-exist").exists())

    def test_live_wrapper_rejects_bad_device_before_credentials_or_network(self):
        result = subprocess.run(["bash", str(ROOT / "scripts/e2e_live.sh"), "invalid-device"],
                                capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 64)
        self.assertIn("Usage:", result.stderr)

    def test_version_cli_preview_prints_plan_and_preserves_checkout(self):
        files = (ROOT / "pubspec.yaml", ROOT / "README.md")
        before = [path.read_bytes() for path in files]
        current, build = read_version(ROOT)
        next_version = f"{current[0]}.{current[1]}.{current[2] + 1}"
        current_version = ".".join(map(str, current))
        result = subprocess.run([sys.executable, str(ROOT / "tool/version/app_version.py"),
                                 "set", "--app-version", next_version, "--build-number", str(build + 1)],
                                capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f"Dry-run: {current_version}+{build} -> {next_version}+{build + 1}", result.stdout)
        self.assertEqual(before, [path.read_bytes() for path in files])


if __name__ == "__main__":
    unittest.main()
