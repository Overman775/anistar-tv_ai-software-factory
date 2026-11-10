"""Shared execution preserves output and never confuses interruption with success."""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from typing import Any, NoReturn

from factory_tooling.runtime.check_process import ProcessResult, run_process


class CommandProcessTests(unittest.TestCase):
    def setUp(self) -> None:
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.out, self.err = self.root / "out", self.root / "err"

    def run_script(self, code: str, **kwargs: Any) -> ProcessResult:
        execution: dict[str, Any] = {
            "argv": [sys.executable, "-c", code],
            "cwd": ".",
            "timeout_seconds": 1,
        }
        return run_process(execution, self.root, self.out, stderr=self.err, **kwargs)

    def test_large_stdin_and_binary_output_are_not_truncated_or_deadlocked(self) -> None:
        payload = b"\xff" * (256 * 1024)
        result = self.run_script(
            'import sys; sys.stdout.buffer.write(sys.stdin.buffer.read()); sys.stderr.write("diagnostic"); sys.exit(7)',
            input_bytes=payload,
        )
        self.assertEqual({"exit_code": 7, "error": None}, result)
        self.assertEqual(payload, self.out.read_bytes())
        self.assertEqual("diagnostic", self.err.read_text())

    def test_unavailable_executable_retains_empty_logs_and_reports_error(self) -> None:
        execution: dict[str, Any] = {
            "argv": [str(self.root / "missing")],
            "cwd": ".",
            "timeout_seconds": 1,
        }
        result = run_process(execution, self.root, self.out, stderr=self.err)
        self.assertIsNone(result["exit_code"])
        self.assertIn("FileNotFoundError", result["error"] or "")
        self.assertTrue(self.out.is_file() and self.err.is_file())

    def test_invalid_command_or_existing_output_never_spawns(self) -> None:
        execution: dict[str, Any] = {"argv": ["unused"], "cwd": ".", "timeout_seconds": 0}

        def forbidden(*args: Any, **kwargs: Any) -> NoReturn:
            self.fail("Unexpected spawn")

        with self.assertRaises(ValueError):
            run_process(execution, self.root, self.out, popen=forbidden)
        self.assertFalse(self.out.exists())
        execution["timeout_seconds"] = 1
        self.out.write_text("previous evidence")
        with self.assertRaises(FileExistsError):
            run_process(execution, self.root, self.out, popen=forbidden)
        self.assertEqual("previous evidence", self.out.read_text())

    @unittest.skipUnless(os.name == "posix", "POSIX process groups")
    def test_timeout_stops_descendants_and_retains_partial_logs(self) -> None:
        child = 'import time; from pathlib import Path; time.sleep(2); Path("child-alive").touch()'
        code = (
            'import subprocess,sys,time; subprocess.Popen([sys.executable,"-c",'
            + repr(child)
            + ']); print("started",flush=True); time.sleep(20)'
        )
        result = self.run_script(code)
        self.assertIsNone(result["exit_code"])
        self.assertIn("TimeoutExpired", result["error"] or "")
        self.assertEqual("started\n", self.out.read_text())
        time.sleep(1.3)
        self.assertFalse((self.root / "child-alive").exists())

    @unittest.skipUnless(os.name == "posix", "POSIX PID check")
    def test_receipt_callback_failure_reaps_started_process(self) -> None:
        pids = []

        def broken(pid: int) -> NoReturn:
            pids.append(pid)
            raise ValueError("receipt cannot be persisted")

        with self.assertRaisesRegex(ValueError, "receipt"):
            self.run_script("import time; time.sleep(20)", on_started=broken)
        with self.assertRaises(ProcessLookupError):
            os.kill(pids[0], 0)

    def test_library_imports_do_not_execute_work_or_mutate_host_state(self) -> None:
        code = """
import sys
sys.path.insert(0, TOOLS_PATH)
import importlib, os, pkgutil, socket, subprocess
from pathlib import Path
from unittest.mock import patch
import factory_tooling
before = (list(sys.path), sys.dont_write_bytecode, dict(os.environ), os.getcwd())
with patch.object(subprocess, "Popen", side_effect=AssertionError("process during import")), \
     patch.object(os, "system", side_effect=AssertionError("shell during import")), \
     patch.object(socket, "socket", side_effect=AssertionError("network during import")), \
     patch.object(Path, "write_text", side_effect=AssertionError("write during import")), \
     patch.object(Path, "write_bytes", side_effect=AssertionError("write during import")), \
     patch.object(Path, "mkdir", side_effect=AssertionError("mkdir during import")):
    for module in pkgutil.walk_packages(factory_tooling.__path__, factory_tooling.__name__ + "."):
        importlib.import_module(module.name)
assert before == (list(sys.path), sys.dont_write_bytecode, dict(os.environ), os.getcwd())
""".replace("TOOLS_PATH", repr(str(Path(__file__).resolve().parents[3] / "tools")))
        subprocess.run([sys.executable, "-B", "-c", code], check=True, capture_output=True)

    def test_context_import_does_not_load_runtime_transition_modules(self) -> None:
        code = (
            "import sys; sys.path.insert(0,"
            + repr(str(Path(__file__).resolve().parents[3] / "tools"))
            + "); "
            "import factory_tooling.context.context; "
            'assert not ({"factory_tooling.runtime.escalation", "factory_tooling.runtime.workflow", "factory_tooling.runtime.workflow_graph", "factory_tooling.runtime.review_findings"} & set(sys.modules))'
        )
        subprocess.run([sys.executable, "-B", "-c", code], check=True, capture_output=True)
