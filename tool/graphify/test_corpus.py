"""Exercise Graphify discovery using the shared policy and real traversal."""
import json
from pathlib import Path
import subprocess
import sys
import shutil
import tempfile
import unittest

from graphify.extract import extract


ROOT = Path(__file__).resolve().parents[2]


class CorpusTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory(prefix="anistar-graphify-corpus-")
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name).resolve()
        shutil.copy2(ROOT / ".graphifyignore", self.root / ".graphifyignore")

    def write(self, relative, contents="class Included {}\n"):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(contents, encoding="utf-8")
        return path

    def detect(self, follow_symlinks=False):
        # Each scan gets its own process: Graphify's global stat-index cache is
        # intentionally scoped to one root per process.
        script = ("import json, sys; from pathlib import Path; from graphify.detect import detect; "
                  "json.dump(detect(Path(sys.argv[1]), follow_symlinks=bool(int(sys.argv[2]))), sys.stdout)")
        result = subprocess.run([sys.executable, "-c", script, str(self.root), str(int(follow_symlinks))],
                                capture_output=True, text=True, check=True)
        return json.loads(result.stdout)

    def files(self):
        result = self.detect()
        return {Path(p).relative_to(self.root).as_posix() for group in result["files"].values() for p in group}

    def test_shared_policy_excludes_outputs_but_keeps_maintained_corpus(self):
        included = {
            "lib/main.dart", "infrastructure/core/lib/result.dart", "test/unit_test.dart",
            "docs/guide.md", "AGENTS.md", ".agents/skills/factory-implement/SKILL.md",
            ".codex/agents/developer.md", ".claude/agents/developer.md",
            "scripts/check.py", "tool/client.ts", "env/prod.example.json",
        }
        excluded = {
            ".git/config.json", ".fvm/versions/sdk/lib/core.dart", ".dart_tool/package_config.json",
            "infrastructure/core/build/generated.dart", "build/verification/log.json",
            "lib/nested/build/stale.dart", ".gradle/cache/config.json", "vendor/sdk/sdk.py",
            "node_modules/sdk/index.ts", "ios/Pods/library/source.swift", "ios/Flutter/ephemeral/file.dart",
            "ios/DerivedData/project/source.swift", ".symlinks/plugins/sdk.dart", "coverage/report.json",
            "lib/result.g.dart", "lib/assets.gen.dart", "lib/model.freezed.dart", "test/client.mocks.dart",
            "graphify-out/graph.json", "graphify-out/memory/query.md",
            "tool/e2e/media/360/segment-00.ts", "assets/demo.json", "resources/binary.json",
            ".private/session.json", "env/prod.json", "env/device.local.json", "nested/key.properties",
            ".ai-pipeline/state/analysis.md", ".ai-pipeline/staging/result.json",
            ".codex/skills/graphify/SKILL.md", ".agents/skills/impeccable/SKILL.md",
            ".claude/settings.local.json", "runtime.log", "capture.har", "test/failures/report.json",
        }
        for relative in included | excluded:
            self.write(relative, "export function maintained() {}\n" if relative == "tool/client.ts" else "class Included {}\n")
        found = self.files()
        self.assertTrue(included <= found, included - found)
        self.assertFalse(excluded & found, excluded & found)
        extraction = extract([self.root / "tool/client.ts"], root=self.root, cache_root=self.root, parallel=False)
        self.assertTrue(any("maintained" in node["label"] for node in extraction["nodes"]))

    def test_fvm_link_cannot_escape_to_external_flutter_sdk(self):
        external = tempfile.TemporaryDirectory(prefix="anistar-fake-flutter-")
        self.addCleanup(external.cleanup)
        sdk = Path(external.name)
        (sdk / "flutter_framework.dart").write_text("class ExternalFlutter {}\n")
        self.write("lib/maintained.dart")
        (self.root / ".fvm").mkdir()
        try:
            (self.root / ".fvm/flutter_sdk").symlink_to(sdk, target_is_directory=True)
            (self.root / "flutter_sdk").symlink_to(sdk, target_is_directory=True)
            (self.root / "external_link").symlink_to(sdk, target_is_directory=True)
        except OSError as error:
            self.skipTest(f"Host cannot create test symlinks: {error}")
        for follow in (False, True):
            result = self.detect(follow_symlinks=follow)
            paths = [Path(p) for group in result["files"].values() for p in group]
            self.assertIn(self.root / "lib/maintained.dart", paths)
            self.assertTrue(all(path.resolve().is_relative_to(self.root) for path in paths))
            self.assertFalse(any(path.name == "flutter_framework.dart" for path in paths))

    def test_feedback_remains_available_without_explicit_corpus_exclusion(self):
        (self.root / ".graphifyignore").unlink()
        feedback = self.write("graphify-out/memory/query.md", "# Reviewed query result\n")
        self.write(".gitignore", "graphify-out/\n")
        result = self.detect()
        self.assertIn(str(feedback), result["files"]["document"])


if __name__ == "__main__":
    unittest.main()
