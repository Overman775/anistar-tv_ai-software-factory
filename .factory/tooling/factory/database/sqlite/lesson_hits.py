"""Read ordered lesson revisions attributed to an individual search."""

import sqlite3

from factory.runtime.knowledge.lesson_trace_repository import SearchHit


def read_hits(db: sqlite3.Connection, search_id: int) -> list[SearchHit]:
    return [
        {"id": lesson, "scope": scope, "revision": revision}
        for lesson, scope, revision in db.execute(
            "SELECT lesson_id,scope,revision FROM lesson_hits WHERE search_id=? ORDER BY ordinal",
            (search_id,),
        )
    ]
