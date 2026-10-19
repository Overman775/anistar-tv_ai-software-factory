"""Native scanner regressions and wrapper contracts in disposable checkouts.

All credential-shaped strings are synthetic and assembled only in temporary files.
The real checkout's index, history, lockfile and source are never changed.
"""

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile
import shlex


PROJECT = Path(__file__).resolve().parents[2]


class ScannerFixture(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="anistar-security-test-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve() / "checkout"
        self.root.mkdir()
        self.bin = Path(temporary.name) / "bin"
        self.bin.mkdir()
        self.env = {key: value for key, value in os.environ.items()
                    if not key.startswith(("GIT_", "LEFTHOOK_", "SEMGREP_"))}
        self.env.update({"GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": os.devnull,
                         "ANISTAR_PYTHON": sys.executable,
                         "PATH": str(self.bin) + os.pathsep + os.environ["PATH"]})
        for relative in ("scripts/security_gitleaks.sh", "scripts/security_osv.sh",
                         "scripts/security_semgrep.sh", "scripts/with_python.sh",
                         ".gitleaks.toml", ".semgrep/security.yaml", ".semgrepignore"):
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(PROJECT / relative, target)
        self.command("git", "init", "-q", "-b", "main")
        self.command("git", "config", "user.name", "Security Fixture")
        self.command("git", "config", "user.email", "fixture@example.invalid")
        self.command("git", "config", "core.hooksPath", "/dev/null")
        self.command("git", "config", "commit.gpgsign", "false")
        self.command("git", "add", ".")
        self.command("git", "commit", "-qm", "Clean fixture")

    def command(self, *arguments, expected=0, cwd=None):
        result = subprocess.run(arguments, cwd=cwd or self.root, env=self.env,
                                capture_output=True, text=True, check=False, timeout=120)
        if expected is not None:
            # Never include arbitrary scanner output in assertions: it can contain
            # the deliberately secret-shaped fixture being checked for redaction.
            self.assertEqual(result.returncode, expected, "Unexpected command exit: " + arguments[0])
        return result

    def write(self, relative, content):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)

    def stage(self, relative, content):
        self.write(relative, content)
        self.command("git", "add", "--", relative)

    def shim(self, name, content):
        path = self.bin / name
        path.write_text("#!/bin/sh\n" + content)
        path.chmod(0o755)

    def snapshot(self):
        files = {str(path.relative_to(self.root)): (path.stat().st_mode,
                 hashlib.sha256(path.read_bytes()).hexdigest())
                 for path in self.root.rglob("*") if path.is_file()
                 and ".git" not in path.relative_to(self.root).parts}
        return (self.command("git", "ls-files", "--stage", "-z").stdout,
                self.command("git", "rev-parse", "HEAD").stdout,
                self.command("git", "for-each-ref", "refs/stash").stdout, files)

    def scan(self, scanner, *arguments, expected=0):
        before = self.snapshot()
        result = self.command("bash", "scripts/security_" + scanner + ".sh",
                              *arguments, expected=expected)
        self.assertEqual(self.snapshot(), before, "Scanner mutated checkout/index/HEAD/stash")
        return result


class GitleaksTest(ScannerFixture):
    @staticmethod
    def password():
        return "synthetic-" + "fixture-password-672"

    def live(self):
        return json.dumps({"ANISTAR_TEST_" + "PASSWORD": self.password()}) + "\n"

    def test_native_defaults_and_both_project_rules_detect_redacted_findings(self):
        token = "ghp_" + "aB3dE6fG9hJ2kL5mN8pQ1rS4tU7vW0xY3zA6"
        examples = (self.live(), 'store' + 'Password = "' + self.password() + '"\n',
                    'key' + 'Password: "' + self.password() + '"\n',
                    'github_token = "' + token + '"\n')
        for content in examples:
            with self.subTest(rule=examples.index(content)):
                self.stage("credentials.txt", content)
                result = self.scan("gitleaks", "staged", expected=1)
                self.assertNotIn(self.password(), result.stdout + result.stderr)
                self.assertNotIn(token, result.stdout + result.stderr)

    def test_empty_password_public_templates_and_clean_index_pass(self):
        self.scan("gitleaks", "staged")
        self.stage("env/live-test.example.json", json.dumps({"ANISTAR_TEST_" + "PASSWORD": ""}))
        self.stage("notes.txt", "Documentation only.\n")
        self.scan("gitleaks", "staged")

    def test_partial_staging_reads_index_and_never_stashes(self):
        self.stage("partial.txt", self.live())
        self.write("partial.txt", "clean worktree\n")
        trace = self.root.parent / "git-trace"
        self.env["GIT_TRACE"] = str(trace)
        self.scan("gitleaks", "staged", expected=1)
        self.stage("partial.txt", "clean index\n")
        self.write("partial.txt", self.live())
        self.scan("gitleaks", "staged")
        self.assertNotIn("git stash", trace.read_text())
        self.assertNotIn("git checkout", trace.read_text())

    def test_sensitive_paths_include_nul_delimited_unusual_names(self):
        paths = ("env/prod.json", "env/live-test.local.json", "nested/key.properties",
                 "signing.properties", "nested/keystore.properties", "a space.jks",
                 "quote'file.keystore", 'quote"file.p12', "line\nbreak.pfx")
        for path in paths:
            with self.subTest(path=path):
                self.stage(path, "public placeholder\n")
                self.scan("gitleaks", "staged", expected=1)
                self.command("git", "rm", "--cached", "--", path)

    def test_deleted_sensitive_file_passes_but_renamed_destination_blocks(self):
        self.stage("env/prod.json", "public placeholder\n")
        self.command("git", "commit", "-qm", "Historical public placeholder")
        self.command("git", "rm", "env/prod.json")
        self.scan("gitleaks", "staged")
        self.stage("source.txt", "public placeholder\n")
        self.command("git", "commit", "-qm", "Rename source")
        self.command("git", "mv", "source.txt", "destination.jks")
        self.scan("gitleaks", "staged", expected=1)

    def test_public_key_exception_is_exact_and_only_private_key_rule(self):
        public_key = (PROJECT / "tool/e2e/tls/localhost.key").read_text()
        self.stage("tool/e2e/tls/localhost.key", public_key)
        self.scan("gitleaks", "staged")
        self.stage("tool/e2e/tls/localhost.key", public_key + self.live())
        self.scan("gitleaks", "staged", expected=1)
        self.stage("tool/e2e/tls/localhost.key", public_key)
        for path in ("other/localhost.key", "prefix/tool/e2e/tls/localhost.key"):
            self.stage(path, public_key)
            self.scan("gitleaks", "staged", expected=1)
            self.command("git", "rm", "--cached", "--", path)

    def test_inline_allow_ignore_and_baseline_cannot_hide_secret(self):
        self.stage("credentials.txt", self.live().rstrip() + " # gitleaks:allow\n")
        self.write(".gitleaksignore", "*\n")
        self.write(".gitleaks-baseline.json", "[]")
        self.scan("gitleaks", "staged", expected=1)

    def test_history_detects_secret_removed_later_and_unmerged_branch(self):
        self.command("git", "checkout", "-qb", "old-secret")
        self.stage("removed.txt", self.live())
        self.command("git", "commit", "-qm", "Synthetic fixture")
        self.command("git", "rm", "removed.txt")
        self.command("git", "commit", "-qm", "Remove synthetic fixture")
        self.scan("gitleaks", "history", expected=1)
        self.command("git", "checkout", "main")
        self.scan("gitleaks", "history", expected=1)

    def test_history_clean_and_shallow_rejected(self):
        self.scan("gitleaks", "history")
        clone = self.root.parent / "shallow"
        self.command("git", "clone", "-q", "--depth=1", self.root.as_uri(), str(clone))
        result = self.command("bash", "scripts/security_gitleaks.sh", "history", cwd=clone, expected=2)
        self.assertIn("complete local clone", result.stderr)

    def test_errors_missing_config_and_missing_binary_fail_closed(self):
        (self.root / ".gitleaks.toml").unlink()
        self.scan("gitleaks", "staged", expected=2)
        self.shim("gitleaks", "exit 19\n")
        self.scan("gitleaks", "staged", expected=2)
        self.env["PATH"] = str(self.bin) + ":/usr/bin:/bin"
        (self.bin / "gitleaks").unlink()
        self.scan("gitleaks", "staged", expected=127)
        self.scan("gitleaks", "unsupported", expected=64)


class OsvTest(ScannerFixture):
    def setUp(self):
        super().setUp()
        self.write("pubspec.lock", "packages: {}\nsdks:\n  dart: '>=3.0.0 <4.0.0'\n")

    def test_fixed_root_lockfile_no_resolve_and_native_exits(self):
        trace = self.root.parent / "arguments.json"
        self.env["SECURITY_ARGV_TRACE"] = str(trace)
        self.shim("osv-scanner", 'exec ' + str(Path(sys.executable)) + ' -c \'import json,os,sys; '
                  'open(os.environ["SECURITY_ARGV_TRACE"],"w").write(json.dumps(sys.argv[1:])); '
                  'sys.exit(int(os.environ.get("SECURITY_OSV_EXIT","0")))\' "$@"\n')
        for exit_code in (0, 1, 2, 17):
            self.env["SECURITY_OSV_EXIT"] = str(exit_code)
            self.scan("osv", expected=exit_code)
            self.assertEqual(json.loads(trace.read_text()),
                             ["scan", "source", "--no-resolve", "--lockfile", str(self.root / "pubspec.lock")])

    def test_missing_lock_binary_and_extra_arguments(self):
        self.scan("osv", "--fix", expected=2)
        (self.root / "pubspec.lock").unlink()
        self.scan("osv", expected=128)
        self.env["PATH"] = "/usr/bin:/bin"
        self.scan("osv", expected=127)

    def test_native_vulnerable_and_fixed_lock_against_controlled_offline_database(self):
        native = shutil.which("osv-scanner")
        self.assertIsNotNone(native, "Install OSV-Scanner before running native regressions")
        cache = self.root.parent / "osv-database"
        database = cache / "osv-scalibr/Pub/all.zip"
        database.parent.mkdir(parents=True)
        advisory = {
            "schema_version": "1.6.0", "id": "TEST-2026-0001",
            "modified": "2026-01-01T00:00:00Z", "published": "2026-01-01T00:00:00Z",
            "summary": "Controlled synthetic test advisory",
            "affected": [{"package": {"name": "security_fixture", "ecosystem": "Pub"},
                          "ranges": [{"type": "SEMVER", "events": [{"introduced": "0"}, {"fixed": "2.0.0"}]}]}],
        }
        with zipfile.ZipFile(database, "w") as archive:
            archive.writestr("TEST-2026-0001.json", json.dumps(advisory))
        self.env["OSV_SCALIBR_LOCAL_DB_CACHE_DIRECTORY"] = str(cache)
        # Only the native leaf gets offline test configuration. Production wrapper
        # remains unchanged and supplies its real fixed-root arguments.
        self.shim("osv-scanner", "exec " + shlex.quote(native) + ' "$@" --offline --format=json\n')
        for version, expected in (("1.0.0", 1), ("2.0.0", 0)):
            self.write("pubspec.lock", "packages:\n  security_fixture:\n"
                       "    dependency: transitive\n    description:\n      name: security_fixture\n"
                       "      url: https://pub.dev\n    source: hosted\n    version: '" + version + "'\n")
            result = self.scan("osv", expected=expected)
            self.assertEqual("TEST-2026-0001" in result.stdout, expected == 1)
        database.unlink()
        result = self.scan("osv", expected=None)
        self.assertNotEqual(result.returncode, 0, "Missing offline database must fail")


class SemgrepTest(ScannerFixture):
    def test_native_eight_rules_positive_and_negative(self):
        sources = {
            "positive.dart": "void insecure(client, adapter, logger, password) {\n"
                             "client.badCertificateCallback = (cert, host, port) => true;\n"
                             "adapter.validateCertificate = (cert, host, port) => true;\n"
                             "logger.e(password);\n}\n",
            "positive.kt": "fun onReceivedSslError(view: WebView, handler: SslErrorHandler, error: SslError) {\n"
                           "handler.proceed()\n}\n",
            "positive.py": "import requests, subprocess, pickle\n"
                           "requests.get(url, verify=False)\n"
                           "subprocess.run(command, shell=True)\n"
                           "pickle.loads(payload)\n"
                           "eval(payload)\n",
            "negative.dart": "void safe(client, adapter, logger, password) {\n"
                             "client.badCertificateCallback = (cert, host, port) => false;\n"
                             "adapter.validateCertificate = (cert, host, port) => false;\n"
                             "logger.e(redact(password));\n}\n",
            "negative.kt": "fun onReceivedSslError(view: WebView, handler: SslErrorHandler, error: SslError) {\n"
                           "handler.cancel()\n}\n",
            "negative.py": "import requests, subprocess, json, yaml\n"
                           "requests.get(url, verify=True)\n"
                           "subprocess.run(['safe', argument], shell=False)\n"
                           "json.loads(payload)\nyaml.safe_load(payload)\neval('1 + 1')\n",
        }
        for path, source in sources.items():
            self.write(path, source)
        result = self.command("semgrep", "scan", "--config", ".semgrep", "--metrics=off",
                              "--disable-version-check", "--oss-only", "--strict", "--json",
                              "--no-rewrite-rule-ids", ".")
        parsed = json.loads(result.stdout)
        self.assertEqual(parsed["errors"], [])
        self.assertEqual(len(parsed["results"]), 8)
        self.assertEqual({item["check_id"] for item in parsed["results"]}, {
            "anistar.dart.accept-all-certificates", "anistar.dart.dio-accept-all-certificates",
            "anistar.dart.direct-credential-log", "anistar.kotlin.webview-ssl-proceed",
            "anistar.python.disabled-tls-verification", "anistar.python.shell-command",
            "anistar.python.unsafe-deserialization", "anistar.python.nonliteral-code-execution"})
        self.assertTrue(all(Path(item["path"]).name.startswith("positive.") for item in parsed["results"]))

    def test_native_wrapper_scans_tests_tools_and_only_exact_fixture_exception(self):
        source = "import subprocess\nsubprocess.run(command, shell=True) # nosemgrep\n"
        self.write("tool/security/fixtures/semgrep/positive.py", source)
        self.write("clean.py", "value = 1\n")
        self.scan("semgrep")
        for path in ("test/positive.py", "tool/positive.py", "tool/security/fixtures/other/positive.py"):
            with self.subTest(path=path):
                self.write(path, source)
                result = self.scan("semgrep", expected=1)
                self.assertIn(path, result.stdout)
                self.assertNotIn("subprocess.run", result.stdout + result.stderr)
                (self.root / path).unlink()

    def fake_result(self, payload, status=0):
        self.write("fake-result.json", json.dumps(payload))
        self.shim("semgrep", 'printf "%s\\n" "$@" > "$SECURITY_ARGV_TRACE"\n'
                  'echo "private diagnostic" >&2\ncat fake-result.json\nexit ' + str(status) + "\n")
        self.env["SECURITY_ARGV_TRACE"] = str(self.root.parent / "arguments")

    def test_safe_result_rendering_and_offline_local_cli_arguments(self):
        self.fake_result({"results": [{"check_id": "local.rule", "path": "test/quote\nfile.py",
                          "start": {"line": 7}, "extra": {"lines": "private source", "metavars": "private value"}}],
                          "errors": [], "paths": {"scanned": ["test/quote\nfile.py"]}}, 1)
        result = self.scan("semgrep", expected=1)
        for hidden in ("private source", "private value", "private diagnostic"):
            self.assertNotIn(hidden, result.stdout + result.stderr)
        self.assertIn(r"quote\nfile.py", result.stdout)
        arguments = Path(self.env["SECURITY_ARGV_TRACE"]).read_text().splitlines()
        self.assertEqual(arguments, ["scan", "--config", str(self.root / ".semgrep"), "--oss-only",
                                    "--metrics=off", "--disable-version-check", "--disable-nosem",
                                    "--strict", "--error", "--json", "--quiet", "--no-rewrite-rule-ids", "."])

    def test_errors_parser_failures_empty_targets_and_status_fail_closed(self):
        clean = {"results": [], "errors": [], "paths": {"scanned": ["clean.py"]}}
        for payload, status in (({**clean, "errors": [{"message": "private diagnostic"}]}, 0),
                                ({**clean, "paths": {"scanned": []}}, 0),
                                (clean, 1), (clean, 7), ({}, 0)):
            self.fake_result(payload, status)
            result = self.scan("semgrep", expected=status if status == 7 else 2)
            self.assertNotIn("private diagnostic", result.stdout + result.stderr)
        self.shim("semgrep", "echo malformed\nexit 0\n")
        self.scan("semgrep", expected=2)
        self.scan("semgrep", "--config=p/remote", expected=2)
        self.env["PATH"] = "/usr/bin:/bin"
        self.scan("semgrep", expected=2)


if __name__ == "__main__":
    unittest.main()
