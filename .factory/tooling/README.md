# Factory tools

Implementation lives in the importable `factory` package. Stable command
paths in tooling/bin/, gates/skills/ and skill scripts are thin entry points. Setup registers
the bundle with the venv; launchers load it without per-script path setup. The
Decompose graph entry point retains its own path bootstrap; the dry-run entry point
reports missing dependencies even with Python site disabled. All tooling tests live in tooling/tests/, with package suites in tooling/tests/factory/; fixture configuration is independent of consumer settings.

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
| `tooling/factory/runtime/workflow.py` | Public Ledger API, run lifecycle and coordination |
| `tooling/factory/runtime/transitions/` | Packet delivery, command receipts, report acceptance and graph revisions, each in its own module |
| `tooling/factory/database/port.py` | One database contract with sections for runs, verified history, packet receipts, Teacher jobs, lesson and case indexes, traces, export checkpoints and diagnostics. |
| `tooling/factory/database/sqlite/` | `SQLiteDatabaseBackend`, SQL schemas, queries and transaction boundaries. A terminal archive and its optional Teacher event commit together. |
| `tooling/factory/file_reader.py`, `secret_reader.py`, `environment.py` | File contents and binary streams, named secrets and environment settings. |
| `tooling/factory/runtime/run_journal.py` | Checkout lock, validated state reads and atomic state, event and evidence writes |
| `tooling/factory/adapters/` | ACP transport |
| `tooling/factory/planning/`, `decompose/`, `review/`, `github/` | Process tooling |
| `tooling/factory/diagnostics/` | Local diagnostic records, queries and safe preparation dry run |
| `tests/` | All suites and pinned, disposable configuration fixtures |

### Find the owner of a change

Start a workflow trace at [the CLI](factory/runtime/workflow_cli.py) or the public
[Ledger](factory/runtime/workflow.py). A state-changing operation enters
`runtime/transitions/` when it needs the journal lock. Its rules and data live
with the corresponding feature:

| Change | Implementation under `factory/` |
|---|---|
| Assign work, bind a session or spend a retry | `runtime/scheduling/` |
| Run a command or verify its receipt | `runtime/commands/`. The subprocess enters through `runtime/command_worker.py`. |
| Build or acknowledge a packet | `runtime/packets/` |
| Accept a report, resolve findings or request approval | `runtime/reports/` |
| Read archived reports and evidence | `runtime/history/`. Python consumers can use `factory.runtime.memory`. |
| Retrieve a lesson or deliver a Teacher job | `runtime/knowledge/`. The workflows are `runtime/lessons.py` and `runtime/teacher.py`. |
| Recover transport output or export telemetry | `runtime/transport/` owns streams and evidence. `runtime/observability/` owns usage and OTLP export. |
| Validate a plan or build tasks | `planning/` owns plan validation. `decompose/graph/` owns task relations, checks and rendering. `decompose/staging/` owns staged files and their manifest. |
| Run a review or interpret findings | `review/review_run.py` coordinates the run. `review/protocol/` owns records, evidence and verdict rules. |

Find feature tests under `tests/factory/<process>/`. For example, command execution
is covered in `tests/factory/runtime/commands/`; multi-step workflow tests start
in `tests/factory/runtime/test_workflow.py`.

Project setup/editing/visualization share the existing project and gate tools.
Read [configuration verification](../skills/factory-project-configure/references/verification.md)
for profile validation, recipient previews, check selection and evidence limits.

Implement uses accepted source and instruction snapshots throughout a run.
Prepare the [Implement workspace](../workflow/README.md#workspace-selection)
before taking the first snapshot.
Use `workflow.py read-instructions - PATH...` and `workflow.py read-project`
for active coordinator context. Candidate edits remain subject to verification
on current scope and command inputs. For authorized changes to the active
baseline, see [re-intake](../workflow/README.md#configuration-and-preparation).

### Workflow domain rules

A run owns session handles and shared reservations. A dispatch records one attempt
at a node, and [dispatch recovery](factory/runtime/scheduling/dispatch.py) checks whether an
uncertain attempt may resume. Reconciliation requires nonblank evidence. The Ledger coordinates the lock, read and save.

| Owner | Guarantee |
|---|---|
| [RunSessions](factory/runtime/scheduling/run_sessions.py) | Each physical handle belongs to one logical agent. An ACP creation request reserves the name for its current epoch. Explicit replacement closes that epoch even if the session was never bound. |
| [RetryBudget](factory/runtime/scheduling/escalation_policy.py) | Each task and retry cause use their configured allowance. The transition saves the counter and new state together. |
| [TestRetryRequest](factory/runtime/transitions/revisions.py) | Revision receives named test node, failed dispatch, diagnosis node and repair node. Existing four-item Python tuples are accepted. |
| [CheckExecution](factory/runtime/commands/execution.py) | A replay identifies the original request. Abandoning a running intent requires checking that no process owner was registered. |
| [PacketDelivery](factory/runtime/packets/delivery.py) | At most one served chunk awaits acknowledgement. Final confirmation records receipt of the complete packet. |
| [TeacherJob](factory/runtime/knowledge/teacher_models.py) | Waiting for the owner requires an open job and a question. Queue keys and stored JSON retain the existing representation. |

Planning compares two [PlanRevision](factory/planning/plan_revision.py) snapshots using the
headers validated by the [PlanMetadata adapter](factory/planning/plan_document.py). Both snapshots
must have consistent approval metadata. Approval may
change only the approval fields in the plan header. Identically named lines in examples
belong to the plan body. Decompose uses [TaskRelationGraph](factory/decompose/graph/relations.py)
to report cycles and check that a task closing an acceptance criterion depends on all
contributors. Only `depends_on` establishes that dependency.

### Storage and input adapters

The tooling exposes three I/O contracts: `DatabaseBackend`, `FileReader` and
`SecretReader`. Their default implementations are `SQLiteDatabaseBackend`, `LocalFileReader`
and `EnvironmentSecretReader`.

Select the active adapter with `current_database()` at the invocation boundary.
The workflow CLI builds its Ledger with the selected run, history, packet and Teacher
repositories. Both `next` and `status` use that Teacher queue for the finalizer
and pending jobs. When calling Ledger directly, pass the repositories to its
constructor or use the invocation defaults. A Ledger keeps its history repository
for report verification across packet delivery, corrections, revisions and completion.
The lessons CLI passes the selected index, search trace store, history and Teacher
queue to their consumers. Python callers can submit a decoded case reference to
`teacher.capture_case(root, reference, observation, history=history, jobs=jobs)`.
For example, `database.runs.save_progress(...)` writes the run and evidence, and
`database.teacher.pending(...)` reads queued jobs. A backend implements all sections
of `DatabaseBackend` and the read-only pre-installation check. Bind it around an
invocation with `use_database(backend)`. The SQLite adapter loads each section
on demand so bootstrap works before third-party dependencies are installed.

`file_reader.use_reader(...)` and `environment.use_environment(...)` select file contents
and environment variables for the same scope. Local path validation, directory
enumeration, writes and OS locks still operate on the checkout. Each child process
loads the installed configuration independently. A future backend must configure
the CLI, supervisor and bootstrap active-run check consistently, provide its own
migrations, and preserve the atomic writes and verified historical reads.
Run the [shared storage contract tests](tests/factory/runtime/test_run_repository_contract.py)
for each backend. Its `open_backend(root)` must return a fresh adapter to the same
isolated store on repeated calls for that root.

## Python setup

Factory tools use the standard project venv `.factory/.venv/`. No activation,
global pip install, global PATH edit or temporary PYTHONPATH is needed. This is
only the factory's own Python environment, not a layout imposed on vendor tools.

1. Choose an installed Python **3.14**. If absent, follow the official
   [Python installation instructions](https://www.python.org/downloads/) for the OS.
   On Linux ensure that interpreter has venv/ensurepip support using the distribution's
   instructions. Do not replace the system Python. An installed uv can provision a project-local managed interpreter: on Unix run
   `UV_PYTHON_INSTALL_DIR="$PWD/.factory/.python" uv python install --no-bin --no-registry 3.14`, then
   use `UV_PYTHON_INSTALL_DIR="$PWD/.factory/.python" uv python find --managed-python 3.14`
   to locate it. On Windows PowerShell set `$env:UV_PYTHON_INSTALL_DIR` to the
   absolute project `.factory/.python` directory and run the same uv commands.
   Exclude that directory from Git and indexing. Runtime installation must be within
   the user’s authorized setup scope; do not ask again when already authorized.
   The helper never installs an OS package or downloads Python.
2. From the project root, explicitly prepare the environment (may download packages):

   macOS/Linux: `python3.14 -E -s -B .factory/tooling/bootstrap.py setup`

   Windows: `py -3.14 -E -s -B .factory/tooling/bootstrap.py setup`

   These are bootstrap examples: substitute the verified Python executable when
   `python3.14`/`py -3.14` is unavailable or selects an unexpected interpreter. Setup creates venv,
   installs PyYAML, Pydantic v2, OpenTelemetry protobuf message types and their dependencies from the hash-locked requirements.txt, checks dependencies, and records readiness. Existing
   compatible venv is reused; a wrong-minor venv blocks setup before package changes. Stop active runs, preserve any data in it, then remove and recreate the disposable `.factory/.venv` using Python 3.14. A non-venv directory or active workflow also blocks setup.
3. For subsequent factory Python commands use the launcher:

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
python3.14 -E -s -B .factory/tooling/bootstrap.py setup --dev
sh .factory/tooling/bin/python.sh .factory/tooling/bin/check.py --report-dir /absolute/path/to/reports
```

On Windows use `py -3.14` for setup and `.\.factory\tooling\bin\python.cmd` for checks.
Setup installs the resolved, hash-locked `requirements-dev.txt`, including runtime
requirements. `requirements.in` declares runtime dependencies; `requirements-dev.in`
declares development dependencies. Normal checks never install packages or use the network.
A runtime-only installation needs only setup without `--dev`. Reusing a dev venv for
runtime setup does not remove its extra packages; runtime-only verification uses a fresh venv.

The default checker runs eight stages: Ruff lint, Ruff format check, mypy strict,
import-linter, YAML lint, YAML contracts, unittest with branch/subprocess coverage,
and the safe dry run. `pyproject.toml` and `imports.ini`
are explicit factory configuration; application configuration is not used.
Ruff lint preview renders selected diagnostics by rule name (for example
`undefined-name` for F821). Every owned Python source, including hidden paths, tests and project gate examples,
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
The unittest stage checks relative Markdown links and heading/explicit anchors in factory
skills, contracts, project rules and this README, including containment within the
shipped src root. Markdown headings and HTML id/name anchors are checked; fragment
targets must be Markdown or HTML. It runs in unittest so the existing test stage owns
its regression fixtures and no additional checker entry point is required.
External URLs are skipped. Selected documented dry-run command and linked example profile
are exercised through the launcher and profile validator. These checks use the pinned
markdown-it-py parser and run offline.

Tests use temporary workspaces and pinned fixtures, not the consumer's current
factory.yaml or project profile. Test discovery must find every expected suite.
A dry-run PASS demonstrates preparation, not live model or application readiness.

CI must invoke the same checker on Python 3.14, on Linux, macOS and Windows. The Lab workflow provides this matrix;
an installed consumer connects the same command to its own CI. Remote CI execution
and required branch protection depend on the repository host.

To update dependencies, resolve both `.in` files into their `.txt` lock files with
transitive versions and hashes (for example `uv pip compile --python-version 3.14
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

For saved run evidence, use `workflow.py list-artifacts RUN_ID` and `workflow.py export-artifact RUN_ID LOGICAL_PATH NEW_FILE`. The workflow database holds original bytes, including frozen packets, reports and binary attachments. After cleanup a stopped database can be copied independently of runtime scratch files.

For Implement report handoffs, `workflow.py prepare-report` captures current file
hashes. An intermediate `WRITES_READY` node can declare exhaustive `handoff_inputs`
to narrow that snapshot to its owned task files and declared inputs. Omission uses
the full task scope; final verification retains full-scope freshness checks. See
[command reservation and stage results](../workflow/README.md#command-reservation-and-stage-results).

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

`tooling/factory/checks/command.py` validates command declarations; `tooling/factory/runtime/commands/process.py`
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

`tooling/factory/runtime/scheduling/assignment.py` projects Implement state for the shared context builder.
Decompose source-lock preparation reads the approved plan and selected profile;
see the [generation contract](../skills/factory-decompose/references/generation-contract.md).
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

factory.yaml groups profiles by canonical role ID. Role and contract paths default to
`roles/<group>.md` and `contracts/<group>.md`; explicit paths must match. Common
capabilities, enforcement and MCP belong to the group; variants specify only
model, adapter and optional escalation. default selects a variant in that group.
The loader emits a flat runtime profile map with independent copies.
Unknown fields are rejected. Active run configuration stays pinned.

## Local diagnostics

Workflow, ACP, lessons/Teacher, context, project and OTLP export commands write bounded local records in the workspace's
ignored `.factory/diagnostics/journal.sqlite3`. Records contain identifiers and outcomes, not
prompts, reports, command output or exception text. This journal is separate from workflow
state and is not acceptance evidence. A failed call prints its invocation ID; inspect it with:

```bash
sh .factory/tooling/bin/python.sh .factory/tooling/bin/workflow.py --workspace PROJECT diagnostics --invocation ID
```

Use `--run ID` or `--dispatch ID` to filter related records. Use
`--operation lessons.search_lessons` or `--operation lessons.publish` to find recent invocations.
A `database_failed` record identifies the workflow store or lesson index and a bounded error code.
A successful search can also report `lesson_trace_unavailable` when saving its evidence failed. Pages default to 30 records,
maximum 8 KiB; follow `next_cursor` with `--cursor N`. The most recent 5,000 records are
retained. SQLite transactions coordinate concurrent writers and recover interrupted writes.
Transition logging does not wait on a busy database while the workflow lock is held; a
lost diagnostic record is reported on stderr. Identifiers outside the diagnostic field
length and character limits are omitted.
Journal failures never block workflow operations and are reported on stderr. The journal
is intended for local troubleshooting, not automatic inclusion in agent context.

### Read the journal with jq or a local Collector

```sh
export FACTORY_JOURNAL_SNAPSHOT="$(mktemp -d)/journal.otlp.jsonl"
sh .factory/tooling/bin/python.sh .factory/tooling/bin/telemetry.py journal > "$FACTORY_JOURNAL_SNAPSHOT"
jq -c '.resourceLogs[].scopeLogs[].logRecords[] | select(.severityNumber >= 17)' "$FACTORY_JOURNAL_SNAPSHOT"
```

Each line is one OTLP JSON logs request. The command reads the retained records
in insertion order. It works offline, including in development. Records tied to a run
carry its trace ID and the span ID of the dispatch or run. An empty journal produces
an empty file. Each invocation creates a full snapshot, so replaying overlapping snapshots
into the same destination can repeat records.

To inspect one completed snapshot with `otelcol-contrib`, save the following as
`collector.yaml` and run `otelcol-contrib --config=collector.yaml` in the same shell.
Stop the Collector after it displays the records.

```yaml
receivers:
  otlp_json_file:
    include:
      - ${env:FACTORY_JOURNAL_SNAPSHOT}
    start_at: beginning
exporters:
  debug:
    verbosity: detailed
service:
  telemetry:
    metrics:
      level: none
  pipelines:
    logs:
      receivers: [otlp_json_file]
      exporters: [debug]
```

## Project memory

Use `bin/lessons.py search_lessons "query"` through the Python launcher for
read-only retrieval from the workspace's Git-owned lesson catalog. The
checkout-local FTS5 index is disposable. Lookup hashes current Markdown files and updates only added, changed or removed cards in one transaction. Each hit has `source_type: lesson`.
Add `--include-history` to search accepted terminal work even when lessons match.
The command returns up to three lessons and three `source_type: case` hits.
Case search reads terminal archives for the current workspace and branch or
detached commit and searches current accepted reports. A run without a recorded
checkout at acceptance is omitted. Failed, superseded and unaccepted attempts
stay available in their original history. A case identifies the run, task, node,
dispatch, attempt ordinal and exact report reference with SHA-256. Copy
`report_ref` to `REF.json` and use `workflow.py read-report REF.json` to verify
and read it. Unreadable archives or selected reports are skipped and reported on
stderr. Searching history creates no lesson or Teacher event. To report a verified
reuse, include `applied_cases` in the current PASS report. Each entry has the
exact historical `report_ref` and a nonblank `result` describing what was
verified here. Finish validates the reference. Task acceptance retains those
entries with the task's stable incident ID and references to failed and successful
attempts. After `workflow.py archive completed SUMMARY` the queue exposes one
Teacher event for the run. In `packet EVENT`, each `incidents` key identifies
the task or retrospective finding to cite with `publish EVENT CARD --incident ID`.
For a retrospective belonging to the active run, record its evidence with
`workflow.py record-retro RUN_ID INCIDENT SOURCE OBSERVATION` before archival.
A retro first offers the owner specific findings. Use `lessons.py retro INCIDENT SOURCE OBSERVATION --confirmed` only for selected findings; attach a note to an active run only if the owner chooses its final review. Cancelled runs retain their evidence
in the archive. Both `workflow.py next` and `lessons.py pending` can recover
delivery after successful archival. Cleanup also ensures delivery. New Git events belong to their original
branch or detached commit. Completion moves their records out of the active queue.
Manual requests use [factory-lessons](../skills/factory-lessons/SKILL.md). Automatic events go directly to Teacher dispatch. Use `route EVENT` to recover the operation and `waiting` for owner questions.

Before starting a Teacher worker the coordinator runs `bin/lessons.py teacher-launch` through the launcher. It resolves the default Teacher variant, exact model ID, effort and adapter from the checkout. Follow the [dispatch procedure](../skills/factory-lessons/references/dispatch.md).

A user deletion pins the target at intake. A changed target leaves the request
pending. Resolve it on a new owner message as described in the refresh protocol.
User edits of existing cards record message references in `edits`. Use
`user --new-observation` when the owner contributes incident evidence.

### Local workflow observations

Read an active run or its archive, including after cleanup:

```sh
sh .factory/tooling/bin/python.sh .factory/tooling/bin/telemetry.py show --run RUN_ID
```

Add `--dispatch DISPATCH_ID` to see the run, that attempt, its observations and any
Teacher job linked to it. Each JSON observation carries hex trace and span IDs,
parent, links, timestamps in Unix nanoseconds, attributes, events and local report
references (dispatch, path and SHA-256). The run comes first. Remaining observations
are ordered by start time. An unknown time is `null`. A match records retrieval,
an application comes from the worker report, and a confirmed Teacher change records
the actual card revision. Read-only access works in development with export disabled.

### OTLP telemetry bridge

Configure the receiver in the exporting checkout's `.factory/factory.yaml` before a production run:

```yaml
telemetry:
  enabled: false
  endpoint: http://localhost:4318/v1/traces
  headers:
    Authorization: "Bearer ${env:OTLP_TOKEN}"

logs:
  enabled: false
  endpoint: http://localhost:4318/v1/logs
  headers:
    Authorization: "Bearer ${env:OTLP_LOGS_TOKEN}"
```

`telemetry.endpoint` and `logs.endpoint` are the complete trace and log URLs.
Set `telemetry.enabled: true` for traces and `logs.enabled: true` for external diagnostic logs.
Both default to false. Local diagnostics still go to SQLite.
Configure headers per signal. To use the same credential, reference the same environment
variable in both templates. For a Logfire write token, use `Authorization: "${env:LOGFIRE_WRITE_TOKEN}"`. Use `headers: {}` for a Collector
without authentication. For an API key, use `x-api-key: "${env:MY_API_KEY}"`.
Copy [.env.example](../.env.example) to `.factory/.env` and set the referenced value there,
or supply it in the exporter's process environment. Process values take precedence, including
empty values. Keep credentials out of YAML because workflow runs preserve configuration snapshots.

```sh
sh .factory/tooling/bin/python.sh .factory/tooling/bin/telemetry.py --follow
```

The bridge sends binary OTLP/HTTP Protobuf to each configured receiver directly. Without `--follow`
it drains the current backlog once. `--env-file PATH` selects a different fallback file.
Files use literal UTF-8 `NAME=VALUE` assignments. Matching outer quotes are stripped.
In header templates, each `${env:NAME}` requests one value from `SecretReader` when preparing
a batch. Values are inserted verbatim. A missing, blank or invalid credential stops the batch
before HTTP or checkpoint advancement. Follow mode checks YAML at each poll. Restart the bridge to reload its environment file.
`OTEL_SERVICE_NAME` can still override the default service name `overfactory`.

A missing section or switch leaves its signal disabled. A `setup --dev` installation and
checker subprocesses suppress collection and delivery regardless of receiver settings.
For other test commands, set `OTEL_SDK_DISABLED=true` in the process environment.
Local workflow history and Teacher evidence continue to be recorded. The bridge rechecks
the switch before each batch. Previously eligible batches resume when enabled.
Version 1 backlog and runs or Teacher jobs created or updated while disabled stay local.
Run one bridge per workspace and receiver. Use a different `--consumer` for another
project at the same endpoint. A credential rotation within the project keeps its position.
The SQLite feed selects committed sources eligible for export. After the transaction closes,
the bridge encodes the same observations used by the local timeline. Report paths and hashes stay local. Delivery resumes at the first unacknowledged batch.
The log receiver reads eligible events from the 5,000-row diagnostic journal, up to 128 per
request. Log records with a run or dispatch carry the corresponding trace and span IDs.
Each signal has its own checkpoint per endpoint and consumer. A failed request leaves its
batch pending. A crash after remote receipt and before checkpointing can repeat that batch.
If retention evicted pending logs, the bridge reports the count on stderr and resumes at the
first retained record. Older journal schemas, diagnostics emitted while log export was disabled,
and the bridge's own diagnostics stay local.
In follow mode, transient failures use exponential backoff with jitter. A valid
HTTP `Retry-After` (seconds or HTTP date) sets the minimum wait.
Search observations are available after each lookup, run/attempt/ACPX spans after
archive, and Teacher decisions after completion. Attempt spans carry the role and
available harness recorded at reservation. Older attempts use matching archived ACPX
assignments when available. Request tokens and session cost keep their original scope. Cleanup preserves these sources.
In instrumentation scope `overfactory` version `2`, each archived ACPX invocation and
each parent check receipt is a child span of its dispatch. Prompt spans summarize the
last observed tool kind and status per call from archived ACP notifications. A partial
stream is marked. Only allowlisted categories and counts leave the workspace.
Cache usage uses `gen_ai.usage.cache_read.input_tokens` and
`gen_ai.usage.cache_creation.input_tokens`. ACPX usage is scoped to a prompt request.
Span links connect assignments to sessions and lesson applications to observed searches.
The optional `lessons.py telemetry` command reads local evidence as JSON.

For an accepted incident, `bin/lessons.py feedback EVENT INCIDENT_ID` returns the
attributed lookup wording, candidate revisions and whether the checkout catalog
still matches the lookup. Only local Teacher feedback retains short (up to 512
characters), validated assignment queries. Telemetry and OTLP omit the wording.
