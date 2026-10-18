"""Print last N comments from ONE GitHub comment namespace, newest first.

Usage: fetch_recent_notes.py {issue|review} PR_NUMBER [-n N] [--repo OWNER/REPO]
Fetches all pages before sorting: GitHub issue and review endpoints differ in sorting.
"""
import argparse
import sys
from fetch_note import fetch_comments, positive_id, print_note


def recent(comments, count):
    if count < 1:
        raise ValueError("count must be positive")
    return sorted(comments, key=lambda note: (note.get("created_at", ""), note["id"]), reverse=True)[:count]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("kind", choices=("issue", "review"))
    parser.add_argument("pr", type=positive_id)
    parser.add_argument("-n", type=int, default=10)
    parser.add_argument("--repo")
    args = parser.parse_args()
    try:
        if args.n < 1:
            raise ValueError("count must be positive")
        for note in recent(fetch_comments(args.kind, args.pr, args.repo), args.n):
            print_note(note)
    except (OSError, RuntimeError, ValueError) as error:
        print(str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
