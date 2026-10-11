"""Apply the reviewed producer patch only to the exact graphify 0.9.85 sources."""
import argparse
import hashlib
import importlib.metadata
import json
import shutil
import subprocess
import tempfile
from pathlib import Path

import graphify


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="verify installed patch without writing")
    args = parser.parse_args()
    here = Path(__file__).resolve().parent
    manifest = json.loads((here / "patch-manifest.json").read_text())
    version = importlib.metadata.version(manifest["distribution"])
    if version != manifest["version"]:
        parser.error(f"Expected graphify {manifest['version']}, found {version}; review upstream before repatching")
    package = Path(graphify.__file__).resolve().parent
    originals = []
    for name, hashes in manifest["files"].items():
        actual = digest(package / name)
        if actual == hashes["original"]:
            originals.append(name)
        elif actual != hashes["patched"]:
            parser.error(f"Unrecognized installed source: {name}; no files changed")
    if not originals:
        print("graphify 0.9.85 producer patch verified (all SHA-256 hashes match)")
        return
    if args.check:
        parser.error("Producer patch is not installed")
    if len(originals) != len(manifest["files"]):
        parser.error("Partially patched installation; restore original files before applying")
    # Preflight the entire patch before changing the tool installation.
    command = ["patch", "--batch", "--forward", "-p1", "-i", str(here / "graphify-0.9.85.patch")]
    subprocess.run(command + ["--dry-run"], cwd=package, check=True)
    with tempfile.TemporaryDirectory(prefix="anistar-graphify-backup-") as temp:
        backup = Path(temp)
        for name in originals:
            dest = backup / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(package / name, dest)
        try:
            subprocess.run(command, cwd=package, check=True)
            for name, hashes in manifest["files"].items():
                if digest(package / name) != hashes["patched"]:
                    raise RuntimeError(f"Post-patch hash mismatch: {name}")
        except BaseException:
            for name in originals:
                shutil.copy2(backup / name, package / name)
            raise
    print("Applied graphify 0.9.85 producer patch; full re-extraction is required")


if __name__ == "__main__":
    main()
