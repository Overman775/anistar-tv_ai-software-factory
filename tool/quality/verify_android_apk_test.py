"""Regressions for stale native libraries observed in incremental APK builds."""

from pathlib import Path
import tempfile
import unittest
import zipfile

from verify_android_apk import verify


class ApkVerificationTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="anistar-apk-test-")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name) / "app" / "intermediates"
        self.apk = self.root / "app.apk"
        self.compiled = self.root / "flutter/prodRelease/jniLibs/arm64-v8a/libapp.so"
        self.merged = self.root / "merged_jni_libs/prodRelease/mergeProdReleaseJniLibFolders/out/arm64-v8a/libapp.so"
        self.stripped = self.root / "stripped_native_libs/prodRelease/stripProdReleaseDebugSymbols/out/lib/arm64-v8a/libapp.so"
        for file, content in [(self.compiled, b"new-aot"), (self.merged, b"new-aot"), (self.stripped, b"stripped-aot")]:
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_bytes(content)
        self.write_apk(b"stripped-aot")

    def write_apk(self, library):
        with zipfile.ZipFile(self.apk, "w") as archive:
            archive.writestr("lib/arm64-v8a/libapp.so", library)

    def test_accepts_current_build_after_symbol_stripping(self):
        self.assertEqual(verify(self.apk, self.root, "prodRelease"), 1)

    def test_rejects_old_merge_even_if_the_apk_matches_old_stripped_output(self):
        self.merged.write_bytes(b"old-aot")
        with self.assertRaisesRegex(ValueError, "Stale JNI merge"):
            verify(self.apk, self.root, "prodRelease")

    def test_rejects_apk_with_an_older_library(self):
        self.write_apk(b"old-aot")
        with self.assertRaisesRegex(ValueError, "Stale APK library"):
            verify(self.apk, self.root, "prodRelease")

    def modern_layout(self):
        aot = self.root / "flutter/prodRelease/arm64-v8a/app.so"
        aot.parent.mkdir(parents=True, exist_ok=True)
        aot.write_bytes(self.compiled.read_bytes())
        self.compiled.unlink()
        staged = self.root.parent / "generated/jniLibs/copyJniLibsflutterBuildProdRelease/arm64-v8a/libapp.so"
        staged.parent.mkdir(parents=True, exist_ok=True)
        staged.write_bytes(aot.read_bytes())
        return aot, staged

    def test_accepts_modern_aot_and_independent_staging(self):
        self.modern_layout()
        self.assertEqual(verify(self.apk, self.root, "prodRelease"), 1)

    def test_rejects_stale_staging_even_when_merge_and_apk_agree(self):
        _, staged = self.modern_layout()
        staged.write_bytes(b"old-aot")
        self.merged.write_bytes(b"old-aot")
        with self.assertRaisesRegex(ValueError, "Stale JNI staging"):
            verify(self.apk, self.root, "prodRelease")

    def test_rejects_an_unverified_abi_in_the_apk(self):
        self.modern_layout()
        with zipfile.ZipFile(self.apk, "a") as archive:
            archive.writestr("lib/x86_64/libapp.so", b"old-aot")
        with self.assertRaisesRegex(ValueError, "ABI mismatch"):
            verify(self.apk, self.root, "prodRelease")

    def test_rejects_an_aot_abi_missing_from_the_apk(self):
        aot, _ = self.modern_layout()
        extra = aot.parent.parent / "x86_64/app.so"
        extra.parent.mkdir(parents=True)
        extra.write_bytes(b"new-aot")
        with self.assertRaisesRegex(ValueError, "ABI mismatch"):
            verify(self.apk, self.root, "prodRelease")

    def test_rejects_missing_aot_outputs(self):
        self.compiled.unlink()
        with self.assertRaisesRegex(ValueError, "No compiled AOT"):
            verify(self.apk, self.root, "prodRelease")


if __name__ == "__main__":
    unittest.main()
