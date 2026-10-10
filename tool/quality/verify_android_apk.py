"""Verify that an APK packages the AOT libraries from the current Flutter build."""

import argparse
import hashlib
from pathlib import Path
import zipfile


def verify(apk: Path, intermediates: Path, variant: str) -> int:
    compiled = intermediates / "flutter" / variant
    variant_task = variant[0].upper() + variant[1:]
    merge_task = f"merge{variant[0].upper()}{variant[1:]}JniLibFolders"
    strip_task = f"strip{variant[0].upper()}{variant[1:]}DebugSymbols"
    # Flutter 3.47 stages app.so in generated/jniLibs, outside Flutter task
    # outputs. Compare against the original AOT file, not only its staged copy.
    libraries = sorted(compiled.glob("*/app.so"))
    modern_layout = bool(libraries)
    if not modern_layout:
        libraries = sorted((compiled / "jniLibs").glob("*/libapp.so"))
    if not libraries:
        raise ValueError(f"No compiled AOT libraries in {compiled}")
    with zipfile.ZipFile(apk) as archive:
        packaged_abis = {
            name.split("/")[1] for name in archive.namelist()
            if name.startswith("lib/") and name.endswith("/libapp.so") and len(name.split("/")) == 3
        }
        compiled_abis = {library.parent.name for library in libraries}
        if packaged_abis != compiled_abis:
            raise ValueError(f"APK/AOT ABI mismatch: APK={sorted(packaged_abis)}, AOT={sorted(compiled_abis)}")
        for library in libraries:
            abi = library.parent.name
            if modern_layout:
                staged = intermediates.parent / "generated" / "jniLibs" / f"copyJniLibsflutterBuild{variant_task}" / abi / "libapp.so"
                if library.read_bytes() != staged.read_bytes():
                    raise ValueError(f"Stale JNI staging for {abi}: Flutter copy used an older Dart library")
            merged = intermediates / "merged_jni_libs" / variant / merge_task / "out" / abi / "libapp.so"
            stripped = intermediates / "stripped_native_libs" / variant / strip_task / "out" / "lib" / abi / "libapp.so"
            if library.read_bytes() != merged.read_bytes():
                raise ValueError(f"Stale JNI merge for {abi}: APK build used an older Dart library")
            if stripped.read_bytes() != archive.read(f"lib/{abi}/libapp.so"):
                raise ValueError(f"Stale APK library for {abi}: packaged bytes differ from stripped output")
    return len(libraries)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--variant", default="prodRelease")
    parser.add_argument("--apk", type=Path, default=Path("build/app/outputs/flutter-apk/app-prod-release.apk"))
    arguments = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    count = verify(arguments.apk, root / "build/app/intermediates", arguments.variant)
    digest = hashlib.sha256(arguments.apk.read_bytes()).hexdigest()
    print(f"APK matches current AOT output for {count} ABIs; SHA256 {digest}")


if __name__ == "__main__":
    main()
