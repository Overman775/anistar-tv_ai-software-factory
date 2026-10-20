"""Preparation must recover local state without hiding a broken installation."""
import contextlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import prepare


class PrepareTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory(prefix="anistar-graphify-prepare-")
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name).resolve()
        manifest = self.root / "tool/graphify/patch-manifest.json"
        manifest.parent.mkdir(parents=True)
        manifest.write_text('{"version":"0.9.92"}', encoding="utf-8")
        self.env = patch.dict(os.environ, {}, clear=True)
        self.env.start()
        self.addCleanup(self.env.stop)

    def sidecar(self, value):
        output = self.root / "graphify-out"
        output.mkdir(exist_ok=True)
        (output / ".graphify_python").write_text(value, encoding="utf-8")

    def result(self, version="0.9.92", code=0):
        return subprocess.CompletedProcess([], code,
            json.dumps({"python": sys.executable, "version": version}), "")

    def test_absent_optional_tool_skips_without_creating_local_state(self):
        with patch.object(prepare.shutil, "which", return_value=None), \
                patch.object(prepare.subprocess, "run", return_value=subprocess.CompletedProcess([], 1)), \
                contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertIsNone(prepare.prepare(self.root, optional=True))
        self.assertIn("not installed", output.getvalue())
        self.assertFalse((self.root / "graphify-out").exists())

    def test_absent_required_tool_fails(self):
        with patch.object(prepare.shutil, "which", return_value=None), \
                patch.object(prepare.subprocess, "run", return_value=subprocess.CompletedProcess([], 1)):
            with self.assertRaisesRegex(ValueError, "not installed"):
                prepare.prepare(self.root)

    def test_override_takes_precedence_over_stale_sidecar(self):
        self.sidecar("/old/machine/python")
        os.environ["ANISTAR_GRAPHIFY_PYTHON"] = sys.executable
        self.assertEqual(prepare.resolve_python(self.root), sys.executable)

    def test_empty_override_and_empty_sidecar_are_errors(self):
        os.environ["ANISTAR_GRAPHIFY_PYTHON"] = " "
        with self.assertRaisesRegex(ValueError, "is empty"):
            prepare.resolve_python(self.root)
        del os.environ["ANISTAR_GRAPHIFY_PYTHON"]
        self.sidecar("")
        with self.assertRaisesRegex(ValueError, "is empty"):
            prepare.resolve_python(self.root)

    def test_stale_sidecar_is_not_treated_as_optional_absence(self):
        self.sidecar(str(self.root / "missing-python"))
        with self.assertRaises(FileNotFoundError):
            prepare.prepare(self.root, optional=True)
        self.assertEqual((self.root / "graphify-out/.graphify_python").read_text(),
                         str(self.root / "missing-python"))

    def test_cli_symlink_keeps_venv_python_path(self):
        directory = self.root / "tool venv/bin"
        directory.mkdir(parents=True)
        interpreter = directory / ("python.exe" if os.name == "nt" else "python")
        interpreter.touch()
        cli = directory / "graphify"
        cli.write_text("#!/unrelated/python\n", encoding="utf-8")
        if os.name == "nt":
            selected = prepare._cli_python(str(cli))
        else:
            link = self.root / "graphify"
            link.symlink_to(cli)
            selected = prepare._cli_python(str(link))
        self.assertEqual(selected, str(interpreter))

    def test_cli_env_shebang_resolves_existing_python(self):
        cli = self.root / "graphify"
        cli.write_text("#!/usr/bin/env -S python3\n", encoding="utf-8")
        with patch.object(prepare.shutil, "which", return_value=sys.executable):
            self.assertEqual(prepare._cli_python(str(cli)), sys.executable)

    def test_uv_persistent_tool_is_found_without_running_transient_environment(self):
        tool_dir = self.root / "uv tools"
        interpreter = tool_dir / "graphifyy/bin/python"
        interpreter.parent.mkdir(parents=True)
        interpreter.touch()
        with patch.object(prepare.shutil, "which", side_effect=lambda name: "/uv" if name == "uv" else None), \
                patch.object(prepare.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, str(tool_dir))) as run:
            self.assertEqual(prepare.resolve_python(self.root), str(interpreter))
        self.assertEqual(run.call_args.args[0], ["/uv", "tool", "dir"])

    def test_windows_venv_layout_is_supported(self):
        interpreter = self.root / "Scripts/python.exe"
        interpreter.parent.mkdir()
        interpreter.touch()
        self.assertEqual(prepare._venv_python(self.root), str(interpreter))

    def test_present_unresolvable_cli_does_not_fall_through_to_optional_skip(self):
        cli = self.root / "graphify"
        cli.write_bytes(b"not a Python launcher")
        with patch.object(prepare.shutil, "which", return_value=str(cli)):
            with self.assertRaisesRegex(ValueError, "no resolvable Python"):
                prepare.prepare(self.root, optional=True)

    def test_success_validates_patch_before_writing_checkout_local_paths(self):
        os.environ["ANISTAR_GRAPHIFY_PYTHON"] = sys.executable
        with patch.object(prepare.subprocess, "run", side_effect=[self.result(), subprocess.CompletedProcess([], 0)]) as run:
            self.assertEqual(prepare.prepare(self.root), sys.executable)
        self.assertEqual(run.call_args_list[1].args[0],
                         [sys.executable, str(self.root / "tool/graphify/patch_graphify.py"), "--check"])
        self.assertEqual((self.root / "graphify-out/.graphify_python").read_text(), sys.executable)
        self.assertEqual((self.root / "graphify-out/.graphify_root").read_text(), str(self.root.resolve()))

    def test_bad_import_wrong_version_and_bad_patch_fail_even_when_optional(self):
        os.environ["ANISTAR_GRAPHIFY_PYTHON"] = sys.executable
        for result, message in ((self.result(code=1), "cannot import"),
                                (self.result(version="0.9.93"), "Expected graphifyy")):
            with self.subTest(message=message), patch.object(prepare.subprocess, "run", return_value=result):
                with self.assertRaisesRegex(ValueError, message):
                    prepare.prepare(self.root, optional=True)
                self.assertFalse((self.root / "graphify-out").exists())
        failure = subprocess.CalledProcessError(2, ["patch-check"])
        with patch.object(prepare.subprocess, "run", side_effect=[self.result(), failure]):
            with self.assertRaises(subprocess.CalledProcessError):
                prepare.prepare(self.root, optional=True)
        self.assertFalse((self.root / "graphify-out").exists())

    def test_check_and_update_dispatch_through_validated_interpreter(self):
        for flag, arguments in (("--check", ["-m", "unittest", "discover", "-s", "tool/graphify", "-p", "test_*.py"]),
                                ("--update", ["-m", "graphify", "update", "."])):
            with self.subTest(flag=flag), patch.object(sys, "argv", ["prepare.py", flag]), \
                    patch.object(prepare, "prepare", return_value=sys.executable), \
                    patch.object(prepare.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)) as run:
                self.assertEqual(prepare.main(), 0)
                self.assertEqual(run.call_args.args[0], [sys.executable, *arguments])


if __name__ == "__main__":
    unittest.main()
