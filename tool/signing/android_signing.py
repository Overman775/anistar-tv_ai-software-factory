"""Verify local production APK metadata and the public signing certificate pin."""

import argparse
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import zipfile


ROOT = Path(__file__).resolve().parents[2]
APPLICATION_ID = "com.anistar.tv"


def run_tool(command: list[str], *, allow_failure: bool = False) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if result.returncode and not allow_failure:
        # Tool diagnostics can include signing configuration; never forward them.
        raise ValueError("Android tool failed; check tool installation and signing inputs")
    return result


def android_tool(name: str) -> str:
    sdk = Path(os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
               or Path.home() / "Library/Android/sdk")
    candidates = [p for p in (sdk / "build-tools").glob(f"*/{name}") if p.is_file()]
    if not candidates:
        raise ValueError("Required Android SDK build-tools are unavailable")
    # Prefer the newest stable build-tools without relying on lexical ordering.
    stable = [p for p in candidates if re.fullmatch(r"\d+(?:\.\d+)+", p.parent.name)]
    if not stable:
        raise ValueError("Stable Android SDK build-tools are unavailable")
    return str(max(stable, key=lambda p: tuple(int(n) for n in p.parent.name.split("."))))


def expected_version(root: Path) -> tuple[str, str]:
    match = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+([1-9]\d*)\s*$",
                      (root / "pubspec.yaml").read_text(encoding="utf-8"), re.MULTILINE)
    if match is None:
        raise ValueError("Root pubspec version is invalid")
    return match.group(1), match.group(2)


def certificate_pin(root: Path) -> str:
    value = json.loads((root / "android/signing-certificate.json").read_text(encoding="utf-8"))
    pin = value.get("certificateSha256") if isinstance(value, dict) else None
    if not isinstance(pin, str):
        raise ValueError("Trusted public signing pin is missing")
    pin = pin.replace(":", "").upper()
    if re.fullmatch(r"[0-9A-F]{64}", pin) is None:
        raise ValueError("Trusted public signing pin is invalid")
    return pin


def verify_metadata(apk: Path, root: Path, aapt: str) -> None:
    with zipfile.ZipFile(apk) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)) or "AndroidManifest.xml" not in names:
            raise ValueError("Malformed APK archive")
        if archive.testzip() is not None:
            raise ValueError("Corrupt APK archive")
    badging = run_tool([aapt, "dump", "badging", str(apk)]).stdout
    package = re.search(r"^package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'",
                        badging, re.MULTILINE)
    version_name, version_code = expected_version(root)
    if package is None or package.groups() != (APPLICATION_ID, version_code, version_name):
        raise ValueError("APK application ID or version does not match production pubspec")
    manifest = run_tool([aapt, "dump", "xmltree", str(apk), "AndroidManifest.xml"]).stdout
    # Absence means false. Reject non-literal or resource-valued attributes too.
    for line in manifest.splitlines():
        if re.search(r"\bandroid:(?:debuggable|testOnly)\(", line):
            if re.search(r"=\(type 0x12\)0x0\s*$", line) is None:
                raise ValueError("APK is debuggable, testOnly, or has unresolved release flags")
    if "application-debuggable" in badging or "application-testOnly" in badging:
        raise ValueError("APK is not a production release")


def require_unsigned(apk: Path, apksigner: str) -> None:
    with zipfile.ZipFile(apk) as archive:
        if any(re.fullmatch(r"META-INF/[^/]+\.(?:SF|RSA|DSA|EC)", name, re.IGNORECASE)
               for name in archive.namelist()):
            raise ValueError("Input APK already contains signature entries")
        # The signing block precedes the ZIP central directory. Reject it even
        # when verification fails (for example a damaged existing signature).
        with apk.open("rb") as stream:
            tail_size = min(apk.stat().st_size, 65557)
            stream.seek(-tail_size, 2)
            tail = stream.read()
            eocd = tail.rfind(b"PK\x05\x06")
            if eocd < 0 or eocd + 22 > len(tail):
                raise ValueError("Malformed APK ZIP directory")
            central_offset = struct.unpack_from("<I", tail, eocd + 16)[0]
            if central_offset >= 16:
                stream.seek(central_offset - 16)
                if stream.read(16) == b"APK Sig Block 42":
                    raise ValueError("Input APK already contains an APK signing block")
    if run_tool([apksigner, "verify", str(apk)], allow_failure=True).returncode == 0:
        raise ValueError("Input APK is already signed")


def verify_signature(apk: Path, root: Path, apksigner: str) -> None:
    output = run_tool([apksigner, "verify", "--verbose", "--print-certs", str(apk)]).stdout
    signers = re.findall(r"^Signer #(\d+) certificate SHA-256 digest: ([0-9a-fA-F:]+)\s*$",
                         output, re.MULTILINE)
    if len(signers) != 1 or signers[0][0] != "1":
        raise ValueError("APK must have exactly one signer")
    if signers[0][1].replace(":", "").upper() != certificate_pin(root):
        raise ValueError("APK signer does not match trusted production certificate")


def verify(apk: Path, mode: str, root: Path = ROOT) -> None:
    verify_metadata(apk, root, android_tool("aapt"))
    apksigner = android_tool("apksigner")
    if mode == "unsigned":
        require_unsigned(apk, apksigner)
    else:
        verify_signature(apk, root, apksigner)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    verification = commands.add_parser("verify")
    verification.add_argument("--apk", type=Path, required=True)
    verification.add_argument("--mode", choices=("local", "unsigned"), default="local")
    args = parser.parse_args()
    try:
        verify(args.apk, args.mode)
        print("Production APK verification passed")
    except (OSError, ValueError, zipfile.BadZipFile, struct.error):
        # Do not expose private paths or subprocess output.
        print("Android APK verification failed; check trusted inputs and Android build-tools", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
