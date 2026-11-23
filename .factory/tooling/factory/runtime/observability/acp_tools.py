"""Summarize ACP tool notifications without retaining arguments, titles or results."""

import json
from collections import Counter
from collections.abc import Iterable, Iterator
from dataclasses import dataclass
from typing import TypeGuard

_MAX_LINE = 1024 * 1024
_MAX_CALLS = 4096
_KINDS = {
    "read",
    "edit",
    "delete",
    "move",
    "search",
    "execute",
    "think",
    "fetch",
    "switch_mode",
    "other",
}
_STATES = {"pending", "in_progress", "completed", "failed"}


@dataclass(frozen=True)
class ToolSummary:
    partial: bool
    counts: Counter[tuple[str, str]]


def _lines(chunks: Iterable[bytes]) -> Iterator[bytes | None]:
    """A None marks one oversized line. Recover at the next newline."""
    pending = bytearray()
    skipping = False
    for chunk in chunks:
        parts = chunk.split(b"\n")
        for index, part in enumerate(parts):
            if not skipping:
                if len(pending) + len(part) <= _MAX_LINE:
                    pending.extend(part)
                else:
                    pending.clear()
                    skipping = True
                    yield None
            if index < len(parts) - 1:
                if pending:
                    yield bytes(pending)
                    pending.clear()
                skipping = False
    if pending:
        yield bytes(pending)


def _identifier(value: object) -> TypeGuard[str]:
    return isinstance(value, str) and 0 < len(value) <= 512


def summarize_tools(chunks: Iterable[bytes]) -> ToolSummary:
    calls: dict[tuple[str, str], tuple[str, str]] = {}
    partial = False
    for line in _lines(chunks):
        if line is None:
            partial = True
            continue
        try:
            message = json.loads(line)
        except ValueError, RecursionError:
            partial = True
            continue
        if (
            not isinstance(message, dict)
            or message.get("jsonrpc") != "2.0"
            or message.get("method") != "session/update"
        ):
            continue
        params = message.get("params")
        if not isinstance(params, dict):
            continue
        update = params.get("update")
        if not isinstance(update, dict) or update.get("sessionUpdate") not in (
            "tool_call",
            "tool_call_update",
        ):
            continue
        session, call = params.get("sessionId"), update.get("toolCallId")
        if not _identifier(session) or not _identifier(call):
            partial = True
            continue
        key = (session, call)
        if key not in calls and len(calls) >= _MAX_CALLS:
            partial = True
            continue
        kind, status = calls.get(key, ("unknown", "unknown"))
        observed_kind, observed_status = update.get("kind"), update.get("status")
        if isinstance(observed_kind, str) and observed_kind in _KINDS:
            kind = observed_kind
        if isinstance(observed_status, str) and observed_status in _STATES:
            status = observed_status
        calls[key] = kind, status
    return ToolSummary(partial, Counter(calls.values()))
