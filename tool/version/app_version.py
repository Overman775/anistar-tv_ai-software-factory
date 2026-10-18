"""Plan or explicitly edit the app version. Never invokes Git or a registry."""

import argparse
from pathlib import Path
import re


SEMVER = r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"
VERSION_LINE = re.compile(rf"^version: ({SEMVER})\+([1-9][0-9]*)$", re.MULTILINE)
README_VERSION = re.compile(r"(Текущая версия: \*\*)[0-9]+\.[0-9]+\.[0-9]+(\*\*)")


def read_version(root: Path) -> tuple[tuple[int, int, int], int]:
    matches = list(VERSION_LINE.finditer((root / "pubspec.yaml").read_text()))
    if len(matches) != 1:
        raise ValueError("Expected one stable version: X.Y.Z+N with positive build number")
    match = matches[0]
    return tuple(int(match[i]) for i in (2, 3, 4)), int(match[5])


def validate(root: Path) -> tuple[tuple[int, int, int], int]:
    version, build = read_version(root)
    text = ".".join(map(str, version))
    if f"Текущая версия: **{text}**" not in (root / "README.md").read_text():
        raise ValueError("README current version disagrees with pubspec.yaml")
    return version, build


def proposed(current: tuple[int, int, int], bump: str) -> tuple[int, int, int]:
    major, minor, patch = current
    return {"patch": (major, minor, patch + 1), "minor": (major, minor + 1, 0),
            "major": (major + 1, 0, 0), "build": current}[bump]


def set_version(root: Path, text: str, build: int, write: bool = False) -> str:
    current, previous_build = validate(root)
    if not re.fullmatch(SEMVER, text):
        raise ValueError("Version must be stable X.Y.Z without leading zeros")
    version = tuple(map(int, text.split(".")))
    if version < current or build <= previous_build:
        raise ValueError("Version must not decrease; build number must strictly increase")
    result = f"{text}+{build}"
    manifest = root / "pubspec.yaml"
    readme = root / "README.md"
    manifest_text = VERSION_LINE.sub(f"version: {result}", manifest.read_text())
    readme_text, count = README_VERSION.subn(rf"\g<1>{text}\g<2>", readme.read_text())
    if count != 1:
        raise ValueError("Expected exactly one README current version")
    if write:
        manifest.write_text(manifest_text)
        readme.write_text(readme_text)
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("show")
    sub.add_parser("check")
    plan = sub.add_parser("plan")
    plan.add_argument("bump", choices=("patch", "minor", "major", "build"))
    edit = sub.add_parser("set")
    edit.add_argument("--app-version", required=True)
    edit.add_argument("--build-number", type=int, required=True)
    edit.add_argument("--write", action="store_true", help="Explicitly write pubspec and README; default is dry-run")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    try:
        version, build = validate(root)
        current = f'{".".join(map(str, version))}+{build}'
        if args.command == "plan":
            next_version = ".".join(map(str, proposed(version, args.bump)))
            print(f"Dry-run: {current} -> {next_version}+{build + 1}")
        elif args.command == "set":
            result = set_version(root, args.app_version, args.build_number, args.write)
            print(f'{"Updated" if args.write else "Dry-run"}: {current} -> {result}')
        else:
            print(f"App version: {current}; README agrees")
    except (ValueError, OSError) as error:
        parser.exit(1, f"Version error: {error}\n")


if __name__ == "__main__":
    main()
