# Factory tools

Implementation lives in the importable `factory` package. Stable command
paths in tooling/bin/, gates/skills/ and skill scripts are thin entry points. Setup registers
the bundle with the venv; launchers load it without per-script path setup. The
Decompose graph entry point also supports the documented direct `python3` command;
the dry-run entry point reports missing dependencies even with Python site disabled.
Both retain their own path bootstrap. All tooling
tests live in tooling/tests/, with package suites in tooling/tests/factory/; fixture configuration is independent of consumer settings.

Use [Factory Meta Develop Tooling](../skills/factory-meta-develop-tooling/SKILL.md)
for changes to factory tooling. Its shared coding/testing/review contracts apply.

| Package | Responsibility |
| --- | --- |
| `tooling/factory/checks/` | Shared command and check declarations |
| `tooling/factory/tasks/` | Task and policy-selection declarations; canonical acceptance criteria parsing and validation |
| `tooling/factory/gates/` | Typed gate results and transition catalogue |
| `tooling/factory/decisions/` | Validated predicate, choice and score contracts |
| `tooling/factory/project/` | Profile validation, selection and portable policy snapshots |
| `tooling/factory/context/` | Context assembly without workflow transitions |
| `tooling/factory/runtime/` | Ledger, graph, acceptance, escalation and process execution |
| `tooling/factory/adapters/` | ACP transport |
| `tooling/factory/planning/`, `decompose/`, `review/`, `github/` | Process tooling |
| `tooling/factory/diagnostics/` | Safe preparation dry run |
| `tests/` | All suites and pinned, disposable configuration fixtures |

Project setup/editing/visualization share the existing project and gate tools.
Read [configuration verification](../skills/factory-project-configure/references/verification.md)
for profile validation, recipient previews, check selection and evidence limits.

## Python setup

Factory tools use the standard project venv `.factory/.venv/`. No activation,
global pip install, global PATH edit or temporary PYTHONPATH is needed. This is
only the factory's own Python environment, not a layout imposed on vendor tools.

1. Choose an installed Python **3.11+**. If absent, follow the official
   [Python installation instructions](https://www.python.org/downloads/) for the OS.
   On Linux ensure that interpreter has venv/ensurepip support using the distribution's
   instructions. Do not replace the system Python. A supported managed Python may be
   used if system installation is unavailable. Runtime installation must be within
   the user’s authorized setup scope; do not ask again when already authorized.
   The helper never installs an OS package or downloads Python.
2. From the project root, explicitly prepare the environment (may download packages):

   macOS/Linux: `python3 -E -s -B .factory/tooling/bootstrap.py setup`

   Windows: `py -3 -E -s -B .factory/tooling/bootstrap.py setup`

   These are bootstrap examples: substitute the verified Python executable when
   `python3`/`py -3` selects an older or unavailable interpreter. Setup creates venv,
   installs PyYAML, Pydantic v2 and their dependencies from the hash-locked requirements.txt, checks dependencies, and records readiness. Existing
   compatible venv is reused; a non-venv directory or active workflow blocks setup.
3. For subsequent factory Python commands use the launcher, except for the
   documented direct Decompose graph entry point described above:

   macOS/Linux: `sh .factory/tooling/bin/python.sh SCRIPT [ARGS]`

   Windows PowerShell/cmd: `.\.factory\tooling\bin\python.cmd SCRIPT [ARGS]`

   Replace SCRIPT with a script path; `-m unittest ...` and `-c ...` also work.
   Unix examples throughout factory instructions use the first launcher; on native
   Windows substitute the second launcher, preserving arguments and native shell quoting.
   Neither launcher searches PATH for Python or activates a shell environment.

Check from a fresh session: launcher `--check`, then launcher
`.factory/tooling/bin/dry_run.py`. Launchers preserve cwd and argument boundaries;
from elsewhere, use absolute launcher and script paths. They ignore inherited
PYTHONPATH/PYTHONHOME and user site-packages. No implicit network or installation on
run. Missing/stale environment fails with a setup hint; no fallback to system Python.

Ignore `.factory/.venv/` and `.factory/.venv.setup.lock` in Git and Graphify. The lock
exists only during setup; remove a stale lock only after checking no setup is running.
After requirements change, rerun setup. After moving checkout or replacing base
Python, stop active runs, preserve anything misplaced in the environment, and recreate
the disposable venv with a compatible Python. Never copy a venv between machines.
A failed setup is not readiness; fix the reported cause before retrying. No pip/venv
support, package download failure, or incompatible wheel is an explicit blocker.

## Development checks

For tooling development, run explicit setup with `--dev` using the selected Python:

```bash
python3 -E -s -B .factory/tooling/bootstrap.py setup --dev
sh .factory/tooling/bin/python.sh .factory/tooling/bin/check.py --report-dir /absolute/path/to/reports
```

On Windows use `py -3` for setup and `.\.factory\tooling\bin\python.cmd` for checks.
Setup installs the resolved, hash-locked `requirements-dev.txt`, including runtime
requirements. `requirements.in` declares runtime dependencies; `requirements-dev.in`
declares development dependencies. Normal checks never install packages or use the network.
A runtime-only installation needs only setup without `--dev`. Reusing a dev venv for
runtime setup does not remove its extra packages; runtime-only verification uses a fresh venv.

The default checker runs eight stages: Ruff lint, Ruff format check, mypy strict,
import-linter, YAML lint, YAML contracts, unittest with branch/subprocess coverage,
and the safe dry run. `pyproject.toml` and `imports.ini`
are explicit factory configuration; application configuration is not used.
Every owned Python source, including hidden paths, tests and project gate examples,
is checked. Third-party skill code, venvs, caches and generated output are outside scope.
Stable CLI wrappers with repeated basenames are type-checked separately, without exclusions.

Each stage is available through repeatable `--stage`: `lint`, `format`, `types`,
`imports`, `yaml-lint`, `yaml-contracts`, `tests`, `dry-run`.
`--stage audit` separately runs online pip-audit against
both resolved dependency sets. Run that when dependencies change and before delivery;
unavailable advisory data or a vulnerability gives a nonzero result.

Reports include exact commands, stage exit codes, Python environment and a digest
of the checked source/configuration. Keep reports outside `.factory/`; choose an explicit
`--report-dir` to retain logs, `result.json` and `coverage.json`. Without it, temporary
reports are removed after the command. A failed or blocked required stage makes the
aggregate result nonzero. Failed or blocked commands include a bounded diagnostic excerpt;
retained logs contain full output. Existing test reports are not reused as a current success.

Coverage includes unexecuted modules and verifies a branch executed only through the
real Unix/Windows launcher subprocess. No universal coverage percentage is imposed.
Tests use temporary workspaces and pinned fixtures, not the consumer's current
factory.yaml or project profile. Test discovery must find every expected suite.
A dry-run PASS demonstrates preparation, not live model or application readiness.

CI must invoke the same checker on Python 3.11 and the selected current supported
version (3.15), on Linux, macOS and Windows. The Lab workflow provides this matrix;
an installed consumer connects the same command to its own CI. Remote CI execution
and required branch protection depend on the repository host.

To update dependencies, resolve both `.in` files into their `.txt` lock files with
transitive versions and hashes (for example `uv pip compile --python-version 3.11
--universal --generate-hashes`). Then run explicit setup, the full checker, the audit,
and a fresh runtime-only verification. The resolver is a maintenance tool, not a
runtime requirement.

## YAML checks

```bash
sh .factory/tooling/bin/python.sh .factory/tooling/bin/check.py --stage yaml-lint --stage yaml-contracts
```

Both stages are part of the default offline checker after `setup --dev`.
Pinned yamllint uses `tooling/yamllint.yaml`: two-space indentation, indented lists,
duplicate keys rejected, explicit true/false booleans, consistent whitespace.
Key sorting, mandatory `---` and line-length limits are disabled. Files are not rewritten.

Discovery covers owned root YAML, tools, gates, project/examples/fixtures and
`skills/factory-*`, including hidden paths and both extensions. Vendor skills,
venvs, caches and run output are excluded. Factory/project validators check actual
settings and composed gate/decision files; definitions must be explicitly listed in
a checked profile's `gate_files`/`decision_files`. Provenance alone is not validation.
Unknown contracts fail. Only `skills/factory-*/agents/openai.{yaml,yml}` receives
the harness syntax-only exemption. Owned directory/YAML symlinks fail discovery;
fixture overlays preflight source/destination links and destination containment.
Pinned fixtures are materialized in a disposable installed layout before validation.
No configured project command or model is executed. Tests remain independent of
consumer configuration; YAML validation deliberately checks that configuration too.

The Lab checks `.github/workflows/factory-tooling.yml` separately with this yamllint
configuration and actionlint **1.7.12**. Install that pinned binary explicitly from
the upstream release to run locally, then use `actionlint -shellcheck= -pyflakes=
.github/workflows/factory-tooling.yml` from the Lab root. CI verifies the release
archive SHA-256 before execution. Optional embedded-script analyzers are disabled
so results do not depend on tools found on PATH. An installed factory needs neither
the Lab workflow nor actionlint. See [YAML authoring](../skills/factory-meta-develop-tooling/references/yaml.md).

## Dry run without a project or model calls

After Python setup, run through the project launcher:

```bash
sh .factory/tooling/bin/python.sh -B .factory/tooling/bin/dry_run.py
```

The script resolves its bundle from its own location, so an absolute script path
also works from another directory. It uses synthetic configuration and a project
profile in a temporary directory, never the consumer's `factory.yaml`, project
profile, credentials or existing workflow state. Runtime instructions and helper
dependencies are read from this bundle; disposable copies and state are removed
on success or failure.

Seven checks cover configuration loading, coordinator project context, workflow
initialization/reservation and worker dispatch preparation for native and ACP.
Native uses the actual context builder; ACP writes a disposable prompt and builds
command arguments without executing them. No model, ACP executable, network,
package installer, Git command or application check is invoked.

Output is JSON: `status: PASS` with completed checks, or `status: FAIL` with an
error and exit code 1. PASS proves fixture preparation only. It does not prove
host skill discovery, authentication, model availability, live transport, task
completion or compatibility of the user's configuration. Factory Install uses this driver for preparation checks.

The test suite runner `python -m factory.test_suite` includes
`tooling/tests/factory/diagnostics/test_dry_run.py`. These tests execute
the same driver, checking repeatability, unchanged bundle files, temporary
cleanup, no external processes/network, CLI execution from another directory,
and failure on a missing role or runtime dependency. No separate test runner is needed.

From the consumer project root, after setup:

```bash
sh .factory/tooling/bin/python.sh .factory/tooling/bin/workflow.py config
sh .factory/tooling/bin/python.sh .factory/tooling/bin/context.py --help
sh .factory/tooling/bin/python.sh .factory/tooling/bin/acpx_adapter.py --help
sh .factory/tooling/bin/python.sh -m factory.test_suite
```

Configuration requirements are defined in the
[project contract](../contracts/common/project-policy.md); command contracts —
in the [operation reference](../workflow/README.md).

## Shared command execution

`tooling/factory/checks/command.py` validates command declarations; `tooling/factory/runtime/check_process.py`
executes them with exclusive full logs, bounded waits and optional stdin.
Implement interprets normal exit codes, Decompose validates structured script
answers, and Code Review records command failures and execution blockers separately.
Review command JSON accepts `timeout_seconds` (default 600; range 1–86400).
A timeout preserves partial logs and blocks review completion. The process abstraction
owns stopping its configured scope and reaping after timeout or interruption. The shared
executor normally starts and stops a separate POSIX process group; on Windows it
stops the direct process only. Implement instead runs checks inside its dedicated
worker group and owns that lifecycle and its Windows Job Object. Native Windows behavior requires separate verification.
Authorization, receipts and input snapshots stay process-owned. ACP, GitHub and Review
use narrow runner interfaces for their own required operations and results.

`tooling/factory/runtime/assignment.py` projects Implement state for the shared context builder.
The builder receives ready assignment data and does not import transition logic.
Decompose `load_tasks` always returns `{tasks, envelopes, errors}`; callers keep
load errors alongside usable data. No flag-dependent return shapes are supported.

## Decision results

`validate_answer(definition, answer)` returns `{id, type, value, confidence,
source, reason}`; `validate_answers` returns these results by ID. Both reject invalid
or unresolved estimates. `preserve_obligations(definitions, before, after)` validates
both revisions with the same contract. Stored estimates retain their original shape.

## Standalone Review lifecycle

Use [review_run.py](../skills/factory-code-review/scripts/review_run.py) for init,
status, assignment, check, submit and finish. See the [run contract](../skills/factory-code-review/references/run-contract.md).
Review rejects composite execution during plan preparation, before execution; use
individual commands. No Implement graph or model runtime is embedded.


## Factory profile groups

factory.yaml groups profiles by canonical role ID. Common role/contract,
capabilities, enforcement and MCP belong to the group; variants specify only
model, adapter and optional escalation. default selects a variant in that group.
The loader emits a flat runtime profile map with independent copies.
Unknown fields are rejected. Active run configuration stays pinned.

## Local diagnostics

Workflow and ACP CLI calls write bounded, local diagnostic records in the workspace's
ignored `.factory/diagnostics/journal.sqlite3`. Records contain identifiers and outcomes, not
prompts, reports, command output or exception text. This journal is separate from workflow
state and is not acceptance evidence. A failed call prints its invocation ID; inspect it with:

```bash
sh .factory/tooling/bin/python.sh .factory/tooling/bin/workflow.py --workspace PROJECT diagnostics --invocation ID
```

Use `--run ID` or `--dispatch ID` to filter related records. Pages default to 30 records,
maximum 8 KiB; follow `next_cursor` with `--cursor N`. The most recent 500 records are
retained. SQLite transactions coordinate concurrent writers and recover interrupted writes.
Transition logging does not wait on a busy database while the workflow lock is held; a
lost diagnostic record is reported on stderr. Identifiers outside the diagnostic field
length and character limits are omitted.
Journal failures never block workflow operations and are reported on stderr. The journal
is intended for local troubleshooting, not automatic inclusion in agent context.
