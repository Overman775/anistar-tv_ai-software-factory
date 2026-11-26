"""Stream evidence and recover interrupted transport calls under the checkout lock."""

from hashlib import file_digest
from pathlib import Path

from factory import file_reader
from factory.runtime.contracts import State
from factory.runtime.transport import streams as transport_streams
from factory.runtime.workflow_core import lock, relative, require


def file_hash(path: Path) -> str:
    with file_reader.open_binary(path) as stream:
        return file_digest(stream, "sha256").hexdigest()


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


def pending_transports(
    root: Path, state: State, *, dispatch_id: str | None = None, mutating_only: bool = False
) -> dict[str, tuple[str, str, str]]:
    """Check unfinished ACPX calls while the ledger is locked and identify recoverable streams."""
    pending = {}
    for event in state["events"]:
        if dispatch_id is not None and event.get("dispatch_id") != dispatch_id:
            continue
        stdout = event.get("stdout")
        if not stdout:
            continue
        if event["event"] == "transport_requested":
            pending[stdout] = event
        elif event["event"] in {"transport_interrupted", "transport_returned"}:
            pending.pop(stdout, None)
    streams = {}
    for stdout, event in pending.items():
        if mutating_only and event.get("operation") not in {"create", "prompt", "cancel", "close"}:
            continue
        require(stdout in state.get("transport_artifacts", []), "Unknown transport output")
        lease = relative(root, stdout + ".lock")
        if lease.exists():
            with lock(lease):
                pass
            if dispatch_id is None:
                lease.unlink(missing_ok=True)
        for kind, name in (("stdout", stdout), ("stderr", event["stderr"])):
            transport_streams.require_idle(relative(root, name))
            streams[name] = (kind, event["node"], event["dispatch_id"])
    return streams
