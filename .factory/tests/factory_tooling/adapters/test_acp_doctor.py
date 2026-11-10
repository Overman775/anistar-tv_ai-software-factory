"""Doctor resolves configured executables by the same rules as dispatch."""

from __future__ import annotations

import io
import json
import os
import shutil
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch

from factory_tooling.adapters import acpx_adapter
from factory_tooling.adapters.acpx_adapter import DoctorConfig, doctor, executable

_TOOLS = Path(__file__).resolve().parents[3] / "tools"


class DoctorTests(unittest.TestCase):
    def test_cli_reports_failure_and_selected_route_isolated(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            config: DoctorConfig = {
                "_path": str(Path(directory) / "factory.yaml"),
                "acpx": {
                    "command": sys.executable,
                    "connections": {
                        "working": {"command": sys.executable},
                        "missing": {"command": str(Path(directory) / "absent")},
                    },
                },
            }
            for args, expected, keys in [
                ([], 1, {"working", "missing"}),
                (["--connection", "working"], 0, {"working"}),
                (["--connection", "missing"], 1, {"missing"}),
            ]:
                output = io.StringIO()
                with (
                    patch.object(
                        sys, "argv", ["adapter", "--workspace", directory, "doctor", *args]
                    ),
                    patch.object(acpx_adapter, "load_config", return_value=config),
                    patch("subprocess.Popen", side_effect=AssertionError("No transport")),
                    redirect_stdout(output),
                ):
                    self.assertEqual(acpx_adapter.main(), expected)
                report = json.loads(output.getvalue())
                self.assertEqual(set(report["connections"]), keys)
                self.assertEqual(bool(report["errors"]), bool(expected))
                self.assertEqual(report["live_handshake"], "NOT_RUN")
            self.assertFalse((Path(directory) / ".factory/memory").exists())

    def test_selected_route_still_requires_client_and_rejects_unknown(self) -> None:
        config: DoctorConfig = {
            "_path": "/unused/factory.yaml",
            "acpx": {
                "command": "/missing/acpx",
                "connections": {"working": {"command": sys.executable}},
            },
        }
        self.assertIn("acpx", doctor(config, "working")["errors"])
        with self.assertRaisesRegex(ValueError, "Unknown ACP connection"):
            doctor(config, "unknown")

    def test_relative_and_home_paths_match_dispatch(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            binary = root / "bin" / ("bridge" + Path(sys.executable).suffix)
            binary.parent.mkdir()
            shutil.copy2(sys.executable, binary)
            relative = binary.relative_to(root).as_posix()
            config: DoctorConfig = {
                "_path": str(root / "factory.yaml"),
                "acpx": {
                    "command": relative,
                    "connections": {
                        "local": {"command": relative},
                        "home": {"command": "~/" + relative},
                        "missing": {"command": "bin/absent"},
                    },
                },
            }
            with patch.dict(os.environ, {"HOME": str(root), "USERPROFILE": str(root)}):
                result = doctor(config)
                self.assertEqual(result["acpx"], executable(relative, root))
                self.assertEqual(result["connections"]["home"], str(binary.resolve()))
            self.assertEqual(result["connections"]["local"], result["acpx"])
            self.assertIsNone(result["connections"]["missing"])
            self.assertEqual(set(result["errors"]), {"missing"})
            self.assertEqual(result["live_handshake"], "NOT_RUN")


if __name__ == "__main__":
    unittest.main()
