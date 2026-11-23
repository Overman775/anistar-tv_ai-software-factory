"""Project boundary regressions. Fixtures prove mechanisms, not app/model quality."""

from __future__ import annotations

import hashlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from collections.abc import Callable
from copy import deepcopy
from pathlib import Path
from typing import Any

import yaml

from factory.context import context
from factory.project.contracts import AcceptedDocument, Policy, ProjectData, Selection
from factory.project.profile_io import (
    check_frozen,
    freeze_materials,
    load_profile,
    material_entries,
    review_materials,
    snapshot,
    validate_snapshot,
)
from factory.project.profile_rules import (
    check_task,
    matches,
    required_checks,
    review_criteria,
    select_rules,
    validate,
)
from factory.project.project import review_snapshot
from factory.runtime.workflow_config import load_config
from factory.runtime.workflow_core import Invalid
from factory.runtime.workflow_graph import expand_intake_checks, validate_graph
from factory.tasks.contracts import TaskSelection
from tests.factory.runtime import workflow_fixture
from tests.factory.runtime.store_fixture import has_current, overwrite

ROOT = workflow_fixture.ROOT


def fixture_profile() -> ProjectData:
    return {
        "id": "requests",
        "rules": {
            "coordinator": [{"id": "coord", "file": "coordinator.md"}],
            "worker": [
                {
                    "id": "server",
                    "for": {
                        "roles": ["developer", "generalist", "test-writer", "judge"],
                        "paths_any": ["services/api/**"],
                    },
                    "file": "backend.md",
                },
                {
                    "id": "browser",
                    "for": {
                        "roles": ["developer", "generalist", "test-writer", "judge"],
                        "paths_any": ["apps/web/**"],
                    },
                    "file": "frontend.md",
                },
            ],
        },
        "gates": [],
    }


class ProjectTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="factory-project-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.data = fixture_profile()
        for name, content in [
            ("backend.md", "Python API rules"),
            ("frontend.md", "Browser UI rules"),
            ("coordinator.md", "Coordinator project context"),
        ]:
            (self.root / name).write_text(content)

    def policy(self, data: object = None) -> Policy:
        file = self.root / "project.yaml"
        file.write_text(yaml.safe_dump(data or self.data))
        return load_profile(file)

    def test_backend_frontend_and_joint_slice_keep_one_universal_role(self) -> None:
        policy = self.policy()
        for scope, expected in [
            (["services/api/app.py"], {"server"}),
            (["apps/web/app.ts"], {"browser"}),
            (["services/api/app.py", "apps/web/app.ts"], {"server", "browser"}),
        ]:
            for role in ["developer", "test-writer", "judge", "generalist"]:
                rules = select_rules(
                    policy["data"],
                    process="implement",
                    audience="worker",
                    role=role,
                    stage="work",
                    scope=scope,
                )
                self.assertEqual(expected, {r["id"] for r in rules})
                self.assertNotIn("Flutter", str(rules))
                self.assertNotIn("coordinator", str(rules))

    def test_unknown_scope_retains_rules_and_empty_or_invalid_scope_is_error(self) -> None:
        self.assertEqual(
            2,
            len(
                select_rules(
                    self.data, process="implement", audience="worker", role="developer", scope=None
                )
            ),
        )
        for scope in [[], ["../outside"], ["a.py", "a.py"]]:
            with self.assertRaises(ValueError):
                select_rules(
                    self.data, process="implement", audience="worker", role="developer", scope=scope
                )

    def test_rule_groups_reject_legacy_shapes_and_recipient_overrides(self) -> None:
        invalid: list[object] = [
            [],
            None,
            {"workers": []},
            {"worker": {}},
            {"worker": [{"id": "old", "audience": ["worker"], "file": "backend.md"}]},
            {
                "coordinator": [
                    {"id": "role", "for": {"roles": ["developer"]}, "file": "backend.md"}
                ]
            },
            {
                "worker": [{"id": "same", "file": "backend.md"}],
                "coordinator": [{"id": "same", "file": "backend.md"}],
            },
        ]
        for rules in invalid:
            with self.subTest(rules=rules), self.assertRaises(ValueError):
                validate({"id": "fixture", "rules": rules})

    def test_optional_groups_and_shared_material_keep_recipients_separate(self) -> None:
        groups: list[dict[str, list[object]]] = [{}, {"worker": []}, {"coordinator": []}]
        for rules in groups:
            data = validate({"id": "fixture", "rules": rules})
            self.assertEqual([], select_rules(data, process="planning", audience="coordinator"))
            self.assertEqual(
                [], select_rules(data, process="implement", audience="worker", role="developer")
            )
        data = {
            "id": "fixture",
            "rules": {
                "worker": [{"id": "worker-common", "file": "backend.md"}],
                "coordinator": [{"id": "coord-common", "file": "backend.md"}],
            },
        }
        policy = self.policy(data)
        for audience, role, expected in [
            ("worker", "developer", "worker-common"),
            ("worker", "reviewer", "worker-common"),
            ("coordinator", None, "coord-common"),
        ]:
            entries = material_entries(
                policy, self.root, process="code-review", audience=audience, role=role
            )
            self.assertEqual(["Python API rules"], [e["content"] for e in entries])
            self.assertEqual([expected], [r["id"] for r in entries[0]["rules"]])
        pinned = snapshot(policy, source="accepted fixture")
        self.assertEqual(data, validate_snapshot(pinned))
        (self.root / "backend.md").write_text("Changed shared policy")
        self.assertNotEqual(policy["hash"], self.policy(data)["hash"])

    def test_exact_glob_semantics(self) -> None:
        for pattern, path, expected in [
            ("a/*.py", "a/x/y.py", False),
            ("a/**/x.py", "a/x.py", True),
            ("a/**", "ab/x.py", False),
            ("**/*.py", "x.py", True),
            ("a/*.py", "a/x.py", True),
        ]:
            self.assertEqual(
                expected, matches({"paths_any": [pattern]}, process="implement", scope=[path])
            )

    def test_every_coordinator_process_resolves_without_implement_graph(self) -> None:
        policy = self.policy()
        for process in [
            "planning",
            "decompose",
            "implement",
            "code-review",
            "code-audit",
            "code-debt",
            "meta-retro",
            "pr",
            "install",
        ]:
            entries = material_entries(
                policy, self.root, process=process, audience="coordinator", scope=None
            )
            self.assertEqual(["Coordinator project context"], [e["content"] for e in entries])

    def test_unknown_fields_duplicate_ids_bad_selectors_and_cycles_rejected(self) -> None:
        changes: list[Callable[[Any], object]] = [
            lambda d: d.update(include=["other.yaml"]),
            lambda d: d.update(support_files=[]),
            lambda d: d.update(support_files=["backend.md"]),
            lambda d: d["rules"]["worker"].append(deepcopy(d["rules"]["worker"][0])),
            lambda d: d["rules"]["worker"][0]["for"].update(roles=["backend-developer"]),
            lambda d: d["rules"]["worker"][0]["for"].update(paths_any=[]),
            lambda d: d["rules"]["worker"][0].update(file="../outside"),
            lambda d: d["rules"]["worker"][0].update(forbidden="ignored"),
            lambda d: d["rules"]["worker"][0].update(audience=["coordinator"]),
            lambda d: d.update(decomposition={}),
            lambda d: d["gates"].append(
                {
                    "id": "review",
                    "at": ["code-review.complete"],
                    "criteria": [
                        {"id": "SYS-INTENT", "lens": "system-design", "question": "override"}
                    ],
                }
            ),
        ]
        for change in changes:
            data = deepcopy(self.data)
            change(data)
            with self.subTest(data=data), self.assertRaises(ValueError):
                validate(data)
        data = deepcopy(self.data)
        data["gates"] = [
            {
                "id": "verify",
                "at": ["implement.verify"],
                "checks": [
                    {
                        "id": c,
                        "kind": "observation",
                        "level": "slice",
                        "method": "observe",
                        "after": [other],
                    }
                    for c, other in [("a", "b"), ("b", "a")]
                ],
            }
        ]
        with self.assertRaisesRegex(ValueError, "cycle"):
            validate(data)

    def test_duplicate_yaml_key_missing_and_symlink_files_block(self) -> None:
        file = self.root / "project.yaml"
        file.write_text("id: a\nid: b\n")
        with self.assertRaisesRegex(ValueError, "duplicate"):
            load_profile(file)
        (self.root / "backend.md").unlink()
        with self.assertRaisesRegex(ValueError, "missing"):
            self.policy()
        (self.root / "backend.md").symlink_to(self.root / "frontend.md")
        with self.assertRaisesRegex(ValueError, "symlink"):
            self.policy()

    def test_shared_file_retains_both_rules_but_is_read_once(self) -> None:
        self.data["rules"]["worker"][1]["file"] = "backend.md"
        policy = self.policy()
        calls = []

        def read(file: Path) -> bytes:
            calls.append(file)
            return file.read_bytes()

        entries = material_entries(
            policy,
            self.root,
            process="implement",
            audience="worker",
            role="developer",
            scope=None,
            read_bytes=read,
        )
        self.assertEqual(1, len(calls))
        self.assertEqual(2, len(entries[0]["rules"]))
        self.assertEqual(hashlib.sha256(b"Python API rules").hexdigest(), entries[0]["sha256"])

    def test_profile_fingerprint_survives_checkout_relocation(self) -> None:
        import shutil

        policy = self.policy()
        moved = self.root / "moved"
        shutil.copytree(self.root, moved, ignore=shutil.ignore_patterns("moved"))
        self.assertEqual(policy["hash"], load_profile(moved / "project.yaml")["hash"])

    def test_anistar_selectors_match_pre_migration_oracle(self) -> None:
        profile = load_profile(ROOT / "project/project.yaml")["data"]
        baseline = json.loads((Path(__file__).parent / "anistar-selectors.before.json").read_text())
        self.assertNotIn("review_rule_ids", profile)
        self.assertEqual(
            [(x["id"], x["lens"], x["regex"]) for x in baseline["gates"]],
            [(x["id"], x["lens"], x["for"]["path_regex"]) for x in review_criteria(profile)],
        )
        paths = [
            "lib/packages/features/player/presentation/player.dart",
            "test/app/app_container_test.dart",
            "docs/04_network_and_playback.md",
            "android/app/build.gradle",
            "pubspec.yaml",
            "tool/e2e/media/movie.bin",
            ".factory/contracts/session.md",
            "services/api/app.py",
            "apps/web/review.ts",
            "test/infrastructure/storage/store.dart",
        ]
        for path in paths:
            before = {x["id"] for x in baseline["gates"] if re.search(x["regex"], path)}
            after = {
                x["id"]
                for x in review_criteria(profile)
                if matches(x["for"], process="code-review", scope=[path])
            }
            self.assertEqual(before, after, path)

    def test_anistar_checks_cannot_be_omitted_changed_or_silently_inapplicable(self) -> None:
        profile = load_profile(ROOT / "project/project.yaml")["data"]
        task: TaskSelection = {
            "scope": ["lib/app.dart"],
            "policy_decisions": {
                "dart-changes": {
                    "probability": 0.9,
                    "source": "agent:fixture",
                    "reason": "changed Dart",
                },
                "application-changes": {
                    "probability": 0.9,
                    "source": "agent:fixture",
                    "reason": "changed application",
                },
            },
        }
        local = required_checks(profile, task)
        final = required_checks(profile, task, final=True)
        self.assertEqual(
            ["anistar-analyze", "anistar-dcm", "anistar-format-check"], [c["id"] for c in local]
        )
        self.assertEqual(
            ["check", "test:e2e", "build:android:prod:apk"],
            [c["execution"]["argv"][-1] for c in final[3:] if c["kind"] != "observation"],
        )
        task["required_checks"] = final
        check_task(profile, task, final=True)
        task["required_checks"] = final[:-1]
        with self.assertRaisesRegex(ValueError, "missing/changed"):
            check_task(profile, task, final=True)
        task["required_checks"] = deepcopy(final)
        command = task["required_checks"][0]
        assert command["kind"] != "observation"
        command["execution"]["argv"] = ["true"]
        with self.assertRaisesRegex(ValueError, "missing/changed"):
            check_task(profile, task, final=True)
        del task["policy_decisions"]["dart-changes"]
        with self.assertRaisesRegex(ValueError, "UNKNOWN"):
            required_checks(profile, task)

    def test_compact_examples_expand_and_persist_checks(self) -> None:
        for name in ("example.workflow.json", "reviewed-slice.workflow.json"):
            fixture = workflow_fixture.WorkflowFixture(self.addCleanup)
            fixture.config["_project"] = load_profile(ROOT / "project/project.yaml")
            fixture.config["_files"].update(fixture.config["_project"]["files"])
            for document in fixture.config["_project"]["data"]["documents"].values():
                path = fixture.root / document["path"]
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("Fixture document", encoding="utf-8")
            graph = json.loads((ROOT / "tooling/examples" / name).read_text(encoding="utf-8"))
            if name.startswith("reviewed"):
                fixture.config["_defaults"]["test-writer"] = "middle-test-writer-zcode"
            full = expand_intake_checks(graph, fixture.config)
            task_id = next(iter(full["tasks"]))
            task = full["tasks"][task_id]
            self.assertEqual(
                [
                    "behavior",
                    "anistar-analyze",
                    "anistar-dcm",
                    "anistar-format-check",
                    "anistar-check",
                    "anistar-test-e2e",
                    "anistar-build-android-prod-apk",
                ],
                [c["id"] for c in task["required_checks"]],
            )
            validate_graph(full, fixture.config, fixture.root)
            explicit = deepcopy(full)
            explicit["tasks"][task_id]["required_checks"].pop()
            with self.assertRaisesRegex(Invalid, "missing/changed"):
                validate_graph(explicit, fixture.config, fixture.root)
            conflict = deepcopy(graph)
            conflict["tasks"][task_id]["required_checks"].append(task["required_checks"][1])
            with self.assertRaisesRegex(Invalid, "conflicts"):
                expand_intake_checks(conflict, fixture.config)
            saved = fixture.ledger.init(graph, fixture.config)["graph"]
            self.assertEqual(full["tasks"], saved["tasks"])
            validate_graph(saved, fixture.config, fixture.root)

    def test_compact_checks_keep_additional_inputs(self) -> None:
        fixture = workflow_fixture.WorkflowFixture(self.addCleanup)
        fixture.config["_project"] = load_profile(ROOT / "project/project.yaml")
        graph = json.loads((ROOT / "tooling/examples/example.workflow.json").read_text())
        graph["tasks"]["label"]["project_check_inputs"] = {"anistar-analyze": ["extra.txt"]}
        task = expand_intake_checks(graph, fixture.config)["tasks"]["label"]
        check_task(fixture.config["_project"]["data"], task, final=True)
        check = task["required_checks"][1]
        assert check["kind"] != "observation"
        self.assertEqual(
            ["pubspec.yaml", "pubspec.lock", "extra.txt"], check["execution"]["inputs"]
        )

    def test_task_inputs_can_strengthen_but_not_weaken_profile_checks(self) -> None:
        profile = load_profile(ROOT / "project/project.yaml")["data"]
        original = deepcopy(profile)
        task: TaskSelection = {
            "scope": ["lib/app.dart"],
            "policy_decisions": {
                "dart-changes": {
                    "probability": 0.9,
                    "source": "agent:fixture",
                    "reason": "changed Dart",
                }
            },
        }
        task["required_checks"] = required_checks(profile, task)
        command = task["required_checks"][0]
        assert command["kind"] != "observation"
        command["execution"]["inputs"].append("tool/check.py")
        check_task(profile, task)
        self.assertEqual(original, profile, "returned check data must not mutate policy")
        mutations_383: list[Callable[[Any], object]] = [
            lambda e: e["inputs"].remove("pubspec.lock"),
            lambda e: e["inputs"].append("../outside"),
            lambda e: e["inputs"].append("tool/check.py"),
            lambda e: e.update(cwd="tool"),
            lambda e: e.update(timeout_seconds=1),
        ]
        for change in mutations_383:
            weakened = deepcopy(task)
            command = weakened["required_checks"][0]
            assert command["kind"] != "observation"
            change(command["execution"])
            with (
                self.subTest(execution=command["execution"]),
                self.assertRaises(ValueError),
            ):
                check_task(profile, weakened)

    def test_snapshot_hash_and_baseline_do_not_hot_reload_candidate(self) -> None:
        policy = self.policy()
        before = snapshot(policy, source="accepted fixture")
        self.data["gates"] = [
            {
                "id": "review",
                "at": ["code-review.complete"],
                "criteria": [{"id": "WEB-CHECK", "lens": "runtime-safety", "question": "new gate"}],
            }
        ]
        self.policy()
        self.assertEqual([], review_criteria(validate_snapshot(before)))
        corrupt = deepcopy(before)
        corrupt["profile"]["id"] = "changed"
        with self.assertRaisesRegex(ValueError, "hash mismatch"):
            validate_snapshot(corrupt)

    def test_review_snapshot_reads_git_baseline_not_changed_checkout(self) -> None:
        self.data["documents"] = {
            "api": {"path": "api.md"},
            "schema": {"path": "schema.md"},
            "owner": {"path": ".factory/memory/USER.md"},
        }
        for audience in ("worker", "coordinator"):
            self.data["rules"][audience].append(
                {
                    "id": "review-docs-" + audience,
                    "for": {"processes": ["code-review"]},
                    "documents": ["api", "schema", "owner"],
                }
            )
        for name in ["api.md", "schema.md"]:
            (self.root / name).write_text("Accepted " + name)
        self.policy()
        (self.root / "AGENTS.md").write_text("Accepted workspace policy")
        user = self.root / ".factory/memory/USER.md"
        user.parent.mkdir(parents=True)
        user.write_text("Baseline owner instructions", encoding="utf-8")

        def git(*args: str) -> str:
            return subprocess.run(
                ["git", "-C", str(self.root), *args], check=True, capture_output=True, text=True
            ).stdout.strip()

        git("init", "-q")
        git("add", ".")
        git(
            "-c",
            "user.name=Fixture",
            "-c",
            "user.email=fixture@example.invalid",
            "-c",
            "commit.gpgsign=false",
            "commit",
            "-qm",
            "baseline",
        )
        sha = git("rev-parse", "HEAD")
        (self.root / "backend.md").write_text("candidate weakens policy")
        (self.root / "api.md").write_text("candidate API")
        user.write_text("Candidate replacement", encoding="utf-8")
        result = review_snapshot(self.root, sha, "project.yaml")
        self.assertEqual("git:" + sha, result["source"])
        self.assertEqual(
            hashlib.sha256(b"Python API rules").hexdigest(), result["files"]["backend.md"]
        )
        entries = review_materials(result, self.root, self.root, role="reviewer")
        [owner] = [entry for entry in entries if entry["path"] == str(user)]
        self.assertEqual(["review-docs-worker"], [r["id"] for r in owner.get("rules", [])])
        self.assertTrue(
            {"Accepted api.md", "Accepted schema.md", "Baseline owner instructions"}
            <= {e["content"] for e in entries}
        )

    def test_review_policy_cli_uses_full_commit_in_repository_object_format(self) -> None:
        for object_format in ("sha1", "sha256"):
            with self.subTest(object_format=object_format):
                root = self.root / object_format
                root.mkdir()
                (root / "project.yaml").write_text(yaml.safe_dump(self.data), encoding="utf-8")
                for name in ("backend.md", "frontend.md", "coordinator.md", "AGENTS.md"):
                    (root / name).write_text("baseline " + name, encoding="utf-8")

                def git(*args: str, root: Path = root) -> str:
                    return subprocess.run(
                        ["git", "-C", str(root), *args],
                        check=True,
                        capture_output=True,
                        text=True,
                    ).stdout.strip()

                git("init", "-q", "--object-format=" + object_format)
                git("add", ".")
                git(
                    "-c",
                    "user.name=Fixture",
                    "-c",
                    "user.email=fixture@example.invalid",
                    "-c",
                    "commit.gpgsign=false",
                    "commit",
                    "-qm",
                    "baseline",
                )
                revision = git("rev-parse", "HEAD")
                blob = git("rev-parse", "HEAD:AGENTS.md")
                (root / "AGENTS.md").write_text("later commit", encoding="utf-8")
                git("add", ".")
                git(
                    "-c",
                    "user.name=Fixture",
                    "-c",
                    "user.email=fixture@example.invalid",
                    "-c",
                    "commit.gpgsign=false",
                    "commit",
                    "-qm",
                    "later",
                )
                (root / "AGENTS.md").write_text("working copy", encoding="utf-8")

                def cli(value: str, root: Path = root) -> subprocess.CompletedProcess[str]:
                    return subprocess.run(
                        [
                            sys.executable,
                            str(ROOT / "tooling/bin/project.py"),
                            "--workspace",
                            str(root),
                            "review-policy",
                            "--profile-path",
                            "project.yaml",
                            "--revision",
                            value,
                        ],
                        capture_output=True,
                        text=True,
                    )

                mixed = "".join(c.upper() if i % 2 == 0 else c for i, c in enumerate(revision))
                for value in (revision, revision.upper(), mixed):
                    with self.subTest(revision=value):
                        result = cli(value)
                        self.assertEqual(0, result.returncode, result.stderr)
                        pinned = json.loads(result.stdout)
                        self.assertEqual("git:" + revision, pinned["source"])
                        self.assertEqual(
                            "baseline AGENTS.md", pinned["documents"]["AGENTS.md"]["content"]
                        )
                for invalid in (
                    revision[:-1],
                    revision + "0",
                    "g" * len(revision),
                    "0" * len(revision),
                    blob,
                ):
                    self.assertNotEqual(0, cli(invalid).returncode, invalid)

    def test_review_stage_documents_are_pinned_and_selected_by_cli(self) -> None:
        data: Any = deepcopy(self.data)
        data["documents"] = {name: {"path": name + ".md"} for name in ("review", "work", "all")}
        data["rules"]["worker"] = [
            {"id": name, "for": {"processes": ["code-review"], **selector}, "documents": [name]}
            for name, selector in (
                ("review", {"stages": ["review"]}),
                ("work", {"stages": ["work"]}),
                ("all", {}),
            )
        ]
        for name in ("review", "work", "all"):
            (self.root / (name + ".md")).write_text("Accepted " + name, encoding="utf-8")
        (self.root / "AGENTS.md").write_text("Accepted instructions", encoding="utf-8")
        self.policy(data)

        def git(*args: str) -> str:
            return subprocess.run(
                ["git", "-C", str(self.root), *args], check=True, capture_output=True, text=True
            ).stdout.strip()

        git("init", "-q")
        git("add", ".")
        git(
            "-c",
            "user.name=Fixture",
            "-c",
            "user.email=fixture@example.invalid",
            "-c",
            "commit.gpgsign=false",
            "commit",
            "-qm",
            "baseline",
        )
        pinned = review_snapshot(self.root, git("rev-parse", "HEAD"), "project.yaml")
        self.assertEqual({"AGENTS.md", "review.md", "all.md"}, pinned["documents"].keys())
        (self.root / "review.md").write_text("Candidate review", encoding="utf-8")
        policy_file = self.root / "snapshot.json"
        policy_file.write_text(json.dumps(pinned), encoding="utf-8")
        result = subprocess.run(
            [
                sys.executable,
                str(ROOT / "tooling/bin/project.py"),
                "--workspace",
                str(self.root),
                "context",
                "--process",
                "code-review",
                "--audience",
                "worker",
                "--role",
                "reviewer",
                "--policy-snapshot",
                str(policy_file),
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        contents = {entry["content"] for entry in json.loads(result.stdout)["instructions"]}
        self.assertIn("Accepted review", contents)
        self.assertIn("Accepted all", contents)
        self.assertNotIn("Accepted work", contents)
        self.assertNotIn("Candidate review", contents)

    def test_review_snapshot_uses_nested_project_baseline(self) -> None:
        self.policy()
        (self.root / "AGENTS.md").write_text("Root policy", encoding="utf-8")
        child = self.root / "nested" / "project"
        child.mkdir(parents=True)
        child_data = deepcopy(self.data)
        child_data["id"] = "child"
        (child / "project.yaml").write_text(yaml.safe_dump(child_data), encoding="utf-8")
        for name in ("backend.md", "frontend.md", "coordinator.md"):
            (child / name).write_text("Child " + name, encoding="utf-8")
        (child / "AGENTS.md").write_text("Child policy", encoding="utf-8")
        colon_child = self.root / ":child"
        if sys.platform != "win32":
            shutil.copytree(child, colon_child)
        sibling = child.parent / "sibling"
        sibling.mkdir()
        (sibling / "tracked").write_text("tracked", encoding="utf-8")

        def git(*args: str) -> str:
            return subprocess.run(
                ["git", "-C", str(self.root), *args], check=True, capture_output=True, text=True
            ).stdout.strip()

        git("init", "-q")
        git("add", ".")
        git(
            "-c",
            "user.name=Fixture",
            "-c",
            "user.email=fixture@example.invalid",
            "-c",
            "commit.gpgsign=false",
            "commit",
            "-qm",
            "baseline",
        )
        revision = git("rev-parse", "HEAD")
        (child / "AGENTS.md").write_text("Candidate policy", encoding="utf-8")
        nested = review_snapshot(child, revision, "project.yaml")
        root = review_snapshot(self.root, revision, "project.yaml")
        self.assertEqual("child", nested["profile"]["id"])
        self.assertEqual("Child policy", nested["documents"]["AGENTS.md"]["content"])
        self.assertEqual(
            hashlib.sha256(b"Child backend.md").hexdigest(), nested["files"]["backend.md"]
        )
        self.assertEqual("requests", root["profile"]["id"])
        self.assertEqual("Root policy", root["documents"]["AGENTS.md"]["content"])
        if sys.platform != "win32":
            self.assertEqual(
                "child", review_snapshot(colon_child, revision, "project.yaml")["profile"]["id"]
            )
        via_parent = sibling / ".." / "project"
        self.assertEqual(
            "child", review_snapshot(via_parent, revision, "project.yaml")["profile"]["id"]
        )

        (child / "AGENTS.md").unlink()
        (child / "AGENTS.md").symlink_to("../../AGENTS.md")
        git("add", ".")
        git(
            "-c",
            "user.name=Fixture",
            "-c",
            "user.email=fixture@example.invalid",
            "-c",
            "commit.gpgsign=false",
            "commit",
            "-qm",
            "symlink",
        )
        with self.assertRaisesRegex(ValueError, "symlink"):
            review_snapshot(child, git("rev-parse", "HEAD"), "project.yaml")

        alias = self.root / "alias"
        alias.symlink_to(child, target_is_directory=True)
        reentry = self.root / "reentry"
        reentry.symlink_to(".", target_is_directory=True)
        git("add", ".")
        git(
            "-c",
            "user.name=Fixture",
            "-c",
            "user.email=fixture@example.invalid",
            "-c",
            "commit.gpgsign=false",
            "commit",
            "-qm",
            "workspace symlink",
        )
        with self.assertRaisesRegex(ValueError, "symlink"):
            review_snapshot(alias, git("rev-parse", "HEAD"), "project.yaml")
        with self.assertRaisesRegex(ValueError, "symlink"):
            review_snapshot(
                reentry / "nested" / "project", git("rev-parse", "HEAD"), "project.yaml"
            )
        with self.assertRaisesRegex(ValueError, "symlink"):
            review_snapshot(alias / ".." / "project", git("rev-parse", "HEAD"), "project.yaml")

        (child / "AGENTS.md").unlink()
        (child / "AGENTS.md").write_text("Child policy", encoding="utf-8")
        (child / "linked").symlink_to(".", target_is_directory=True)
        git("add", ".")
        git(
            "-c",
            "user.name=Fixture",
            "-c",
            "user.email=fixture@example.invalid",
            "-c",
            "commit.gpgsign=false",
            "commit",
            "-qm",
            "symlink directory",
        )
        with self.assertRaisesRegex(ValueError, "symlink"):
            review_snapshot(child, git("rev-parse", "HEAD"), "linked/project.yaml")

    def test_review_snapshot_git_root_with_trailing_space(self) -> None:
        root = self.root / "repo "
        root.mkdir()
        (root / "project.yaml").write_text(yaml.safe_dump(self.data), encoding="utf-8")
        for name in ("AGENTS.md", "backend.md", "frontend.md", "coordinator.md"):
            (root / name).write_text(name, encoding="utf-8")

        def git(*args: str) -> str:
            return subprocess.run(
                ["git", "-C", str(root), *args], check=True, capture_output=True, text=True
            ).stdout.strip()

        git("init", "-q")
        git("add", ".")
        git(
            "-c",
            "user.name=Fixture",
            "-c",
            "user.email=fixture@example.invalid",
            "-c",
            "commit.gpgsign=false",
            "commit",
            "-qm",
            "baseline",
        )
        result = review_snapshot(root, git("rev-parse", "HEAD"), "project.yaml")
        self.assertEqual("requests", result["profile"]["id"])
        self.assertEqual("AGENTS.md", result["documents"]["AGENTS.md"]["content"])

    def test_document_catalog_is_optional_and_not_implicitly_loaded(self) -> None:
        for catalog in [None, {}, {"unused": {"path": "missing.md", "category": "custom"}}]:
            data: dict[str, Any] = {"id": "empty"}
            if catalog is not None:
                data["documents"] = catalog
            policy = self.policy(data)
            self.assertEqual(
                [],
                material_entries(
                    policy, self.root, process="implement", audience="worker", role="developer"
                ),
            )

    def test_decompose_roles_receive_zero_one_or_three_selected_documents(self) -> None:
        for count in (0, 1, 3):
            with self.subTest(count=count):
                names = [f"architecture-{index}" for index in range(count)]
                for name in names:
                    (self.root / f"{name}.md").write_text(name, encoding="utf-8")
                data: dict[str, Any] = {
                    "id": "decompose",
                    "documents": {name: {"path": f"{name}.md"} for name in names},
                }
                if names:
                    data["rules"] = {"worker": [{"id": "sources", "documents": names}]}
                policy = self.policy(data)
                for role in ("task-decomposer", "task-reviewer"):
                    entries = material_entries(
                        policy, self.root, process="decompose", audience="worker", role=role
                    )
                    self.assertEqual(set(names), {entry["content"] for entry in entries})

    def test_document_lists_select_exact_files_and_deduplicate_with_provenance(self) -> None:
        self.data["documents"] = {
            "api": {"path": "backend.md", "category": "architecture"},
            "web": {"path": "frontend.md", "category": "architecture"},
            "api-alias": {"path": "backend.md"},
            "other": {"path": "absent.md", "category": "architecture"},
        }
        self.data["rules"] = {
            "worker": [
                {"id": "api", "for": {"paths_any": ["api/**"]}, "documents": ["api", "api-alias"]},
                {"id": "web", "for": {"paths_any": ["web/**"]}, "documents": ["web", "api"]},
            ]
        }
        policy = self.policy()
        for scope, expected in [
            (["api/a.py"], {"Python API rules"}),
            (["web/a.ts"], {"Python API rules", "Browser UI rules"}),
            (["api/a.py", "web/a.ts"], {"Python API rules", "Browser UI rules"}),
            (None, {"Python API rules", "Browser UI rules"}),
        ]:
            reads: list[Path] = []

            def read(path: Path, reads: list[Path] = reads) -> bytes:
                reads.append(path)
                return path.read_bytes()

            entries = material_entries(
                policy,
                self.root,
                process="implement",
                audience="worker",
                role="developer",
                scope=scope,
                read_bytes=read,
            )
            self.assertEqual(expected, {e["content"] for e in entries})
            self.assertEqual(len(expected), len(reads))
            if scope is None:
                self.assertEqual(
                    {"api", "web"},
                    {
                        x["id"]
                        for e in entries
                        if e["content"] == "Python API rules"
                        for x in e["rules"]
                    },
                )

    def test_document_catalog_rejects_bad_references_and_legacy_schema(self) -> None:
        self.data["documents"] = {"api": {"path": "backend.md"}}
        self.data["rules"] = {"worker": [{"id": "read", "documents": ["api"]}]}
        mutations_525: list[Callable[[Any], object]] = [
            lambda d: d.update(discovery=[]),
            lambda d: d["documents"].update(api="backend.md"),
            lambda d: d["documents"]["api"].update(path="../escape"),
            lambda d: d["documents"]["api"].update(category=[]),
            lambda d: d["rules"]["worker"][0].update(document="api"),
            lambda d: d["rules"]["worker"][0].update(documents=[]),
            lambda d: d["rules"]["worker"][0].update(documents=["unknown"]),
            lambda d: d["rules"]["worker"][0].update(documents=["api", "api"]),
        ]
        for change in mutations_525:
            data = deepcopy(self.data)
            change(data)
            with self.subTest(data=data), self.assertRaises(ValueError):
                validate(data)

    def test_all_selected_documents_are_required_and_frozen(self) -> None:
        self.data["documents"] = {"api": {"path": "backend.md"}, "web": {"path": "frontend.md"}}
        self.data["rules"] = {"worker": [{"id": "read", "documents": ["api", "web"]}]}
        policy = self.policy()
        selection: Selection = dict(process="implement", audience="worker", role="developer")
        frozen = freeze_materials(policy, self.root, [selection])
        self.assertEqual(2, len(frozen))
        (self.root / "frontend.md").write_text("changed")
        with self.assertRaisesRegex(ValueError, "drift"):
            check_frozen(frozen)
        (self.root / "frontend.md").unlink()
        with self.assertRaisesRegex(ValueError, "missing"):
            material_entries(policy, self.root, **selection)


class ProjectIntegrationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.f = workflow_fixture.WorkflowFixture(self.addCleanup)

    def install_policy(self, data: object) -> None:
        f = self.f
        f.fixture_profile.write_text(yaml.safe_dump(data))
        f.config["_project"] = load_profile(f.fixture_profile)
        f.config["_files"].update(f.config["_project"]["files"])

    def test_review_packet_preserves_accepted_profile_rule_paths(self) -> None:
        f = self.f
        paths = [".factory/project", "custom/policy"]
        for directory in paths:
            folder = f.root / directory
            folder.mkdir(parents=True)
            (folder / "rule.md").write_text("Rule from " + directory, encoding="utf-8")
            (folder / "second.md").write_text("Second from " + directory, encoding="utf-8")
            (folder / "project.yaml").write_text(
                yaml.safe_dump(
                    {
                        "id": "fixture",
                        "rules": {
                            "worker": [
                                {"id": "first", "file": "rule.md"},
                                {"id": "second", "file": "second.md"},
                                {"id": "document", "project_file": "other/rule.md"},
                            ]
                        },
                    }
                ),
                encoding="utf-8",
            )
        (f.root / "other").mkdir()
        (f.root / "other/rule.md").write_text("Other rule", encoding="utf-8")

        def git(*args: str) -> str:
            return subprocess.run(
                ["git", "-C", str(f.root), *args], check=True, capture_output=True, text=True
            ).stdout.strip()

        git("init", "-q")
        git("add", ".")
        git(
            "-c",
            "user.name=Fixture",
            "-c",
            "user.email=fixture@example.invalid",
            "-c",
            "commit.gpgsign=false",
            "commit",
            "-qm",
            "baseline",
        )
        revision = git("rev-parse", "HEAD")
        for directory in paths:
            with self.subTest(directory=directory):
                pinned = review_snapshot(f.root, revision, directory + "/project.yaml")
                packet = context.build(
                    f.config,
                    f.root,
                    f.config["_defaults"]["reviewer"],
                    "reviewer",
                    "code-review",
                    {
                        "source": f.g["sources"]["request"],
                        "scope_files": ["lib/example.dart"],
                        "project_policy": pinned,
                    },
                )
                selected = [
                    entry
                    for entry in packet["instructions"]
                    if entry.get("reason", "").startswith("accepted review policy:")
                ]
                self.assertEqual(
                    [
                        (str((f.root / directory / "rule.md").resolve()), "Rule from " + directory),
                        (
                            str((f.root / directory / "second.md").resolve()),
                            "Second from " + directory,
                        ),
                        (str((f.root / "other/rule.md").resolve()), "Other rule"),
                    ],
                    [(entry["path"], entry["content"]) for entry in selected],
                )

    def test_standalone_review_packet_selects_review_stage(self) -> None:
        f = self.f
        self.install_policy(
            {
                "id": "fixture",
                "documents": {name: {"path": name + ".md"} for name in ("review", "work", "all")},
                "rules": {
                    "worker": [
                        {"id": name, "for": selector, "documents": [name]}
                        for name, selector in (
                            ("review", {"stages": ["review"]}),
                            ("work", {"stages": ["work"]}),
                            ("all", {}),
                        )
                    ]
                },
            }
        )
        documents: dict[str, AcceptedDocument] = {}
        for name in ("AGENTS.md", "review.md", "work.md", "all.md"):
            content = "Accepted " + name
            documents[name] = {
                "content": content,
                "sha256": hashlib.sha256(content.encode()).hexdigest(),
            }
        pinned = snapshot(f.config["_project"], source="fixture", documents=documents)
        packet = context.build(
            f.config,
            f.root,
            f.config["_defaults"]["reviewer"],
            "reviewer",
            "code-review",
            {
                "source": f.g["sources"]["request"],
                "task": {"scope": ["lib/example.dart"]},
                "project_policy": pinned,
            },
        )
        contents = {entry["content"] for entry in packet["instructions"]}
        self.assertIn("Accepted review.md", contents)
        self.assertIn("Accepted all.md", contents)
        self.assertNotIn("Accepted work.md", contents)

    def test_worker_packet_and_ledger_freeze_project_document(self) -> None:
        f = self.f
        (f.root / "norm.md").write_text("Original normative input")
        data: dict[str, Any] = {
            "id": "fixture",
            "documents": {"norm": {"path": "norm.md", "category": "custom"}},
            "rules": {"worker": [{"id": "norm", "documents": ["norm"]}]},
        }
        self.install_policy(data)
        f.init()
        f.start("write-label")
        packet = f.ledger.packet("write-label")
        self.assertIn("Original normative input", [x["content"] for x in packet["instructions"]])
        (f.root / "norm.md").write_text("Weakened normative input")
        self.assertEqual(packet, f.ledger.packet("write-label"))

    def test_legacy_document_hash_resumes_with_matching_bytes_or_authorized_replacement(
        self,
    ) -> None:
        f = self.f
        norm = f.root / "norm.md"
        norm.write_text("Accepted rules")
        self.install_policy(
            {"id": "fixture", "rules": {"worker": [{"id": "norm", "project_file": "norm.md"}]}}
        )
        f.init()
        state = f.ledger.read()
        state["config"].pop("_documents")
        overwrite(f.ledger, state)
        f.ledger.claim("write-label")
        self.assertIn(
            "Accepted rules",
            [x["content"] for x in f.ledger.packet("write-label")["instructions"]],
        )
        overwrite(f.ledger, state)
        norm.write_text("Candidate rules")
        with self.assertRaisesRegex(Invalid, "Accepted document bytes unavailable"):
            f.ledger.claim("write-label")
        f.ledger.reintake(
            state["graph"], "Adopt specific replacement", "user evidence", documents=["norm.md"]
        )
        f.ledger.claim("write-label")
        self.assertIn(
            "Candidate rules",
            [x["content"] for x in f.ledger.packet("write-label")["instructions"]],
        )

    def test_reintake_selects_new_scoped_document_and_refreshes_only_authorized_documents(
        self,
    ) -> None:
        f = self.f
        (f.root / "base.md").write_text("Existing policy")
        (f.root / "background.md").write_text("Existing background")
        (f.root / "additional.md").write_text("Additional scoped policy")
        (f.root / "extra").mkdir()
        (f.root / "extra/new.py").write_text("new")
        self.install_policy(
            {
                "id": "fixture",
                "documents": {
                    "base": {"path": "base.md", "category": "custom"},
                    "additional": {"path": "additional.md", "category": "custom"},
                },
                "rules": {
                    "worker": [
                        {"id": "base", "documents": ["base"]},
                        {"id": "background", "project_file": "background.md", "usage": "reference"},
                        {
                            "id": "additional",
                            "for": {"paths_any": ["extra/**"]},
                            "documents": ["additional"],
                        },
                    ]
                },
            }
        )
        f.init()
        graph = deepcopy(f.ledger.read()["graph"])
        graph["tasks"]["label"]["scope"].append("extra/new.py")
        (f.root / "base.md").write_text("Changed policy")
        (f.root / "background.md").write_text("Changed background")
        before = f.ledger.read()
        with self.assertRaisesRegex(Invalid, "Only existing accepted"):
            f.ledger.reintake(
                graph, "scope extension", "user authorization", documents=["additional.md"]
            )
        self.assertEqual(before, f.ledger.read())
        f.ledger.reintake(
            graph, "scope extension", "user authorization", documents=["base.md", "background.md"]
        )
        f.ledger.claim("write-label")
        (f.root / "additional.md").write_text("Changed scoped policy")
        (f.root / "background.md").write_text("Another candidate edit")
        packet = f.ledger.packet("write-label")
        instructions = [x["content"] for x in packet["instructions"]]
        self.assertIn("Additional scoped policy", instructions)
        self.assertIn("Changed policy", instructions)
        self.assertIn("Changed background", instructions)

    def test_decompose_executable_dependency_cannot_be_refreshed_as_document(self) -> None:
        f = self.f
        script = "decompose-check.tool"
        (f.root / script).write_text("executable gate input")
        guide = "guide.md"
        (f.root / guide).write_text("Accepted guide")
        binary = "check-input.bin"
        (f.root / binary).write_bytes(b"\xff\0")
        self.install_policy(
            {
                "id": "fixture",
                "gates": [
                    {
                        "id": "task-structure",
                        "at": ["decompose.complete"],
                        "checks": [
                            {
                                "id": "custom",
                                "kind": "static",
                                "level": "slice",
                                "method": "Check project tasks.",
                                "execution": {
                                    "argv": ["{python}", script],
                                    "cwd": ".",
                                    "timeout_seconds": 1,
                                    "inputs": [script, guide, binary],
                                },
                            }
                        ],
                    }
                ],
            }
        )
        f.g["nodes"][0]["read"] = [script, guide]
        state = f.init()
        with self.assertRaisesRegex(Invalid, "Only existing accepted documents"):
            f.ledger.reintake(state["graph"], "Change gate", "user evidence", documents=[script])
        self.assertNotIn(str(f.root / binary), state["config"]["_documents"])
        (f.root / guide).write_text("Candidate guide")
        f.ledger.claim("write-label")
        self.assertIn(
            "Accepted guide",
            [x["content"] for x in f.ledger.packet("write-label")["instructions"]],
        )
        (f.root / binary).write_bytes(b"\xfd\0")
        with self.assertRaisesRegex(Invalid, "Executable configuration/tooling drift"):
            f.ledger.packet("write-label")
        (f.root / binary).write_bytes(b"\xff\0")
        (f.root / script).write_text("changed executable gate input")
        with self.assertRaisesRegex(Invalid, "Executable configuration/tooling drift"):
            f.ledger.packet("write-label")

    def test_actual_worker_packets_preserve_joint_scope_and_distinct_permissions(self) -> None:
        f = self.f
        for name in ("backend.md", "frontend.md", "coordinator.md"):
            (f.root / name).write_text(name + " project rules")
        self.install_policy(fixture_profile())
        task = deepcopy(f.g["tasks"]["label"])
        task["scope"] = ["services/api/app.py", "apps/web/app.ts"]
        for role in ["developer", "test-writer", "judge"]:
            packet = context.build(
                f.config,
                f.root,
                f.config["_defaults"][role],
                role,
                "implement",
                {
                    "source": f.g["sources"]["request"],
                    "task": task,
                    "node": {"stage": "work", "read": []},
                },
            )
            self.assertEqual(task, dict(packet)["task"])
            selected = {x["content"] for x in packet["instructions"]}
            self.assertIn("backend.md project rules", selected)
            self.assertIn("frontend.md project rules", selected)
            self.assertNotIn("coordinator.md project rules", selected)
            self.assertEqual(
                f.config["profiles"][f.config["_defaults"][role]]["capabilities"],
                packet["profile"]["capabilities"],
            )
            self.assertFalse(
                any("project/rules/coding.md" in x["path"] for x in packet["instructions"])
            )

    def test_review_worker_reads_accepted_policy_not_candidate(self) -> None:
        f = self.f
        data: dict[str, Any] = {
            "id": "fixture",
            "rules": {"worker": [{"id": "review", "file": "review.md"}]},
        }
        (f.root / "review.md").write_text("Accepted strict review")
        self.install_policy(data)
        agents = (f.root / "AGENTS.md").read_text()
        pinned = snapshot(
            f.config["_project"],
            source="accepted fixture",
            documents={
                "AGENTS.md": {
                    "content": agents,
                    "sha256": hashlib.sha256(agents.encode()).hexdigest(),
                },
                ".factory/memory/USER.md": {
                    "content": "Accepted owner notes",
                    "sha256": hashlib.sha256(b"Accepted owner notes").hexdigest(),
                },
            },
        )
        (f.root / "review.md").write_text("Candidate disables review")
        (f.root / "AGENTS.md").write_text("Candidate changes instructions")
        config = f.config_file(lambda _: None)
        candidate_user = config.parent / "memory/USER.md"
        candidate_user.parent.mkdir(exist_ok=True)
        candidate_user.write_bytes(b"\xff")
        packet = context.build(
            load_config(config, policy={**f.config["_project"], "files": {}}),
            f.root,
            f.config["_defaults"]["reviewer"],
            "reviewer",
            "code-review",
            {
                "source": f.g["sources"]["request"],
                "scope_files": ["lib/example.dart"],
                "project_policy": pinned,
            },
        )
        content = "\n".join(x["content"] for x in packet["instructions"])
        self.assertIn("Accepted strict review", content)
        self.assertIn(agents, content)
        self.assertIn("Accepted owner notes", content)
        self.assertNotIn("Candidate disables review", content)
        self.assertNotIn("Candidate changes instructions", content)

    def test_document_deliverables_use_accepted_rules_and_candidate_evidence(self) -> None:
        f = self.f
        (f.root / "norm.md").write_text("Original requirement")
        (f.root / "background.md").write_text("Original background")
        self.install_policy(
            {
                "id": "fixture",
                "rules": {
                    "worker": [
                        {"id": "norm", "project_file": "norm.md"},
                        {"id": "norm-background", "project_file": "norm.md", "usage": "reference"},
                        {"id": "background", "project_file": "background.md", "usage": "reference"},
                    ]
                },
            }
        )
        documents = {
            "norm.md": ("Original requirement", "Updated requirement for next intake"),
            "background.md": ("Original background", "Updated background for next intake"),
        }
        f.g["tasks"]["label"]["scope"].extend(documents)
        f.g["nodes"][0]["owns"].extend(documents)
        f.require_fixture_review()
        f.init()
        f.start("write-label")
        for name, (original, updated) in documents.items():
            path = (f.root / name).resolve()
            path.write_text(updated)
            for deleted in (False, True):
                if deleted:
                    path.unlink()
                packet = f.ledger.packet("write-label")
                baseline = next(x for x in packet["instructions"] if x["path"] == str(path))
                self.assertEqual(original, baseline["content"])
                self.assertTrue(baseline["reason"].startswith("accepted baseline: "))
            path.write_text(updated)
        f.ledger.finish("write-label", f.report("write-label"))
        f.start("verify-label")
        packet = f.ledger.packet("verify-label")
        self.assertTrue(
            {original for original, _ in documents.values()}
            <= {x["content"] for x in packet["instructions"]}
        )
        f.ledger.finish("verify-label", f.report("verify-label"))
        f.start("review-label", "independent-judge")
        judge = f.ledger.packet("review-label")
        by_path = {x["path"]: x for x in judge["instructions"]}
        for name, (original, updated) in documents.items():
            path = (f.root / name).resolve()
            baseline = by_path[str(path)]
            self.assertTrue(baseline["reason"].startswith("accepted baseline: "))
            self.assertEqual(original, baseline["content"])
            self.assertEqual(updated, path.read_text(encoding="utf-8"))
        self.assertEqual(
            [{"id": "norm"}, {"id": "norm-background", "usage": "reference"}],
            by_path[str((f.root / "norm.md").resolve())]["rules"],
        )
        self.assertEqual(
            [{"id": "background", "usage": "reference"}],
            by_path[str((f.root / "background.md").resolve())]["rules"],
        )
        f.ledger.finish("review-label", f.report("review-label", verdict="APPROVE"))
        for name, (_, updated) in documents.items():
            path = (f.root / name).resolve()
            path.write_text("Unverified candidate")
            with self.assertRaisesRegex(Invalid, "Runner evidence invalidated"):
                f.ledger.accept("accept-label")
            path.write_text(updated)
        f.ledger.accept("accept-label")
        f.ledger.archive("completed", "accepted documentation change")
        f.ledger.clean()
        f.init()
        f.ledger.claim("write-label")
        packet = f.ledger.packet("write-label")
        self.assertTrue(
            {updated for _, updated in documents.values()}
            <= {x["content"] for x in packet["instructions"]}
        )

    def test_missing_required_project_document_blocks_intake(self) -> None:
        data = {
            "id": "fixture",
            "rules": {"worker": [{"id": "norm", "project_file": "missing.md"}]},
        }
        self.install_policy(data)
        with self.assertRaisesRegex(Invalid, "missing"):
            self.f.init()
        self.assertFalse(has_current(self.f.ledger))

    def test_acp_delivers_same_project_rule_as_native(self) -> None:
        from factory.adapters.acpx_adapter import prepare_prompt

        f = self.f
        (f.root / "norm.md").write_text("Project policy delivered through both transports")
        self.install_policy(
            {"id": "fixture", "rules": {"worker": [{"id": "norm", "project_file": "norm.md"}]}}
        )
        f.fake_acp()
        active = f.init()
        (f.root / "norm.md").write_text("Candidate policy must not leak into packets")
        native = context.build(
            active["config"],
            f.root,
            "generalist",
            "generalist",
            "implement",
            {
                "source": f.g["sources"]["request"],
                "task": f.g["tasks"]["label"],
                "node": {"stage": "work", "resources": []},
            },
        )
        f.ledger.claim("write-label")
        text = Path(prepare_prompt(f.ledger, "write-label")["prompt"]).read_text(encoding="utf-8")
        entry = next(i for i in native["instructions"] if i["path"].endswith("/norm.md"))
        self.assertIn(entry, json.loads(text)["instructions"])

    def test_shared_command_dependency_enforced_by_real_ledger(self) -> None:
        f = self.f
        data: dict[str, Any] = {
            "id": "fixture",
            "gates": [{"id": "verify", "at": ["implement.verify"], "checks": []}],
        }
        for cid, after in [("first", []), ("second", ["first"])]:
            data["gates"][0]["checks"].append(
                {
                    "id": cid,
                    "kind": "tests",
                    "level": "final",
                    "method": "Fixture " + cid,
                    "after": after,
                    "execution": {
                        "argv": [sys.executable, "-c", 'print("passed")'],
                        "cwd": ".",
                        "timeout_seconds": 10,
                    },
                }
            )
        self.install_policy(data)
        f.g["tasks"]["label"]["required_checks"] += required_checks(
            validate(data), f.g["tasks"]["label"], final=True
        )
        (f.root / "check-input.txt").write_text("before")
        next(c for c in f.g["tasks"]["label"]["required_checks"] if c["id"] == "first")[
            "execution"
        ]["inputs"] = ["check-input.txt"]
        f.init()
        f.start("write-label")
        f.ledger.finish("write-label", f.report("write-label"))
        f.start("verify-label")
        with self.assertRaisesRegex(Invalid, "dependency"):
            f.ledger.run_check("verify-label", "second")
        first = f.ledger.run_check("verify-label", "first")
        self.assertEqual("PASS", first["result"])
        (f.root / "check-input.txt").write_text("after")
        with self.assertRaisesRegex(Invalid, "stale"):
            f.ledger.run_check("verify-label", "second")
        self.assertEqual(
            "PASS", f.ledger.run_check("verify-label", "first", "fresh-input")["result"]
        )
        self.assertEqual("PASS", f.ledger.run_check("verify-label", "second")["result"])

    def test_failed_dependency_does_not_unlock_later_project_command(self) -> None:
        f = self.f
        data: dict[str, Any] = {
            "id": "fixture",
            "gates": [{"id": "verify", "at": ["implement.verify"], "checks": []}],
        }
        for cid, code, after in [("first", 1, []), ("second", 0, ["first"])]:
            data["gates"][0]["checks"].append(
                {
                    "id": cid,
                    "kind": "tests",
                    "level": "final",
                    "method": "Fixture " + cid,
                    "after": after,
                    "execution": {
                        "argv": [sys.executable, "-c", f"raise SystemExit({code})"],
                        "cwd": ".",
                        "timeout_seconds": 10,
                    },
                }
            )
        self.install_policy(data)
        f.g["tasks"]["label"]["required_checks"] += required_checks(
            validate(data), f.g["tasks"]["label"], final=True
        )
        f.init()
        f.start("write-label")
        f.ledger.finish("write-label", f.report("write-label"))
        f.start("verify-label")
        self.assertEqual("FAIL", f.ledger.run_check("verify-label", "first")["result"])
        with self.assertRaisesRegex(Invalid, "dependency"):
            f.ledger.run_check("verify-label", "second")

    def test_final_project_verify_cannot_be_reassigned_from_judge_to_author(self) -> None:
        from factory.runtime.workflow_graph import validate_graph

        f = self.f
        config = load_config(ROOT / "factory.yaml")
        graph = json.loads((ROOT / "tooling/examples/reviewed-slice.workflow.json").read_text())
        graph = expand_intake_checks(graph, config)
        validate_graph(graph, config, f.root)
        next(n for n in graph["nodes"] if n["id"] == "verify")["agent"] = "tests"
        with self.assertRaisesRegex(Invalid, "Judge verification"):
            validate_graph(graph, config, f.root)


if __name__ == "__main__":
    unittest.main()
