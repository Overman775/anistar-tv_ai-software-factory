#!/usr/bin/env python3
"""Read local telemetry or send traces and diagnostic logs to configured OTLP receivers."""

if __name__ == "__main__":
    from factory.runtime.observability.cli import main

    raise SystemExit(main())
