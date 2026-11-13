"""Read one GitHub PR comment and its context; no remote writes.

Usage: fetch_note.py {issue|review} NOTE_ID PR_NUMBER [--repo OWNER/REPO]
Pipe mode: fetch_note.py {issue|review} NOTE_ID < comments.json
Issue comments have no REST thread/reply relation. Review comments do.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from collections.abc import Callable
from typing import Annotated, NotRequired

from pydantic import ConfigDict, Field, TypeAdapter, ValidationError, with_config
from typing_extensions import TypedDict

from factory_tooling.validation import validation_message

Positive = Annotated[int, Field(gt=0)]


@with_config(ConfigDict(strict=True, extra="ignore"))
class CommentUser(TypedDict):
    login: str


@with_config(ConfigDict(strict=True, extra="ignore"))
class Comment(TypedDict):
    id: Positive
    user: NotRequired[CommentUser]
    created_at: NotRequired[str]
    body: NotRequired[str | None]
    path: NotRequired[str]
    line: NotRequired[int | None]
    side: NotRequired[str]
    commit_id: NotRequired[str]
    original_line: NotRequired[int | None]
    original_commit_id: NotRequired[str]
    in_reply_to_id: NotRequired[int | None]
    html_url: NotRequired[str]


COMMENTS = TypeAdapter[list[Comment]](list[Comment], config=ConfigDict(strict=True))
PAGES = TypeAdapter[list[list[Comment]]](list[list[Comment]], config=ConfigDict(strict=True))


def positive_id(value: str) -> int:
    number = int(value)
    if number < 1:
        raise argparse.ArgumentTypeError("ID must be positive")
    return number


def comments_command(kind: str, pr: int, repo: str | None = None) -> list[str]:
    """Build the read-only GitHub command; no network access."""
    resource = "issues" if kind == "issue" else "pulls"
    command = ["gh", "api", "--method", "GET", "--paginate", "--slurp"]
    if repo:
        # gh api has no --repo flag. Use explicit, validated endpoint instead.
        import re

        if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repo):
            raise ValueError("repo must be OWNER/REPO; use GH_HOST for another host")
        root = f"repos/{repo}"
    else:
        root = "repos/{owner}/{repo}"
    command.append(f"{root}/{resource}/{pr}/comments?per_page=100")
    return command


def fetch_comments(
    kind: str,
    pr: int,
    repo: str | None = None,
    *,
    run: Callable[..., subprocess.CompletedProcess[str]] | None = None,
) -> list[Comment]:
    """Fetch through a subprocess-compatible runner and validate the response."""
    run = subprocess.run if run is None else run
    command = comments_command(kind, pr, repo)
    result = run(command, capture_output=True, text=True, check=False)
    if result.returncode:
        raise RuntimeError(f"GitHub API failed ({result.returncode}): {result.stderr.strip()}")
    try:
        pages = PAGES.validate_json(result.stdout)
    except ValidationError as exc:
        raise ValueError(
            validation_message("Invalid paginated GitHub comments", exc, PAGES)
        ) from None
    return [comment for page in pages for comment in page]


def validate_comments(comments: object) -> list[Comment]:
    try:
        return COMMENTS.validate_python(comments)
    except ValidationError as exc:
        raise ValueError(validation_message("Invalid GitHub comments", exc, COMMENTS)) from None


def find_context(comments: object, note_id: int | str, kind: str) -> tuple[Comment, list[Comment]]:
    comments = validate_comments(comments)
    by_id = {str(comment["id"]): comment for comment in comments}
    target = by_id.get(str(note_id))
    if target is None:
        raise ValueError(f"{kind} comment {note_id} not found in this PR")
    if kind == "issue":
        return target, [target]

    def root(comment: Comment) -> str:
        seen = set()
        while comment.get("in_reply_to_id") is not None:
            parent_id = str(comment["in_reply_to_id"])
            if parent_id in seen or parent_id not in by_id:
                raise ValueError("incomplete or cyclic review comment thread")
            seen.add(parent_id)
            comment = by_id[parent_id]
        return str(comment["id"])

    root_id = root(target)
    thread = [comment for comment in comments if root(comment) == root_id]
    return target, sorted(
        thread, key=lambda comment: (comment.get("created_at", ""), comment["id"])
    )


def render_note(note: Comment, target_id: int | str | None = None) -> str:
    """Format one comment without writing to stdout."""
    marker = ">>> " if str(note["id"]) == str(target_id) else ""
    lines = [
        f"{marker}#{note['id']} {note.get('user', {}).get('login', '?')} ({note.get('created_at', '?')}):",
        note.get("body", ""),
    ]
    if note.get("path"):
        lines.append(
            f"File: {note['path']}:{note.get('line')} side={note.get('side')} commit={note.get('commit_id')}"
        )
        lines.append(
            f"Original: {note.get('original_line')} commit={note.get('original_commit_id')} reply_to={note.get('in_reply_to_id')}"
        )
    lines.append(note.get("html_url", ""))
    return "\n".join(str(line) for line in lines)


def print_note(note: Comment, target_id: int | str | None = None) -> None:
    print(render_note(note, target_id))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("kind", choices=("issue", "review"))
    parser.add_argument("note_id", type=positive_id)
    parser.add_argument("pr", nargs="?", type=positive_id)
    parser.add_argument("--repo")
    args = parser.parse_args()
    try:
        comments = (
            fetch_comments(args.kind, args.pr, args.repo)
            if args.pr is not None
            else json.load(sys.stdin)
        )
        target, thread = find_context(comments, args.note_id, args.kind)
        print(f"Kind: {args.kind}")
        print(
            f"Thread root: {thread[0]['id']}"
            if args.kind == "review"
            else "Issue comment: no REST reply thread"
        )
        for note in thread:
            print_note(note, target["id"])
    except (OSError, RuntimeError, ValueError) as error:
        print(str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
