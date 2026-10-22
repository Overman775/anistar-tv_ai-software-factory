"""Read one GitHub PR comment and its context; no remote writes.

Usage: fetch_note.py {issue|review} NOTE_ID PR_NUMBER [--repo OWNER/REPO]
Pipe mode: fetch_note.py {issue|review} NOTE_ID < comments.json
Issue comments have no REST thread/reply relation. Review comments do.
"""
import argparse
import json
import subprocess
import sys


def positive_id(value):
    number = int(value)
    if number < 1:
        raise argparse.ArgumentTypeError("ID must be positive")
    return number


def fetch_comments(kind, pr, repo=None):
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
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if result.returncode:
        raise RuntimeError(f"GitHub API failed ({result.returncode}): {result.stderr.strip()}")
    pages = json.loads(result.stdout)
    if not isinstance(pages, list) or any(not isinstance(page, list) for page in pages):
        raise ValueError("expected paginated comment arrays")
    comments = [comment for page in pages for comment in page]
    validate_comments(comments)
    return comments


def validate_comments(comments):
    if not isinstance(comments, list) or any(
        not isinstance(comment, dict) or not isinstance(comment.get("id"), int)
        for comment in comments
    ):
        raise ValueError("expected comment objects with numeric id")


def find_context(comments, note_id, kind):
    validate_comments(comments)
    by_id = {str(comment["id"]): comment for comment in comments}
    target = by_id.get(str(note_id))
    if target is None:
        raise ValueError(f"{kind} comment {note_id} not found in this PR")
    if kind == "issue":
        return target, [target]
    def root(comment):
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
    return target, sorted(thread, key=lambda comment: (comment.get("created_at", ""), comment["id"]))


def print_note(note, target_id=None):
    marker = ">>> " if str(note["id"]) == str(target_id) else ""
    print(f"{marker}#{note['id']} {note.get('user', {}).get('login', '?')} ({note.get('created_at', '?')}):")
    print(note.get("body", ""))
    if note.get("path"):
        print(f"File: {note['path']}:{note.get('line')} side={note.get('side')} commit={note.get('commit_id')}")
        print(f"Original: {note.get('original_line')} commit={note.get('original_commit_id')} reply_to={note.get('in_reply_to_id')}")
    print(note.get("html_url", ""))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("kind", choices=("issue", "review"))
    parser.add_argument("note_id", type=positive_id)
    parser.add_argument("pr", nargs="?", type=positive_id)
    parser.add_argument("--repo")
    args = parser.parse_args()
    try:
        comments = fetch_comments(args.kind, args.pr, args.repo) if args.pr is not None else json.load(sys.stdin)
        target, thread = find_context(comments, args.note_id, args.kind)
        print(f"Kind: {args.kind}")
        print(f"Thread root: {thread[0]['id']}" if args.kind == "review" else "Issue comment: no REST reply thread")
        for note in thread:
            print_note(note, target["id"])
    except (OSError, RuntimeError, ValueError) as error:
        print(str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
