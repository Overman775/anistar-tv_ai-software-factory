#!/usr/bin/env python3
"""Run the installed factory's own checks, independently of application configuration."""

from factory_tooling.quality import main

if __name__ == "__main__":
    raise SystemExit(main())
