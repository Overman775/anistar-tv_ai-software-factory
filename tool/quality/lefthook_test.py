"""Exercise installed hooks in disposable Git repositories, using pinned Dart."""

import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest


PROJECT = Path(__file__).resolve().parents[2]
FORMATTED = "void main() {}\n"
UNFORMATTED = "void main(){ }\n"


class LefthookTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory(prefix="anistar-hooks-test-")
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name) / "checkout"
        self.root.mkdir()
        self.env = os.environ.copy()
        # Do not inherit a caller's hook bypass, Git repository, or test shim.
        for name in list(self.env):
            if name.startswith(("GIT_", "LEFTHOOK_")) or name == "LEFTHOOK":
                del self.env[name]
        self.env.update({"GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": os.devnull})
        self.run_command("git", "init", "-b", "main")
        self.run_command("git", "config", "user.name", "Hook Fixture")
        self.run_command("git", "config", "user.email", "fixture@example.invalid")
        self.run_command("git", "config", "commit.gpgsign", "false")
        for relative in (
            "lefthook.yml",
            "scripts/lefthook.sh",
            "scripts/quality_runner.sh",
            "scripts/with_python.sh",
            "tool/e2e/e2e_report.py",
            "tool/quality/verify_sdk.dart",
            ".fvmrc",
            ".gitleaks.toml",
            "scripts/security_gitleaks.sh",
        ):
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(PROJECT / relative, target)
        self.write("analysis_options.yaml", "formatter:\n  page_width: 120\n")
        self.write("pubspec.yaml", "name: hook_fixture\nenvironment:\n  sdk: ^3.13.0\n")
        self.run_command("git", "add", ".")
        self.run_command("git", "commit", "-m", "Fixture baseline")
        dart = PROJECT / ".fvm/flutter_sdk/bin/dart"
        self.assertTrue(dart.is_file(), "Install the pinned FVM SDK before running hook regressions")
        self.assertIsNotNone(shutil.which("gitleaks"), "Install Gitleaks before running hook regressions")
        self.assertIsNotNone(shutil.which("lefthook"), "Install Lefthook before running hook regressions")
        self.bin = Path(directory.name) / "bin"
        self.bin.mkdir()
        self.env["PATH"] = str(self.bin) + os.pathsep + self.env["PATH"]
        self.env["ANISTAR_PYTHON"] = sys.executable
        # The real pinned Dart formatter is the pre-commit oracle.
        self.env["ANISTAR_FLUTTER_SDK"] = str(PROJECT / ".fvm/flutter_sdk")
        self.run_command("lefthook", "install")

    def run_command(self, *args, expected=0):
        result = subprocess.run(args, cwd=self.root, env=self.env, capture_output=True, text=True, check=False)
        if expected is not None:
            self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result

    def write(self, relative, content):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)

    def stage(self, relative, content):
        self.write(relative, content)
        self.run_command("git", "add", "--", relative)

    def snapshot(self):
        files = {}
        for path in self.root.rglob("*"):
            relative = path.relative_to(self.root)
            if ".git" in relative.parts or relative.parts[:2] == ("build", "quality"):
                continue
            if path.is_symlink():
                files[str(relative)] = ("symlink", os.readlink(path))
            elif path.is_file():
                files[str(relative)] = (path.stat().st_mode, hashlib.sha256(path.read_bytes()).hexdigest())
        return (self.run_command("git", "ls-files", "--stage", "-z").stdout, files, self.run_command("git", "for-each-ref", "--format=%(objectname)", "refs/stash").stdout)

    def assert_hook(self, passes):
        before = self.snapshot()
        result = self.run_command(".git/hooks/pre-commit", expected=None)
        self.assertEqual(result.returncode == 0, passes, result.stdout + result.stderr)
        self.assertEqual(self.snapshot(), before, "Hook changed the index or working tree")
        return result

    def test_empty_index_and_formatted_staged_sources_pass(self):
        self.assert_hook(True)
        for path in ("lib/a.dart", "lib/nested/a.dart", "infrastructure/b.dart", "test/c.dart", "integration_test/d.dart", "tool/quality/e.dart"):
            self.stage(path, FORMATTED)
        self.assert_hook(True)

    def test_unformatted_sources_in_each_maintained_root_fail(self):
        for path in ("lib/a.dart", "lib/nested/a.dart", "infrastructure/b.dart", "test/c.dart", "integration_test/d.dart", "tool/quality/e.dart"):
            with self.subTest(path=path):
                self.stage(path, UNFORMATTED)
                self.assert_hook(False)
                self.stage(path, FORMATTED)

    def test_unformatted_index_passes_when_worktree_is_formatted(self):
        self.stage("lib/partial.dart", UNFORMATTED)
        self.write("lib/partial.dart", FORMATTED)
        self.assert_hook(True)

    def test_formatted_index_fails_when_worktree_is_unformatted(self):
        self.stage("lib/partial.dart", FORMATTED)
        self.write("lib/partial.dart", UNFORMATTED)
        result = self.assert_hook(False)
        self.assertIn("staged-dart-format", result.stdout + result.stderr)

    def test_partial_staging_does_not_stash_or_checkout_user_files(self):
        self.stage("lib/partial.dart", FORMATTED)
        self.write("lib/partial.dart", UNFORMATTED)
        trace = self.root.parent / "git-trace"
        self.env["GIT_TRACE"] = str(trace)
        self.assert_hook(False)
        commands = trace.read_text()
        self.assertNotIn("git stash", commands)
        self.assertNotIn("git checkout", commands)

    def test_installed_hook_commits_only_staged_bytes_without_stashing(self):
        self.stage("lib/partial.dart", UNFORMATTED)
        self.write("lib/partial.dart", FORMATTED)
        trace = self.root.parent / "git-trace"
        self.env["GIT_TRACE"] = str(trace)
        before = self.snapshot()
        self.run_command("git", "commit", "-m", "Partially staged fixture")
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(self.run_command("git", "show", "HEAD:lib/partial.dart").stdout, UNFORMATTED)
        commands = trace.read_text()
        self.assertNotIn("git stash", commands)
        self.assertNotIn("git checkout", commands)

    def test_whitespace_and_conflict_markers_block_actual_commits(self):
        head = self.run_command("git", "rev-parse", "HEAD").stdout
        for content in ("trailing whitespace \n", "<<<<<<< ours\nfirst\n=======\nsecond\n>>>>>>> theirs\n"):
            with self.subTest(content=content):
                self.stage("notes.txt", content)
                self.assert_hook(False)
                result = self.run_command("git", "commit", "-m", "Must be blocked", expected=None)
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(self.run_command("git", "rev-parse", "HEAD").stdout, head)

    def test_actual_commit_passes_and_bad_dart_commit_is_blocked(self):
        self.stage("lib/good.dart", FORMATTED)
        self.run_command("git", "commit", "-m", "Formatted fixture")
        head = self.run_command("git", "rev-parse", "HEAD").stdout
        self.stage("lib/bad.dart", UNFORMATTED)
        before = self.snapshot()
        result = self.run_command("git", "commit", "-m", "Must be blocked", expected=None)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.run_command("git", "rev-parse", "HEAD").stdout, head)
        self.assertEqual(self.snapshot(), before)

    def test_unusual_names_and_executable_dart_are_checked(self):
        paths = ("lib/a space.dart", "lib/кириллица.dart", "lib/-dash.dart", "lib/a'quote.dart", 'lib/a"quote.dart')
        for path in paths:
            self.stage(path, FORMATTED)
        self.assert_hook(True)
        for path in paths:
            with self.subTest(path=path):
                self.stage(path, UNFORMATTED)
                self.assert_hook(False)
                self.stage(path, FORMATTED)
        path = self.root / "lib/executable.dart"
        self.write("lib/executable.dart", UNFORMATTED)
        path.chmod(0o755)
        self.run_command("git", "add", "--", "lib/executable.dart")
        self.assert_hook(False)

    def test_rename_checks_destination_and_deletion_is_noop(self):
        self.stage("outside/source.dart", UNFORMATTED)
        self.run_command("git", "commit", "-m", "Ignored source")
        (self.root / "lib").mkdir()
        self.run_command("git", "mv", "outside/source.dart", "lib/renamed.dart")
        self.assert_hook(False)
        self.stage("lib/renamed.dart", FORMATTED)
        self.run_command("git", "commit", "-m", "Formatted rename")
        self.run_command("git", "rm", "lib/renamed.dart")
        self.assert_hook(True)

    def test_generated_build_and_outside_sources_are_skipped(self):
        for path in ("lib/a.g.dart", "lib/a.gen.dart", "lib/a.freezed.dart", "lib/generated_plugin_registrant.dart", "lib/build/a.dart", "test/.dart_tool/a.dart", "outside/a.dart", "tool/other/a.dart"):
            self.stage(path, "not valid Dart\n")
        self.assert_hook(True)

    def test_formatter_respects_page_width_and_package_language_version(self):
        source = "const message = '" + "a" * 90 + "';\n"
        self.assertGreater(len(source.rstrip()), 80)
        self.stage("lib/wide.dart", source)
        self.assert_hook(True)
        self.write("analysis_options.yaml", "formatter:\n  page_width: 80\n")
        self.assert_hook(False)
        self.run_command("git", "rm", "--cached", "lib/wide.dart")
        self.write("pubspec.yaml", "name: hook_fixture\nenvironment:\n  sdk: '>=2.19.0 <4.0.0'\n")
        package = {"name": "hook_fixture", "rootUri": "../", "packageUri": "lib/", "languageVersion": "2.19"}
        self.write(".dart_tool/package_config.json", json.dumps({"configVersion": 2, "packages": [package]}))
        self.stage("lib/legacy.dart", "void main() {\n  final values = [\n    1,\n    2,\n  ];\n}\n")
        self.assert_hook(True)
        self.write("pubspec.yaml", "name: hook_fixture\nenvironment:\n  sdk: ^3.13.0\n")
        package["languageVersion"] = "3.13"
        self.write(".dart_tool/package_config.json", json.dumps({"configVersion": 2, "packages": [package]}))
        self.assert_hook(False)

    def test_precommit_does_not_require_python(self):
        for command in ("python", "python3"):
            path = self.bin / command
            path.write_text("#!/bin/sh\nexit 91\n")
            path.chmod(0o755)
        self.env["ANISTAR_PYTHON"] = "/missing/python"
        self.stage("lib/good.dart", FORMATTED)
        self.assert_hook(True)
        self.stage("lib/bad.dart", UNFORMATTED)
        self.assert_hook(False)

    def test_installed_hook_blocks_index_secrets_even_when_worktree_is_clean(self):
        synthetic = "synthetic-" + "password-for-hook-fixture"
        content = json.dumps({"ANISTAR_TEST_" + "PASSWORD": synthetic}) + "\n"
        self.stage("partial.txt", content)
        self.write("partial.txt", "clean worktree\n")
        result = self.assert_hook(False)
        self.assertNotIn(synthetic, result.stdout + result.stderr)
        head = self.run_command("git", "rev-parse", "HEAD").stdout
        self.run_command("git", "commit", "-m", "Must block synthetic fixture", expected=None)
        self.assertEqual(self.run_command("git", "rev-parse", "HEAD").stdout, head)
        self.stage("partial.txt", "clean index\n")
        self.write("partial.txt", content)
        self.assert_hook(True)

    def test_local_push_runs_melos_check_and_allows_dirty_worktree(self):
        remote = self.root.parent / "remote.git"
        self.run_command("git", "init", "--bare", str(remote))
        self.run_command("git", "remote", "add", "fixture", str(remote))
        trace = self.root.parent / "push-trace"
        self.env["ANISTAR_GATE_TRACE"] = str(trace)
        sdk = self.root.parent / "sdk"
        (sdk / "bin").mkdir(parents=True)
        dart = PROJECT / ".fvm/flutter_sdk/bin/dart"
        # Keep the real project Melos scripts; only native leaf tools are replaced.
        project_pubspec = (PROJECT / "pubspec.yaml").read_text()
        self.write("pubspec.yaml", "name: hook_fixture\nenvironment:\n  sdk: ^3.13.0\ndev_dependencies:\n  melos: 7.8.0\nmelos:\n" + project_pubspec.split("\nmelos:\n", 1)[1])
        self.write(".gitignore", ".dart_tool/\n.fvm/\n")
        self.write(".dart_tool/package_config.json", (PROJECT / ".dart_tool/package_config.json").read_text())
        (self.root / ".fvm").mkdir()
        (self.root / ".fvm/flutter_sdk").symlink_to((PROJECT / ".fvm/flutter_sdk").resolve())
        version = json.loads((PROJECT / ".fvmrc").read_text())["flutter"]
        commands = {
            self.bin / "fvm": '#!/bin/sh\n[ "$1" = dart ] || exit 98\nshift\nexec ' + shlex.quote(str(dart)) + ' "$@"\n',
            sdk / "bin/dart": '#!/bin/sh\nif [ "$1" = format ]; then echo format >> "$ANISTAR_GATE_TRACE"; exit "${ANISTAR_GATE_FORMAT_EXIT:-0}"; fi\nexec ' + shlex.quote(str(dart)) + ' "$@"\n',
            sdk / "bin/flutter": '#!/bin/sh\n[ "$1" = --no-version-check ] && shift\ncase "$1" in\n--version) echo \'{"frameworkVersion":"' + version + '"}\';;\npub) echo pub >> "$ANISTAR_GATE_TRACE";;\nanalyze) echo analyze >> "$ANISTAR_GATE_TRACE";;\ntest) case " $* " in *" --tags=golden "*) echo golden >> "$ANISTAR_GATE_TRACE";; *) echo unit >> "$ANISTAR_GATE_TRACE";; esac\nreport=\nfor argument in "$@"; do case "$argument" in --file-reporter=json:*) report=${argument#--file-reporter=json:};; esac; done\nif [ -n "$report" ]; then mkdir -p "$(dirname "$report")"; printf \'%s\\n\' \'{"type":"testStart","test":{"id":1,"name":"fixture test","hidden":false},"time":0}\' \'{"type":"testDone","testID":1,"result":"success","hidden":false,"time":1}\' \'{"type":"done","success":true}\' > "$report"; fi;;\n*) exit 90;;\nesac\n',
            self.bin / "dcm": '#!/bin/sh\necho dcm >> "$ANISTAR_GATE_TRACE"\n',
            self.bin / "gitleaks": '#!/bin/sh\ncase " $* " in *" --log-opts="*) echo secrets >> "$ANISTAR_GATE_TRACE";; esac\nexec ' + shlex.quote(shutil.which("gitleaks")) + ' "$@"\n',
        }
        for path, content in commands.items():
            path.write_text(content)
            path.chmod(0o755)
        self.env["ANISTAR_FLUTTER_SDK"] = str(sdk)
        for relative in ("infrastructure", "test", "integration_test"):
            (self.root / relative).mkdir(exist_ok=True)
        self.write("lib/example.dart", FORMATTED)
        self.write("scripts/test_tooling.sh", 'echo tooling >> "$ANISTAR_GATE_TRACE"\n')
        self.write("tool/version/app_version.py", 'import os\nwith open(os.environ["ANISTAR_GATE_TRACE"], "a") as trace:\n    trace.write("version\\n")\n')
        # Resolve and compile the real Melos runtime before the immutability snapshot.
        self.run_command(str(dart), "run", "melos", "run", "--list")
        # Untracked files and unstaged tracked edits are intentional push input.
        self.write("notes.txt", "dirty untracked fixture\n")
        self.write("pubspec.yaml", (self.root / "pubspec.yaml").read_text() + "# dirty\n")
        before = self.snapshot()
        self.run_command("git", "push", "fixture", "HEAD:refs/heads/main")
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(trace.read_text().splitlines(), ["secrets", "pub", "format", "analyze", "dcm", "unit", "golden", "tooling", "version"])
        first = self.run_command("git", "rev-parse", "HEAD").stdout.strip()
        self.stage("notes.txt", "second fixture\n")
        self.run_command("git", "commit", "-m", "Second fixture")
        self.env["ANISTAR_GATE_FORMAT_EXIT"] = "17"
        trace.write_text("")
        before = self.snapshot()
        result = self.run_command("git", "push", "fixture", "HEAD:refs/heads/main", expected=None)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("FAIL suite=format-check", result.stdout + result.stderr)
        self.assertEqual(trace.read_text().splitlines(), ["secrets", "pub", "format"])
        self.assertEqual(self.snapshot(), before)
        actual = self.run_command("git", "--git-dir", str(remote), "rev-parse", "refs/heads/main").stdout.strip()
        self.assertEqual(actual, first, "Failed check updated the remote branch")
        self.stage("historical.txt", json.dumps({"ANISTAR_TEST_" + "PASSWORD": "synthetic-" + "history-password-fixture"}))
        self.run_command("git", "-c", "core.hooksPath=/dev/null", "commit", "-m", "Synthetic history regression")
        self.run_command("git", "rm", "historical.txt")
        self.run_command("git", "-c", "core.hooksPath=/dev/null", "commit", "-m", "Remove synthetic fixture")
        trace.write_text("")
        before = self.snapshot()
        blocked = self.run_command("git", "push", "fixture", "HEAD:refs/heads/main", expected=None)
        self.assertNotEqual(blocked.returncode, 0)
        self.assertEqual(trace.read_text().splitlines(), ["secrets"])
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(self.run_command("git", "--git-dir", str(remote), "rev-parse", "refs/heads/main").stdout.strip(), first)


if __name__ == "__main__":
    unittest.main()
