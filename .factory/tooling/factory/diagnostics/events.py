"""Emit events to the current invocation's local logger."""

import logging
from contextvars import ContextVar

current_logger: ContextVar[logging.Logger | None] = ContextVar("factory_diagnostics", default=None)

ERROR_EVENTS = {"operation_failed", "database_failed", "lesson_trace_unavailable"}


def event(name: str, **fields: object) -> None:
    logger = current_logger.get()
    if logger is not None:
        logger.log(logging.ERROR if name in ERROR_EVENTS else logging.INFO, name, extra=fields)
