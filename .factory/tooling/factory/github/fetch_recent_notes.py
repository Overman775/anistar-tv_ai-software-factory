"""Print last N comments from ONE GitHub comment namespace, newest first.
Fetches all pages before sorting: GitHub issue and review endpoints differ in sorting.
"""

from __future__ import annotations

import argparse
import sys
from typing import Literal, TypedDict

from factory.cli_output import emit_error, emit_json
from factory.github.fetch_note import Comment, fetch_comments, positive_id, print_note


class RecentComments(TypedDict):
    kind: Literal["issue", "review"]
    pr: int
    comments: list[Comment]


def recent(comments: list[Comment], count: int) -> list[Comment]:
    if count < 1:
        raise ValueError("count must be positive")
    return sorted(
        comments, key=lambda note: (note.get("created_at", ""), note["id"]), reverse=True
    )[:count]


def build_parser(
    parser: argparse.ArgumentParser | None = None,
) -> argparse.ArgumentParser:
    parser = parser or argparse.ArgumentParser(description=__doc__)
    parser.add_argument("kind", choices=("issue", "review"))
    parser.add_argument("pr", type=positive_id)
    parser.add_argument("-n", type=int, default=10)
    parser.add_argument("--repo")
    return parser


def run(args: argparse.Namespace) -> int:
    as_json = getattr(args, "json", False)
    try:
        if args.n < 1:
            raise ValueError("count must be positive")
        comments = recent(fetch_comments(args.kind, args.pr, args.repo), args.n)
        if as_json:
            result: RecentComments = {"kind": args.kind, "pr": args.pr, "comments": comments}
            emit_json(result)
        else:
            for note in comments:
                print_note(note)
    except (OSError, RuntimeError, ValueError) as error:
        if as_json:
            emit_error("pr_recent_notes", str(error))
        else:
            print(str(error), file=sys.stderr)
        return 1
    return 0


def main() -> int:
    parser = build_parser()
    return run(parser.parse_args())


if __name__ == "__main__":
    sys.exit(main())
