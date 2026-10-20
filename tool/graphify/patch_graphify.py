"""Apply the reviewed producer patch only to the exact manifest-version sources."""
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
        print(f"graphify {version} producer patch verified (all SHA-256 hashes match)")
        return
    if args.check:
        parser.error("Producer patch is not installed")
    # The previous reviewed revision patched only the three extractor files.
    # Accept exactly that known complete revision for a corpus-policy upgrade;
    # all other mixtures remain errors. Every source hash was checked above.
    previous_revision = originals == ["detect.py"]
    if len(originals) != len(manifest["files"]) and not previous_revision:
        parser.error("Partially patched installation; restore original files before applying")
    with tempfile.TemporaryDirectory(prefix="anistar-graphify-backup-") as temp:
        reviewed_patch = here / f"graphify-{version}.patch"
        if previous_revision:
            # Use only the reviewed detect.py section. Existing extractor bytes
            # already match their exact patched hashes; never reverse/reapply.
            sections = reviewed_patch.read_text(encoding="utf-8").split("--- a/")
            corpus = ["--- a/" + section for section in sections[1:]
                      if section.startswith("detect.py\n")]
            if len(corpus) != 1:
                parser.error("Missing reviewed corpus migration patch")
            reviewed_patch = Path(temp) / "corpus.patch"
            reviewed_patch.write_text(corpus[0], encoding="utf-8")
        command = ["patch", "--batch", "--forward", "-p1", "-i", str(reviewed_patch)]
        subprocess.run(command + ["--dry-run"], cwd=package, check=True)
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
    print(f"Applied graphify {version} producer patch; full re-extraction is required")


if __name__ == "__main__":
    main()
