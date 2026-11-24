"""Real local venv/launcher tests; no package downloads or external services."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
import unittest
import venv
from pathlib import Path
from typing import Any, ClassVar
from unittest.mock import patch

import bootstrap as runtime
from factory.paths import TOOLS
from tests import CLI

SETUP_COMMAND = f".factory/tooling/bin/{Path(CLI[0]).name} setup"
SETUP_HELP = (
    r".\.factory\tooling\bin\cli.cmd setup --help" if os.name == "nt" else f"{SETUP_COMMAND} --help"
)


class RuntimeTests(unittest.TestCase):
    temp: ClassVar[tempfile.TemporaryDirectory[str]]
    root: ClassVar[Path]
    tools: ClassVar[Path]
    environment: ClassVar[Path]
    python: ClassVar[Path]
    bundle_path: ClassVar[Path]

    @classmethod
    def setUpClass(cls) -> None:
        cls.temp = tempfile.TemporaryDirectory(prefix="factory runtime кириллица ' ")
        cls.addClassCleanup(cls.temp.cleanup)
        cls.root = Path(cls.temp.name)
        cls.tools = cls.root / ".factory/tooling"
        cls.tools.mkdir(parents=True)
        for name in ("bootstrap.py", "requirements.txt"):
            shutil.copy2(TOOLS / name, cls.tools / name)
        shutil.copytree(TOOLS / "bin", cls.tools / "bin")
        cls.environment = cls.root / ".factory/.venv"
        venv.EnvBuilder(with_pip=False, symlinks=os.name != "nt").create(cls.environment)
        cls.python = runtime.interpreter(cls.environment)
        site = json.loads(
            subprocess.check_output(
                [
                    str(cls.python),
                    "-E",
                    "-s",
                    "-c",
                    'import json,sysconfig; print(json.dumps(sysconfig.get_path("purelib")))',
                ],
                text=True,
            )
        )
        # Reuse the test runner's real PyYAML package offline, not a fake module.
        import yaml

        shutil.copytree(Path(yaml.__file__).parent, Path(site) / "yaml")
        package = cls.tools / "factory"
        package.mkdir()
        shutil.copy2(TOOLS / "factory/__init__.py", package / "__init__.py")
        shutil.copy2(TOOLS / "factory/cli_output.py", package / "cli_output.py")
        (package / "cli.py").write_text(
            "import json, sys\n"
            "def main(args):\n"
            "    print(json.dumps([sys.prefix, args]))\n"
            "    return 17 if args == ['exit'] else 0\n"
            "if __name__ == '__main__': sys.exit(main(sys.argv[1:]))\n",
            encoding="utf-8",
        )
        cls.bundle_path = Path(site) / "factory-bundle.pth"
        cls.bundle_path.write_text(runtime.bundle_site_line(package.parent), encoding="ascii")
        subprocess.run(
            [str(cls.python), "-E", "-s", "-B", str(cls.tools / "bootstrap.py"), "_ready"],
            check=True,
        )

    def launch(
        self, *args: Any, env: dict[str, str] | None = None
    ) -> subprocess.CompletedProcess[str]:
        command = (
            [str(self.tools / "bin/cli.cmd")] if os.name == "nt" else [str(self.tools / "bin/cli")]
        )
        return subprocess.run(
            [*command, *args], cwd=self.root, env=env, capture_output=True, text=True, timeout=30
        )

    def test_launch_without_activation_preserves_arguments_and_exit(self) -> None:
        env = dict(
            os.environ, PYTHONHOME="/does/not/exist", PYTHONPATH="/does/not/exist", LC_ALL="C"
        )
        result = self.launch("space value", "кириллица", env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        prefix, args = json.loads(result.stdout)
        self.assertEqual(Path(prefix).resolve(), self.environment.resolve())
        self.assertEqual(args, ["space value", "кириллица"])
        self.assertEqual(self.launch("exit").returncode, 17)

    def test_installed_cli_from_unrelated_directory_uses_its_bundle(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            collision = Path(directory) / "factory"
            collision.mkdir()
            (collision / "__init__.py").touch()
            result = subprocess.run(
                [*CLI, "help", "--json"],
                cwd=directory,
                capture_output=True,
                text=True,
                timeout=30,
            )
            self.assertEqual(0, result.returncode, result.stderr)
            self.assertEqual(1, json.loads(result.stdout)["schema_version"])

    def test_changed_requirements_fail_without_running_target(self) -> None:
        requirements = self.tools / "requirements.txt"
        original = requirements.read_bytes()
        try:
            requirements.write_bytes(original + b"\n# change\n")
            result = self.launch("MUST_NOT_RUN")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("stale", result.stderr)
            self.assertIn(SETUP_HELP, result.stderr)
            self.assertNotIn("MUST_NOT_RUN", result.stdout)
        finally:
            requirements.write_bytes(original)

    def test_corrupt_readiness_marker_reports_setup_help_in_text_and_json(self) -> None:
        marker = self.environment / ".factory-ready.json"
        original = marker.read_bytes()
        try:
            for content in (b"{", b"[]", b"[1]"):
                with self.subTest(content=content):
                    marker.write_bytes(content)
                    result = self.launch("help")
                    self.assertEqual(result.returncode, 1)
                    self.assertEqual(result.stdout, "")
                    self.assertIn(SETUP_HELP, result.stderr)
                    result = self.launch("help", "--json")
                    self.assertEqual(result.returncode, 1)
                    self.assertEqual(result.stderr, "")
                    error = json.loads(result.stdout)["error"]
                    self.assertEqual(error["code"], "environment_not_ready")
                    self.assertIn(SETUP_HELP, error["next_action"])
        finally:
            marker.write_bytes(original)

    def test_missing_or_wrong_bundle_blocks_launch(self) -> None:
        original = self.bundle_path.read_bytes()
        try:
            other = self.root / "other"
            package = other / "factory"
            package.mkdir(parents=True)
            (package / "__init__.py").touch()
            for content in (b"", runtime.bundle_site_line(other).encode("ascii")):
                with self.subTest(content=content):
                    self.bundle_path.write_bytes(content)
                    result = self.launch("MUST_NOT_RUN")
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("Factory package missing or from another bundle", result.stderr)
                    self.assertNotIn("MUST_NOT_RUN", result.stdout)
        finally:
            self.bundle_path.write_bytes(original)

    def test_missing_runtime_dependency_blocks_command_dispatch(self) -> None:
        yaml = self.bundle_path.parent / "yaml"
        hidden = yaml.with_name("yaml-hidden")
        yaml.rename(hidden)
        try:
            result = self.launch("MUST_NOT_RUN")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("No module named 'yaml'", result.stderr)
            self.assertNotIn("MUST_NOT_RUN", result.stdout)
        finally:
            hidden.rename(yaml)

    def test_missing_environment_has_no_system_fallback(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            tools = Path(directory) / ".factory/tooling/bin"
            tools.mkdir(parents=True)
            for name in ("cli", "cli.cmd"):
                shutil.copy2(TOOLS / "bin" / name, tools / name)
            cmd = [str(tools / ("cli.cmd" if os.name == "nt" else "cli"))]
            result = subprocess.run(
                [*cmd, "-c", 'print("MUST_NOT_RUN")'], capture_output=True, text=True
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn("MUST_NOT_RUN", result.stdout)
            self.assertFalse((tools.parent.parent / ".venv").exists())
            for args in (["workflow", "status", "--json"], ["--json", "workflow", "status"]):
                with self.subTest(args=args):
                    result = subprocess.run([*cmd, *args], capture_output=True, text=True)
                    self.assertEqual(result.returncode, 1)
                    error = json.loads(result.stdout)["error"]
                    self.assertEqual(error["code"], "environment_not_ready")
                    self.assertIn(SETUP_COMMAND, error["message"])
            result = subprocess.run([*cmd, "--", "--json"], capture_output=True, text=True)
            self.assertEqual(result.stdout, "")
            self.assertIn("not ready", result.stderr)
            self.assertIn(SETUP_COMMAND, result.stderr)

    def test_invalid_setup_interpreter_reports_json_before_creating_environment(self) -> None:
        for args in (["setup", "--json"], ["--json", "setup"]):
            with self.subTest(args=args):
                result = self.launch(
                    *args,
                    env=dict(os.environ, FACTORY_SETUP_PYTHON=str(self.root / "missing-python")),
                )
                self.assertEqual(result.returncode, 1)
                self.assertEqual(json.loads(result.stdout)["error"]["code"], "setup_failed")

    def test_setup_lock_blocks_launch(self) -> None:
        lock = self.root / ".factory/.venv.setup.lock"
        lock.touch()
        try:
            result = self.launch("help")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("in progress", result.stderr)
            result = self.launch("workflow", "status", "--json")
            self.assertEqual(result.returncode, 1)
            error = json.loads(result.stdout)["error"]
            self.assertEqual(error["code"], "environment_not_ready")
            self.assertIn("in progress", error["message"])
        finally:
            lock.unlink()

    def test_platform_interpreter_paths(self) -> None:
        self.assertEqual(runtime.interpreter(Path("env"), "nt"), Path("env/Scripts/python.exe"))
        self.assertEqual(runtime.interpreter(Path("env"), "posix"), Path("env/bin/python"))

    def test_failed_package_install_invalidates_marker_and_releases_lock(self) -> None:
        agents = self.root / ".factory"
        marker = self.environment / ".factory-ready.json"
        original = marker.read_bytes()
        try:
            with (
                patch.object(runtime, "AGENTS", agents),
                patch.object(runtime, "ENV", self.environment),
                patch.object(runtime, "MARKER", marker),
                patch.object(runtime, "interpreter", return_value=self.python),
                patch(
                    "subprocess.check_output",
                    side_effect=["True\n", json.dumps(str(self.tools))],
                ),
                patch("subprocess.run", side_effect=subprocess.CalledProcessError(1, "pip")),
            ):
                with self.assertRaises(subprocess.CalledProcessError):
                    runtime.setup()
            self.assertFalse(marker.exists())
            self.assertFalse((agents / ".venv.setup.lock").exists())
        finally:
            marker.write_bytes(original)

    def test_unsupported_minors_block_setup_and_launch(self) -> None:
        for version in ((3, 11, 14), (3, 15, 2)):
            with self.subTest(version=version), patch("sys.version_info", version):
                with self.assertRaisesRegex(RuntimeError, "Python 3.14 required"):
                    runtime.setup()
                with self.assertRaisesRegex(RuntimeError, "Python 3.14 required"):
                    runtime.check()

    def test_wrong_minor_venv_blocks_setup_before_package_changes(self) -> None:
        agents = self.root / ".factory"
        marker = self.environment / ".factory-ready.json"
        original = marker.read_bytes()
        with (
            patch.object(runtime, "AGENTS", agents),
            patch.object(runtime, "ENV", self.environment),
            patch.object(runtime, "MARKER", marker),
            patch("subprocess.check_output", return_value="False\n"),
            patch("subprocess.run") as run,
        ):
            with self.assertRaisesRegex(RuntimeError, "recreate .factory/.venv"):
                runtime.setup()
            run.assert_not_called()
        self.assertEqual(marker.read_bytes(), original)
        self.assertFalse((agents / ".venv.setup.lock").exists())

    def test_clean_environment_does_not_redirect_pip(self) -> None:
        with patch.dict(
            os.environ, {"PIP_TARGET": "/wrong", "PIP_USER": "1", "PYTHONPATH": "/wrong"}
        ):
            env = runtime.clean_environment()
        self.assertNotIn("PIP_TARGET", env)
        self.assertNotIn("PIP_USER", env)
        self.assertNotIn("PYTHONPATH", env)
        self.assertEqual(env["PIP_CONFIG_FILE"], os.devnull)
