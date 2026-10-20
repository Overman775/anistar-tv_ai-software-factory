"""Exercise flavor dispatch and Python preflight without building or releasing."""

import json
import os
from pathlib import Path
import shutil
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
        self.mode_log = self.temp / "modes.jsonl"
        self.env = dict(os.environ, ANISTAR_FLUTTER_SDK=str(self.temp), CALLS=str(self.log),
                        MODES=str(self.mode_log))
        self.env.pop("ANISTAR_ANDROID_SIGNING_MODE", None)
        for relative in ("scripts/flutter_app.sh", "scripts/with_python.sh", "tool/environment/prepare.py"):
            destination = self.temp / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, destination)
        environment = self.temp / "env"
        environment.mkdir()
        for name in ("dev.json", "prod.example.json"):
            (environment / name).write_text('{"ANISTAR_MIRROR_URL":"https://fixture.example/"}\n')
        for name in ("flutter", "dart"):
            path = self.bin / name
            path.write_text("#!/usr/bin/env python3\nimport json, os, sys\n"
                            "with open(os.environ['CALLS'], 'a') as log:\n"
                            "    log.write(json.dumps(sys.argv[1:]) + '\\n')\n"
                            "with open(os.environ['MODES'], 'a') as log:\n"
                            "    log.write(json.dumps(os.environ.get('ANISTAR_ANDROID_SIGNING_MODE')) + '\\n')\n"
                            "if sys.argv[0].endswith('/dart'):\n"
                            "    sys.stdin.read()\n"
                            "print('{}')\n")
            path.chmod(0o755)

    def dispatch(self, *arguments):
        return subprocess.run(["bash", str(self.temp / "scripts/flutter_app.sh"), *arguments],
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

    def test_prod_release_defaults_local_and_explicit_unsigned_preserves_verifiers(self):
        # Intercept only Python verifier processes; the wrapper itself is real.
        verifier_log = self.temp / "verifiers.jsonl"
        python = self.bin / "python3"
        python.write_text(f"#!{sys.executable}\nimport json, os, sys\n"
                          "if sys.argv[1:2] == ['-c']:\n"
                          "    os.execv(sys.executable, [sys.executable, *sys.argv[1:]])\n"
                          "with open(os.environ['VERIFIERS'], 'a') as log:\n"
                          "    log.write(json.dumps(sys.argv[1:]) + '\\n')\n")
        python.chmod(0o755)
        # Existing SDK stubs use env python3; give them a direct interpreter so
        # only wrapper verification commands are intercepted by PATH.
        for name in ("flutter", "dart"):
            stub = self.bin / name
            stub.write_text(stub.read_text().replace("#!/usr/bin/env python3", f"#!{sys.executable}"))
        self.env.update(PATH=f"{self.bin}{os.pathsep}{os.environ['PATH']}", VERIFIERS=str(verifier_log))
        for mode in ("local", "unsigned"):
            if mode == "unsigned":
                self.env["ANISTAR_ANDROID_SIGNING_MODE"] = mode
            result = self.dispatch("apk", "prod", "release")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(set(json.loads(line) for line in self.mode_log.read_text().splitlines()), {mode})
            verifiers = [json.loads(line) for line in verifier_log.read_text().splitlines()]
            self.assertEqual(verifiers[0][:3], ["tool/quality/verify_android_apk.py", "--variant", "prodRelease"])
            self.assertEqual(verifiers[1], ["tool/signing/android_signing.py", "verify", "--apk",
                                           "build/app/outputs/flutter-apk/app-prod-release.apk", "--mode", mode])
            self.mode_log.unlink()
            verifier_log.unlink()

    def test_dev_and_prod_debug_override_inherited_local_signing(self):
        self.env["ANISTAR_ANDROID_SIGNING_MODE"] = "local"
        for arguments in (("run", "dev", "debug"), ("bundle", "dev", "release"),
                          ("apk", "prod", "debug")):
            result = self.dispatch(*arguments)
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(set(json.loads(line) for line in self.mode_log.read_text().splitlines()), {"unsigned"})

    def test_invalid_production_signing_mode_fails_before_sdk(self):
        self.env["ANISTAR_ANDROID_SIGNING_MODE"] = "debug"
        result = self.dispatch("apk", "prod", "release")
        self.assertEqual(result.returncode, 64)
        self.assertIn("Invalid Android signing mode", result.stderr)
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
