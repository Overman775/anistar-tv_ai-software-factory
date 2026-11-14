from __future__ import annotations

import sys

from factory.project.contracts import ProjectCheck, ProjectData


def policy(checks: list[ProjectCheck] | None = None) -> ProjectData:
    return {
        "id": "gates",
        "gates": [{"id": "work-ready", "at": ["implement.work"], "checks": checks or [check()]}],
    }


def check(cid: str = "lint", code: int = 0) -> ProjectCheck:
    return {
        "id": cid,
        "level": "slice",
        "kind": "static",
        "method": "Fixture static check",
        "execution": {
            "argv": [sys.executable, "-c", f"raise SystemExit({code})"],
            "cwd": ".",
            "timeout_seconds": 10,
        },
    }
