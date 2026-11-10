"""Store and read a terminal run as one verified gzip-compressed tar."""

import gzip
import io
import json
import os
import re
import tarfile
import tempfile
from datetime import UTC, datetime
from hashlib import file_digest, sha256
from pathlib import Path
from typing import IO, BinaryIO

from factory_tooling.runtime.contracts import State
from factory_tooling.runtime.state_io import parse_state
from factory_tooling.runtime.workflow_core import Invalid, digest, relative, require

HISTORY = ".factory/memory/history"


def find_archive(root: Path, run_id: str) -> Path | None:
    folder = relative(root, f"{HISTORY}/archive")
    pattern = re.compile(r"\d{4}-\d{2}-\d{2}_" + re.escape(run_id) + r"\.tar\.gz")
    matches = [p for p in folder.iterdir() if pattern.fullmatch(p.name)] if folder.exists() else []
    require(len(matches) <= 1, f"Multiple archives for run {run_id}")
    return relative(root, matches[0].relative_to(root).as_posix()) if matches else None


def transport_paths(root: Path, state: State) -> list[Path]:
    directory = root / ".factory/memory/state"
    paths = []
    for name in sorted(set(state.get("transport_artifacts", []))):
        path = relative(root, name)
        require(
            path.parent == directory and path.name.startswith(state["run_id"] + "-"),
            "Invalid cleanup ownership",
        )
        require(not path.exists() or path.is_file(), "Unsafe cleanup entry")
        paths.append(path)
    return paths


def _add(tar: tarfile.TarFile, name: str, data: BinaryIO, size: int) -> None:
    info = tarfile.TarInfo(name)
    info.size = size
    info.mode = 0o600
    tar.addfile(info, data)


def _add_json(tar: tarfile.TarFile, name: str, data: object) -> str:
    body = (json.dumps(data, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    _add(tar, name, io.BytesIO(body), len(body))
    return digest(body)


def _member(tar: tarfile.TarFile, name: str) -> IO[bytes]:
    item = tar.getmember(name)
    require(item.isfile(), f"Expected a regular archive member: {name}")
    data = tar.extractfile(item)
    if data is None:
        raise Invalid(f"Missing archive member: {name}")
    return data


def _manifest(tar: tarfile.TarFile) -> dict[str, str]:
    with _member(tar, "manifest.json") as f:
        return _decode_manifest(json.load(f))


def _decode_manifest(raw: object) -> dict[str, str]:
    require(
        isinstance(raw, dict)
        and "run.json" in raw
        and all(isinstance(k, str) and isinstance(v, str) for k, v in raw.items()),
        "Invalid archive manifest",
    )
    if not isinstance(raw, dict):
        raise Invalid("Invalid archive manifest")
    return dict(raw)


def read_member(path: Path, name: str) -> bytes:
    try:
        with tarfile.open(path, "r:gz") as tar:
            expected = _manifest(tar).get(name)
            require(expected is not None, f"Archive member not registered: {name}")
            with _member(tar, name) as f:
                data = f.read()
            require(digest(data) == expected, f"Archive member digest mismatch: {name}")
            return data
    except (OSError, EOFError, KeyError, tarfile.TarError) as exc:
        raise Invalid(f"Cannot read archive {path.name}: {exc}") from exc


def _verified_manifest(path: Path, state: State) -> dict[str, str]:
    try:
        with (
            gzip.open(path, "rb") as compressed,
            tarfile.open(fileobj=compressed, mode="r|") as tar,
        ):
            observed = {}
            hashes = None
            for item in tar:
                require(item.isfile() and item.name not in observed, "Invalid archive inventory")
                data = tar.extractfile(item)
                if data is None:
                    raise Invalid(f"Missing archive member: {item.name}")
                with data:
                    if item.name == "manifest.json":
                        hashes = _decode_manifest(json.load(data))
                    elif item.name == "run.json":
                        body = data.read()
                        require(
                            parse_state(json.loads(body)) == state, "Terminal history is immutable"
                        )
                        observed[item.name] = digest(body)
                    else:
                        hashed = sha256()
                        while block := data.read(256 * 1024):
                            hashed.update(block)
                        observed[item.name] = hashed.hexdigest()
                if item.name == "manifest.json":
                    observed[item.name] = ""
            del observed["manifest.json"]
            require(hashes == observed, "Archive inventory or digest mismatch")
            # Consume the gzip footer to detect truncation even after the tar end marker.
            while compressed.read(256 * 1024):
                pass
            return observed
    except (OSError, EOFError, KeyError, tarfile.TarError) as exc:
        raise Invalid(f"Cannot verify archive {path.name}: {exc}") from exc


def pack_run(root: Path, state: State) -> Path:
    run_id = state["run_id"]
    require(re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]*", run_id), "Invalid archive run ID")
    existing = find_archive(root, run_id)
    date = datetime.now(UTC).date().isoformat()
    path = existing or relative(root, f"{HISTORY}/archive/{date}_{run_id}.tar.gz")
    state["archive_path"] = path.relative_to(root).as_posix()
    if existing is not None:
        verified_cleanup_paths(root, state)
        return path
    directory = relative(root, f"{HISTORY}/{run_id}")
    paths = transport_paths(root, state)
    for item in directory.rglob("*"):
        checked = relative(root, item.relative_to(root).as_posix())
        if not checked.is_dir():
            require(checked.is_file(), f"Cannot archive non-file: {item}")
            paths.append(checked)
    recorded_hashes = {
        receipt["output"]: receipt["output_hash"]
        for receipt in state.get("executions", {}).values()
        if "output_hash" in receipt
    }
    for dispatch in state["nodes"].values():
        packet = dispatch.get("packet_file")
        if packet is not None:
            recorded_hashes[packet["path"]] = packet["sha256"]
    recorded_hashes.update(state.get("packet_hashes", {}))
    require(
        set(recorded_hashes) <= {source.relative_to(root).as_posix() for source in paths},
        "Missing recorded run artifact",
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(prefix=".archive-", dir=path.parent)
    temp = Path(temp_name)
    try:
        with os.fdopen(fd, "wb") as output:
            with tarfile.open(fileobj=output, mode="w:gz") as tar:
                hashes = {"run.json": _add_json(tar, "run.json", state)}
                for source in paths:
                    name = source.relative_to(root).as_posix()
                    expected = recorded_hashes.get(name)
                    if not source.exists():
                        require(
                            expected is None and not source.name.endswith(".packet.json"),
                            f"Missing recorded run artifact: {name}",
                        )
                        continue  # A reserved ACP report path may never have been written.
                    with source.open("rb") as f:
                        observed = file_digest(f, "sha256").hexdigest()
                        require(
                            expected is None or expected == observed,
                            f"Recorded run artifact digest mismatch: {name}",
                        )
                        f.seek(0)
                        _add(tar, name, f, source.stat().st_size)
                    hashes[name] = observed
                _add_json(tar, "manifest.json", hashes)
            output.flush()
            os.fsync(output.fileno())
        _verified_manifest(temp, state)
        os.replace(temp, path)
        return path
    finally:
        temp.unlink(missing_ok=True)


def verified_cleanup_paths(root: Path, state: State) -> list[Path]:
    path = find_archive(root, state["run_id"])
    require(
        path is not None and path.relative_to(root).as_posix() == state.get("archive_path"),
        "History must be saved before cleanup",
    )
    assert path is not None
    transport = set(transport_paths(root, state))
    hashes = _verified_manifest(path, state)
    history = f"{HISTORY}/{state['run_id']}/"
    remove = []
    for name, expected in hashes.items():
        if name == "run.json":
            continue
        source = relative(root, name)
        require(name.startswith(history) or source in transport, "Invalid archive ownership")
        if source.exists():
            require(source.is_file(), f"Invalid archived source: {name}")
            with source.open("rb") as f:
                require(
                    file_digest(f, "sha256").hexdigest() == expected,
                    f"Source changed: {name}",
                )
            remove.append(source)
    require(
        all(not source.exists() or source in remove for source in transport),
        "Archive is missing a transport artifact",
    )
    return remove
