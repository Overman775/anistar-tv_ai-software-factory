"""Show the full GitHub review comment thread, marking the requested comment.

Usage: fetch_note_context.py {issue|review} NOTE_ID PR_NUMBER [--repo OWNER/REPO]
The same read-only CLI and pipe mode as fetch_note.py; issue comments are standalone.
"""
import sys
from fetch_note import main

if __name__ == "__main__":
    sys.exit(main())
