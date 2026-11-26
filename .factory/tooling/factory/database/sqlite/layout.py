"""Create or verify a store's single supported SQLite layout."""

import shutil
import sqlite3
from collections.abc import Callable
from contextlib import closing
from functools import cache
from pathlib import Path
from tempfile import TemporaryDirectory


def _objects(db: sqlite3.Connection) -> tuple[tuple[str, str, str], ...]:
    rows = db.execute(
        "SELECT type,name,sql FROM main.sqlite_schema "
        "WHERE name NOT GLOB 'sqlite_*' ORDER BY type,name"
    )
    return tuple((kind, name, sql) for kind, name, sql in rows)


@cache
def _expected(schema: str) -> tuple[tuple[str, str, str], ...]:
    with closing(sqlite3.connect(":memory:")) as db:
        db.executescript(schema)
        return _objects(db)


def layout_present(db: sqlite3.Connection, schema: str, name: str) -> bool:
    objects = _objects(db)
    if db.execute("PRAGMA user_version").fetchone()[0] or (
        objects and objects != _expected(schema)
    ):
        raise sqlite3.DatabaseError(f"Unsupported {name}")
    return bool(objects)


def check_layout(
    db: sqlite3.Connection, schema: str, name: str, *, initialize: bool = False
) -> None:
    if layout_present(db, schema, name):
        return
    if not initialize:
        raise sqlite3.DatabaseError(f"Unsupported {name}")
    if not db.in_transaction:
        db.execute("BEGIN IMMEDIATE")
        if layout_present(db, schema, name):
            return
    for statement in schema.split(";"):
        if statement.strip():
            db.execute(statement)


def read_snapshot[T](path: Path, inspect: Callable[[sqlite3.Connection], T], timeout: float) -> T:
    """Read the committed store, recovering only a private copy if SQLite requires replay."""
    try:
        with closing(sqlite3.connect(path.as_uri() + "?mode=ro", uri=True, timeout=timeout)) as db:
            db.execute("BEGIN")
            return inspect(db)
    except sqlite3.OperationalError as exc:
        if exc.sqlite_errorcode != sqlite3.SQLITE_READONLY_ROLLBACK:
            raise
        # SQLite must replay a hot rollback journal even for SELECT. Inspect a private copy.
        with TemporaryDirectory() as tmp:
            copy = Path(tmp) / "store"
            shutil.copyfile(path, copy)
            shutil.copyfile(Path(str(path) + "-journal"), Path(str(copy) + "-journal"))
            with closing(sqlite3.connect(copy)) as db:
                return inspect(db)


def preflight_recovery(path: Path, schema: str, name: str, timeout: float) -> None:
    """Validate pending recovery before allowing a writer to touch the source."""
    if any(Path(str(path) + suffix).exists() for suffix in ("-journal", "-wal")):
        read_snapshot(path, lambda db: layout_present(db, schema, name), timeout)
