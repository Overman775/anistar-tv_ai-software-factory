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

from factory.runtime.check_process import ProcessResult, run_process


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

    def test_composite_execution_never_creates_logs_or_spawns(self) -> None:
        def forbidden(*args: Any, **kwargs: Any) -> NoReturn:
            self.fail("Unexpected spawn")

        with self.assertRaisesRegex(ValueError, "Composite execution"):
            run_process(
                {"argv": [], "cwd": ".", "timeout_seconds": 1, "stages": ["check"]},
                self.root,
                self.out,
                stderr=self.err,
                popen=forbidden,
            )
        self.assertFalse(self.out.exists())
        self.assertFalse(self.err.exists())

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

    @unittest.skipUnless(os.name == "posix", "POSIX PID check")
    def test_timeout_without_separate_group_reaps_direct_process(self) -> None:
        pids: list[int] = []
        result = self.run_script(
            "import time; time.sleep(20)", on_started=pids.append, separate_group=False
        )
        self.assertIn("TimeoutExpired", result["error"] or "")
        with self.assertRaises(ProcessLookupError):
            os.kill(pids[0], 0)

    def test_injected_process_owns_termination_and_is_reaped(self) -> None:
        def check(failure: BaseException, missing: bool) -> None:
            events: list[str] = []

            class FakeProcess:
                pid = 987654321

                def wait(self, timeout: float | None = None) -> int:
                    events.append("wait" if timeout is not None else "reap")
                    if timeout is not None:
                        raise failure
                    return -1

                def kill(self) -> None:
                    events.append("kill")
                    if missing:
                        raise ProcessLookupError()

            def spawn(*args: Any, **kwargs: Any) -> FakeProcess:
                return FakeProcess()

            output = self.root / f"{type(failure).__name__}-{missing}"
            result = run_process(
                {"argv": ["fake"], "cwd": ".", "timeout_seconds": 1},
                self.root,
                output,
                lambda pid: events.append(f"pid:{pid}"),
                popen=spawn,
            )
            self.assertEqual(["pid:987654321", "wait", "kill", "reap"], events)
            self.assertIn(type(failure).__name__, result["error"] or "")
            self.assertIsNone(result["exit_code"])

        for failure in (subprocess.TimeoutExpired("fake", 1), KeyboardInterrupt()):
            for missing in (False, True):
                with self.subTest(failure=type(failure).__name__, missing=missing):
                    check(failure, missing)

    def test_library_imports_do_not_execute_work_or_mutate_host_state(self) -> None:
        code = """
import sys
sys.path.insert(0, TOOLS_PATH)
import importlib, os, pkgutil, socket, subprocess
from pathlib import Path
from unittest.mock import patch
import factory
before = (list(sys.path), sys.dont_write_bytecode, dict(os.environ), os.getcwd())
with patch.object(subprocess, "Popen", side_effect=AssertionError("process during import")), \
     patch.object(os, "system", side_effect=AssertionError("shell during import")), \
     patch.object(socket, "socket", side_effect=AssertionError("network during import")), \
     patch.object(Path, "write_text", side_effect=AssertionError("write during import")), \
     patch.object(Path, "write_bytes", side_effect=AssertionError("write during import")), \
     patch.object(Path, "mkdir", side_effect=AssertionError("mkdir during import")):
    for module in pkgutil.walk_packages(factory.__path__, factory.__name__ + "."):
        importlib.import_module(module.name)
assert before == (list(sys.path), sys.dont_write_bytecode, dict(os.environ), os.getcwd())
""".replace("TOOLS_PATH", repr(str(Path(__file__).resolve().parents[3] / "bin")))
        subprocess.run([sys.executable, "-B", "-c", code], check=True, capture_output=True)

    def test_context_import_does_not_load_runtime_transition_modules(self) -> None:
        code = (
            "import sys; sys.path.insert(0,"
            + repr(str(Path(__file__).resolve().parents[3] / "bin"))
            + "); "
            "import factory.context.context; "
            'assert not ({"factory.runtime.escalation", "factory.runtime.workflow", "factory.runtime.workflow_graph", "factory.runtime.review_findings"} & set(sys.modules))'
        )
        subprocess.run([sys.executable, "-B", "-c", code], check=True, capture_output=True)

    def test_task_criteria_import_does_not_load_runtime(self) -> None:
        code = (
            "import sys; sys.path.insert(0,"
            + repr(str(Path(__file__).resolve().parents[3] / "bin"))
            + "); import factory.tasks.criteria; "
            'assert not any(name == "factory.runtime" or name.startswith("factory.runtime.") '
            "for name in sys.modules)"
        )
        subprocess.run([sys.executable, "-B", "-c", code], check=True, capture_output=True)
