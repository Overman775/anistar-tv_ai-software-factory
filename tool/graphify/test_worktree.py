"""A new worktree has shared corpus rules but no machine-specific sidecars."""
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class FreshWorktreeTest(unittest.TestCase):
    def command(self, arguments, *, cwd=ROOT, env=None):
        result = subprocess.run(arguments, cwd=cwd, env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def test_new_worktree_resolves_python_runs_regressions_and_excludes_media_sdk_builds(self):
        if not (ROOT / ".git").exists():
            self.skipTest("Actual Git worktree integration requires a repository checkout")
        directory = tempfile.TemporaryDirectory(prefix="anistar-graphify-worktree-")
        self.addCleanup(directory.cleanup)
        worktree = Path(directory.name).resolve() / "checkout"
        # Hooks belong to a separate improvement. Disable only for this command;
        # do not modify shared hooks or repository configuration.
        self.command(["git", "-c", "core.hooksPath=", "worktree", "add", "--detach", str(worktree), "HEAD"])
        self.addCleanup(lambda: subprocess.run(["git", "-c", "core.hooksPath=", "worktree", "remove", "--force", str(worktree)],
                                              cwd=ROOT, capture_output=True, check=False))
        # No commits/staging: apply the candidate working bytes over the clean
        # baseline, including the newly shared ignore file and preparation code.
        tracked = self.command(["git", "diff", "HEAD", "--name-only", "-z"]).stdout.split("\0")
        untracked = self.command(["git", "ls-files", "--others", "--exclude-standard", "-z"]).stdout.split("\0")
        for relative in set(tracked + untracked) - {""}:
            source, destination = ROOT / relative, worktree / relative
            if source.is_file():
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, destination)
            elif destination.exists():
                destination.unlink()
        self.assertTrue((worktree / ".graphifyignore").is_file())
        self.assertFalse((worktree / "graphify-out/.graphify_python").exists())
        # The child --check runs the real suite, excluding only this integration
        # harness to avoid recursively creating worktrees.
        (worktree / "tool/graphify/test_worktree.py").unlink()
        env = dict(os.environ)
        env.pop("ANISTAR_GRAPHIFY_PYTHON", None)
        env.pop("PYTHONPATH", None)
        # Execute the real post-bootstrap hook from the candidate Melos config,
        # without fetching Flutter dependencies or invoking bootstrap itself.
        config = (worktree / "pubspec.yaml").read_text(encoding="utf-8")
        hook = re.search(r'(?m)^        post: "([^"]+)"$', config)
        self.assertIsNotNone(hook, "Missing bootstrap preparation hook")
        self.command(shlex.split(hook.group(1)), cwd=worktree, env=env)
        self.assertTrue((worktree / "graphify-out/.graphify_python").is_file())
        prepared = self.command([sys.executable, "tool/graphify/prepare.py", "--check"], cwd=worktree, env=env)
        self.assertIn("producer patch verified", prepared.stdout)
        self.assertIn("Ran ", prepared.stderr)
        self.assertIn("OK", prepared.stderr)
        selected = (worktree / "graphify-out/.graphify_python").read_text()
        self.assertTrue(Path(selected).is_absolute())
        self.assertEqual((worktree / "graphify-out/.graphify_root").read_text(), str(worktree))
        for relative in ("infrastructure/core/build/should_not_index.dart", "ios/Pods/hidden.swift",
                         "coverage/run.json", "graphify-out/memory/should_not_index.md"):
            destination = worktree / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text("class Excluded {}\n", encoding="utf-8")
        external = Path(directory.name).resolve() / "external-flutter"
        external.mkdir()
        (external / "framework.dart").write_text("class ExternalFlutter {}\n", encoding="utf-8")
        (worktree / ".fvm").mkdir()
        (worktree / ".fvm/flutter_sdk").symlink_to(external, target_is_directory=True)
        scan = ("import json; from pathlib import Path; from graphify.detect import detect; "
                "print(json.dumps(detect(Path.cwd())))")
        detection = json.loads(self.command([selected, "-c", scan], cwd=worktree, env=env).stdout)
        found = {Path(p).relative_to(worktree).as_posix() for paths in detection["files"].values() for p in paths}
        self.assertIn("lib/main_dev.dart", found)
        self.assertIn("infrastructure/core/README.md", found)
        self.assertIn("docs/melos_tooling.md", found)
        self.assertIn("AGENTS.md", found)
        self.assertIn(".agents/skills/factory-implement/SKILL.md", found)
        self.assertTrue(any(p.startswith("test/") for p in found))
        self.assertFalse(any(p.startswith((".fvm/", "graphify-out/", "tool/e2e/media/", "coverage/", "ios/Pods/"))
                             or "/build/" in p for p in found))
        self.assertFalse(any("framework.dart" in p for p in found))
        ignored = self.command(["git", "check-ignore", "graphify-out/.graphify_python"], cwd=worktree)
        self.assertIn("graphify-out/.graphify_python", ignored.stdout)


if __name__ == "__main__":
    unittest.main()
