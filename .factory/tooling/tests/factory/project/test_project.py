"""Project boundary regressions. Fixtures prove mechanisms, not app/model quality."""

from __future__ import annotations

import hashlib
import json
import re
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
from factory.project.contracts import Policy, ProjectData, Selection
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
from factory.tasks.contracts import TaskSelection
from tests.factory.runtime import workflow_fixture

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
        self.data["documents"] = {"api": {"path": "api.md"}, "schema": {"path": "schema.md"}}
        for audience in ("worker", "coordinator"):
            self.data["rules"][audience].append(
                {
                    "id": "review-docs-" + audience,
                    "for": {"processes": ["code-review"]},
                    "documents": ["api", "schema"],
                }
            )
        for name in ["api.md", "schema.md"]:
            (self.root / name).write_text("Accepted " + name)
        self.policy()
        (self.root / "AGENTS.md").write_text("Accepted workspace policy")

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
        result = review_snapshot(self.root, sha, "project.yaml")
        self.assertEqual("git:" + sha, result["source"])
        self.assertEqual(
            hashlib.sha256(b"Python API rules").hexdigest(), result["files"]["backend.md"]
        )
        entries = review_materials(result, self.root, self.root, role="reviewer")
        self.assertTrue(
            {"Accepted api.md", "Accepted schema.md"} <= {e["content"] for e in entries}
        )

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
        with self.assertRaisesRegex(Invalid, "drift"):
            f.ledger.packet("write-label")

    def test_reintake_selects_new_scoped_document_and_rejects_existing_drift(self) -> None:
        f = self.f
        (f.root / "base.md").write_text("Existing policy")
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
        before = f.ledger.read()
        with self.assertRaisesRegex(Invalid, "drift"):
            f.ledger.reintake(deepcopy(graph), "scope extension", "user authorization")
        self.assertEqual(before, f.ledger.read())
        (f.root / "base.md").write_text("Existing policy")
        f.ledger.reintake(graph, "scope extension", "user authorization")
        f.ledger.claim("write-label")
        packet = f.ledger.packet("write-label")
        self.assertIn("Additional scoped policy", [x["content"] for x in packet["instructions"]])
        (f.root / "additional.md").write_text("Changed scoped policy")
        with self.assertRaisesRegex(Invalid, "drift"):
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
                }
            },
        )
        (f.root / "review.md").write_text("Candidate disables review")
        (f.root / "AGENTS.md").write_text("Candidate changes instructions")
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
        content = "\n".join(x["content"] for x in packet["instructions"])
        self.assertIn("Accepted strict review", content)
        self.assertIn(agents, content)
        self.assertNotIn("Candidate disables review", content)
        self.assertNotIn("Candidate changes instructions", content)

    def test_policy_drift_after_verification_blocks_acceptance(self) -> None:
        f = self.f
        (f.root / "norm.md").write_text("Original requirement")
        self.install_policy(
            {"id": "fixture", "rules": {"worker": [{"id": "norm", "project_file": "norm.md"}]}}
        )
        f.init()
        f.start("write-label")
        f.ledger.finish("write-label", f.report("write-label"))
        f.start("verify-label")
        f.ledger.finish("verify-label", f.report("verify-label"))
        (f.root / "norm.md").write_text("Relaxed requirement")
        with self.assertRaisesRegex(Invalid, "drift"):
            f.ledger.accept("accept-label")

    def test_missing_required_project_document_blocks_intake(self) -> None:
        data = {
            "id": "fixture",
            "rules": {"worker": [{"id": "norm", "project_file": "missing.md"}]},
        }
        self.install_policy(data)
        with self.assertRaisesRegex(Invalid, "missing"):
            self.f.init()
        self.assertFalse(self.f.ledger.path.exists())

    def test_reference_doc_update_does_not_replace_frozen_policy(self) -> None:
        f = self.f
        (f.root / "output.md").write_text("Prior documentation")
        data = {
            "id": "fixture",
            "rules": {
                "worker": [{"id": "output", "project_file": "output.md", "usage": "reference"}]
            },
        }
        self.install_policy(data)
        f.init()
        f.start("write-label")
        (f.root / "output.md").write_text("Updated documentation")
        self.assertIn(
            "Updated documentation",
            [x["content"] for x in f.ledger.packet("write-label")["instructions"]],
        )

    def test_acp_delivers_same_project_rule_as_native(self) -> None:
        from factory.adapters.acpx_adapter import prepare_prompt

        f = self.f
        (f.root / "norm.md").write_text("Project policy delivered through both transports")
        self.install_policy(
            {"id": "fixture", "rules": {"worker": [{"id": "norm", "project_file": "norm.md"}]}}
        )
        native = context.build(
            f.config,
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
        f.fake_acp()
        f.init()
        f.ledger.claim("write-label")
        text = Path(prepare_prompt(f.ledger, "write-label")["prompt"]).read_text()
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
        validate_graph(graph, config, f.root)
        next(n for n in graph["nodes"] if n["id"] == "verify")["agent"] = "tests"
        with self.assertRaisesRegex(Invalid, "Judge verification"):
            validate_graph(graph, config, f.root)


if __name__ == "__main__":
    unittest.main()
