"""Prepare checkout-local Graphify state using an existing compatible installation."""
import argparse
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[2]


def _venv_python(directory):
    for relative in ("bin/python", "Scripts/python.exe"):
        candidate = directory / relative
        if candidate.is_file():
            return str(candidate.absolute())
    return None


def _cli_python(cli):
    # Resolve the CLI symlink, not the Python symlink: resolving a venv Python
    # loses its pyvenv.cfg and silently selects the base interpreter instead.
    executable = Path(cli).resolve()
    sibling = executable.parent / ("python.exe" if os.name == "nt" else "python")
    if sibling.is_file():
        return str(sibling)
    try:
        with executable.open("rb") as source:
            first = source.readline(4096).decode("utf-8").strip()
        if first.startswith("#!"):
            command = shlex.split(first[2:])
            if command and Path(command[0]).name == "env":
                command = command[1:]
                if command[:1] == ["-S"]:
                    command = command[1:]
                if len(command) == 1:
                    return shutil.which(command[0])
            elif len(command) == 1:
                return command[0]
    except (OSError, UnicodeError, ValueError):
        pass
    return None


def resolve_python(root=ROOT):
    """Return the selected interpreter, or None only when Graphify is absent."""
    override = os.environ.get("ANISTAR_GRAPHIFY_PYTHON")
    if override is not None:
        if not override.strip():
            raise ValueError("ANISTAR_GRAPHIFY_PYTHON is empty")
        return override
    sidecar = root / "graphify-out/.graphify_python"
    if sidecar.exists():
        configured = sidecar.read_text(encoding="utf-8").strip()
        if not configured:
            raise ValueError("graphify-out/.graphify_python is empty")
        return configured
    cli = shutil.which("graphify")
    if cli:
        interpreter = _cli_python(cli)
        if interpreter:
            return interpreter
        raise ValueError("Installed graphify CLI has no resolvable Python; set ANISTAR_GRAPHIFY_PYTHON")
    # uv's persistent tool directory is safe to inspect; never create a transient
    # `uv tool run` environment, which can have another version and no patch.
    uv = shutil.which("uv")
    if uv:
        result = subprocess.run([uv, "tool", "dir"], capture_output=True, text=True)
        if result.returncode != 0:
            raise ValueError("Cannot inspect existing uv tools directory")
        directory = Path(result.stdout.strip()) / "graphifyy"
        if directory.exists():
            interpreter = _venv_python(directory)
            if interpreter:
                return interpreter
            raise ValueError("Existing graphifyy uv environment has no Python")
    # An active pip/venv install need not expose a CLI on PATH.
    result = subprocess.run(
        [sys.executable, "-c", "import importlib.util; raise SystemExit(0 if importlib.util.find_spec('graphify') else 1)"],
        capture_output=True, text=True,
    )
    if result.returncode == 0:
        return sys.executable
    if result.returncode != 1:
        raise ValueError("Cannot inspect the active Python for Graphify")
    return None


def prepare(root=ROOT, *, optional=False):
    interpreter = resolve_python(root)
    if interpreter is None:
        if optional:
            sys.stdout.write("Graphify not installed; optional Graphify checks skipped.\n")
            return None
        raise ValueError("Graphify is not installed; see tool/graphify/README.md")
    manifest = json.loads((root / "tool/graphify/patch-manifest.json").read_text(encoding="utf-8"))
    probe = subprocess.run(
        [interpreter, "-c", "import graphify, importlib.metadata, json, sys; "
         "sys.stdout.write(json.dumps({'python': sys.executable, 'version': importlib.metadata.version('graphifyy')}))"],
        capture_output=True, text=True,
    )
    if probe.returncode != 0:
        raise ValueError("Configured/installed Graphify Python cannot import graphifyy; repair it or set ANISTAR_GRAPHIFY_PYTHON")
    try:
        installation = json.loads(probe.stdout)
        actual = installation["version"]
        selected = installation["python"]
        if not isinstance(selected, str) or not Path(selected).is_absolute():
            raise ValueError()
    except (ValueError, KeyError, TypeError):
        raise ValueError("Graphify Python returned invalid installation metadata") from None
    if actual != manifest["version"]:
        raise ValueError(f"Expected graphifyy {manifest['version']}, found {actual}; use a compatible patched installation")
    # This checks hashes without installing or mutating the shared tool venv.
    subprocess.run([selected, str(root / "tool/graphify/patch_graphify.py"), "--check"],
                   cwd=root, check=True)
    output = root / "graphify-out"
    output.mkdir(exist_ok=True)
    (output / ".graphify_python").write_text(selected, encoding="utf-8")
    (output / ".graphify_root").write_text(str(root.resolve()), encoding="utf-8")
    return selected


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--optional", action="store_true", help="skip only when Graphify is not installed")
    action = parser.add_mutually_exclusive_group()
    action.add_argument("--check", action="store_true", help="also run Graphify regressions")
    action.add_argument("--update", action="store_true", help="update the graph with the validated interpreter")
    args = parser.parse_args()
    try:
        interpreter = prepare(optional=args.optional)
        if interpreter and args.check:
            subprocess.run([interpreter, "-m", "unittest", "discover", "-s", "tool/graphify", "-p", "test_*.py"],
                           cwd=ROOT, check=True)
        if interpreter and args.update:
            subprocess.run([interpreter, "-m", "graphify", "update", "."], cwd=ROOT, check=True)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        # Child import stderr can include local configuration; report the failure
        # category here rather than echoing captured data or environment values.
        message = str(error) if isinstance(error, ValueError) else "Graphify preparation or child command failed"
        sys.stderr.write(f"{message}; see tool/graphify/README.md.\n")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
