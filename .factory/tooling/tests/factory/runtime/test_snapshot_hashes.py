import hashlib
import tempfile
import unittest
from pathlib import Path

from factory.runtime.workflow_core import snapshot


class SnapshotHashesTest(unittest.TestCase):
    def test_file_hashes_match_original_and_detect_changes(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            contents = {"empty": b"", "binary": bytes(range(256)), "large": b"01234567" * 131072}
            for name, data in contents.items():
                (root / name).write_bytes(data)
            expected = {name: hashlib.sha256(data).hexdigest() for name, data in contents.items()}
            expected["missing"] = "DELETED"
            self.assertEqual(snapshot(root, list(expected)), expected)
            (root / "binary").write_bytes(b"changed")
            self.assertNotEqual(snapshot(root, ["binary"])["binary"], expected["binary"])
