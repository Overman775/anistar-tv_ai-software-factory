"""Build correlated observations from committed workflow, lookup and Teacher records."""

from collections.abc import Iterator, Mapping

from factory.runtime.observability.acpx_usage import Session, Usage
from factory.runtime.observability.export_feed import (
    ObservationSource,
    RunObservation,
    SearchObservation,
    TransportCall,
)
from factory.runtime.observability.observations import (
    Observation,
    ObservationEvent,
    ObservationLink,
    ReportReference,
    Scalar,
    ident,
    nanos,
)


def span(
    name: str,
    trace: str,
    key: str,
    parent: str | None,
    start: int | None,
    end: int | None,
    fields: Mapping[str, Scalar | None],
    *,
    failed: bool = False,
    reports: tuple[ReportReference, ...] = (),
) -> Observation:
    return Observation(
        name,
        ident(trace, size=16),
        key,
        parent,
        min(start, end) if start is not None and end is not None else start,
        end,
        failed,
        {k: v for k, v in fields.items() if v is not None},
        reports=reports,
    )


def transport_span(record: RunObservation, call: TransportCall) -> Observation:
    start = int(call.start * 1_000_000_000)
    end = int(call.end * 1_000_000_000) if call.end is not None else None
    coverage = None
    if call.operation == "prompt":
        if call.tools is None:
            coverage = "unavailable"
        elif call.tools.partial or call.outcome in ("interrupted", "unconfirmed"):
            coverage = "partial"
        else:
            coverage = "parsed"
    result = span(
        "factory.acpx.transport",
        record.run,
        ident(record.run, "transport", str(call.ordinal)),
        ident(record.run, call.dispatch),
        start,
        end,
        {
            "factory.run.id": record.run,
            "factory.project.id": record.project,
            "factory.dispatch.id": call.dispatch,
            "factory.node.id": call.node,
            "factory.transport.operation": call.operation,
            "factory.outcome": call.outcome,
            "factory.transport.stale": call.stale,
            "factory.transport.exit_code": call.exit_code,
            "factory.acpx.tool_stream": coverage,
            "error.type": call.outcome if call.outcome in ("failure", "interrupted") else None,
        },
        failed=call.outcome in ("failure", "interrupted"),
    )
    if call.tools is not None:
        for (kind, status), count in sorted(call.tools.counts.items()):
            result.events.append(
                ObservationEvent(
                    "factory.acpx.tool.summary",
                    end,
                    {
                        "factory.tool.kind": kind,
                        "factory.tool.status": status,
                        "factory.tool.count": count,
                    },
                )
            )
    return result


def usage_attributes(usage: Usage) -> dict[str, int]:
    fields = {
        "gen_ai.usage.input_tokens": usage.input_tokens,
        "gen_ai.usage.output_tokens": usage.output_tokens,
        "gen_ai.usage.cache_read.input_tokens": usage.cache_read_input_tokens,
        "gen_ai.usage.cache_creation.input_tokens": usage.cache_creation_input_tokens,
        "factory.acpx.thought_tokens": usage.thought_tokens,
        "factory.acpx.total_tokens": usage.total_tokens,
    }
    return {key: value for key, value in fields.items() if value is not None}


def session_spans(
    record: RunObservation, session: Session, end: int | None
) -> Iterator[Observation]:
    run = record.run
    session_key = ident(run, "acpx", session.connection, session.name)
    fields = {
        "factory.run.id": run,
        "factory.project.id": record.project,
        "factory.acpx.session": session.name,
        "factory.acpx.connection": session.connection,
    }
    cost = session.cumulative_cost
    yield span(
        "factory.acpx.session",
        run,
        session_key,
        ident(run),
        end,
        end,
        {
            **fields,
            "factory.acpx.collection": session.collection,
            "factory.acpx.collection_error": session.collection_error,
            "factory.cost.amount": cost.amount if cost else None,
            "factory.cost.currency": cost.currency if cost else None,
        },
    )
    for attempt in session.attempts:
        binding = span(
            "factory.acpx.assignment",
            run,
            ident(run, session.name, session.connection, attempt.dispatch_id),
            ident(run, attempt.dispatch_id),
            end,
            end,
            {
                **fields,
                "factory.dispatch.id": attempt.dispatch_id,
                "factory.agent": attempt.agent,
                "factory.role": attempt.role,
                "factory.harness": attempt.harness,
                "gen_ai.request.model": attempt.requested_model,
                "factory.effective_model": attempt.effective_model,
                "factory.requested_effort": attempt.requested_effort,
            },
        )
        binding.links.append(ObservationLink(binding.trace_id, session_key))
        yield binding
    for request, usage in (session.request_token_usage or {}).items():
        tokens = usage_attributes(usage)
        yield span(
            "factory.acpx.request.usage",
            run,
            ident(run, session.name, session.connection, request, "usage"),
            session_key,
            end,
            end,
            {**fields, "factory.request.id": request, **tokens},
        )


def workflow_milestones(record: RunObservation) -> Iterator[ObservationEvent]:
    # Both ordered lists are appended in the same correction transaction. Older
    # incomplete histories can still expose the markers without inferring identities.
    markers = [
        (e.node, e.decision, e.target) for e in record.events if e.kind == "correction_decided"
    ]
    details = (
        iter(record.corrections)
        if markers == [(c.node, c.decision, c.to_profile) for c in record.corrections]
        else iter(())
    )
    for event in record.events:
        if event.kind not in {"retry", "revised", "accepted", "correction_decided"}:
            continue
        fields: dict[str, Scalar] = {}
        if event.node:
            fields["factory.node.id"] = event.node
        if event.kind == "retry" and event.stage in {
            "static",
            "tests",
            "docs",
            "review",
            "recovery",
        }:
            fields["factory.retry.stage"] = event.stage
        if event.kind == "correction_decided":
            if event.decision in {"blocked", "human", "retry", "escalate"}:
                fields["factory.correction.decision"] = event.decision
            if event.target:
                fields["factory.correction.to_profile"] = event.target
            if correction := next(details, None):
                fields.update(
                    {
                        "factory.correction.from_profile": correction.from_profile,
                        "factory.correction.cause": correction.cause,
                        "factory.dispatch.id": correction.author_dispatch,
                        "factory.correction.evidence_node": correction.evidence_node,
                        "factory.correction.evidence_dispatch": correction.evidence_dispatch,
                    }
                )
        yield ObservationEvent(f"factory.run.{event.kind}", int(event.at * 1_000_000_000), fields)


def run_spans(record: RunObservation) -> Iterator[Observation]:
    run = record.run
    end = nanos(record.at) if record.at is not None else None
    common = {"factory.run.id": run, "factory.project.id": record.project}
    root = ident(run)
    assignments = {
        attempt.dispatch_id: attempt for session in record.sessions for attempt in session.attempts
    }
    started = end
    starts: dict[str, tuple[str, int, str | None, str | None]] = {}
    current: dict[str, str] = {}
    finishes: dict[str, tuple[int, str | None]] = {}
    for entry in record.events:
        event, node, dispatch = entry.kind, entry.node, entry.dispatch
        when = int(entry.at * 1_000_000_000)
        if event == "archived":
            end = when
        elif event == "created":
            started = when
        elif event == "reserved" and node and dispatch:
            current[node] = dispatch
            starts[dispatch] = node, when, entry.role, entry.harness
        elif (
            node is not None
            and node in current
            and (event == "finished" or (event == "reconciled" and entry.status == "blocked"))
        ):
            finishes[current[node]] = when, entry.outcome or entry.status
    run_span = span(
        "factory.run",
        run,
        root,
        None,
        started,
        end,
        {**common, "factory.outcome": record.status},
    )
    run_span.events.extend(workflow_milestones(record))
    yield run_span
    for dispatch, (node, begin, role, harness) in starts.items():
        assignment = assignments.get(dispatch)
        # A missing terminal event gives only a reservation instant.
        stop, result = finishes.get(dispatch, (None, None))
        yield span(
            "factory.attempt",
            run,
            ident(run, dispatch),
            root,
            begin,
            stop,
            {
                **common,
                "factory.node.id": node,
                "factory.dispatch.id": dispatch,
                "factory.outcome": result,
                "factory.attempt.current": dispatch in record.current_dispatches,
                "factory.role": role or (assignment.role if assignment else None),
                "factory.harness": harness or (assignment.harness if assignment else None),
            },
            failed=result in {"FAIL", "BLOCKED", "blocked"},
            reports=(record.reports[dispatch],) if dispatch in record.reports else (),
        )
    for dispatch, lesson, revision, outcome, search, search_uid in record.applications:
        applied_at = finishes[dispatch][0] if dispatch in finishes else end
        applied = span(
            "factory.lesson.applied",
            run,
            ident(run, "application", dispatch, lesson, revision),
            ident(run, dispatch),
            applied_at,
            applied_at,
            {
                **common,
                "factory.dispatch.id": dispatch,
                "factory.lesson.id": lesson,
                "factory.lesson.revision": revision,
                "factory.report.outcome": outcome,
                "factory.lesson.search.id": search,
            },
            reports=(record.reports[dispatch],) if dispatch in record.reports else (),
        )
        if search_uid:
            applied.links.append(ObservationLink(applied.trace_id, ident(search_uid)))
        yield applied
    for session in record.sessions:
        yield from session_spans(record, session, end)

    # Append new span families after the historical projection to preserve partial offsets.
    for call in record.transports:
        yield transport_span(record, call)
    for check in record.checks:
        start = int(check.start * 1_000_000_000)
        yield span(
            "factory.check",
            run,
            ident(run, "check", check.execution),
            ident(run, check.dispatch),
            start,
            int(check.end * 1_000_000_000) if check.end is not None else None,
            {
                **common,
                "factory.node.id": check.node,
                "factory.dispatch.id": check.dispatch,
                "factory.execution.id": check.execution,
                "factory.check.id": check.check,
                "factory.outcome": check.status,
                "factory.check.exit_code": check.exit_code,
            },
            failed=check.status in ("FAIL", "BLOCKED"),
        )


def observe(record: ObservationSource) -> Iterator[Observation]:
    if isinstance(record, RunObservation):
        yield from run_spans(record)
        return
    uid, end = record.uid, nanos(record.at)
    if isinstance(record, SearchObservation):
        search = record.search
        run = search.run_id
        fields: dict[str, Scalar | None] = {
            "factory.run.id": run,
            "factory.node.id": search.node_id,
            "factory.dispatch.id": search.dispatch_id,
            "factory.lesson.search.id": search.id,
            "factory.search.status": search.status,
            "factory.search.matches": len(search.matches),
            "error.type": search.error_type,
        }
        result = span(
            "factory.lesson.search",
            run or uid,
            ident(uid),
            ident(run, search.dispatch_id) if run and search.dispatch_id else None,
            end - search.elapsed_ms * 1_000_000,
            end,
            fields,
            failed=search.status == "error",
        )
        for rank, hit in enumerate(search.matches, 1):
            result.events.append(
                ObservationEvent(
                    "factory.lesson.match",
                    end,
                    {
                        "factory.lesson.id": hit["id"],
                        "factory.lesson.scope": hit["scope"],
                        "factory.lesson.revision": hit["revision"],
                        "factory.search.rank": rank,
                    },
                )
            )
    else:
        job = record.job
        run = job.incident if job.kind == "accept" else None
        evidence = job.incidents or {}

        report_groups = {
            incident: tuple(
                ReportReference(r["dispatch_id"], r["path"], r["sha256"])
                for r in info.reports
                if r["run_id"] == run
            )
            for incident, info in evidence.items()
        }
        reports = tuple(dict.fromkeys(ref for group in report_groups.values() for ref in group))
        if job.cancelled_by:
            outcome = "cancelled"
        elif job.done:
            outcome = "completed"
        elif job.waiting_for:
            outcome = "waiting"
        else:
            outcome = "pending"
        result = span(
            "factory.teacher.job",
            run or uid,
            ident(uid),
            ident(run) if run else None,
            nanos(record.created),
            end if job.done else None,
            {
                "factory.run.id": run,
                "factory.teacher.id": record.key,
                "factory.teacher.kind": job.kind,
                "factory.teacher.operation": job.route(),
                "factory.outcome": outcome,
            },
            reports=reports,
        )
        if run:
            dispatches = sorted({ref.dispatch_id for ref in reports})
            result.links.extend(ObservationLink(result.trace_id, ident(run, d)) for d in dispatches)
        for change in job.changes:
            change_reports = report_groups.get(change.incident, ())
            result.events.append(
                ObservationEvent(
                    "factory.lesson.change",
                    nanos(change.at),
                    {
                        "factory.lesson.id": change.id,
                        "factory.lesson.scope": change.scope,
                        "factory.lesson.revision": change.revision,
                        "factory.lesson.action": change.action,
                        "factory.lesson.confirmed": change.confirmed,
                    },
                    reports=change_reports,
                )
            )
    if record.project is not None:
        result.attributes["factory.project.id"] = record.project
    yield result
