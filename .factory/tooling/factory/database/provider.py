"""Select the database backend for one tooling invocation."""

from collections.abc import Iterator
from contextlib import contextmanager
from contextvars import ContextVar

from factory.database.port import DatabaseBackend
from factory.database.sqlite.adapter import SQLiteDatabaseBackend

_default: DatabaseBackend = SQLiteDatabaseBackend()
_database: ContextVar[DatabaseBackend] = ContextVar("factory_database", default=_default)


def current_database() -> DatabaseBackend:
    return _database.get()


@contextmanager
def use_database(database: DatabaseBackend) -> Iterator[None]:
    """Route all database operations in this context through the same backend."""
    with _database.set(database):
        yield
