from __future__ import annotations

import tempfile
from collections.abc import Callable
from pathlib import Path
from typing import Any

import yaml

from tests.factory.project.fixture_policy import policy


class DecisionFileFixture:
    def __init__(self, add_cleanup: Callable[[Callable[[], object]], object]) -> None:
        tmp = tempfile.TemporaryDirectory()
        add_cleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.data: dict[str, Any] = dict(policy())
        self.data["gates"][0]["checks"][0]["decision"] = "needs-static"
        self.definitions: list[dict[str, Any]] = [
            {"id": "needs-static", "question": "Are static checks required?"}
        ]
        self.data["decision_files"] = ["decisions/verification.yaml"]
        self.file = self.root / "project.yaml"
        self.bundle = self.root / "decisions/verification.yaml"
        self.bundle.parent.mkdir()
        self.write()

    def write(self) -> None:
        self.file.write_text(yaml.safe_dump(self.data))
        self.bundle.write_text(yaml.safe_dump({"decisions": self.definitions}))
