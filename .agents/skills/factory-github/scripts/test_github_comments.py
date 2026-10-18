"""Offline tests for the GitHub-specific adaptation of source note helpers."""
import contextlib
import io
import json
import subprocess
import unittest
from unittest.mock import patch

from fetch_note import fetch_comments, find_context, main
from fetch_recent_notes import recent


class CommentsTest(unittest.TestCase):
    def test_pagination_retains_late_reply(self):
        pages = [[{"id": 1}], [{"id": 2, "in_reply_to_id": 1}]]
        with patch("fetch_note.subprocess.run", return_value=subprocess.CompletedProcess([], 0, json.dumps(pages), "")) as run:
            comments = fetch_comments("review", 8, "owner/repo")
        command = run.call_args.args[0]
        self.assertIn("--paginate", command)
        self.assertIn("--slurp", command)
        self.assertIn("repos/owner/repo/pulls/8/comments?per_page=100", command)
        self.assertEqual([note["id"] for note in find_context(comments, 2, "review")[1]], [1, 2])

    def test_issue_namespace_never_fetches_review(self):
        with patch("fetch_note.subprocess.run", return_value=subprocess.CompletedProcess([], 0, '[[{"id": 1}]]', "")) as run:
            fetch_comments("issue", 8)
        self.assertEqual(run.call_count, 1)
        self.assertIn("repos/{owner}/{repo}/issues/8/comments?per_page=100", run.call_args.args[0])

    def test_issue_same_id_does_not_join_thread(self):
        comments = [{"id": 1}, {"id": 2, "in_reply_to_id": 1}]
        self.assertEqual(find_context(comments, 2, "issue")[1], [comments[1]])

    def test_missing_comment_fails(self):
        with self.assertRaisesRegex(ValueError, "not found"):
            find_context([{"id": 1}], 9, "review")

    def test_incomplete_thread_fails(self):
        with self.assertRaisesRegex(ValueError, "incomplete"):
            find_context([{"id": 2, "in_reply_to_id": 1}], 2, "review")

    def test_cycle_fails(self):
        with self.assertRaisesRegex(ValueError, "cyclic"):
            find_context([{"id": 1, "in_reply_to_id": 2}, {"id": 2, "in_reply_to_id": 1}], 1, "review")

    def test_complete_thread_preserves_full_body_and_position(self):
        comments = [{"id": 1, "body": "x" * 1000, "path": "a.dart", "line": None, "original_line": 4, "commit_id": "abc", "side": "RIGHT"}, {"id": 2, "in_reply_to_id": 1}, {"id": 3}]
        out = io.StringIO()
        with patch("sys.argv", ["fetch_note.py", "review", "2"]), patch("sys.stdin", io.StringIO(json.dumps(comments))), contextlib.redirect_stdout(out):
            self.assertEqual(main(), 0)
        self.assertIn("x" * 1000, out.getvalue())
        self.assertIn(">>> #2", out.getvalue())
        self.assertIn("side=RIGHT commit=abc", out.getvalue())
        self.assertNotIn("#3", out.getvalue())

    def test_api_failure_does_not_claim_not_found_or_fallback(self):
        with patch("fetch_note.subprocess.run", return_value=subprocess.CompletedProcess([], 1, "", "permission denied")) as run:
            with self.assertRaisesRegex(RuntimeError, "permission denied"):
                fetch_comments("review", 8)
        self.assertEqual(run.call_count, 1)

    def test_invalid_page_fails(self):
        with patch("fetch_note.subprocess.run", return_value=subprocess.CompletedProcess([], 0, '{"message": "error"}', "")):
            with self.assertRaisesRegex(ValueError, "paginated"):
                fetch_comments("review", 8)

    def test_invalid_comment_fails(self):
        with self.assertRaisesRegex(ValueError, "numeric id"):
            find_context([{"id": "1"}], 1, "issue")

    def test_recent_orders_before_limit(self):
        comments = [{"id": 1, "created_at": "2026-02"}, {"id": 3, "created_at": "2026-01"}, {"id": 2, "created_at": "2026-02"}]
        self.assertEqual([note["id"] for note in recent(comments, 2)], [2, 1])

    def test_recent_rejects_negative(self):
        with self.assertRaises(ValueError):
            recent([], -1)

    def test_zero_pr_is_not_pipe_mode(self):
        with patch("sys.argv", ["fetch_note.py", "review", "1", "0"]), patch("sys.stdin") as stdin, contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as error:
                main()
        self.assertEqual(error.exception.code, 2)
        stdin.read.assert_not_called()

    def test_repo_cannot_inject_endpoint(self):
        with patch("fetch_note.subprocess.run") as run:
            with self.assertRaises(ValueError):
                fetch_comments("review", 8, "owner/repo/../bad")
        run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
