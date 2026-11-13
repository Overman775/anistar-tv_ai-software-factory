#!/usr/bin/env python3
"""Exercise factory preparation on disposable fixtures; never dispatch a model."""

from __future__ import annotations

import argparse
import json
import shutil
import sys
import tempfile
from pathlib import Path
from typing import TYPE_CHECKING, Any

from factory_tooling.paths import TOOLS

if TYPE_CHECKING:
    from factory_tooling.runtime.contracts import Graph


def configuration() -> dict[str, Any]:
    profile = dict(
        role="roles/generalist.md",
        contract="contracts/generalist.md",
        capabilities=dict(read=True, edit=True, commands=True, web=False),
        enforcement="instructions",
        mcp=[],
    )
    return dict(
        project="project/project.yaml",
        router="workflow/router.md",
        orchestration="workflow/orchestration.md",
        native={"max_parallel_agents": 1},
        execution={
            "retry_budgets": dict(
                static=0, tests=0, docs=0, recovery=0, review=dict(feature=0, other=0)
            ),
            "on_budget_exhausted": "human",
        },
        models={"fixture": {"id": "dry-run-model"}},
        profiles={
            "generalist": dict(
                profile,
                default="native",
                variants={
                    "native": dict(model="fixture", adapter="native"),
                    "acp": dict(model="fixture", adapter="acp"),
                },
            )
        },
        adapters={
            "native": dict(
                harness="codex",
                runner="native",
                instructions="adapters/codex.md",
                worker_instructions="adapters/worker/codex.md",
            ),
            "acp": dict(
                harness="fixture",
                runner="acpx",
                connection="fixture",
                instructions="adapters/acpx.md",
                worker_instructions="adapters/worker/acpx.md",
            ),
        },
        acpx={
            "command": "dry-run-never-execute",
            "connections": {
                "fixture": dict(
                    command="dry-run-never-execute",
                    args=[],
                    max_parallel_agents=1,
                    permissions="deny-all",
                )
            },
        },
    )


def graph(profile: str) -> Graph:
    return dict(
        sources={
            "request": {
                "text": "Inspect the fixture only.",
                "acceptance": [
                    dict(
                        id="AC-01",
                        applies_to="global",
                        requirement="Fixture remains readable",
                        verification="Observe fixture contents",
                    )
                ],
            }
        },
        agents={"author": dict(role="generalist", profile=profile)},
        tasks={
            "fixture": dict(
                slice="fixture",
                source="request",
                outcome="Readable fixture",
                reason="Disposable preparation probe",
                risk="low",
                kind="fix",
                independent_review=False,
                scope=["sample.txt"],
                depends_on=[],
                acceptance_ids=["AC-01"],
                required_checks=[
                    dict(
                        id="observe",
                        category="acceptance",
                        criteria=["AC-01"],
                        kind="observation",
                        method="Read disposable sample",
                    )
                ],
            )
        },
        nodes=[
            dict(
                id="work",
                task="fixture",
                stage="work",
                agent="author",
                depends_on=[],
                owns=["sample.txt"],
                resources=[],
            ),
            dict(
                id="verify",
                task="fixture",
                stage="verify",
                agent="author",
                depends_on=["work"],
                owns=[],
                resources=["project-checks"],
            ),
            dict(
                id="accept",
                task="fixture",
                stage="accept",
                agent=None,
                depends_on=["verify"],
                owns=[],
                resources=[],
            ),
        ],
    )


def copy_bundle(source: Path, target: Path) -> None:
    """Copy owned runtime inputs only; never copy user settings or project data."""
    ignored = shutil.ignore_patterns(
        "__pycache__",
        "*.py[cod]",
        "tests",
        ".DS_Store",
        ".venv",
        ".venv.setup.lock",
        ".ruff_cache",
        ".mypy_cache",
        ".pytest_cache",
        ".coverage*",
        "htmlcov",
    )
    for name in ("roles", "contracts", "gates", "workflow", "adapters", "tools", "factory_tooling"):
        shutil.copytree(source / name, target / name, ignore=ignored, symlinks=True)
    for skill in (
        "factory-planning",
        "factory-implement",
        "factory-decompose",
        "factory-code-review",
    ):
        shutil.copytree(
            source / "skills" / skill, target / "skills" / skill, ignore=ignored, symlinks=True
        )


def run(source: Path = TOOLS.parent) -> dict[str, Any]:
    try:
        import yaml
    except ModuleNotFoundError as exc:
        raise RuntimeError(
            "PyYAML unavailable: use Python with tools/requirements.txt installed"
        ) from exc
    from factory_tooling.adapters.acpx_adapter import prepare_prompt
    from factory_tooling.project.profile_io import material_entries
    from factory_tooling.runtime.workflow import Ledger
    from factory_tooling.runtime.workflow_config import load_config

    checks = []
    with tempfile.TemporaryDirectory(prefix="factory-dry-run-") as directory:
        root = Path(directory)
        bundle = root / ".factory"
        copy_bundle(Path(source), bundle)
        project = bundle / "project"
        project.mkdir()
        (project / "rules.md").write_text(
            "DRY_RUN_PROJECT_RULE: preserve sample.txt.\n", encoding="utf-8"
        )
        policy = dict(
            id="dry-run",
            rules={
                audience: [dict(id="fixture-" + audience, file="rules.md")]
                for audience in ("coordinator", "worker")
            },
        )
        (project / "project.yaml").write_text(yaml.safe_dump(policy), encoding="utf-8")
        config_file = bundle / "factory.yaml"
        config_file.write_text(yaml.safe_dump(configuration()), encoding="utf-8")
        config = load_config(config_file)
        checks.append("configuration")
        for route in ("native", "acp"):
            workspace = root / route
            workspace.mkdir()
            (workspace / "AGENTS.md").write_text(
                "Disposable dry-run workspace.\n", encoding="utf-8"
            )
            (workspace / "sample.txt").write_text("fixture\n", encoding="utf-8")
            entries = material_entries(
                config["_project"],
                workspace,
                process="implement",
                audience="coordinator",
                scope=["sample.txt"],
            )
            if not any("DRY_RUN_PROJECT_RULE" in entry["content"] for entry in entries):
                raise ValueError("Project context lost fixture rule")
            ledger = Ledger(workspace)
            ledger.init(graph(route), config)
            ledger.claim("work")
            if route == "native":
                packet = ledger.packet("work")
                content = "\n".join(entry["content"] for entry in packet["instructions"])
            else:
                prepared = prepare_prompt(ledger, "work")
                content = Path(prepared["prompt"]).read_text(encoding="utf-8")
                if prepared["create"][0] != "dry-run-never-execute":
                    raise ValueError("Unexpected ACP executable")
            if "DRY_RUN_PROJECT_RULE" not in content:
                raise ValueError("Worker context lost fixture rule")
            if (workspace / "sample.txt").read_text(encoding="utf-8") != "fixture\n":
                raise ValueError("Preparation modified fixture source")
            checks.extend(
                [
                    route + ":project-context",
                    route + ":workflow-reservation",
                    route + ":dispatch-preparation",
                ]
            )
    return dict(
        status="PASS",
        checks=checks,
        model_calls=0,
        scope="Disposable fixtures; not installed host or real project readiness",
    )


def main() -> int:
    argparse.ArgumentParser(description=__doc__).parse_args()
    try:
        result = run()
    except Exception as exc:
        print(json.dumps(dict(status="FAIL", error=str(exc)), ensure_ascii=False))
        return 1
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
