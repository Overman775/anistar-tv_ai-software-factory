"""Behavioral regressions for standalone review planning and lifecycle."""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from collections.abc import Callable
from contextlib import chdir
from copy import deepcopy
from pathlib import Path
from typing import Any
from unittest.mock import patch

import yaml

from factory.project.profile_io import load_profile, snapshot
from factory.review.protocol.contracts import validate_manifest
from factory.review.protocol.plan import prepare, validate_plan
from tests import CLI
from tests.factory.review.fixture_protocol import ProtocolFixture, write_json


class ReviewRunTests(unittest.TestCase):
    def test_status_does_not_create_uninitialized_run(self) -> None:
        f = self.fixture()
        request, run = f.root / "request.json", f.root / "run"
        write_json(request, f.manifest)
        result = self.call(f, "status", "--run", run)
        self.assertNotEqual(0, result.returncode)
        self.assertFalse(run.exists())
        result = self.call(f, "init", "--input", request, "--run", run)
        self.assertEqual(0, result.returncode, result.stderr)

    def test_status_during_init_before_inputs_does_not_lock(self) -> None:
        f = self.fixture()
        run = f.root / "run"
        run.mkdir()
        result = self.call(f, "status", "--run", run)
        self.assertNotEqual(0, result.returncode)
        self.assertFalse((run / ".review.lock").exists())

    def test_pr_review_completes_with_sha256_and_broken_candidate_project_yaml(self) -> None:
        self.git_review("pr")

    def test_branch_review_completes_against_accepted_policy(self) -> None:
        self.git_review("branch")

    def git_review(self, mode: str) -> None:
        from factory.project.project import review_snapshot
        from tests.fixture_bundle import ROOT as fixture

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            f = ProtocolFixture(root, mode=mode)
            bundle = root / ".factory"
            shutil.copytree(fixture, bundle)
            project = bundle / "project/project.yaml"
            project.write_text(
                """id: accepted
documents:
  author-guide: {path: author-guide.md}
  review-guide: {path: review-guide.md}
rules:
  worker:
    - id: author-guide
      for: {processes: [code-review], stages: [work]}
      documents: [author-guide]
    - id: review-guide
      for: {processes: [code-review], stages: [review]}
      documents: [review-guide]
""",
                encoding="utf-8",
            )
            (root / "AGENTS.md").write_text("Accepted policy.", encoding="utf-8")

            def git(*args: str) -> bytes:
                return subprocess.check_output(["git", "-C", str(root), *args])

            def commit(message: str) -> str:
                git(
                    "add",
                    "--",
                    ".factory/project/project.yaml",
                    ".factory/graphs/code-review.yaml",
                    "AGENTS.md",
                    "review-check.py",
                    "review-guide.md",
                    f.path,
                )
                git(
                    "-c",
                    "user.name=Fixture",
                    "-c",
                    "user.email=fixture@example.invalid",
                    "-c",
                    "commit.gpgsign=false",
                    "commit",
                    "-qm",
                    message,
                )
                return git("rev-parse", "HEAD").decode().strip()

            git("init", "-q", "--object-format=sha256")
            (root / f.path).parent.mkdir()
            (root / f.path).write_text("int value = 0;\n", encoding="utf-8")
            guide = root / "review-guide.md"
            guide.write_text("Review reference from baseline.", encoding="utf-8")
            tool = root / "review-check.py"
            tool.write_text(
                "from pathlib import Path\nprint('accepted tool', Path('"
                + f.path
                + "').read_text().strip())\n"
            )
            base = commit("baseline")
            pinned = review_snapshot(root, base)
            self.assertEqual({"AGENTS.md", "review-guide.md"}, pinned["documents"].keys())

            git("rm", "--", "review-guide.md")
            git(
                "-c",
                "user.name=Fixture",
                "-c",
                "user.email=fixture@example.invalid",
                "-c",
                "commit.gpgsign=false",
                "commit",
                "-qm",
                "missing review guide",
            )
            with self.assertRaisesRegex(ValueError, "review-guide.md"):
                review_snapshot(root, git("rev-parse", "HEAD").decode().strip())
            git("restore", "--source", base, "--", "review-guide.md")

            (bundle / "graphs/code-review.yaml").write_text(
                "id: code-review\nentry: broken-candidate-graph\n"
            )
            project.write_text("broken: [", encoding="utf-8")
            (root / f.path).write_text("int value = 1;\n", encoding="utf-8")
            tool.write_text("print('candidate tool')\n")
            head = commit("change under review")
            diff = git("diff", "--no-ext-diff", "--no-color", base + "..." + head)
            diff_path = Path(f.manifest["diff_file"])
            diff_path.write_bytes(diff)
            f.manifest.update(
                base_sha=base,
                head_sha=head,
                project_policy=pinned,
                scope_files=[
                    ".factory/graphs/code-review.yaml",
                    ".factory/project/project.yaml",
                    f.path,
                    "review-check.py",
                ],
                diff_sha256=hashlib.sha256(diff).hexdigest(),
            )
            if mode == "pr":
                f.manifest["context"]["pr"]["head_sha"] = head
            f.manifest["additional_checks"] = [
                {
                    "id": "accepted-tool",
                    "method": "Check candidate with accepted script",
                    "execution": {
                        "argv": [sys.executable, "-B", "review-check.py"],
                        "cwd": ".",
                        "inputs": [f.path],
                    },
                }
            ]
            f.rebind()
            request, run = root / "request.json", root / "run"
            write_json(request, f.manifest)
            env = {**os.environ, "PYTHONPATH": str(bundle / "tooling")}

            def cli(command: tuple[str, ...], *args: str | Path) -> dict[str, Any]:
                result = subprocess.run(
                    [sys.executable, "-m", "factory.cli", *command, *map(str, args)],
                    cwd=root,
                    capture_output=True,
                    text=True,
                    env=env,
                    check=False,
                )
                self.assertEqual(0, result.returncode, result.stderr)
                value: dict[str, Any] = json.loads(result.stdout)
                return value

            runner = ("review", "run")
            raw = deepcopy(f.manifest)
            raw["project_policy"]["documents"]["review-guide.md"]["content"] = "Changed input."
            from factory.project.profile_io import fingerprint
            from factory.review import subject

            raw["project_policy"]["documents"]["review-guide.md"]["sha256"] = hashlib.sha256(
                b"Changed input."
            ).hexdigest()
            raw["project_policy"]["sha256"] = fingerprint(
                {k: v for k, v in raw["project_policy"].items() if k != "sha256"}
            )
            with chdir(root), self.assertRaisesRegex(ValueError, "differs from accepted"):
                subject.accepted_revision(raw, bundle)
            cli(runner, "init", "--input", request, "--run", run)
            outcome = cli(
                runner,
                "check",
                "--id",
                "accepted-tool",
                "--run",
                run,
                "--request",
                "accepted-tool-check",
            )
            self.assertEqual("PASS", outcome["status"])
            self.assertIn("accepted tool int value = 1;", outcome["commands"][0]["stdout_excerpt"])
            view = cli(runner, "diagram", "--run", run)
            self.assertNotIn("broken-candidate-graph", view["mermaid"])
            self.assertIn("architecture", view["mermaid"])
            for lens in f.lenses:
                direction = lens["lens"]
                assignment = cli(runner, "assignment", "--id", direction, "--run", run)
                self.assertEqual((base, head), (assignment["base_sha"], assignment["head_sha"]))
                path = root / "assignment.json"
                write_json(path, assignment)
                packet = cli(
                    ("context",),
                    "--process",
                    "code-review",
                    "--role",
                    "reviewer",
                    "--profile",
                    assignment["profile"],
                    path,
                )
                self.assertIn(
                    "Review reference from baseline.",
                    [entry["content"] for entry in packet["instructions"]],
                )
                write_json(path, lens)
                dispatch = assignment["dispatch"]
                worker = "worker-" + direction
                cli(
                    runner,
                    "bind",
                    "--id",
                    direction,
                    "--dispatch",
                    dispatch,
                    "--handle",
                    worker,
                    "--run",
                    run,
                )
                mid = cli(
                    runner,
                    "note",
                    "--id",
                    direction,
                    "--dispatch",
                    dispatch,
                    "--handle",
                    worker,
                    "--run",
                    run,
                    "--evidence",
                    "Inspected the pinned change",
                )
                reopened = cli(
                    runner,
                    "packet",
                    "--id",
                    direction,
                    "--dispatch",
                    dispatch,
                    "--handle",
                    worker,
                    "--run",
                    run,
                )
                self.assertEqual(mid["observations"], reopened["observations"])
                self.assertFalse({"reports", "reviewers", "verdict", "findings"} & reopened.keys())
                cli(
                    runner,
                    "submit",
                    "--id",
                    direction,
                    "--input",
                    path,
                    "--run",
                    run,
                    "--dispatch",
                    dispatch,
                    "--handle",
                    worker,
                )
            write_json(path, f.qa)
            result = cli(runner, "finish", "--input", path, "--run", run)
            self.assertEqual("COMPLETE", result["pipeline_status"], result.get("errors"))

    def test_legacy_markers_never_authorize_or_replace_an_attempt(self) -> None:
        f = self.fixture()
        request, run = f.root / "request.json", f.root / "previous-run"
        run.mkdir()
        (run / "inputs.json").write_text('{"review_id":"OLD-RUN-ID"}')
        (run / ".busy").mkdir()
        self.assertNotEqual(0, self.call(f, "status", "--run", run).returncode)
        write_json(request, f.manifest)
        self.assertEqual(0, self.call(f, "init", "--input", request, "--run", run).returncode)
        history = self.history(f, run)
        self.assertNotIn("OLD-RUN-ID", str(history))
        self.assertEqual([], history["events"])
        self.assertEqual('{"review_id":"OLD-RUN-ID"}', (run / "inputs.json").read_text())

    def test_interrupted_check_retains_its_reservation_and_prevents_second_execution(self) -> None:
        f = self.fixture()
        request, run = f.root / "request.json", f.root / "run"
        write_json(request, f.manifest)
        created = self.call(f, "init", "--input", request, "--run", run)
        self.assertEqual(0, created.returncode, created.stderr)
        check = f.manifest["checks"][0]["id"]
        script = """import os,sys
from unittest.mock import patch
from factory.review.review_run import check
with patch('factory.review.review_run.collect_results',side_effect=lambda *a,**k: os._exit(32)):
    check(sys.argv[1],sys.argv[2],'interruption')
"""
        exited = subprocess.run(
            [sys.executable, "-c", script, str(run), check],
            cwd=f.root,
            capture_output=True,
            text=True,
        )
        self.assertEqual(32, exited.returncode, exited.stderr)
        for request_key in ("interruption", "second-request"):
            result = self.call(f, "check", "--run", run, "--id", check, "--request", request_key)
            self.assertNotEqual(0, result.returncode)
            self.assertIn("unknown outcome", result.stderr)
        status = json.loads(self.call(f, "status", "--run", run).stdout)
        self.assertEqual("interruption", status["outstanding_checks"][check]["request"])
        self.assertEqual(1, len(self.history(f, run)["events"]))
        resume = (
            "reconcile-check",
            "--id",
            check,
            "--run",
            run,
            "--original-request",
            "interruption",
            "--evidence",
            "Observed original child and process stopped",
            "--request",
            "observed-stop",
        )
        self.assertNotEqual(
            0, self.call(f, "cancel", "--run", run, "--evidence", "Owner cancelled").returncode
        )
        self.assertIn("reconcile-check", str(status["commands"]))
        recovered = self.call(f, *resume)
        self.assertEqual(0, recovered.returncode, recovered.stderr)
        self.assertEqual("BLOCKED", json.loads(recovered.stdout)["status"])
        self.assertEqual(recovered.stdout, self.call(f, *resume).stdout)
        collision = self.call(f, "check", "--run", run, "--id", check, "--request", "observed-stop")
        self.assertNotEqual(0, collision.returncode)
        self.assertFalse(
            json.loads(self.call(f, "status", "--run", run).stdout)["outstanding_checks"]
        )

        self.assertEqual(
            recovered.stdout,
            self.call(f, "check", "--run", run, "--id", check, "--request", "interruption").stdout,
        )
        self.assertEqual(
            "PASS",
            json.loads(
                self.call(f, "check", "--run", run, "--id", check, "--request", "retry-1").stdout
            )["status"],
        )
        self.assertEqual(
            0, self.call(f, "cancel", "--run", run, "--evidence", "Owner cancelled").returncode
        )
        self.assertEqual(0, self.call(f, "clean", "--run", run).returncode)

    def test_interrupted_blocked_attempt_can_retry_and_completed_receipt_replays(self) -> None:
        f = self.fixture()
        f.manifest["additional_checks"][0]["execution"]["argv"] = ["missing-review-command"]
        f.rebind()
        request, run = f.root / "request.json", f.root / "run"
        write_json(request, f.manifest)
        self.assertEqual(0, self.call(f, "init", "--input", request, "--run", run).returncode)
        check = f.manifest["checks"][0]["id"]
        for req in ("attempt-a", "attempt-a", "attempt-b"):
            result = self.call(f, "check", "--run", run, "--id", check, "--request", req)
            self.assertEqual(0, result.returncode, result.stderr)
            self.assertEqual("BLOCKED", json.loads(result.stdout)["status"])
        self.assertEqual(2, len(self.history(f, run)["state"]["facts"]["checks"][check]))

    def test_source_drift_requires_new_intake_and_retains_original_history(self) -> None:
        f = self.fixture()
        request, run = f.root / "request.json", f.root / "run"
        write_json(request, f.manifest)
        self.assertEqual(0, self.call(f, "init", "--input", request, "--run", run).returncode)
        original = self.history(f, run)["subject"]
        (f.root / f.path).write_text("changed")
        self.assertIn("source drift", self.call(f, "status", "--run", run).stderr)
        self.assertEqual(original, self.history(f, run)["subject"])
        self.assertNotEqual(0, self.call(f, "recover-legacy", "--run", run).returncode)

    def history(self, f: ProtocolFixture, run: Path) -> dict[str, Any]:
        result = self.call(f, "history", "--run", run)
        self.assertEqual(0, result.returncode, result.stderr)
        return dict(json.loads(result.stdout))

    def fixture(self) -> ProtocolFixture:
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        return ProtocolFixture(Path(temp.name))

    def call(self, f: ProtocolFixture, *args: Any) -> subprocess.CompletedProcess[str]:
        if args[0] == "submit" and "--dispatch" not in args:
            direction = args[args.index("--id") + 1]
            name = args[args.index("--run") + 1]
            issued = self.call(f, "assignment", "--id", direction, "--run", name)
            if issued.returncode:
                return issued
            ticket = json.loads(issued.stdout)["dispatch"]
            handle = "fixture-" + direction
            bound = self.call(
                f,
                "bind",
                "--id",
                direction,
                "--dispatch",
                ticket,
                "--handle",
                handle,
                "--run",
                name,
            )
            if bound.returncode:
                return bound
            args = (*args, "--dispatch", ticket, "--handle", handle)
        return subprocess.run(
            [*CLI, "review", "run", *args], cwd=f.root, text=True, capture_output=True
        )

    def test_changed_check_input_requires_new_subject_and_three_fresh_tickets(self) -> None:
        f = self.fixture()
        request = f.root / "request.json"
        inp = f.root / "command-input.txt"
        inp.write_text("before")
        f.manifest["additional_checks"][0]["execution"]["inputs"] = [inp.name]
        f.rebind()
        write_json(request, f.manifest)

        def tickets(run: str) -> dict[str, str]:
            created = self.call(f, "init", "--run", run, "--input", request)
            self.assertEqual(0, created.returncode, created.stderr)
            result = {}
            for lens in f.lenses:
                key = lens["lens"]
                issued = self.call(f, "assignment", "--run", run, "--id", key)
                self.assertEqual(0, issued.returncode, issued.stderr)
                result[key] = json.loads(issued.stdout)["dispatch"]
            return result

        first = tickets("first")
        inp.write_text("after")
        self.assertIn("source drift", self.call(f, "status", "--run", "first").stderr)
        second = tickets("second")
        self.assertFalse(set(first.values()) & set(second.values()))
        key = "system-design"
        handle = "architecture-worker"
        common = ["--run", "second", "--id", key, "--handle", handle, "--dispatch", second[key]]
        self.assertEqual(0, self.call(f, "bind", *common).returncode)
        self.assertEqual(
            0, self.call(f, "lost", *common, "--evidence", "adapter timeout").returncode
        )
        self.assertEqual(
            second[key],
            json.loads(self.call(f, "assignment", "--run", "second", "--id", key).stdout)[
                "dispatch"
            ],
        )
        self.assertNotEqual(0, self.call(f, "history", *common).returncode)
        self.assertEqual(
            0,
            self.call(f, "stopped", *common, "--evidence", "adapter confirmed stopped").returncode,
        )
        retry = self.call(f, "assignment", "--run", "second", "--id", key)
        self.assertNotEqual(second[key], json.loads(retry.stdout)["dispatch"])
        self.assertEqual(
            second["runtime-safety"],
            json.loads(
                self.call(f, "assignment", "--run", "second", "--id", "runtime-safety").stdout
            )["dispatch"],
        )

    def test_status_validates_policy_once_and_detects_subsequent_source_drift(self) -> None:
        from factory.project.profile_io import validate_snapshot
        from factory.review import review_run, subject
        from factory.review.protocol import contracts as review_contracts

        f = self.fixture()
        request, run = f.root / "request.json", f.root / "run"
        write_json(request, f.manifest)
        with chdir(f.root):
            review_run.initialize(request, run)
            with (
                patch.object(
                    review_contracts, "validate_snapshot", wraps=review_contracts.validate_snapshot
                ) as contract,
                patch(
                    "factory.review.protocol.plan.validate_snapshot", wraps=validate_snapshot
                ) as plan,
            ):
                saved = review_run.record(run)
                manifest = subject.fresh(saved.subject)
                review_run.inspect(saved, manifest)
                self.assertEqual(1, contract.call_count + plan.call_count)
            (f.root / f.path).write_text("changed", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "source drift"):
                subject.fresh(saved.subject)

    def test_three_specializations_cover_intent_under_acceptance(self) -> None:
        f = self.fixture()
        names = {a["name"]: a["criteria"] for a in f.manifest["assignments"]}
        self.assertEqual(set(names), {"ArchitectureReviewer", "CodeReviewer", "AcceptanceReviewer"})
        self.assertIn("SYS-INTENT", names["AcceptanceReviewer"])
        self.assertNotIn("SYS-INTENT", names["ArchitectureReviewer"])
        f.manifest["assignments"][2]["criteria"].remove("SYS-INTENT")
        with self.assertRaisesRegex(ValueError, "assignments"):
            validate_plan(f.manifest)

    def test_run_assignment_is_accepted_by_context_entry_point(self) -> None:
        from factory.context.context import build
        from factory.project.profile_io import sha
        from factory.project.profile_rules import document_paths, select_rules
        from factory.runtime.workflow_config import load_config
        from tests.fixture_bundle import ROOT as fixture

        f = self.fixture()
        policy = load_profile(fixture / "project/project.yaml")
        paths = {"AGENTS.md"}
        for rule in select_rules(
            policy["data"], process="code-review", audience="worker", role="reviewer"
        ):
            if "file" not in rule:
                paths.update(document_paths(policy["data"], rule))
        content = "Accepted baseline documentation."
        f.manifest["project_policy"] = snapshot(
            policy,
            source="fixture baseline",
            documents={
                path: {"content": content, "sha256": sha(content.encode())} for path in paths
            },
        )
        f.rebind()
        request, run = f.root / "request.json", f.root / "run"
        write_json(request, f.manifest)
        created = self.call(f, "init", "--input", request, "--run", run)
        self.assertEqual(0, created.returncode, created.stderr)
        response = self.call(f, "assignment", "--id", "system-design", "--run", run)
        self.assertEqual(0, response.returncode, response.stderr)
        config = load_config(fixture / "factory.yaml")
        packet: dict[str, Any] = dict(
            build(
                config, f.root, "reviewer", "reviewer", "code-review", json.loads(response.stdout)
            )
        )
        self.assertEqual(f.manifest["target"], packet["source"]["target"])
        self.assertEqual("system-design", packet["lens"])

    def test_dispatch_packets_contain_only_owned_project_questions(self) -> None:
        from factory.context.context import build
        from factory.project.profile_io import sha
        from factory.project.profile_rules import document_paths, select_rules
        from factory.runtime.workflow_config import load_config
        from tests.fixture_bundle import ROOT as fixture

        f = self.fixture()
        project = f.root / ".factory/project"
        shutil.copytree(fixture / "project", project)
        gate = project / "gates/skills/code-review.yaml"
        gate.write_text(
            yaml.safe_dump(
                {
                    "gates": [
                        {
                            "id": "review-ready",
                            "at": ["implement.review", "code-review.complete"],
                            "criteria": [
                                {
                                    "id": "PROJECT-" + str(i),
                                    "lens": lens,
                                    "question": "Check " + lens,
                                }
                                for i, lens in enumerate(
                                    ("system-design", "runtime-safety", "verification-quality")
                                )
                            ],
                        }
                    ]
                }
            ),
            encoding="utf-8",
        )
        policy = load_profile(project / "project.yaml")
        paths = {"AGENTS.md"}
        for rule in select_rules(
            policy["data"], process="code-review", audience="worker", role="reviewer"
        ):
            if "file" not in rule:
                paths.update(document_paths(policy["data"], rule))
        content = "Accepted baseline documentation."
        f.manifest["project_policy"] = snapshot(
            policy,
            source="fixture",
            documents={
                path: {"content": content, "sha256": sha(content.encode())} for path in paths
            },
        )
        f.rebind()
        request, run = f.root / "request.json", f.root / "run"
        write_json(request, f.manifest)
        created = self.call(f, "init", "--input", request, "--run", run)
        self.assertEqual(0, created.returncode, created.stderr)
        config = load_config(fixture / "factory.yaml")
        for i, (lens, count) in enumerate(
            (("system-design", 3), ("runtime-safety", 4), ("verification-quality", 5))
        ):
            response = self.call(f, "assignment", "--id", lens, "--run", run)
            self.assertEqual(0, response.returncode, response.stderr)
            assignment = json.loads(response.stdout)
            self.assertEqual(count, len(assignment["owned_gates"]))
            packet: dict[str, Any] = dict(
                build(config, f.root, "reviewer", "reviewer", "code-review", assignment)
            )
            project_id = "PROJECT-" + str(i)
            self.assertEqual("Check " + lens, packet["owned_gates"][project_id])
            self.assertEqual([], packet["project_policy"]["review_criteria"])
            self.assertEqual(1, json.dumps(packet).count("Check " + lens))

    def test_configured_reviewer_profile_packages_all_directions(self) -> None:
        from factory.context.context import build
        from factory.project.profile_io import sha
        from factory.project.profile_rules import document_paths, select_rules
        from factory.review.review_run import initialize
        from factory.runtime.workflow_config import load_config
        from tests.fixture_bundle import ROOT as fixture

        for variants, default in [
            (["local-review"], None),
            (["reviewer"], None),
            (["reviewer", "local-review"], "local-review"),
        ]:
            with self.subTest(variants=variants, default=default):
                f = self.fixture()
                bundle = f.root / ".factory"
                shutil.copytree(fixture, bundle)
                config_path = bundle / "factory.yaml"
                settings = yaml.safe_load(config_path.read_text(encoding="utf-8"))
                group = settings["agent_workers"]["reviewer"]
                variant = next(iter(group["variants"].values()))
                group["variants"] = {name: deepcopy(variant) for name in variants}
                group.pop("default", None)
                if default:
                    group["default"] = default
                config_path.write_text(yaml.safe_dump(settings), encoding="utf-8")
                config = load_config(config_path)
                policy = load_profile(bundle / "project/project.yaml")
                paths = {"AGENTS.md"}
                for rule in select_rules(
                    policy["data"], process="code-review", audience="worker", role="reviewer"
                ):
                    if "file" not in rule:
                        paths.update(document_paths(policy["data"], rule))
                content = "Accepted baseline documentation."
                f.manifest["project_policy"] = snapshot(
                    policy,
                    source="fixture baseline",
                    documents={
                        path: {"content": content, "sha256": sha(content.encode())}
                        for path in paths
                    },
                )
                request, run = f.root / "request.json", f.root / "run"
                write_json(request, f.manifest)
                with patch("factory.review.review_run.FACTORY_ROOT", bundle), chdir(f.root):
                    initialize(request, run)
                expected = default or variants[0]
                manifest = self.history(f, run)["subject"]["manifest"]
                self.assertEqual([expected] * 3, [a["profile"] for a in manifest["assignments"]])
                for direction in ("system-design", "runtime-safety", "verification-quality"):
                    response = self.call(f, "assignment", "--id", direction, "--run", run)
                    self.assertEqual(0, response.returncode, response.stderr)
                    assignment = json.loads(response.stdout)
                    self.assertEqual(expected, assignment["profile"])
                    packet: dict[str, Any] = dict(
                        build(config, f.root, expected, "reviewer", "code-review", assignment)
                    )
                    self.assertEqual(direction, packet["lens"])

    def test_project_commands_and_criteria_extend_without_orchestrator_changes(self) -> None:
        f = self.fixture()
        profile = f.root / "project.yaml"
        profile.write_text("""id: fixture
rules: {}
gates:
- id: review-command
  at: [code-review.complete]
  checks:
  - id: custom-check
    level: slice
    kind: tests
    method: project check
    execution: {argv: [check], cwd: '.', timeout_seconds: 10, inputs: []}
- id: review-criteria
  at: [code-review.complete]
  criteria:
  - {id: CUSTOM, lens: runtime-safety, question: "Is the project invariant preserved?"}
""")
        f.manifest["project_policy"] = snapshot(load_profile(profile), source="fixture")
        m = prepare(f.manifest)
        self.assertIn("CUSTOM", m["assignments"][1]["criteria"])
        self.assertIn("custom-check", [c["id"] for c in m["checks"]])
        m["checks"] = [c for c in m["checks"] if c["id"] != "custom-check"]
        with self.assertRaisesRegex(ValueError, "mandatory commands"):
            validate_plan(m)

    def test_command_substitution_and_waiver_block(self) -> None:
        mutations_73: list[Callable[[Any], object]] = [
            lambda t: t["commands"][0].update(argv=["fake"]),
            lambda t: t.update(status="NOT_APPLICABLE", reason="skip", commands=[]),
        ]
        for mutate in mutations_73:
            f = self.fixture()
            mutate(f.tools[0])
            _, result, _ = f.execute()
            self.assertEqual("INCOMPLETE", result["pipeline_status"])

    def test_no_commands_valid_with_explanation(self) -> None:
        f = self.fixture()
        f.manifest["additional_checks"] = []
        f.tools = []
        f.rebind()
        _, result, _ = f.execute()
        self.assertEqual("COMPLETE", result["pipeline_status"], result["errors"])
        self.assertEqual({}, result["tool_statuses"])

    def test_unknown_requirements_do_not_erase_valid_findings(self) -> None:
        f = self.fixture()
        f.manifest["context"]["requirements"] = []
        f.manifest["context"]["limitations"] = ["Incident expected result unavailable"]
        f.rebind()
        f.add_finding(severity="high")
        f.qa["code_verdict"] = "NEEDS_WORK"
        _, result, _ = f.execute()
        self.assertEqual("INCOMPLETE", result["pipeline_status"])
        self.assertEqual(1, len(result["findings"]))
        self.assertIn("SYS-INTENT", " ".join(result["errors"]))

    def test_pr_body_is_required_but_may_be_empty(self) -> None:
        f = self.fixture()
        f.manifest["mode"] = "pr"
        f.manifest["context"]["pr"] = None
        with self.assertRaisesRegex(ValueError, "PR title/body"):
            prepare(f.manifest)

    def test_context_changes_invalidate_identity(self) -> None:
        f = self.fixture()
        f.manifest["context"]["sources"][0]["content"] = "Different task"
        self.assertIn("manifest: scope_hash mismatch", validate_manifest(f.manifest))

    def test_missing_requirement_has_no_fake_diff_location(self) -> None:
        f = self.fixture()
        content = (f.root / f.path).read_text()
        f.manifest["source_evidence"] = {
            f.path: {"content": content, "sha256": hashlib.sha256(content.encode()).hexdigest()}
        }
        f.rebind()
        finding = f.add_finding(lens="verification-quality", gate_id="SYS-INTENT", severity="high")
        finding.update(
            kind="missing-requirement",
            path=None,
            line=None,
            investigation="Inspected service and found no requested branch",
            evidence=[
                {"kind": "requirement", "requirement_id": "AC1"},
                {"kind": "inspection", "path": f.path, "line": 1},
            ],
        )
        f.qa["code_verdict"] = "NEEDS_WORK"
        _, result, report = f.execute()
        self.assertEqual("COMPLETE", result["pipeline_status"], result["errors"])
        self.assertIn("unimplemented requirement", report)
        finding["evidence"].pop()
        _, result, _ = f.execute()
        self.assertEqual("INCOMPLETE", result["pipeline_status"])

    def test_missing_requirement_accepts_omitted_location_with_source_evidence(self) -> None:
        f = self.fixture()
        finding = f.add_finding(lens="verification-quality", gate_id="SYS-INTENT", severity="high")
        finding.update(
            kind="missing-requirement",
            investigation="Inspected changed source and found no requested branch",
            evidence=[
                {"kind": "requirement", "requirement_id": "AC1"},
                {"kind": "source", "path": f.path, "line": 1, "side": "new"},
            ],
        )
        del finding["path"]
        del finding["line"]
        f.qa["code_verdict"] = "NEEDS_WORK"
        process, result, _ = f.execute()
        self.assertEqual(0, process.returncode, process.stderr)
        self.assertEqual("COMPLETE", result["pipeline_status"], result["errors"])
        self.assertNotIn("path", result["findings"][0])
        self.assertNotIn("line", result["findings"][0])

    def test_free_discovery_needs_no_registry_and_no_auto_merge(self) -> None:
        f = self.fixture()
        a = f.add_finding()
        a["gate_id"] = None
        b = deepcopy(a)
        b["finding_id"] = "RUN-2"
        f.lenses[1]["findings"].append(b)
        for gate in f.lenses[1]["gates"]:
            gate["status"] = "PASS"
        f.qa["code_verdict"] = "NEEDS_WORK"
        _, result, _ = f.execute()
        self.assertEqual("COMPLETE", result["pipeline_status"], result["errors"])
        self.assertEqual(2, len(result["findings"]))

    def test_lifecycle_runs_commands_preserves_results_and_rejects_drift(self) -> None:
        from tests.factory.runtime.workflow_fixture import WorkflowFixture

        execution = WorkflowFixture(self.addCleanup)
        previous = execution.init()
        f = ProtocolFixture(execution.root)
        request = f.root / "request.json"
        write_json(request, f.manifest)
        run = f.root / "run"
        result = self.call(f, "init", "--input", str(request), "--run", str(run))
        self.assertEqual(0, result.returncode, result.stderr)
        for check in f.manifest["checks"]:
            result = self.call(f, "check", "--id", check["id"], "--run", str(run))
            self.assertEqual(0, result.returncode, result.stderr)
        for value in f.lenses:
            path = f.root / "out.json"
            path.write_text(json.dumps(value))
            result = self.call(
                f, "submit", "--id", value["lens"], "--input", str(path), "--run", str(run)
            )
            self.assertEqual(0, result.returncode, result.stderr)
        result = self.call(
            f, "submit", "--id", value["lens"], "--input", str(path), "--run", str(run)
        )
        self.assertNotEqual(0, result.returncode)
        qa = f.root / "qa.json"
        write_json(qa, f.qa)
        result = self.call(f, "finish", "--input", str(qa), "--run", str(run))
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual("COMPLETE", json.loads(result.stdout)["pipeline_status"])
        self.assertEqual(previous, execution.ledger.read())
        self.assertIn("APPROVE", self.call(f, "report", "--run", run).stdout)
        self.assertEqual(0, self.call(f, "clean", "--run", run).returncode)
        self.assertEqual("completed", self.history(f, run)["state"]["terminal"])
        (f.root / f.path).write_text("changed")
        result = self.call(f, "status", "--run", str(run))
        self.assertIn("drift", result.stderr)

    def test_recovery_limit_and_independent_run_directories(self) -> None:
        f = self.fixture()
        request = f.root / "request.json"
        write_json(request, f.manifest)
        for name in ["first", "second"]:
            result = self.call(f, "init", "--input", str(request), "--run", str(f.root / name))
            self.assertEqual(0, result.returncode, result.stderr)
        broken = f.root / "broken.json"
        write_json(broken, {"lens": "system-design", "done_signal": "FAILED"})
        for attempt in range(3):
            result = self.call(
                f,
                "submit",
                "--id",
                "system-design",
                "--input",
                str(broken),
                "--run",
                str(f.root / "first"),
            )
            self.assertEqual(result.returncode == 0, attempt < 2, result.stderr)
        self.assertNotIn("reports", self.history(f, f.root / "second")["state"]["facts"])

    def test_prefix_related_check_ids_have_independent_lifecycle_and_budget(self) -> None:
        f = self.fixture()

        def check(
            identifier: str, argv: list[str], after: list[str] | None = None
        ) -> dict[str, Any]:
            return {
                "id": identifier,
                "method": "fixture command",
                "after": after or [],
                "execution": {"argv": argv, "cwd": ".", "timeout_seconds": 10},
            }

        f.manifest["additional_checks"] = [
            check("lint", [sys.executable, "-c", "pass"]),
            check("lint-1", [sys.executable, "-c", "pass"]),
            check("lint-extra", ["fixture-command-that-does-not-exist"]),
            check("dependent", [sys.executable, "-c", "pass"], ["lint"]),
        ]
        f.rebind()
        request, run = f.root / "request.json", f.root / "run"
        write_json(request, f.manifest)
        self.assertEqual(0, self.call(f, "init", "--input", request, "--run", run).returncode)
        for _ in range(2):
            result = self.call(f, "check", "--id", "lint-extra", "--run", run)
            self.assertEqual(0, result.returncode, result.stderr)
            self.assertEqual("BLOCKED", json.loads(result.stdout)["status"])
        exhausted = self.call(f, "check", "--id", "lint-extra", "--run", run)
        self.assertIn("recovery exhausted", exhausted.stderr)
        self.assertEqual(0, self.call(f, "check", "--id", "lint-1", "--run", run).returncode)
        status = json.loads(self.call(f, "status", "--run", run).stdout)
        self.assertEqual("PENDING", status["checks"]["lint"])
        self.assertEqual("PASS", status["checks"]["lint-1"])
        blocked = self.call(f, "check", "--id", "dependent", "--run", run)
        self.assertIn("dependency", blocked.stderr)
        self.assertEqual(0, self.call(f, "check", "--id", "lint", "--run", run).returncode)
        self.assertEqual(0, self.call(f, "check", "--id", "dependent", "--run", run).returncode)
        checks = self.history(f, run)["state"]["facts"]["checks"]
        self.assertEqual((1, 1), (len(checks["lint"]), len(checks["lint-1"])))

    def test_command_dependency_and_mutating_command_cannot_complete(self) -> None:
        f = self.fixture()
        f.manifest["additional_checks"] = [
            {
                "id": "first",
                "method": "prepare evidence",
                "execution": {
                    "argv": [sys.executable, "-c", "pass"],
                    "cwd": ".",
                    "timeout_seconds": 10,
                },
            },
            {
                "id": "second",
                "method": "dependent evidence",
                "after": ["first"],
                "execution": {
                    "argv": [
                        sys.executable,
                        "-c",
                        "from pathlib import Path; Path('lib/sample.dart').write_text('mutated')",
                    ],
                    "cwd": ".",
                    "timeout_seconds": 10,
                },
            },
        ]
        f.rebind()
        request = f.root / "request.json"
        write_json(request, f.manifest)
        run = f.root / "run"
        self.assertEqual(
            0, self.call(f, "init", "--input", str(request), "--run", str(run)).returncode
        )
        result = self.call(f, "check", "--id", "second", "--run", str(run))
        self.assertIn("dependency", result.stderr)
        self.assertEqual(0, self.call(f, "check", "--id", "first", "--run", str(run)).returncode)
        result = self.call(f, "check", "--id", "second", "--run", str(run))
        self.assertIn("drift", result.stderr)
        self.assertEqual(1, len(self.history(f, run)["state"]["facts"]["checks"]["second"]))

    def test_changed_core_definition_and_unknown_dependency_block(self) -> None:
        f = self.fixture()
        f.manifest["core_criteria"][0][2] = "Weakened question"
        with self.assertRaisesRegex(ValueError, "core criteria"):
            validate_plan(f.manifest)
        f.manifest["additional_checks"][0]["after"] = ["not-selected"]
        with self.assertRaisesRegex(ValueError, "dependency"):
            prepare(f.manifest)

    def test_malformed_command_result_preserves_other_findings(self) -> None:
        f = self.fixture()
        f.add_finding(severity="high")
        f.qa["code_verdict"] = "NEEDS_WORK"
        f.tools[0]["commands"] = [None]
        _, result, _ = f.execute()
        self.assertEqual("INCOMPLETE", result["pipeline_status"])
        self.assertEqual(1, len(result["findings"]))

    def test_retry_cannot_erase_valid_findings_from_incomplete_attempt(self) -> None:
        f = self.fixture()
        f.add_finding(severity="high")
        request = f.root / "request.json"
        write_json(request, f.manifest)
        run = f.root / "run"
        self.assertEqual(
            0, self.call(f, "init", "--input", str(request), "--run", str(run)).returncode
        )
        first = deepcopy(f.lenses[1])
        first["gates"].pop()
        out = f.root / "out.json"
        write_json(out, first)
        result = self.call(
            f, "submit", "--id", "runtime-safety", "--input", str(out), "--run", str(run)
        )
        self.assertEqual(0, result.returncode, result.stderr)
        second = deepcopy(f.lenses[1])
        second["findings"] = []
        out.write_text(json.dumps(second))
        result = self.call(
            f, "submit", "--id", "runtime-safety", "--input", str(out), "--run", str(run)
        )
        self.assertEqual(0, result.returncode, result.stderr)
        retained = self.history(f, run)["state"]["facts"]["reports"]["runtime-safety"][1]
        self.assertEqual("RUN-1", retained["findings"][0]["finding_id"])
