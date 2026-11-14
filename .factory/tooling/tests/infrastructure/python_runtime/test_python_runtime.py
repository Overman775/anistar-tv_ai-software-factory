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
from factory.paths import FACTORY_ROOT, TOOLS


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
            [str(self.tools / "bin/python.cmd")]
            if os.name == "nt"
            else ["sh", str(self.tools / "bin/python.sh")]
        )
        return subprocess.run(
            [*command, *args], cwd=self.root, env=env, capture_output=True, text=True, timeout=30
        )

    def test_launch_without_activation_preserves_arguments_and_exit(self) -> None:
        env = dict(
            os.environ, PYTHONHOME="/does/not/exist", PYTHONPATH="/does/not/exist", LC_ALL="C"
        )
        result = self.launch(
            "-c",
            "import sys,yaml,json; print(json.dumps([sys.prefix,sys.argv[1:]]))",
            "space value",
            "кириллица",
            env=env,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        prefix, args = json.loads(result.stdout)
        self.assertEqual(Path(prefix).resolve(), self.environment.resolve())
        self.assertEqual(args, ["space value", "кириллица"])
        self.assertEqual(self.launch("-c", "raise SystemExit(17)").returncode, 17)

    def test_installed_launcher_check_from_an_unrelated_directory(self) -> None:
        command = (
            [str(TOOLS / "bin/python.cmd")]
            if os.name == "nt"
            else ["sh", str(TOOLS / "bin/python.sh")]
        )
        with tempfile.TemporaryDirectory() as directory:
            collision = Path(directory) / "factory"
            collision.mkdir()
            (collision / "__init__.py").touch()
            result = subprocess.run(
                [*command, "--check"], cwd=directory, capture_output=True, text=True, timeout=30
            )
            self.assertEqual(0, result.returncode, result.stderr)
            self.assertEqual("PASS", json.loads(result.stdout)["status"])
            result = subprocess.run(
                [*command, "-c", "import factory; print(factory.__file__)"],
                cwd=directory,
                capture_output=True,
                text=True,
                timeout=30,
            )
            self.assertEqual(0, result.returncode, result.stderr)
            self.assertEqual(
                (TOOLS / "factory/__init__.py").resolve(), Path(result.stdout.strip()).resolve()
            )

    def test_entry_points_load_from_an_unrelated_directory(self) -> None:
        scripts = (
            "tooling/bin/catalog.py",
            "tooling/bin/dry_run.py",
            "tooling/bin/acpx_adapter.py",
            "tooling/bin/context.py",
            "tooling/bin/workflow.py",
            "tooling/bin/project.py",
            "tooling/bin/check.py",
            "gates/skills/code-review/run_tool_checks.py",
            "gates/skills/code-review/validate_review_protocol.py",
            "gates/skills/planning/validate_plan.py",
            "gates/skills/decompose/prepare_metadata.py",
            "gates/skills/decompose/assemble.py",
            "gates/skills/decompose/generate_task_graph.py",
            "skills/factory-pr/scripts/fetch_note.py",
            "skills/factory-pr/scripts/fetch_note_context.py",
            "skills/factory-pr/scripts/fetch_recent_notes.py",
            "skills/factory-code-review/scripts/review_run.py",
        )
        command = (
            [str(TOOLS / "bin/python.cmd")]
            if os.name == "nt"
            else ["sh", str(TOOLS / "bin/python.sh")]
        )
        with tempfile.TemporaryDirectory() as directory:
            for script in scripts:
                with self.subTest(script=script):
                    result = subprocess.run(
                        [*command, str(FACTORY_ROOT / script), "--help"],
                        cwd=directory,
                        capture_output=True,
                        text=True,
                        timeout=30,
                    )
                    self.assertEqual(0, result.returncode, result.stderr)

    def test_changed_requirements_fail_without_running_target(self) -> None:
        requirements = self.tools / "requirements.txt"
        original = requirements.read_bytes()
        try:
            requirements.write_bytes(original + b"\n# change\n")
            result = self.launch("-c", 'print("MUST_NOT_RUN")')
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("stale", result.stderr)
            self.assertNotIn("MUST_NOT_RUN", result.stdout)
        finally:
            requirements.write_bytes(original)

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
                    result = self.launch("-c", 'print("MUST_NOT_RUN")')
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("Factory package missing or from another bundle", result.stderr)
                    self.assertNotIn("MUST_NOT_RUN", result.stdout)
        finally:
            self.bundle_path.write_bytes(original)

    def test_missing_environment_has_no_system_fallback(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            tools = Path(directory) / ".factory/tooling/bin"
            tools.mkdir(parents=True)
            for name in ("python.sh", "python.cmd"):
                shutil.copy2(TOOLS / "bin" / name, tools / name)
            cmd = (
                [str(tools / "python.cmd")] if os.name == "nt" else ["sh", str(tools / "python.sh")]
            )
            result = subprocess.run(
                [*cmd, "-c", 'print("MUST_NOT_RUN")'], capture_output=True, text=True
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn("MUST_NOT_RUN", result.stdout)
            self.assertFalse((tools.parent.parent / ".venv").exists())

    def test_setup_lock_blocks_launch(self) -> None:
        lock = self.root / ".factory/.venv.setup.lock"
        lock.touch()
        try:
            result = self.launch("--check")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("in progress", result.stderr)
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
                patch("subprocess.run", side_effect=subprocess.CalledProcessError(1, "pip")),
            ):
                with self.assertRaises(subprocess.CalledProcessError):
                    runtime.setup()
            self.assertFalse(marker.exists())
            self.assertFalse((agents / ".venv.setup.lock").exists())
        finally:
            marker.write_bytes(original)

    def test_clean_environment_does_not_redirect_pip(self) -> None:
        with patch.dict(
            os.environ, {"PIP_TARGET": "/wrong", "PIP_USER": "1", "PYTHONPATH": "/wrong"}
        ):
            env = runtime.clean_environment()
        self.assertNotIn("PIP_TARGET", env)
        self.assertNotIn("PIP_USER", env)
        self.assertNotIn("PYTHONPATH", env)
        self.assertEqual(env["PIP_CONFIG_FILE"], os.devnull)
