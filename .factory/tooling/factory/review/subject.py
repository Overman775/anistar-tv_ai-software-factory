"""Capture a review subject and check the accepted checkout at each transition."""

import subprocess
import tarfile
import tempfile
from collections.abc import Iterable, Iterator
from contextlib import contextmanager
from hashlib import sha256
from pathlib import Path
from typing import Any

from factory import file_reader
from factory.graphs.definition import closure, load
from factory.project.project import review_snapshot
from factory.review.protocol.artifact_io import load_object
from factory.review.protocol.contracts import validate_manifest
from factory.review.protocol.diff import load_diff_context
from factory.review.protocol.plan import prepare
from factory.runtime.workflow_config import default_profile
from factory.runtime.workflow_core import require


def hashes(paths: Iterable[str]) -> dict[str, str | None]:
    return {
        p: sha256(file_reader.read_bytes(Path(p))).hexdigest() if Path(p).is_file() else None
        for p in sorted(set(paths))
    }


def accepted_graph(manifest: dict[str, Any], factory_root: Path) -> dict[str, str]:
    feature = manifest["mode"] == "feature"
    if feature and not factory_root.resolve().is_relative_to(Path.cwd()):
        return load(factory_root / "graphs", "code-review")
    base = "HEAD" if feature else manifest["base_sha"]

    def blob(revision: str, path: str) -> subprocess.CompletedProcess[bytes]:
        return subprocess.run(
            ["git", "show", f"{revision}:./{path}"], capture_output=True, check=False
        )

    entry = ".factory/graphs/code-review.yaml"
    if blob(base, entry).returncode:
        # The delivery may be untracked in the consumer. Only accept an independent
        # installation if the candidate introduces the entry itself.
        if feature:
            require(
                not any(p.startswith(".factory/graphs/") for p in manifest["scope_files"]),
                "Use an accepted factory checkout to review untracked graph definitions",
            )
        require(
            blob("HEAD", entry).returncode or not factory_root.resolve().is_relative_to(Path.cwd()),
            "Use an accepted factory checkout for the new review graph",
        )
        return load(factory_root / "graphs", "code-review")

    def read(name: str) -> str:
        raw = blob(base, ".factory/graphs/" + name + ".yaml")
        require(raw.returncode == 0, f"Missing accepted review graph {name}")
        return raw.stdout.decode()

    return closure("code-review", read)


def accepted_revision(manifest: dict[str, Any], factory_root: Path) -> str | None:
    root = Path.cwd().resolve()
    if manifest["mode"] in {"branch", "pr"}:
        revision = str(manifest["base_sha"])
        policy = review_snapshot(root, revision)
        require(
            policy == manifest["project_policy"], "Review policy differs from accepted Git revision"
        )
    else:
        head = subprocess.run(
            ["git", "rev-parse", "--verify", "HEAD"], check=False, capture_output=True, text=True
        )
        if head.returncode:
            return None
        revision = head.stdout.strip()
        require(revision == manifest["head_sha"], "Feature review requires the current Git head")
        if (
            subprocess.run(
                ["git", "cat-file", "-e", revision + ":./.factory/project/project.yaml"],
                check=False,
                capture_output=True,
            ).returncode
            == 0
        ):
            require(
                review_snapshot(root, revision) == manifest["project_policy"],
                "Feature review policy differs from accepted Git revision",
            )
    if factory_root.resolve().is_relative_to(root):
        protected = (
            ".factory/tooling/",
            ".factory/contracts/",
            ".factory/roles/",
            ".factory/gates/",
            ".factory/skills/factory-code-review/",
            ".factory/adapters/",
        )
        changed = (
            subprocess.check_output(
                ["git", "diff", "--relative", "--name-only", "-z", revision, "--", ".factory/"]
            )
            .decode()
            .split("\0")
        )
        tracked = set(
            subprocess.check_output(["git", "ls-files", "-z", "--", ".factory"])
            .decode()
            .split("\0")
        )
        untracked_scope = set(manifest["scope_files"]) - tracked
        require(
            not any(
                p.startswith(protected) or p == ".factory/factory.yaml"
                for p in [*changed, *untracked_scope]
            ),
            "Run review with an independent accepted factory installation for changed review tooling",
        )
    return revision


@contextmanager
def command_arguments(revision: str | None, argv: list[str], cwd: str) -> Iterator[list[str]]:
    """Run project-local check programs from the accepted tree, with candidate data as cwd."""
    root = Path.cwd().resolve()
    if revision is None:
        yield argv
        return
    directory = (root / cwd).resolve()
    executable = Path(argv[0])
    scripts = [0] if executable.is_absolute() or "/" in argv[0] else []
    if (
        executable.name.startswith(("python", "ruby", "node", "perl", "bash", "zsh"))
        or executable.name == "sh"
    ):
        arguments = iter(enumerate(argv[1:], start=1))
        for index, argument in arguments:
            if argument in {"-c", "-e", "-m", "--eval", "--print"}:
                break
            if argument in {"-W", "-X", "--require", "-r"}:
                next(arguments, None)
            elif not argument.startswith("-"):
                scripts.append(index)
                break
    paths = {}
    for index in scripts:
        file = (directory / argv[index]).absolute()
        require(
            ".." not in file.parts or file.resolve().is_relative_to(root),
            "Check program escapes the reviewed workspace",
        )
        if file.is_relative_to(root):
            paths[index] = file.relative_to(root)
    if not paths:
        yield argv
        return
    prefix = (
        subprocess.check_output(["git", "rev-parse", "--show-prefix"], text=True)
        .strip()
        .rstrip("/")
    )
    tree = revision + ":" + prefix if prefix else revision
    with tempfile.TemporaryDirectory(prefix="factory-accepted-review-") as temporary:
        directory = Path(temporary).resolve()
        archive = directory / "tools.tar"
        subprocess.run(
            ["git", "archive", "--format=tar", "--output", str(archive), tree],
            check=True,
            capture_output=True,
        )
        installed = directory / "accepted"
        installed.mkdir()
        with tarfile.open(archive) as bundle:
            bundle.extractall(installed, filter="data")
        effective = list(argv)
        for index, path in paths.items():
            program = (installed / path).resolve()
            require(
                program.is_relative_to(installed) and program.is_file(),
                f"Missing accepted check tool: {path}",
            )
            effective[index] = str(program)
        yield effective


def capture(request: Path, factory_root: Path) -> dict[str, Any]:
    manifest = prepare(
        load_object(request), default_profile(factory_root / "factory.yaml", "reviewer")
    )
    errors = validate_manifest(manifest)
    _, diff_errors = load_diff_context(manifest)
    if errors or diff_errors:
        raise ValueError("; ".join(errors + diff_errors))
    if manifest["mode"] in {"pr", "branch"}:
        head = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
        dirty = subprocess.check_output(
            ["git", "status", "--porcelain", "--untracked-files=no"], text=True
        )
        if head != manifest["head_sha"] or dirty:
            raise ValueError(
                "review needs clean checkout at pinned head; preserve user work and use a separate checkout"
            )
    if manifest["mode"] in {"pr", "branch"}:
        actual = subprocess.check_output(
            [
                "git",
                "diff",
                "--no-ext-diff",
                "--no-color",
                manifest["base_sha"] + "..." + manifest["head_sha"],
            ]
        )
        if actual != file_reader.read_bytes(Path(manifest["diff_file"])):
            raise ValueError(
                "diff differs from reviewed Git comparison; capture canonical git diff"
            )
    for p, value in manifest["source_evidence"].items():
        if (
            not Path(p).is_file()
            or file_reader.read_text(Path(p), encoding="utf-8") != value["content"]
        ):
            raise ValueError("source evidence does not match reviewed checkout")
    revision = accepted_revision(manifest, factory_root)
    paths = list(manifest["scope_files"]) + list(manifest["source_evidence"])
    for c in manifest["checks"]:
        for p in c["execution"].get("inputs", []):
            if not Path(p).is_file():
                raise ValueError(f"missing check input: {p}")
            paths.append(p)
    paths += [
        str(p.resolve())
        for directory, pattern in [
            ("contracts/common", "*.md"),
            ("skills/factory-code-review/references", "*.md"),
        ]
        for p in (factory_root / directory).glob(pattern)
    ]
    paths += [
        str((factory_root / p).resolve())
        for p in [
            "factory.yaml",
            "roles/reviewer.md",
            "contracts/reviewer.md",
            "gates/roles/reviewer.md",
            "gates/common/verification-rules.md",
            "tooling/factory/context/context.py",
            "tooling/factory/checks/command.py",
            "tooling/factory/runtime/commands/process.py",
            "skills/factory-code-review/SKILL.md",
        ]
    ]
    paths += [str(p.resolve()) for p in (factory_root / "tooling/factory").rglob("*.py")]
    paths.extend(
        str(factory_root / path)
        for path in ("tooling/bootstrap.py", "tooling/bin/cli", "tooling/bin/cli.cmd")
    )
    paths.append(str(Path(__file__).resolve()))
    if manifest.get("diff_file"):
        paths.append(manifest["diff_file"])
    return {
        "manifest": manifest,
        "files": hashes(paths),
        "workspace": str(Path.cwd().resolve()),
        "tool_revision": revision,
    }


def fresh(subject: dict[str, Any]) -> dict[str, Any]:
    manifest = subject["manifest"]
    if Path.cwd().resolve() != Path(subject["workspace"]):
        raise ValueError("Open the reviewed workspace")
    if hashes(subject["files"]) != subject["files"]:
        raise ValueError("review source drift; start a new run")
    if manifest["mode"] in {"pr", "branch"}:
        if subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip() != manifest[
            "head_sha"
        ] or subprocess.check_output(
            ["git", "status", "--porcelain", "--untracked-files=no"], text=True
        ):
            raise ValueError("review HEAD or checkout changed; new intake required")
    errors = validate_manifest(manifest)
    if errors:
        raise ValueError("; ".join(errors))
    return dict(manifest)
