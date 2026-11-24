"""Read local telemetry or send traces and diagnostic logs to configured OTLP receivers."""

import argparse
import json
import sys
from dataclasses import asdict
from pathlib import Path

from factory.cli_output import emit_error, emit_json
from factory.database.provider import current_database
from factory.runtime.observability.journal_logs import journal_lines, journal_records
from factory.runtime.observability.timeline import timeline
from factory.secret_reader import SecretReader


def build_parser(
    parser: argparse.ArgumentParser | None = None,
) -> argparse.ArgumentParser:
    parser = parser or argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", type=Path, default=Path.cwd())
    parser.add_argument(
        "--follow", action="store_true", help="Poll for new observations until stopped"
    )
    parser.add_argument(
        "--consumer", default="default", help="Checkpoint name within this endpoint"
    )
    parser.add_argument(
        "--env-file", type=Path, help="Read fallback credential values from this file"
    )
    commands = parser.add_subparsers(dest="command")
    show = commands.add_parser("show", help="Read local workflow observations as JSON")
    show.add_argument("--workspace", type=Path, default=argparse.SUPPRESS)
    show.add_argument("--run", required=True)
    show.add_argument("--dispatch")
    journal = commands.add_parser(
        "journal", help="Write a snapshot of local diagnostics as OTLP JSON lines"
    )
    journal.add_argument("--workspace", type=Path, default=argparse.SUPPRESS)
    return parser


def main(*, secrets: SecretReader | None = None) -> int:
    return run(build_parser().parse_args(), secrets=secrets)


def _failure(as_json: bool, code: str, message: str) -> int:
    if as_json:
        emit_error(code, message)
    else:
        print(message, file=sys.stderr)
    return 1


def run(args: argparse.Namespace, *, secrets: SecretReader | None = None) -> int:
    root = args.workspace.resolve()
    as_json = getattr(args, "json", False)
    if args.command == "journal":
        try:
            store = current_database().diagnostics
            if as_json:
                emit_json(list(journal_records(root, store)))
            else:
                for line in journal_lines(root, store):
                    print(line)
        except ValueError, OSError:
            return _failure(as_json, "journal_unavailable", "Could not export diagnostic journal")
        return 0
    if args.command == "show":
        try:
            records = timeline(
                root, args.run, args.dispatch, reader=current_database().observations
            )
        except (FileNotFoundError, LookupError) as exc:
            return _failure(as_json, "observation_not_found", str(exc))
        except ValueError, OSError:
            return _failure(
                as_json, "observations_unavailable", "Could not read workflow observations"
            )
        print(
            json.dumps(
                {"run_id": args.run, "observations": [asdict(r) for r in records]},
                ensure_ascii=False,
            )
        )
        return 0
    from factory.runtime.observability.otlp_bridge import SinkError, export, export_status

    if not as_json:
        return export(root, args.follow, args.consumer, args.env_file, secrets=secrets)
    try:
        status = export_status(root, args.follow, args.consumer, args.env_file, secrets=secrets)
    except SinkError as exc:
        message = (
            "A configured telemetry credential is missing"
            if exc.code == "missing_telemetry_credential"
            else str(exc)
        )
        emit_error(exc.code, message)
        return 1
    emit_json({"status": status, "consumer": args.consumer, "follow": args.follow})
    return 0
