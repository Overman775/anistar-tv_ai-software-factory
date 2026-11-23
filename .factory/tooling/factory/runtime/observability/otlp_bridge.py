"""Deliver retained factory traces and diagnostic logs directly over OTLP/HTTP."""

import hashlib
import random
import re
import sys
import time
from collections.abc import Callable
from dataclasses import dataclass, field
from email.utils import parsedate_to_datetime
from http.client import HTTPConnection, HTTPException, HTTPSConnection
from itertools import batched, islice
from pathlib import Path
from typing import cast
from urllib.parse import urlsplit

from google.protobuf.message import DecodeError
from opentelemetry.proto.collector.logs.v1.logs_service_pb2 import (
    ExportLogsServiceRequest,
    ExportLogsServiceResponse,
)
from opentelemetry.proto.collector.trace.v1.trace_service_pb2 import (
    ExportTraceServiceRequest,
    ExportTraceServiceResponse,
)
from opentelemetry.proto.logs.v1.logs_pb2 import SeverityNumber
from opentelemetry.proto.trace.v1.trace_pb2 import Span

from factory.database.provider import current_database
from factory.diagnostics.diagnostic_journal import DiagnosticJournal
from factory.diagnostics.events import event
from factory.diagnostics.records import error_code
from factory.environment import settings
from factory.logging_config import finish, initialize
from factory.runtime.observability import export_policy
from factory.runtime.observability.configuration import SECRET_REFERENCE
from factory.runtime.observability.export_feed import ExportFeed
from factory.runtime.observability.journal_logs import JournalLog, project_log
from factory.runtime.observability.otlp_fields import attributes
from factory.runtime.observability.otlp_projection import project
from factory.runtime.workflow_core import lock, relative, require
from factory.secret_reader import EnvironmentSecretReader, SecretReader


class MissingSecret(ValueError):
    """A named header credential is absent from the selected source."""


class SinkError(Exception):
    def __init__(
        self,
        message: str,
        *,
        transient: bool = False,
        retry_after: float | None = None,
        code: str = "receiver_protocol",
    ) -> None:
        super().__init__(message)
        self.code = code
        self.transient = transient
        self.retry_after = retry_after


def retry_after_seconds(value: str | None) -> float | None:
    if value is None:
        return None
    value = value.strip()
    if re.fullmatch(r"[0-9]+", value):
        # HTTP delay-seconds saturate on overflow (RFC 9111, section 1.2.2).
        return min(float(value), float(2**31))
    try:
        deadline = parsedate_to_datetime(value)
        if deadline.tzinfo is None:
            return None
        return max(0.0, deadline.timestamp() - time.time())
    except TypeError, ValueError, OverflowError, OSError:
        return None


@dataclass(frozen=True)
class Receiver:
    url: str
    headers: dict[str, str] = field(repr=False)
    service: str = "overfactory"

    secrets: SecretReader | None = field(default=None, repr=False)

    def request_headers(self) -> dict[str, str]:
        def substitute(match: re.Match[str]) -> str:
            name = match[1]
            value = self.secrets.read_secret(name) if self.secrets is not None else None
            if not value or not value.strip():
                raise MissingSecret(name)
            if not re.fullmatch(r"[ -~]+", value):
                raise ValueError("Invalid telemetry credential")
            return value

        return {
            name: SECRET_REFERENCE.sub(substitute, template)
            for name, template in self.headers.items()
        }

    def send(self, spans: tuple[Span, ...]) -> int:
        payload = ExportTraceServiceRequest()
        resource = payload.resource_spans.add()
        resource.resource.attributes.extend(attributes({"service.name": self.service}))
        scope = resource.scope_spans.add()
        scope.scope.name = "overfactory"
        scope.scope.version = "2"
        scope.spans.extend(spans)
        return self._post(payload.SerializeToString(), len(spans), _trace_result)

    def send_logs(self, logs: list[JournalLog]) -> int:
        payload = ExportLogsServiceRequest()
        resource = payload.resource_logs.add()
        resource.resource.attributes.extend(attributes({"service.name": self.service}))
        scope = resource.scope_logs.add()
        scope.scope.name = "overfactory.diagnostics"
        for record in logs:
            log = scope.log_records.add(
                time_unix_nano=record.timestamp, severity_text=record.level, event_name=record.name
            )
            log.severity_number = cast("SeverityNumber.ValueType", record.severity)
            log.body.string_value = record.name
            log.attributes.extend(attributes(record.attributes))
            if record.trace and record.span:
                log.trace_id = bytes.fromhex(record.trace)
                log.span_id = bytes.fromhex(record.span)
        return self._post(payload.SerializeToString(), len(logs), _log_result)

    def _post(self, body: bytes, count: int, result: Callable[[bytes], tuple[int, str]]) -> int:
        headers = self.request_headers()
        target = urlsplit(self.url)
        connection = HTTPSConnection if target.scheme == "https" else HTTPConnection
        client = connection(target.hostname or "", target.port, timeout=5)
        try:
            path = target.path or "/"
            if target.query:
                path += "?" + target.query
            client.request(
                "POST",
                path,
                body,
                {**headers, "Content-Type": "application/x-protobuf"},
            )
            response = client.getresponse()
            if response.status != 200:
                raise SinkError(
                    f"OTLP receiver returned HTTP {response.status}",
                    transient=response.status in {429, 502, 503, 504},
                    code="receiver_auth" if response.status in (401, 403) else "receiver_http",
                    retry_after=retry_after_seconds(response.getheader("Retry-After")),
                )
            expected_bytes = response.length
            data = response.read(65537)
            if (
                len(data) > 65536
                or response.getheader("Content-Type", "").split(";")[0].strip().lower()
                != "application/x-protobuf"
            ):
                raise SinkError("Invalid OTLP response")
            if expected_bytes is not None and len(data) != expected_bytes:
                raise SinkError("Incomplete OTLP response", transient=True)
            rejected, message = result(data)
            if not 0 <= rejected <= count:
                raise SinkError("Invalid OTLP rejection count")
            if message or rejected:
                print(f"OTLP partial success: {rejected} rejected records", file=sys.stderr)
            return rejected
        except (OSError, HTTPException) as exc:
            raise SinkError(
                "OTLP receiver unavailable", transient=True, code="receiver_unavailable"
            ) from exc
        except DecodeError as exc:
            raise SinkError("Invalid OTLP response") from exc
        finally:
            client.close()


def _trace_result(data: bytes) -> tuple[int, str]:
    reply = ExportTraceServiceResponse.FromString(data).partial_success
    return reply.rejected_spans, reply.error_message


def _log_result(data: bytes) -> tuple[int, str]:
    reply = ExportLogsServiceResponse.FromString(data).partial_success
    return reply.rejected_log_records, reply.error_message


def drain(root: Path, receiver: Receiver, consumer: str, *, feed: ExportFeed | None = None) -> int:
    """Advance only after delivery. Never hold a SQLite transaction over the network."""
    feed = current_database().exports if feed is None else feed
    if not export_policy.enabled(root) or not feed.exists(root):
        return 0
    key = hashlib.sha256((receiver.url + "\x00" + consumer).encode()).hexdigest()
    with lock(relative(root, f".factory/diagnostics/otlp-{key}.lock")):
        after, offset, until = feed.checkpoint(root, key)
        rejected = 0
        while after < until:
            item = feed.next_observation(root, after, until)
            if item is None:
                break
            sequence, observation = item
            require(offset >= 0, "Invalid telemetry cursor")
            batches = batched(islice(project(observation), offset, None), 128, strict=False)
            batch = next(batches, ())
            require(bool(batch), "Invalid telemetry cursor")
            while batch:
                if not export_policy.enabled(root):
                    return rejected
                following = next(batches, ())
                rejected += receiver.send(batch)
                offset += len(batch)
                feed.acknowledge(
                    root, key, after if following else sequence, offset if following else 0
                )
                batch = following
                if rejected:
                    return rejected
            after, offset = sequence, 0
        return rejected


def drain_logs(root: Path, receiver: Receiver, consumer: str, store: DiagnosticJournal) -> int:
    key = hashlib.sha256((receiver.url + "\x00" + consumer).encode()).hexdigest()
    with lock(relative(root, f".factory/diagnostics/otlp-logs-{key}.lock")):
        after, until = store.delivery_window(root, key)
        while after < until:
            rows = store.delivery_batch(root, after, until, 128)
            current = export_policy.logs_settings(root)
            if (
                not current
                or current["endpoint"] != receiver.url
                or current.get("headers", {}) != receiver.headers
            ):
                break
            # Eligible sequences are consecutive. Retention can remove a prefix between batches.
            first = rows[0][0] if rows else until + 1
            if first > after + 1:
                print(
                    f"OTLP logs: {first - after - 1} eligible records expired before delivery",
                    file=sys.stderr,
                )
                store.acknowledge(root, key, first - 1)
            if not rows:
                break
            logs = [log for _, payload in rows if (log := project_log(payload)) is not None]
            if len(logs) != len(rows):
                print(
                    f"OTLP logs: skipped {len(rows) - len(logs)} invalid records", file=sys.stderr
                )
            rejected = receiver.send_logs(logs) if logs else 0
            after = rows[-1][0]
            store.acknowledge(root, key, after)
            if rejected:
                return rejected
    return 0


def _deliver(root: Path, traces: Receiver | None, logs: Receiver | None, consumer: str) -> int:
    # A failed trace request must still give the independent log cursor a turn.
    error: SinkError | OSError | ValueError | None = None
    rejected = 0
    if traces is not None:
        try:
            rejected = drain(root, traces, consumer)
        except (SinkError, OSError, ValueError) as exc:
            error = exc
    if logs is not None and export_policy.logs_settings(root):
        rejected += drain_logs(root, logs, consumer, current_database().diagnostics)
    if error is not None:
        raise error
    return rejected


def export(
    root: Path,
    follow: bool,
    consumer: str,
    env_file: Path | None,
    *,
    secrets: SecretReader | None = None,
) -> int:
    try:
        config = export_policy.active_settings(root)
    except OSError, ValueError:
        print("Invalid telemetry configuration in .factory/factory.yaml", file=sys.stderr)
        return 1
    if not config:
        print("Factory OTLP disabled", file=sys.stderr)
        return 0
    handler = initialize(root, "telemetry.export")
    failed = True
    try:
        if env_file is None:
            default = relative(root, ".factory/.env")
            env_file = default if default.is_file() else None
        env = settings(env_file)
        provider = EnvironmentSecretReader(env) if secrets is None else secrets
        service = env.get("OTEL_SERVICE_NAME") or "overfactory"
        backoff = 1
        while config:
            trace_options = config.get("telemetry")
            log_options = config.get("logs")
            traces = (
                Receiver(
                    trace_options["endpoint"], trace_options.get("headers", {}), service, provider
                )
                if trace_options
                else None
            )
            logs = (
                Receiver(log_options["endpoint"], log_options.get("headers", {}), service, provider)
                if log_options
                else None
            )
            try:
                rejected = _deliver(root, traces, logs, consumer)
                if rejected:
                    event("operation_failed", error_code="receiver_rejected")
                    return 1
                if not follow:
                    failed = False
                    event("operation_completed")
                    return 0
                backoff = 1
                delay = 1.0
            except SinkError as exc:
                if not follow or not exc.transient:
                    raise
                if backoff == 1:
                    event("export_retry", error_code=exc.code)
                print(str(exc), file=sys.stderr)
                backoff = min(backoff * 2, 60)
                delay = max(exc.retry_after or 0.0, random.uniform(backoff / 2, backoff))
            # Recheck opt-out during long receiver-specified delays.
            while delay > 60:
                time.sleep(60)
                delay -= 60
                if not export_policy.active_settings(root):
                    break
            else:
                time.sleep(delay)
            config = export_policy.active_settings(root)
        failed = False
        return 0
    except (OSError, ValueError, SinkError) as exc:
        event(
            "operation_failed",
            error_code=exc.code if isinstance(exc, SinkError) else error_code(exc),
        )
        if isinstance(exc, SinkError):
            print(str(exc), file=sys.stderr)
            return 1
        if isinstance(exc, MissingSecret):
            print(f"Missing telemetry credential: {exc.args[0]}", file=sys.stderr)
            return 1
        # The receiver URL, headers and persisted source records may contain secrets.
        print(
            "OTLP export failed. Check the receiver configuration, access and workflow database.",
            file=sys.stderr,
        )
        return 1
    except KeyboardInterrupt:
        failed = False
        return 0
    except BaseException as exc:
        event("operation_failed", error_code=error_code(exc))
        raise
    finally:
        finish(handler, failed=failed)
