"""Read local telemetry or send traces and diagnostic logs to configured OTLP receivers."""

import argparse
import json
import sys
from dataclasses import asdict
from pathlib import Path

from factory.database.provider import current_database
from factory.runtime.observability.journal_logs import journal_lines
from factory.runtime.observability.timeline import timeline
from factory.secret_reader import SecretReader


def main(*, secrets: SecretReader | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
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
    args = parser.parse_args()
    root = args.workspace.resolve()
    if args.command == "journal":
        try:
            for line in journal_lines(root, current_database().diagnostics):
                print(line)
        except ValueError, OSError:
            print("Could not export diagnostic journal", file=sys.stderr)
            return 1
        return 0
    if args.command == "show":
        try:
            records = timeline(
                root, args.run, args.dispatch, reader=current_database().observations
            )
        except (FileNotFoundError, LookupError) as exc:
            print(str(exc), file=sys.stderr)
            return 1
        except ValueError, OSError:
            print("Could not read workflow observations", file=sys.stderr)
            return 1
        print(
            json.dumps(
                {"run_id": args.run, "observations": [asdict(r) for r in records]},
                ensure_ascii=False,
            )
        )
        return 0
    from factory.runtime.observability.otlp_bridge import export

    return export(root, args.follow, args.consumer, args.env_file, secrets=secrets)
