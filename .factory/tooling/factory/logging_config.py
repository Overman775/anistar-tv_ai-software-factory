"""Configure and close the diagnostic handler for one CLI invocation."""

import logging
import sys
from collections.abc import Iterator
from contextlib import contextmanager
from contextvars import Token
from dataclasses import dataclass
from pathlib import Path

from factory.database.provider import current_database
from factory.diagnostics.diagnostic_journal import DiagnosticJournal
from factory.diagnostics.events import current_logger, event
from factory.diagnostics.handler import Journal
from factory.diagnostics.records import error_code
from factory.runtime.observability.export_policy import logs_settings


@dataclass
class Invocation:
    handler: Journal | None
    token: Token[logging.Logger | None]


def initialize(
    workspace: str | Path, operation: str, *, store: DiagnosticJournal | None = None
) -> Invocation:
    """Bind a private logger to this invocation, including nested or concurrent CLI calls."""
    try:
        store = current_database().diagnostics if store is None else store
        handler = Journal(
            workspace,
            operation,
            store=store,
            can_export=lambda root: logs_settings(root) is not None,
        )
    except Exception:
        return Invocation(None, current_logger.set(None))
    logger = logging.Logger("factory.diagnostics.local", logging.INFO)
    logger.addHandler(handler)
    return Invocation(handler, current_logger.set(logger))


def finish(invocation: Invocation, *, failed: bool = False) -> None:
    current_logger.reset(invocation.token)
    handler = invocation.handler
    if handler is not None:
        handler.flush_pending()
        handler.close()
    try:
        if handler is None or handler.failed:
            print("Factory diagnostics unavailable", file=sys.stderr)
        elif failed:
            print(f"Factory diagnostic invocation: {handler.invocation_id}", file=sys.stderr)
    except OSError:
        pass


@contextmanager
def diagnostic_operation(workspace: str | Path, operation: str) -> Iterator[None]:
    """Record the result of a workspace command before its CLI formats any error."""
    handler = initialize(workspace, operation)
    failed = False
    try:
        yield
    except BaseException as exc:
        failed = True
        event("operation_failed", error_code=error_code(exc))
        raise
    else:
        event("operation_completed")
    finally:
        finish(handler, failed=failed)
