"""Receiver-side assertions on the production bridge with a disposable workflow and local HTTP."""

import json
import os
import sqlite3
import subprocess
import sys
import unittest
from contextlib import closing, redirect_stderr, redirect_stdout
from dataclasses import replace
from http.server import BaseHTTPRequestHandler, HTTPServer
from io import StringIO
from pathlib import Path
from threading import Thread
from typing import Any
from unittest.mock import Mock, call, patch

import yaml
from opentelemetry.proto.collector.logs.v1.logs_service_pb2 import (
    ExportLogsServiceRequest,
    ExportLogsServiceResponse,
)
from opentelemetry.proto.collector.trace.v1.trace_service_pb2 import (
    ExportTraceServiceRequest,
    ExportTraceServiceResponse,
)
from opentelemetry.proto.logs.v1.logs_pb2 import LogRecord
from opentelemetry.proto.trace.v1.trace_pb2 import Span

from factory.adapters.acpx_adapter import install_connection, prepare_prompt, run_operation
from factory.cli import main as cli_main
from factory.database.sqlite import sqlite_diagnostic_journal as journal
from factory.database.sqlite import sqlite_export_feed, workflow_db
from factory.diagnostics.diagnostic_journal import LogRow
from factory.diagnostics.events import event
from factory.environment import use_environment
from factory.logging_config import diagnostic_operation
from factory.runtime import command_worker, teacher
from factory.runtime.contracts import ExecutionReceipt
from factory.runtime.lessons import Lesson, search_lessons
from factory.runtime.observability import export_policy
from factory.runtime.observability.acp_tools import summarize_tools
from factory.runtime.observability.acpx_usage import Attempt
from factory.runtime.observability.cli import main
from factory.runtime.observability.export_feed import RunObservation
from factory.runtime.observability.observations import ident
from factory.runtime.observability.otlp_bridge import Receiver, drain, retry_after_seconds
from factory.runtime.observability.otlp_projection import project
from factory.runtime.state_io import parse_state
from factory.secret_reader import SecretReader
from tests import CLI
from tests.factory.runtime.workflow_fixture import WorkflowFixture, bound_teacher


class OtlpTests(unittest.TestCase):
    def setUp(self) -> None:
        self.f = WorkflowFixture(self.addCleanup)
        self.config = self.f.root / ".factory/factory.yaml"
        self.config.parent.mkdir(exist_ok=True)
        from shutil import copytree

        copytree(Path(self.f.config["_path"]).parent / "graphs", self.config.parent / "graphs")
        self.enterContext(use_environment({}))
        self.development = self.enterContext(
            patch.object(export_policy, "development_install", return_value=False)
        )
        self.enterContext(patch.object(command_worker, "launch", self.launch_check))
        self.spans: list[Span] = []
        self.logs: list[LogRecord] = []
        self.requests: list[tuple[str, str | None, str | None]] = []
        self.responses: list[int] = []
        self.retry_after: str | None = None
        self.status = 200
        self.rejected = 0
        self.missing_bytes = 0
        fixture = self

        class Sink(BaseHTTPRequestHandler):
            def log_message(self, format: str, *args: object) -> None:
                pass

            def do_POST(self) -> None:
                raw = self.rfile.read(int(self.headers["Content-Length"]))
                fixture.requests.append(
                    (self.path, self.headers.get("Content-Type"), self.headers.get("Authorization"))
                )
                if self.path.endswith("/logs"):
                    resource = ExportLogsServiceRequest.FromString(raw).resource_logs[0]
                    fixture.logs.extend(resource.scope_logs[0].log_records)
                    log_reply = ExportLogsServiceResponse()
                    if fixture.rejected:
                        log_reply.partial_success.rejected_log_records = fixture.rejected
                    data = log_reply.SerializeToString()
                else:
                    fixture.spans.extend(
                        ExportTraceServiceRequest.FromString(raw)
                        .resource_spans[0]
                        .scope_spans[0]
                        .spans
                    )
                    reply = ExportTraceServiceResponse()
                    if fixture.rejected:
                        reply.partial_success.rejected_spans = fixture.rejected
                    data = reply.SerializeToString()
                self.send_response(
                    fixture.responses.pop(0) if fixture.responses else fixture.status
                )
                if fixture.retry_after:
                    self.send_header("Retry-After", fixture.retry_after)
                self.send_header("Content-Type", "application/x-protobuf")
                self.send_header("Content-Length", str(len(data) + fixture.missing_bytes))
                self.end_headers()
                self.wfile.write(data)

        server = HTTPServer(("127.0.0.1", 0), Sink)
        thread = Thread(target=server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(server.server_close)
        self.addCleanup(thread.join)
        self.addCleanup(server.shutdown)
        self.url = f"http://127.0.0.1:{server.server_port}"
        self.sink = Receiver(self.url + "/v1/traces", {"Authorization": "local-only"})

        self.configure()

    def launch_check(
        self, root: Path, execution_id: str, record: ExecutionReceipt
    ) -> subprocess.Popen[bytes]:
        # The supervisor is a new interpreter. Give it the fixture's telemetry policy
        # just as the coordinator has it, independently of the checker's dev install.
        script = (
            "import sys\n"
            "from unittest.mock import patch\n"
            "from factory.environment import use_environment\n"
            "from factory.runtime.command_worker import main\n"
            "from factory.runtime.observability import export_policy\n"
            "disabled = sys.argv.pop(1)\n"
            "with patch.object(export_policy, 'development_install', return_value=False), "
            "use_environment({'OTEL_SDK_DISABLED': disabled}):\n"
            "    main()\n"
        )
        disabled = "false" if export_policy.enabled(root) else "true"
        with command_worker.artifact(root, record, ".supervisor.log").open("ab") as log:
            return subprocess.Popen(
                [sys.executable, "-I", "-B", "-c", script, disabled, str(root), execution_id],
                stdin=subprocess.DEVNULL,
                stdout=log,
                stderr=log,
                start_new_session=os.name == "posix",
            )

    def configure(self, path: str = "/v1/traces", headers: dict[str, str] | None = None) -> None:
        self.config.write_text(
            yaml.safe_dump(
                {
                    "telemetry": {
                        "enabled": True,
                        "endpoint": self.url + path,
                        "headers": {"Authorization": "${env:TEST_TOKEN}"}
                        if headers is None
                        else headers,
                    }
                }
            ),
            encoding="utf-8",
        )

    def configure_logs(self, *, logs_only: bool = False) -> None:
        config = yaml.safe_load(self.config.read_text())
        if logs_only:
            config["telemetry"]["enabled"] = False
        config["logs"] = {
            "enabled": True,
            "endpoint": self.url + "/v1/logs",
            "headers": {"Authorization": "Logs ${env:LOG_TOKEN}"},
        }
        self.config.write_text(yaml.safe_dump(config))

    def bridge(self, *options: str) -> subprocess.CompletedProcess[str]:
        args = ["telemetry", "--workspace", str(self.f.root), *options]
        errors = StringIO()
        with (
            use_environment(
                {
                    "TEST_TOKEN": "local-only",
                }
            ),
            patch.object(sys, "argv", args),
            redirect_stderr(errors),
        ):
            code = main()
        return subprocess.CompletedProcess(args, code, "", errors.getvalue())

    def show(self, run: str, *options: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                *CLI,
                "telemetry",
                "show",
                "--run",
                run,
                "--workspace",
                str(self.f.root),
                *options,
            ],
            env={**os.environ, "OTEL_SDK_DISABLED": "true"},
            capture_output=True,
            text=True,
            check=False,
            timeout=10,
        )

    def local(self, run: str, *options: str) -> list[dict[str, Any]]:
        result = self.show(run, *options)
        self.assertEqual(result.returncode, 0, result.stderr)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["run_id"], run)
        records = payload["observations"]
        assert isinstance(records, list)
        return records

    def test_separate_receivers_and_credentials_resume_independently(self) -> None:
        self.configure_logs()
        run, dispatch = "run-112233445566", "a" * 32
        search_lessons(self.f.root, "fixture")
        with diagnostic_operation(self.f.root, "context"):
            event("database_failed", run_id=run, dispatch_id=dispatch, error_code="database_busy")
        first = self.bridge()
        self.assertEqual(first.returncode, 1)
        self.assertIn("LOG_TOKEN", first.stderr)
        self.assertEqual([r[0] for r in self.requests], ["/v1/traces"])
        (self.config.parent / ".env").write_text("LOG_TOKEN=logs-only-value\n")
        self.assertEqual(self.bridge().returncode, 0)
        self.assertEqual(
            self.requests,
            [
                ("/v1/traces", "application/x-protobuf", "local-only"),
                ("/v1/logs", "application/x-protobuf", "Logs logs-only-value"),
            ],
        )
        failure, completion = self.logs
        self.assertEqual(
            (failure.event_name, failure.body.string_value, failure.severity_number),
            ("database_failed", "database_failed", 17),
        )
        self.assertEqual(
            (failure.trace_id.hex(), failure.span_id.hex()),
            (ident(run, size=16), ident(run, dispatch)),
        )
        self.assertEqual(completion.severity_number, 9)
        self.assertEqual(completion.trace_id, b"")
        self.assertEqual(self.bridge().returncode, 0)
        self.assertEqual(len(self.logs), 2)
        self.assertEqual(self.bridge("--consumer", "second").returncode, 0)
        self.assertEqual(self.logs[:2], self.logs[2:])

    def test_log_eligibility_at_emission_and_logs_only_receiver(self) -> None:
        def complete() -> None:
            with diagnostic_operation(self.f.root, "context"):
                pass

        complete()  # trace-only configuration
        self.configure_logs(logs_only=True)
        self.development.return_value = True
        complete()
        self.development.return_value = False
        with use_environment({"OTEL_SDK_DISABLED": "true"}):
            complete()
        self.config.write_text("telemetry: {enabled: false}\n")
        complete()
        self.configure_logs(logs_only=True)
        complete()
        (self.config.parent / ".env").write_text("LOG_TOKEN=value\n")
        self.assertEqual(len(journal.snapshot(self.f.root)), 5)
        self.assertEqual(self.bridge().returncode, 0)
        self.assertEqual([log.event_name for log in self.logs], ["operation_completed"])
        self.assertEqual([r[0] for r in self.requests], ["/v1/logs"])

    def test_independent_switches_with_both_receivers_configured(self) -> None:
        self.configure_logs()
        options = yaml.safe_load(self.config.read_text())
        (self.config.parent / ".env").write_text("LOG_TOKEN=logs-only\n")
        for traces, logs in ((False, False), (True, False), (False, True), (True, True)):
            with self.subTest(traces=traces, logs=logs):
                options["telemetry"]["enabled"] = traces
                options["logs"]["enabled"] = logs
                self.config.write_text(yaml.safe_dump(options))
                search_lessons(self.f.root, "switch test")
                with diagnostic_operation(self.f.root, "context"):
                    pass
                self.requests.clear()
                result = self.bridge()
                self.assertEqual(result.returncode, 0, result.stderr)
                paths = [path for path, _, _ in self.requests]
                expected = (["/v1/traces"] if traces else []) + (["/v1/logs"] if logs else [])
                self.assertEqual(paths, expected)
        self.assertEqual(len(self.spans), 2)
        self.assertEqual(len(self.logs), 2)

    def test_log_batch_retry_partial_response_and_retention_gap(self) -> None:
        self.configure_logs(logs_only=True)
        (self.config.parent / ".env").write_text("LOG_TOKEN=value\n")
        with diagnostic_operation(self.f.root, "context"):
            pass
        (payload,) = journal.snapshot(self.f.root)
        journal.append(self.f.root, "test", [LogRow(payload, None, None, True)] * 129, 1)
        self.responses = [200, 503]
        self.assertEqual(self.bridge().returncode, 1)
        self.assertEqual(len(self.logs), 130)
        self.missing_bytes = 1
        self.assertIn("Incomplete OTLP response", self.bridge().stderr)
        self.missing_bytes = 0
        self.rejected = 3
        self.assertIn("Invalid OTLP rejection count", self.bridge().stderr)
        self.rejected = 1
        result = self.bridge()
        self.assertEqual(result.returncode, 1)
        self.assertIn("1 rejected", result.stderr)
        self.assertEqual(len(self.logs), 136)
        self.rejected = 0
        self.assertEqual(self.bridge().returncode, 0)
        self.assertEqual(len(self.logs), 136)
        with patch.object(journal, "MAX_RECORDS", 2):
            journal.append(self.f.root, "test", [LogRow(payload, None, None, True)] * 3, 1)
            journal.append(self.f.root, "test", [LogRow(payload, None, None)] * 2, 1)
        result = self.bridge()
        self.assertEqual(result.returncode, 0)
        self.assertIn("3 eligible records expired", result.stderr)
        self.assertNotIn("expired", self.bridge().stderr)
        self.assertEqual(len(self.logs), 136)

    def test_local_view_before_archive_and_without_export(self) -> None:
        self.assertNotEqual(self.show("unknown").returncode, 0)
        self.assertFalse((self.f.root / workflow_db.DATABASE).exists())
        self.development.return_value = True
        run = self.f.init()["run_id"]
        self.f.start("write-label")
        dispatch = self.f.ledger.read()["nodes"]["write-label"]["dispatch_id"]
        search_lessons(self.f.root, "private lookup", run_id=run, dispatch_id=dispatch)
        self.config.write_text("invalid: [", encoding="utf-8")
        records = {s["name"]: s for s in self.local(run, "--dispatch", dispatch)}
        self.assertEqual(set(records), {"factory.run", "factory.attempt", "factory.lesson.search"})
        root, attempt, search = (
            records["factory.run"],
            records["factory.attempt"],
            records["factory.lesson.search"],
        )
        self.assertEqual(attempt["parent_span_id"], root["span_id"])
        self.assertEqual(search["parent_span_id"], attempt["span_id"])
        self.assertIsNone(root["end_ns"])
        self.assertIsNone(attempt["end_ns"])
        self.assertEqual(search["attributes"]["factory.search.status"], "miss")
        self.assertNotIn("private lookup", str(search))
        self.assertNotEqual(self.show(run, "--dispatch", "unknown").returncode, 0)
        self.assertNotEqual(self.show("unknown").returncode, 0)
        self.configure()
        self.f.ledger.finish("write-label", self.f.report("write-label"))
        self.f.ledger.archive("cancelled", "fixture")
        self.f.ledger.clean()
        closed = self.local(run)
        self.assertEqual(closed[0]["span_id"], root["span_id"])
        self.assertIsNotNone(closed[0]["end_ns"])
        self.assertEqual(search, next(s for s in closed if s["name"] == search["name"]))
        with workflow_db.database(self.f.root) as db:
            for table in ("telemetry_feed", "telemetry_offsets"):
                self.assertEqual(db.execute(f"SELECT count(*) FROM {table}").fetchone(), (0,))
        self.assertFalse(self.requests)

    def test_timeline_distinguishes_replaced_pass_and_acceptance(self) -> None:
        run = self.f.init()["run_id"]
        node = "write-label"
        self.f.start(node)
        first = self.f.ledger.read()["nodes"][node]["dispatch_id"]
        self.f.ledger.finish(node, self.f.report(node))
        self.f.ledger.retry(node, "tests", "private-retry-reason", "private-evidence")
        # There is no current assignment between retry and the next reservation.
        attempt = next(item for item in self.local(run) if item["name"] == "factory.attempt")
        self.assertFalse(attempt["attributes"]["factory.attempt.current"])
        graph = self.f.ledger.read()["graph"]
        graph["tasks"]["label"]["scope"].append("lib/new.txt")
        self.f.ledger.revise(graph, "private-revision-reason")
        self.f.complete()
        self.f.ledger.archive("completed", "fixture")
        self.f.ledger.clean()
        records = self.local(run)
        milestones = records[0]["events"]
        self.assertEqual(
            [e["name"] for e in milestones],
            ["factory.run.retry", "factory.run.revised", "factory.run.accepted"],
        )
        self.assertEqual(
            milestones[0]["attributes"], {"factory.node.id": node, "factory.retry.stage": "tests"}
        )
        attempts = [item for item in records if item["name"] == "factory.attempt"]
        self.assertEqual(len(attempts), 3)
        for item in attempts:
            fields = item["attributes"]
            self.assertEqual(fields["factory.outcome"], "PASS")
            self.assertEqual(
                fields["factory.attempt.current"], fields["factory.dispatch.id"] != first
            )
            self.assertTrue(item["reports"])
        self.assertNotIn("private-", str(records))
        self.assertEqual(self.bridge().returncode, 0)
        root = next(span for span in self.spans if span.name == "factory.run")
        self.assertEqual(
            [(e.name, e.time_unix_nano) for e in root.events],
            [(e["name"], e["time_ns"]) for e in milestones],
        )
        self.assertNotIn("private-", str(self.spans))

    def test_dev_and_disabled_work_is_never_replayed(self) -> None:
        self.development.return_value = True
        search_lessons(self.f.root, "development")
        self.assertEqual(self.bridge().returncode, 0)
        self.development.return_value = False
        self.config.write_text("telemetry: {enabled: false}\n", encoding="utf-8")
        search_lessons(self.f.root, "disabled")
        self.configure()
        with use_environment({"OTEL_SDK_DISABLED": "true"}):
            search_lessons(self.f.root, "checker")
        self.assertEqual(self.bridge().returncode, 0)
        self.assertEqual(self.requests, [])
        search_lessons(self.f.root, "production")
        self.assertEqual(self.bridge().returncode, 0)
        self.assertEqual(len(self.spans), 1)
        with workflow_db.database(self.f.root) as db:
            self.assertEqual(db.execute("SELECT count(*) FROM lesson_searches").fetchone(), (4,))
            self.assertEqual(db.execute("SELECT count(*) FROM telemetry_feed").fetchone(), (1,))

    def test_mixed_run_and_dev_teacher_stay_local_when_finished_in_production(self) -> None:
        self.f.init()
        self.development.return_value = True
        self.f.ledger.set_paused("dev work")
        key = teacher.enqueue(
            self.f.root,
            teacher.Event(kind="user", incident="fixture", source="fixture", observation="fixture"),
        )
        self.development.return_value = False
        self.f.ledger.archive("cancelled", "fixture")
        teacher.complete(self.f.root, key, reason="fixture")
        self.assertEqual(self.bridge().returncode, 0)
        self.assertFalse(self.requests)

    def test_default_env_file_and_process_override(self) -> None:
        self.configure(
            "/custom/traces", {"Authorization": "Bearer ${env:TEST_TOKEN}-${env:SUFFIX}"}
        )
        (self.config.parent / ".env").write_text(
            "TEST_TOKEN=file-key\nSUFFIX=file\n", encoding="utf-8"
        )
        search_lessons(self.f.root, "fixture")
        args = ["telemetry", "--workspace", str(self.f.root)]
        with (
            patch.object(sys, "argv", args),
            use_environment(
                {
                    "TEST_TOKEN": "raw,%20=foo",
                    "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT": "http://unused.invalid",
                    "OTEL_EXPORTER_OTLP_HEADERS": "Authorization=ignored",
                }
            ),
        ):
            self.assertEqual(main(), 0)
        self.assertEqual(
            self.requests, [("/custom/traces", "application/x-protobuf", "Bearer raw,%20=foo-file")]
        )

    def test_disabled_follow_exits_before_loading_secrets_or_connecting(self) -> None:
        result = subprocess.run(
            [
                *CLI,
                "telemetry",
                "--workspace",
                str(self.f.root),
                "--follow",
                "--env-file",
                str(self.f.root / "missing.env"),
            ],
            env={
                **os.environ,
                "OTEL_SDK_DISABLED": "true",
                "OTEL_EXPORTER_OTLP_ENDPOINT": self.url,
            },
            capture_output=True,
            text=True,
            check=False,
            timeout=5,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("OTLP disabled", result.stderr)
        self.assertFalse(self.requests)
        self.assertFalse((self.f.root / workflow_db.DATABASE).exists())

    def test_historical_workflow_schema_is_left_untouched(self) -> None:
        with workflow_db.database(self.f.root):
            pass
        path = self.f.root / workflow_db.DATABASE
        for version in (1, 2):
            with closing(sqlite3.connect(path)) as db, db:
                db.execute(f"PRAGMA user_version={version}")
            before = path.read_bytes()
            with (
                self.assertRaisesRegex(ValueError, "Unsupported workflow database"),
                workflow_db.database(self.f.root),
            ):
                self.fail("opened a historical workflow schema")
            self.assertEqual(path.read_bytes(), before)

    def test_delivery_after_clean_includes_late_teacher_but_no_source_text(self) -> None:
        f = self.f
        key = teacher.enqueue(
            f.root,
            teacher.Event(
                kind="user",
                incident="personal-message",
                source="private-source",
                observation="private observation",
            ),
        )
        card = Lesson(
            id="receipt",
            scope="factory",
            title="Receipt",
            observed="private observation",
            applies_when="Reuse a receipt",
            action="Verify receipt",
            tags=["receipt"],
        )
        teacher.apply(f.root, key, card, None)
        teacher.complete(f.root, key)
        run = f.init()["run_id"]
        f.start("write-label")
        dispatch = f.ledger.read()["nodes"]["write-label"]["dispatch_id"]
        assigned = f.ledger.read()["nodes"]["write-label"]
        expected_role = assigned["role"]
        expected_harness = f.config["profiles"][assigned["profile"]]["harness"]
        (hit,) = search_lessons(f.root, "receipt", run_id=run, dispatch_id=dispatch)
        f.ledger.finish(
            "write-label",
            f.report(
                "write-label",
                applied_lessons=[
                    {
                        "id": hit.id,
                        "revision": hit.revision,
                        "result": "private application evidence",
                    }
                ],
            ),
        )
        f.start("verify-label")
        f.ledger.finish("verify-label", f.report("verify-label"))
        f.ledger.accept("accept-label")
        acpx = {
            "run_id": run,
            "project_id": "unit-fixture",
            "sessions": [
                {
                    "name": "session",
                    "cwd": "private-path",
                    "connection": "test",
                    "collection": "ok",
                    "attempts": [],
                    "cumulative_cost": {"amount": 0.25, "currency": "USD"},
                    "request_token_usage": {
                        "req": {
                            "input_tokens": 9,
                            "output_tokens": 0,
                            "cache_read_input_tokens": 0,
                            "cache_creation_input_tokens": 3,
                            "thought_tokens": 2**63,
                        }
                    },
                }
            ],
        }
        with patch("factory.runtime.workflow.telemetry.collect", return_value=acpx):
            f.ledger.archive("completed", "private summary")
        f.ledger.clean()
        self.assertFalse(self.requests)
        first = self.bridge()
        self.assertEqual(first.returncode, 0, first.stderr)
        by_name = {s.name: s for s in self.spans}
        root = by_name["factory.run"]
        search = by_name["factory.lesson.search"]
        applied = by_name["factory.lesson.applied"]
        self.assertEqual(search.trace_id, root.trace_id)
        self.assertEqual(
            [(link.trace_id, link.span_id) for link in applied.links],
            [(search.trace_id, search.span_id)],
        )
        check = by_name["factory.check"]
        check_attrs = {a.key: a.value for a in check.attributes}
        self.assertEqual(check_attrs["factory.check.id"].string_value, "behavior")
        self.assertEqual(check_attrs["factory.outcome"].string_value, "PASS")
        self.assertEqual(check_attrs["factory.check.exit_code"].int_value, 0)
        self.assertGreater(check.end_time_unix_nano, check.start_time_unix_nano)
        self.assertEqual(search.parent_span_id, applied.parent_span_id)
        attempts = [s for s in self.spans if s.name == "factory.attempt"]
        self.assertIn(search.parent_span_id, {s.span_id for s in attempts})
        self.assertTrue(all(s.parent_span_id == root.span_id for s in attempts))
        write = next(s for s in attempts if s.span_id == search.parent_span_id)
        attempt_fields = {a.key: a.value.string_value for a in write.attributes}
        self.assertEqual(attempt_fields["factory.role"], expected_role)
        self.assertEqual(attempt_fields["factory.harness"], expected_harness)
        self.assertNotIn("gen_ai.usage.input_tokens", attempt_fields)
        self.assertNotIn("factory.cost.amount", attempt_fields)
        usage = by_name["factory.acpx.request.usage"]
        self.assertEqual(usage.parent_span_id, by_name["factory.acpx.session"].span_id)
        values = {a.key: a.value for a in usage.attributes}
        self.assertEqual(values["gen_ai.usage.output_tokens"].int_value, 0)
        self.assertEqual(values["gen_ai.usage.cache_read.input_tokens"].int_value, 0)
        self.assertEqual(values["gen_ai.usage.cache_creation.input_tokens"].int_value, 3)
        self.assertNotIn("factory.acpx.total_tokens", values)
        self.assertNotIn("factory.acpx.thought_tokens", values)
        self.assertEqual(usage.dropped_attributes_count, 1)
        self.assertEqual(self.bridge().returncode, 0)
        before = len(self.spans)
        (job,) = teacher.pending(f.root)
        local_pending = self.local(run, "--dispatch", dispatch)
        pending = next(s for s in local_pending if s["name"] == "factory.teacher.job")
        self.assertIsNone(pending["end_ns"])
        attempt_ids = {s["span_id"] for s in local_pending if s["name"] == "factory.attempt"}
        self.assertEqual(attempt_ids, {write.span_id.hex()})
        teacher.apply(
            f.root,
            job,
            card.model_copy(update={"action": "Check the latest receipt"}),
            hit.revision,
            dispatch_id=bound_teacher(f.root, job),
        )
        teacher.complete(f.root, job, dispatch_id=bound_teacher(f.root, job))
        self.assertEqual(self.bridge().returncode, 0)
        self.assertEqual(len(self.spans), before + 1)
        self.assertEqual(self.spans[-1].parent_span_id, root.span_id)
        local = self.local(run)
        exported = {s.span_id.hex(): s for s in self.spans if s.trace_id == root.trace_id}
        self.assertEqual(set(exported), {s["span_id"] for s in local})
        for item in local:
            wire = exported[item["span_id"]]
            self.assertEqual(
                (
                    item["name"],
                    item["trace_id"],
                    item["parent_span_id"],
                    item["start_ns"],
                    item["end_ns"],
                ),
                (
                    wire.name,
                    wire.trace_id.hex(),
                    wire.parent_span_id.hex() or None,
                    wire.start_time_unix_nano,
                    wire.end_time_unix_nano,
                ),
            )
            self.assertEqual(
                item["links"],
                [
                    {"trace_id": link.trace_id.hex(), "span_id": link.span_id.hex()}
                    for link in wire.links
                ],
            )
        final = next(s for s in local if s["span_id"] == pending["span_id"])
        application = next(s for s in local if s["name"] == "factory.lesson.applied")
        report = application["reports"][0]
        self.assertEqual(report["dispatch_id"], dispatch)
        self.assertEqual(len(report["sha256"]), 64)
        self.assertIn(report, final["events"][0]["reports"])
        self.assertTrue(final["events"][0]["attributes"]["factory.lesson.confirmed"])
        self.assertNotIn(report["path"], str(self.spans))
        self.assertEqual(
            set(self.requests), {("/v1/traces", "application/x-protobuf", "local-only")}
        )
        for secret in ("private", "local-only", "personal-message", str(f.root)):
            self.assertNotIn(secret, str(self.spans))

    def test_bridge_uses_selected_secret_provider_with_file_settings(self) -> None:
        search_lessons(self.f.root, "example")
        config = self.f.root / ".env"
        config.write_text("TEST_TOKEN=file-value\n", encoding="utf-8")
        provider = Mock(spec_set=SecretReader)
        provider.read_secret.return_value = "provider-value"
        args = ["telemetry", "--workspace", str(self.f.root), "--env-file", str(config)]
        with patch.object(sys, "argv", args), use_environment({}):
            self.assertEqual(main(secrets=provider), 0)
            self.assertEqual(
                self.requests, [("/v1/traces", "application/x-protobuf", "provider-value")]
            )
            self.assertEqual(
                provider.read_secret.call_args_list,
                [call("TEST_TOKEN")],
            )
            search_lessons(self.f.root, "another lookup")
            provider.read_secret.side_effect = OSError("sensitive provider detail")
            errors = StringIO()
            with redirect_stderr(errors):
                self.assertEqual(main(secrets=provider), 1)
            self.assertIn("OTLP export failed", errors.getvalue())
            self.assertNotIn("sensitive provider detail", errors.getvalue())
            self.assertEqual(len(self.requests), 1)

    def test_failed_post_retries_stable_span_and_partial_success_is_not_replayed(self) -> None:
        search_lessons(self.f.root, "undisclosed")
        self.status = 503
        self.assertNotEqual(self.bridge().returncode, 0)
        first = self.spans[0]
        self.status = 200
        self.rejected = 1
        result = self.bridge()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("1 rejected", result.stderr)
        self.assertNotIn("local-only", result.stderr)
        self.assertEqual(self.spans, [first, first])
        self.assertEqual(self.bridge().returncode, 0)
        self.assertEqual(len(self.spans), 2)

    def test_reservations_use_only_graph_event_attributes(self) -> None:
        run = self.f.init()["run_id"]
        self.f.start("write-label")
        dispatch = self.f.ledger.read()["nodes"]["write-label"]["dispatch_id"]
        self.f.ledger.finish("write-label", self.f.report("write-label"))
        self.f.start("verify-label")
        self.f.ledger.finish("verify-label", self.f.report("verify-label"))
        attempt = Attempt(
            node_id="write-label",
            dispatch_id=dispatch,
            agent="author",
            role="developer",
            harness="codex",
            transport="acp",
        )
        archive = {
            "run_id": run,
            "project_id": "unit-fixture",
            "sessions": [
                {
                    "name": "session",
                    "cwd": "private-path",
                    "connection": "test",
                    "attempts": [attempt.model_dump()],
                }
            ],
        }
        with patch("factory.runtime.workflow.telemetry.collect", return_value=archive):
            self.f.ledger.archive("cancelled", "fixture")
        item = sqlite_export_feed.next_observation(self.f.root, 0, 1)
        assert item is not None and isinstance(item[1], RunObservation)
        record = item[1]
        missing_attributes = replace(
            record, events=[e._replace(role=None, harness=None) for e in record.events]
        )
        spans = [
            {a.key: a.value.string_value for a in s.attributes}
            for s in project(missing_attributes)
            if s.name == "factory.attempt"
        ]
        self.assertEqual(len(spans), 2)
        self.assertNotIn("factory.role", spans[0])
        self.assertNotIn("factory.harness", spans[0])
        self.assertNotIn("factory.role", spans[1])
        self.assertNotIn("factory.harness", spans[1])

    def test_reopen_resumes_at_first_unacknowledged_span_of_large_archive(self) -> None:
        run = self.f.init()["run_id"]
        sessions = [
            {
                "name": name,
                "cwd": "private-path",
                "connection": "test",
                "request_token_usage": {str(i): {"input_tokens": i} for i in range(90)},
            }
            for name in ("second", "first")
        ]
        archive = {"run_id": run, "project_id": "unit-fixture", "sessions": sessions}
        with patch("factory.runtime.workflow.telemetry.collect", return_value=archive):
            self.f.ledger.archive("cancelled", "fixture")
        self.responses = [200, 503]
        self.assertEqual(self.bridge().returncode, 1)
        first, retried = self.spans[:128], self.spans[128:]
        self.assertEqual((len(first), len(retried)), (128, 55))
        self.assertEqual(len({s.span_id for s in self.spans}), 183)
        self.spans.clear()
        self.assertEqual(self.bridge().returncode, 0)
        self.assertEqual(self.spans, retried)
        self.spans.clear()
        self.assertEqual(self.bridge().returncode, 0)
        self.assertEqual(self.spans, [])

    def test_follow_waits_for_retry_after_and_retries_same_data(self) -> None:
        self.responses = [429, 200]
        self.retry_after = "17"
        search_lessons(self.f.root, "throttle")
        args = ["telemetry", "--workspace", str(self.f.root), "--follow", "--json"]
        waits: list[float] = []
        output = StringIO()

        def wait(delay: float) -> None:
            self.assertEqual(output.getvalue(), "")
            waits.append(delay)
            if len(waits) == 2:
                self.config.write_text("telemetry: {enabled: false}\n", encoding="utf-8")

        with (
            use_environment({"TEST_TOKEN": "private"}),
            patch("factory.runtime.observability.otlp_bridge.time.sleep", side_effect=wait),
            redirect_stderr(StringIO()),
            redirect_stdout(output),
        ):
            self.assertEqual(cli_main(args), 0)
        self.assertEqual(
            json.loads(output.getvalue()),
            {"status": "stopped", "consumer": "default", "follow": True},
        )
        self.assertEqual(waits, [17.0, 1.0])
        self.assertEqual(len(self.spans), 2)
        self.assertEqual(self.spans[0], self.spans[1])

    def test_retry_after_date_and_malformed_hint(self) -> None:
        with patch("factory.runtime.observability.otlp_bridge.time.time", return_value=10):
            self.assertEqual(retry_after_seconds("Thu, 01 Jan 1970 00:00:30 GMT"), 20)
            self.assertEqual(retry_after_seconds("Thu, 01 Jan 1970 00:00:01 GMT"), 0)
        self.assertIsNone(retry_after_seconds("invalid"))

    def test_incomplete_response_or_impossible_rejection_does_not_acknowledge(self) -> None:
        search_lessons(self.f.root, "private")
        self.missing_bytes = 12
        self.assertIn("Incomplete OTLP response", self.bridge().stderr)
        self.missing_bytes = 0
        for count in (-1, 2):
            self.rejected = count
            self.assertIn("Invalid OTLP rejection count", self.bridge().stderr)
        self.rejected = 0
        self.assertEqual(self.bridge().returncode, 0)
        self.assertEqual(len(self.spans), 4)
        self.assertEqual(len({s.span_id for s in self.spans}), 1)
        self.assertEqual(self.bridge().returncode, 0)
        self.assertEqual(len(self.spans), 4)

    def test_prompt_tools_and_interrupted_poll_belong_to_original_dispatch(self) -> None:
        f = self.f
        f.fake_acp()
        install_connection(f.config, f.root, "zcode")
        f.init()
        f.claim("write-label")
        prepared = prepare_prompt(f.ledger, "write-label")

        def execute(argv: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
            if "show" in argv:
                raise OSError("private details")
            if "prompt" in argv:
                for action, details in (
                    ("tool_call", {"kind": "read", "title": "private path"}),
                    ("tool_call_update", {"status": "in_progress"}),
                    ("tool_call_update", {"status": "completed", "rawOutput": "private data"}),
                ):
                    update = {"sessionUpdate": action, "toolCallId": "private-id", **details}
                    message = {
                        "jsonrpc": "2.0",
                        "method": "session/update",
                        "params": {"sessionId": "private-sid", "update": update},
                    }
                    kwargs["stdout"].write(json.dumps(message) + "\n")
            return subprocess.CompletedProcess(argv, 0)

        run_operation(f.ledger, "write-label", "create", run=execute)
        f.ledger.bind(
            "write-label",
            prepared["session"],
            f.config["models"]["glm-5-3"]["id"] or "fixture-default",
        )
        run_operation(f.ledger, "write-label", "prompt", run=execute)
        with self.assertRaises(OSError):
            run_operation(f.ledger, "write-label", "show", run=execute)
        f.ledger.unknown("write-label", "fixture")
        f.ledger.resolve("write-label", "blocked", "fixture")
        f.ledger.archive("cancelled", "fixture")
        f.ledger.clean()
        self.assertEqual(self.bridge().returncode, 0)
        attempt = next(s for s in self.spans if s.name == "factory.attempt")
        calls = {}
        for span in self.spans:
            if span.name == "factory.acpx.transport":
                self.assertEqual(span.parent_span_id, attempt.span_id)
                fields = {a.key: a.value.string_value for a in span.attributes}
                calls[fields["factory.transport.operation"]] = span
        self.assertEqual(set(calls), {"create", "prompt", "show"})
        self.assertGreater(calls["prompt"].end_time_unix_nano, calls["prompt"].start_time_unix_nano)
        self.assertEqual(calls["show"].status.code, 2)
        (summary,) = calls["prompt"].events
        attrs = {a.key: a.value for a in summary.attributes}
        self.assertEqual(attrs["factory.tool.kind"].string_value, "read")
        self.assertEqual(attrs["factory.tool.status"].string_value, "completed")
        self.assertEqual(attrs["factory.tool.count"].int_value, 1)
        session = next(s for s in self.spans if s.name == "factory.acpx.session")
        binding = next(s for s in self.spans if s.name == "factory.acpx.assignment")
        self.assertEqual(binding.links[0].span_id, session.span_id)
        self.assertNotIn("private", str(self.spans))

    def test_partial_tool_output_recovers_after_an_oversized_or_invalid_line(self) -> None:
        update = {
            "sessionUpdate": "tool_call_update",
            "toolCallId": "x",
            "status": "failed",
            "kind": "private-kind",
        }
        good = json.dumps(
            {
                "jsonrpc": "2.0",
                "method": "session/update",
                "params": {"sessionId": "s", "update": update},
            }
        ).encode()
        summary = summarize_tools([b"x" * (1024 * 1024), b"xxx\n{broken}\n" + good[:10], good[10:]])
        self.assertTrue(summary.partial)
        self.assertEqual(summary.counts, {("unknown", "failed"): 1})
        self.assertNotIn("private-kind", str(summary))

    def test_invalid_route_and_templates_fail_before_secret_access(self) -> None:
        reader = Mock(spec_set=SecretReader)
        args = ["telemetry", "--workspace", str(self.f.root)]
        for options in (
            {"enabled": True},
            {"enabled": True, "endpoint": "https://user:private@host/path"},
            {"enabled": True, "logs": {"headers": {}}},
            {"enabled": True, "logs": {"endpoint": self.url, "headers": {"Host": "elsewhere"}}},
            {"enabled": True, "endpoint": self.url, "headers": {"Authorization": "${TOKEN}"}},
            {"enabled": True, "endpoint": self.url, "headers": {"Host": "elsewhere"}},
        ):
            with self.subTest(options=options):
                self.config.write_text(yaml.safe_dump({"telemetry": options}), encoding="utf-8")
                with patch.object(sys, "argv", args), redirect_stderr(StringIO()) as errors:
                    self.assertEqual(main(secrets=reader), 1)
                self.assertNotIn("private", errors.getvalue())
        reader.read_secret.assert_not_called()
        self.assertFalse(self.requests)

    def test_missing_blank_or_invalid_value_never_advances_delivery(self) -> None:
        search_lessons(self.f.root, "fixture")
        reader = Mock(spec_set=SecretReader)
        args = ["telemetry", "--workspace", str(self.f.root)]
        for token in (None, "  ", "private\r\nheader"):
            reader.read_secret.return_value = token
            with patch.object(sys, "argv", args), redirect_stderr(StringIO()) as errors:
                self.assertEqual(main(secrets=reader), 1)
            self.assertNotIn("private", errors.getvalue())
            if token is None:
                self.assertIn("TEST_TOKEN", errors.getvalue())
        self.assertFalse(self.requests)
        self.assertEqual(self.bridge().returncode, 0)
        self.assertEqual(len(self.spans), 1)

    def test_only_current_receiver_settings_are_readable(self) -> None:
        state = self.f.init()
        for settings in ({"otlp_enabled": True}, {"enabled": True, "logs": {"endpoint": self.url}}):
            with self.subTest(settings=settings):
                raw = {**state, "config": {**state["config"], "telemetry": settings}}
                with self.assertRaisesRegex(ValueError, "Invalid persisted state"):
                    parse_state(raw)
        self.assertEqual(parse_state(state), state)

    def test_delivery_from_current_schema(self) -> None:
        run = self.f.init()["run_id"]
        self.f.ledger.archive("cancelled", "old")
        search_lessons(self.f.root, "old lookup")
        self.assertEqual(drain(self.f.root, self.sink, "old"), 0)
        with workflow_db.database(self.f.root) as db:
            self.assertEqual(db.execute("PRAGMA user_version").fetchone(), (0,))
            self.assertEqual(db.execute("SELECT count(*) FROM telemetry_feed").fetchone(), (2,))
        self.assertEqual({s.name for s in self.spans}, {"factory.run", "factory.lesson.search"})
        self.assertIn(run, str(self.spans))
