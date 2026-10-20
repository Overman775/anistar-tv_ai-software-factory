"""Signing contract tests: synthetic archives and mocked Android subprocesses only."""

import contextlib
import io
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import android_signing as signing


PIN = "AB" * 32
RUN_PROCESS = subprocess.run
BADGING = "package: name='com.anistar.tv' versionCode='7' versionName='1.2.3'\n"


class AndroidSigningTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        (self.root / "android").mkdir()
        (self.root / "pubspec.yaml").write_text("version: 1.2.3+7\n")
        self.pin = self.root / "android/signing-certificate.json"
        self.pin.write_text(json.dumps({"certificateSha256": PIN}))
        self.apk = self.root / "input.apk"
        self.archive()
        self.calls = []
        self.badging = BADGING
        self.manifest = "E: application\n"
        self.signature = f"Signer #1 certificate SHA-256 digest: {PIN}\n"
        self.unsigned_status = 1
        self.addCleanup(patch.stopall)
        patch.object(signing, "android_tool", side_effect=lambda name: name).start()
        patch.object(signing.subprocess, "run", side_effect=self.android_process).start()

    def archive(self, extra=None):
        with zipfile.ZipFile(self.apk, "w") as archive:
            archive.writestr("AndroidManifest.xml", b"synthetic manifest")
            for name, content in (extra or {}).items():
                archive.writestr(name, content)

    def android_process(self, command, **kwargs):
        self.calls.append(command)
        self.assertEqual(kwargs, {"capture_output": True, "text": True, "check": False})
        status, output = 0, ""
        if command[:3] == ["aapt", "dump", "badging"]:
            output = self.badging
        elif command[:3] == ["aapt", "dump", "xmltree"]:
            output = self.manifest
        elif command[:2] == ["apksigner", "verify"]:
            if "--print-certs" in command:
                output = self.signature
            else:
                status = self.unsigned_status
        else:
            self.fail(f"Unexpected Android tool command: {command}")
        return subprocess.CompletedProcess(command, status, output, "")

    def test_verified_signed_and_unsigned_modes(self):
        signing.verify(self.apk, "local", self.root)
        self.assertIn("--print-certs", self.calls[-1])
        signing.verify(self.apk, "unsigned", self.root)
        self.assertEqual(self.calls[-1][:2], ["apksigner", "verify"])
        self.assertNotIn("--print-certs", self.calls[-1])

    def test_metadata_rejects_wrong_application_version_and_release_flags(self):
        for badging in (BADGING.replace("com.anistar.tv'", "com.anistar.tv.dev'"),
                        BADGING.replace("com.anistar.tv'", "com.anistar.anistar_tv'"),
                        BADGING.replace("versionCode='7'", "versionCode='8'"),
                        BADGING.replace("1.2.3", "1.2.4"), "unparseable",
                        BADGING + "application-debuggable\n", BADGING + "application-testOnly\n"):
            with self.subTest(badging=badging):
                self.badging = badging
                with self.assertRaises(ValueError):
                    signing.verify(self.apk, "local", self.root)
        self.badging = BADGING
        for flag in ("debuggable", "testOnly"):
            for value in ("(type 0x12)0xffffffff", "@0x7f010001", "(type 0x10)0x0"):
                self.manifest = f"A: android:{flag}(0x01010000)={value}\n"
                with self.subTest(flag=flag, value=value), self.assertRaises(ValueError):
                    signing.verify(self.apk, "local", self.root)
        self.manifest = "A: android:debuggable(0x01010000)=(type 0x12)0x0\n"
        signing.verify_metadata(self.apk, self.root, "aapt")

    def test_malformed_duplicate_and_corrupt_archives_fail_before_tools(self):
        self.apk.write_bytes(b"not a zip")
        with self.assertRaises(zipfile.BadZipFile):
            signing.verify(self.apk, "local", self.root)
        self.archive({"classes.dex": b"payload"})
        data = self.apk.read_bytes().replace(b"payload", b"damaged")
        self.apk.write_bytes(data)
        with self.assertRaises(ValueError):
            signing.verify(self.apk, "local", self.root)
        with zipfile.ZipFile(self.apk, "w") as archive:
            archive.writestr("classes.dex", b"missing manifest")
        with self.assertRaises(ValueError):
            signing.verify(self.apk, "local", self.root)
        with contextlib.redirect_stderr(io.StringIO()):
            with zipfile.ZipFile(self.apk, "w") as archive:
                archive.writestr("AndroidManifest.xml", b"one")
                archive.writestr("AndroidManifest.xml", b"two")
        with self.assertRaises(ValueError):
            signing.verify(self.apk, "local", self.root)
        self.assertEqual(self.calls, [])

    def test_single_signer_pin_is_required_and_normalized(self):
        self.signature = "Signer #1 certificate SHA-256 digest: " + ":".join(["ab"] * 32) + "\n"
        signing.verify_signature(self.apk, self.root, "apksigner")
        for output in ("", self.signature.replace("#1", "#2"),
                       self.signature + self.signature.replace("#1", "#2"),
                       self.signature.replace("ab", "cd")):
            self.signature = output
            with self.subTest(output=output), self.assertRaises(ValueError):
                signing.verify_signature(self.apk, self.root, "apksigner")

    def test_bad_or_missing_trusted_pin_rejected(self):
        for value in ({}, [], {"certificateSha256": "bad"}, {"certificateSha256": 42}):
            self.pin.write_text(json.dumps(value))
            with self.subTest(value=value), self.assertRaises(ValueError):
                signing.verify(self.apk, "local", self.root)
        self.pin.unlink()
        with self.assertRaises(OSError):
            signing.verify(self.apk, "local", self.root)

    def test_rejects_v1_signatures_signing_blocks_and_valid_existing_signature(self):
        for entry in ("META-INF/CERT.RSA", "meta-inf/cert.sf", "META-INF/CERT.EC", "META-INF/CERT.DSA"):
            self.archive({entry: b"synthetic signature marker"})
            with self.subTest(entry=entry), self.assertRaises(ValueError):
                signing.require_unsigned(self.apk, "apksigner")
        self.archive()
        data = self.apk.read_bytes()
        eocd = data.rfind(b"PK\x05\x06")
        central = struct.unpack_from("<I", data, eocd + 16)[0]
        data = bytearray(data[:central] + b"APK Sig Block 42" + data[central:])
        struct.pack_into("<I", data, eocd + 16 + 16, central + 16)
        self.apk.write_bytes(data)
        with self.assertRaisesRegex(ValueError, "signing block"):
            signing.require_unsigned(self.apk, "apksigner")
        self.archive()
        self.unsigned_status = 0
        with self.assertRaisesRegex(ValueError, "already signed"):
            signing.require_unsigned(self.apk, "apksigner")

    def test_tool_failure_suppresses_raw_diagnostics(self):
        with patch.object(signing.subprocess, "run", return_value=subprocess.CompletedProcess(
                ["apksigner"], 1, "private signing input", "private diagnostic")):
            with self.assertRaises(ValueError) as error:
                signing.run_tool(["apksigner"])
        self.assertNotIn("private", str(error.exception))

    def test_cli_rejects_removed_sign_command_and_unknown_modes_before_tools(self):
        for arguments in (["sign"], ["verify", "--apk", str(self.apk), "--mode", "ci"]):
            with self.subTest(arguments=arguments), patch.object(sys, "argv", ["android_signing.py", *arguments]):
                with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as error:
                    signing.main()
                self.assertEqual(error.exception.code, 2)
        self.assertEqual(self.calls, [])

    def test_cli_defaults_to_local_and_accepts_explicit_unsigned(self):
        for mode in ("local", "unsigned"):
            arguments = ["android_signing.py", "verify", "--apk", str(self.apk)]
            if mode == "unsigned":
                arguments.extend(["--mode", mode])
            with self.subTest(mode=mode), patch.object(sys, "argv", arguments):
                with patch.object(signing, "verify") as verify, contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(signing.main(), 0)
                verify.assert_called_once_with(self.apk, mode)

    def test_cli_failure_redacts_tool_details_and_private_paths(self):
        with patch.object(sys, "argv", ["android_signing.py", "verify", "--apk", str(self.apk)]):
            output = io.StringIO()
            with patch.object(signing, "verify", side_effect=ValueError("private tool diagnostic")):
                with contextlib.redirect_stderr(output):
                    self.assertEqual(signing.main(), 1)
            self.assertNotIn("private", output.getvalue())
            self.assertNotIn(str(self.apk), output.getvalue())

    def test_signing_material_is_ignored_at_root_and_nested_paths(self):
        # check-ignore does not open or create any file at these synthetic paths.
        paths = ["key.properties", "android/key.properties", "nested/key.properties",
                 "synthetic.jks", "nested/synthetic.jks", "synthetic.keystore", "nested/synthetic.keystore"]
        result = RUN_PROCESS(["git", "check-ignore", "--no-index", "--", *paths],
                                cwd=signing.ROOT, capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertCountEqual(result.stdout.splitlines(), paths)


if __name__ == "__main__":
    unittest.main()
