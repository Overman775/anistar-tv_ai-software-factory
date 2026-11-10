"""Example: require a task outcome; customize for real project requirements."""

from __future__ import annotations

import json
import sys

if __name__ == "__main__":
    tasks = json.load(sys.stdin)["tasks"]
    errors = [key for key, task in tasks.items() if not str(task.get("outcome") or "").strip()]
    print(
        json.dumps(
            {
                "status": "FAIL" if errors else "PASS",
                "message": "Missing outcomes: " + ", ".join(errors)
                if errors
                else "Project task outcomes passed",
                "evidence": ["stdin task outcomes"],
            }
        )
    )
    sys.exit(bool(errors))
