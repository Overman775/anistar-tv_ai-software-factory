# Workflow helpers

The parent agent is the scheduler. These Python helpers load YAML, validate a
proposed graph, reserve local resources, preserve evidence/counters and invoke
ACP and declared required check commands. They are not a daemon, sandbox, semantic verifier or cross-machine queue.
Use Python 3.11+ and `pip install -r .factory/tools/requirements.txt` in a venv.
Run commands from the consumer checkout. `--workspace` can select another
checkout; `--config` can select another factory YAML. Do not run application work
inside the Lab snapshot, which has no AniStar source or Flutter toolchain.

## Tool layout

Executable helpers and tests live in [`../tools/`](../tools/README.md).
This directory contains process instructions and the operation reference.

## Configuration and preparation

```bash
sh .factory/tools/python.sh .factory/tools/workflow.py config > "$CONFIG_SNAPSHOT"
sh .factory/tools/python.sh .factory/tools/workflow.py read-instructions "$CONFIG_SNAPSHOT" roles/orchestrator.md
sh .factory/tools/python.sh .factory/tools/workflow.py validate workflow.json
sh .factory/tools/python.sh .factory/tools/workflow.py init workflow.json --config-pin "$CONFIG_SNAPSHOT"
```

For Implement, save the snapshot in OS temporary storage and use verified
`read-instructions` content for factory instructions. See the Implement entry
for the complete reading sequence. Bare `init` remains a low-level compatibility
interface; it does not verify what the coordinator read before initialization.

Human edits `.factory/factory.yaml`; the orchestrator writes the graph. Profile
paths are relative to YAML. `models.*.id: null` explicitly permits the backend's
configured default; record its real identity before dispatch. A missing exact
model never silently falls back. Effort is passed only through a confirmed
adapter mapping. The shipped native model is a configurable choice, not proof
of availability on another account. Native defaults to Codex; changing native
harness/profile requires the matching host adapter.

The file `.factory/tools/example.workflow.json` is a runnable structural example
for a small low-risk label correction. Replace source/outcome/scope with the real
request, and replace the explicit REPLACE_WITH_ACTUAL_TEST command placeholder.
It does not authorize edits or supply actual PASS evidence.

Graph:

- `sources`: stable ID → `text` for a direct instruction, or project-relative
  `path`; init records raw content_hash plus normalized semantic hash and copies a snapshot. Approved-plan sources
  additionally require the existing plan validator/approval tuple at intake. Every source
  carries `acceptance`; bounded runs may declare `selected_acceptance_ids`.
- `tasks`: stable ID → `slice`, `source`, `outcome`, `reason`, `risk`
  (`low|moderate|high`), `kind` (`feature|task|refactor|fix|docs|integration`),
  `independent_review`, exact changed-file `scope`, task `depends_on`,
  `acceptance_ids` and `required_checks` (ID/category/kind/criteria/method plus `execution` for commands).
- `agents`: logical ID → configured `role`, `profile`. One role may have several
  instances. The canonical role path determines eligible profiles.
- `nodes`: `id`, `task`, `stage` (`explore|work|docs|verify|review|accept`), `agent`
  (null only for accept), `depends_on`, `owns` (relative paths/subtrees),
  `resources` and optional concrete `read` document paths.

All task work must reach exactly one accept node. Authoritative verify follows
all writers. Independent review follows verification and has a different agent.
High risk uses separate production and test authors. Dependencies across tasks
include predecessor acceptance. A batch of several tasks needs one integration
task depending on all others with union scope. Its verification checks the actual
combined tree; local acceptance alone does not finish the batch.

Scope must include all task changes including tests, generated files and docs.
The orchestrator compares it with real git diff/untracked changes, separating
pre-existing user changes. A validator cannot infer missing semantic scope or
whether a claimed command was actually run; the parent verifies raw evidence.
Role ownership and mandatory project command choice are also semantic checks.

## Native/ACP dispatch and results

```bash
sh .factory/tools/python.sh .factory/tools/workflow.py claim write-label
# Parent inspects actual host capacity and uses selected adapter to start/continue.
sh .factory/tools/python.sh .factory/tools/workflow.py bind write-label ACTUAL_HANDLE ACTUAL_MODEL
sh .factory/tools/python.sh .factory/tools/workflow.py finish write-label /path/to/result.json
```

Claim is atomic and creates `dispatch_id` before external side effects. It blocks
on dependencies, pool capacity, overlapping owners, shared resources or active
writers during verification. All in-flight/unknown requests occupy a slot.
Host open-thread limits and provider quotas are additional checks by the parent.
Native dispatch cannot be called by a shell helper; the parent uses exposed tools.

The worker result envelope and stage boundaries are defined in
[implement-result](../contracts/common/implement-result.md); reserved checks and
receipts in [check-execution](../contracts/common/check-execution.md).
The parent validates those interfaces before acceptance. Native delivers the full
packet inline or by the file route below; ACP persists it in its prompt.

```bash
sh .factory/tools/python.sh .factory/tools/workflow.py accept accept-label
sh .factory/tools/python.sh .factory/tools/workflow.py archive completed "Brief outcome"
# Capture required packet and recipient-read evidence before cleanup.
sh .factory/tools/python.sh .factory/tools/workflow.py clean
```

Archive verifies all required nodes and final evidence, then atomically saves
`.factory/memory/history/<run-id>/run.json`. After all workers stop and required
packet/read evidence is captured, the coordinator calls `clean` for the whole
completed/cancelled run. It removes the manifest and all exact registered helper
artifacts, including current and retired native packets. Do not remove individual
packets early; downstream tasks may need them. Unknown files and history remain;
active, blocked and unknown work is not cleaned.

## Repair, revision and recovery

```bash
sh .factory/tools/python.sh .factory/tools/workflow.py unknown write-label "Lost transport outcome"
# Reconcile actual runtime/files first; evidence below must be real.
sh .factory/tools/python.sh .factory/tools/workflow.py retry write-label recovery "Reason" "Proof old writer stopped"
sh .factory/tools/python.sh .factory/tools/workflow.py revise /path/to/revised-graph.json "Reason for technical change"
sh .factory/tools/python.sh .factory/tools/workflow.py replace-session author "Reason" "Proof old session stopped" "Handoff summary"
```

Retry invalidates downstream nodes and retains old results in events. Stage is
`static|tests|review|docs|recovery`; counters key stable task+stage. A correction
caused by review increments review, even when the corrected node is a work node.
Revisions keep stable task/source/node identities and locked product semantics.
They may extend verification file scope, strengthen risk/review, and reassign
steps after quiescing the run. Affected completed evidence is invalidated and
retained in events. Failed nodes stay blocked until a budgeted retry. Outcome or
source changes use `reintake GRAPH REASON AUTHORIZATION_EVIDENCE`; it relocks and
revalidates sources without resetting counters. Explicit selected plan scope is
part of source identity. The parent must establish real authorization first.
Do not reset budgets by moving the same failure into another stage/run.

A stale workflow.lock is not automatically stolen. Confirm its process stopped
and no ledger write is in progress before deleting that exact lock. Unknown
transport cannot be retried without terminal evidence. A successful cancellation
command is not proof of no later writes. Replace-session increments a logical
epoch, preserves history/counters and requires handoff; new conversation starts
without memory. Reviewers never inherit an author's session.

## Sequence view

Render with `workflow.py diagram`; the projection uses unique logical-agent
lifelines and dispatch/dependency order. It is a human view, never an alternative
source of statuses. The configured [router](router.md) selects roles, team composition
and model profiles; `factory.yaml` supplies the available options. See `.factory/workflow/orchestration.md` for interpretation and loops.

## ACP

Use [ACP adapter](../adapters/acpx.md). Helpers keep registry setup explicit,
pass argv without shell interpolation, materialize profile instructions, journal
create/prompt before transport and leave outcome interpretation to the parent.
Configuration/fixture checks do not establish live Codex/ZCode behavior.

For recovered output use `resolve NODE running EVIDENCE`, then validate/finish
the original dispatch without a repeat. A confirmed terminal failure/cancellation
may resolve to blocked. Only an unbound, unsent creation can resolve to reserved.
For a failed unbound ACP creation, reconcile it to blocked, replace the session
epoch with terminal proof/handoff, then take the single recovery retry. Never
reuse a retired physical handle, even for the same logical agent.

## Command reservation and stage results

A writer with no applicable command gate and no project-checks resource edits only and returns
`stage_result: WRITES_READY`, outcome PASS for that edit stage, empty command
evidence. This is not a passed verification or overall IMPLEMENTED result.
Continue the logical agent in a later verify/command node holding project-checks,
or reserve that resource for the entire writer when codegen cannot be separated.
All reported static/tests/build/codegen commands require the reservation. The
parent prohibits unreported commands too. Docs-only verification can belong to
DocWriter, with concrete link/example commands and justified tests N/A.

Terminal ledgers/history are immutable: retries, revisions and transport writes
require an active run. Inspect terminal state with show; after archival inspect
ACP through its read-only CLI if necessary without updating the closed ledger.
Relative paths use canonical spelling, no traversal/symlinks/hardlinks. Ownership
comparison is conservatively case-insensitive with Unicode normalization on all
platforms to avoid aliases on macOS/Windows.

## Externally approved plans

An external plan need not use Planning's template. Keep it as `kind:
approved_plan`, with a real relative `path` and explicit `selected_scope`.
Set `approval_evidence: explicit_external_hash_approval` and include:

```json
"external_approval": {
  "state": "approved",
  "source_path": "external-plan.md",
  "content_sha256": "SHA-256 of the exact approved file bytes",
  "selected_scope": "the exact selected_scope from the source",
  "approved_by": "user",
  "evidence_ref": "reference to the actual approval message/artifact"
}
```

This is a record of existing authorization, not a way to create it. The parent
must inspect the actual approval and confirm plan sufficiency/scope. The helper
validates required provenance fields and exact byte/path/scope binding; it cannot
authenticate an arbitrary message reference. Changed content needs real renewed
approval before reintake; passing generic continuation does not refresh it.
Without this explicit route the existing canonical validator is used unchanged.
Canonical plan paths/identifying frontmatter cannot use the external route.

## Initial profile selection

For a profile group with `initial_profile_decision`, each assigned node carries
`profile_selection: {task_id, node_id, decision_id, answer}`. `answer` is the
complete Choice estimate in the Decisions contract, stored as JSON in the workflow
ledger and archived history. IDs match the graph node and task. The chosen profile
must match its agent. Configurations without this optional group field retain their
previous behavior. Invalid, tied, unknown and `no-eligible-profile` answers block
assignment. `workflow.py validate` checks graph structure only; `init` additionally validates initial profile selections. Choices are coordinator judgments; validation cannot prove their reasons.

Example node field (JSON, for a Developer group with these four choices):

```json
"profile_selection": {
  "task_id": "T1",
  "node_id": "write-label",
  "decision_id": "initial-developer-profile",
  "answer": {
    "choice": "junior-developer",
    "probabilities": {"junior-developer": 0.7, "middle-developer": 0.1, "senior-developer": 0.1, "no-eligible-profile": 0.1},
    "confidence": 0.6,
    "source": "agent:coordinator; choice confidence=(max(p)-1/n)/(1-1/n)",
    "reason": "Bounded local change, known behavior and reliable checks."
  }
}
```

Revise preserves prior graphs in history. A different initial profile before any
reservation requires a new agent and answer; after work starts, only the existing
correction transition may change it. Corrections retain the initial answer and record
exact reassigned nodes. Re-intake saves the prior graph and policy, preserves node
task/stage identities and cannot undo correction budgets or retired profiles. Worker
packets omit the coordinator-only selection; other packet integrity checks remain.

## YAML: named profiles and adapters

`factory.yaml` is the active configuration without comments.
`factory.example.yaml` is a separate annotated example with help beside sections
and fields; it is not loaded automatically. Maintain the example when the schema
changes, but do not overwrite user settings from it.
A profile declares adapter, role (path under `.factory/roles/`), required contract, model, capabilities,
MCP allowlist and enforcement. An adapter declares coordinator instructions, worker_instructions, harness, runner
and (for ACP) connection. The loader validates references and freezes adapter
instruction hashes too. Runner/harness/connection on profiles are rejected to
avoid two competing sources. Configuration, graph and run state have no schema
version field; graph revisions and frozen file hashes track actual changes.
There is no repeated `roles` list. `roles/<role-id>.md` and matching contract
define specialty; `profiles.<role>.default` selects its normal profile. Developer and
TestWriter have junior/middle/senior profiles sharing one procedure and contract.
The annotated example additionally shows ZCode/GLM and Pi/DeepSeek; verify
backend IDs, credentials and required tools before selecting them.

After `claim NODE`, `workflow.py packet NODE` returns the full native packet. It
uses `context.py` to return role/contract, worker adapter, shared assignment,
stage-specific rules, project documents, locked source, dependency results and
review findings, task-scoped correction/replacement history, assignment IDs,
model and capabilities for a generic agent. Only a worker-facing projection of
the profile is included; routing/escalation and transport policy stay with the parent.
Each `instructions` entry records path/hash/reason/audience alongside its content.
Router, orchestration, coordinator checkpoint and this full README stay with the parent.
For native file delivery, run `workflow.py prepare-packet NODE` after claim and
send the returned bootstrap (including `read_command`, identity, role and owned
paths) to a worker sharing this canonical workspace. Run the bootstrap command in
its named shell (POSIX shell or Windows PowerShell). Spawn and bind its actual
handle/model without waiting for work. The worker executes the command once per
chunk, replacing `--chunk 1` with each returned `next`; it reads all chunks in order
and waits for running bind before writes or assigned commands. Each chunk is at most
12,000 UTF-8 bytes of packet content, without splitting a character. Calls recheck
identity, config, source and the complete file hash. Preparation is idempotent only
for the registered unchanged file; conflicting files block. `ready_for_work` on the
last chunk assumes all preceding chunks were read; it is not a delivery receipt.
Record actual recipient reads and preserve the packet and output before cleanup when
delivery evidence is needed. The file and hash alone do not prove recipient reading.
Inline full-packet delivery remains available. These helpers do not spawn; ACP prepare
similarly includes adapter and profile.
No `.codex/agents/`, `.claude/agents/` or registration files are generated.

All current profiles use `enforcement: instructions`. These are agent rules;
they do not filter inherited tools or stop shell writes technically. `required`
blocks in the current generic adapters until a verified enforcement mapping is
implemented. False edit/commands is additionally checked against graph ownership
and project-checks reservations; this still is not an OS sandbox.

Integration review retries use the batch work types: two if at least one task is
`feature`, otherwise one. The initial attempt is separate; the counter remains
bound to the integration task, including for mixed batches.

## Acceptance data (required for new runs)

Read [acceptance-data](../skills/factory-implement/references/acceptance-data.md) for the graph schema;
[shared acceptance](../gates/common/verification-rules.md) defines the three independent check groups.
Sources carry `acceptance` (AC ID, applies_to, requirement, verification); tasks
carry `acceptance_ids` and `required_checks`. Both examples include these fields.
`category: acceptance` checks requirements; `category: project` preserves the
applicable project gates even with an empty criteria list. Additional checks use
`category: additional` in results and need no graph edit. Failed additional
checks need explicit diagnosis/resolution; open blocking findings forbid PASS.

The graph gate checks coverage, finish checks mapped results, accept rechecks
required evidence and freshness. Integration must recheck all selected source ACs;
other sources use qualified `source-id:AC-01` references. Both native and ACP
receive the shared contract and integration source definitions. Existing command
kinds and high-risk tests remain required; observation checks do not replace them.

`revise` can add required checks, preserving existing IDs/methods/criteria and
invalidating verification; it cannot remove checks or source criteria. Source
changes use the existing explicit re-intake route. Legacy artifacts lacking
acceptance fields are not automatically migrated or marked covered. The helper
validates declared evidence; required commands must now use the runner below.

## Required command runner

Before init, assign each required command an `execution` object:

```json
{"argv": ["flutter", "test", "test/preference_test.dart"], "cwd": ".",
 "timeout_seconds": 600, "inputs": ["pubspec.yaml", "pubspec.lock", "test/preference_test.dart"]}
```

Use actual project command definitions. `inputs` adds exact files to task scope
for before/after and acceptance snapshots; include wrappers/config/test inputs
whose changes invalidate the result. The runner does not discover all dependencies.
No shell expansion, implicit environment overrides or detached services. The command
must wait for its checks and return their real exit code. A wrapper that swallows
failures or selects zero tests still needs semantic review.

After claim/bind of a node with `project-checks`, run:

```bash
sh .factory/tools/python.sh .factory/tools/workflow.py run-check verify-label behavior
```

The coordinator or the bound role may call this helper; it does not call an LLM
or require an additional model turn just to execute a command. Normal node/session
identity remains in the ledger. The JSON `result` is the check record to copy
unchanged into `checks` in the role report. Read `result.result`: CLI `ok: true`
means the execution record was saved, not that the check passed. Missing program,
timeout or interruption is BLOCKED, a nonzero exit is FAIL. No receipt means NOT_RUN,
not PASS. Required checks cannot be excused via report `not_applicable`; applicability
must be resolved at intake. Observations retain their separate evidence contract.

Records live in state `executions`, logs in
`.factory/memory/history/<run-id>/checks/<execution-id>.log`, even before archival.
Each receipt binds run, dispatch, source, declared command, checked files and output
hash. The latest attempt of the check on that dispatch supersedes previous ones.
Verify, accept and completed archival recheck required receipts. Repeated command
execution is explicit, never an automatic failure retry; diagnose failures and use
existing node retry budgets when correcting/recovering work.

The minimal runner is synchronous and holds the ledger lock for the whole command.
Other state mutations wait operationally: they return `Ledger locked` and must be
retried after completion. `show` and reading the log remain possible. Keep the
host's command session and wait on it; do not start a duplicate command because a
host tool yielded. The runner records its PID and child PID. On timeout/keyboard
interrupt it kills the POSIX process group (on other platforms, only the direct
child); it does not provide a portable process supervisor. Use foreground commands
that do not detach children; non-POSIX descendant termination needs host verification.

If the runner is forcibly killed, a lock/RUNNING record may remain. Confirm the
runner and descendants stopped before removing a stale ledger lock or resolving
the node. Use existing unknown/resolve/retry recovery with terminal evidence;
never change RUNNING to PASS or reuse the old receipt. A fresh dispatch can run
a new check after that recovery. There is no automatic restart or cross-host recovery.

The local ledger/log are not a security boundary against a process with write
access. Only declared input files are checked; external services, environment
changes, transient changes restored between snapshots and dishonest wrapper exit
codes are not proven. Environment metadata stores platform/Python/executable path,
not a full environment dump or reproducible toolchain. Live Flutter/native/ACP
integration must be checked in the consumer project. Existing active ledgers must
finish with their matching runtime or be explicitly reconciled; no silent migration.


## Judge finding history

`review_findings[task_id][REV-ID]` stores status and transition history separately
from replaceable node reports. Native/ACP packets include current task findings
without full history. Use [the shared contract](../contracts/common/review-findings.md)
for report fields and transitions. Retry, session change, revise and reintake keep
this registry; acceptance/completed archive enforce current blocking closures.
Existing active ledgers are not silently migrated to the new runtime.

## Context outside Implement

Planning, Decompose and standalone Code Review keep their own source gates,
staging, approvals and result formats. Their coordinators prepare a JSON assignment
with `source`, exact input/output paths, allowed writes and mandatory `read` paths:

```bash
sh .factory/tools/python.sh .factory/tools/context.py --process planning --role architect --profile architect assignment.json
```

Use the process/role/profile actually selected by the owning skill. The CLI
assembles a complete packet; it does not approve the source, create an Implement
ledger, reserve capacity or spawn a worker. The coordinator checks those conditions
through its own process and the selected parent adapter before delivery.

## Correct a failed assignment or hand off a blocker

After all in-flight work is terminal and reconciled, the coordinator writes a
JSON decision (paths below belong to the consuming project's state directory):

```json
{
  "author_dispatch_id": "COPY_FROM_CORRECTED_NODE",
  "evidence_node": "verify-label",
  "evidence_dispatch_id": "COPY_FROM_TERMINAL_REPORT",
  "cause": "tests",
  "kind": "quality",
  "reason": "Describe the reproduced defect and why this worker owns it",
  "terminal_evidence": "Actual runtime/process termination evidence",
  "handoff": "Source/AC, current changes, rejected hypotheses, exact logs and next question"
}
```

```bash
sh .factory/tools/python.sh .factory/tools/workflow.py correct write-label .factory/memory/state/correction.json
sh .factory/tools/python.sh .factory/tools/workflow.py resume-task label "Verified resolution or human decision"
```

`correct` supports profiles with escalation in Implement. Cause is
static/tests/docs/review. Kind is quality (FAIL, or diagnosed BLOCKED_STATIC_FAILURE
with cause static), complexity (BLOCKED with a
technical reason), environment or requirements (BLOCKED, no model cascade).
Use the actual IDs, not placeholder strings. Evidence belongs to this task and
is the corrected node or its descendant. Files/source must still match.
`FAIL_CODE` belongs to Developer; `FAIL_TEST` belongs to TestWriter. Successful
WRITES_READY, source drift, unavailable tools or missing requirements cannot be
relabelled as poor model quality.

Quality failure counts are task/cause/profile scoped; thresholds do not add retries.
The configured chain is acyclic and ends at human. Complexity may advance early
without a quality failure; the existing budget must still permit continuation.
An identical decision replay returns its stored result without another change;
changed content for the same author/evidence pair is rejected. State is saved
atomically before model calls. Inspect `decision`: retry/escalate opens work;
human/blocked stops the task. `ok: true` means the operation completed, not PASS.

When escalating, the corrected author's affected nodes in this task move to a
new logical ID/profile. Independent nodes and other agents retain their profiles
and remain eligible for separate diagnosis. Retired profiles cannot be restored
to switched nodes under a different agent ID. Bind a fresh physical session: old handles retain their
owners. The coordinator closes actual backend sessions and confirms capacity.
No hot model switching is performed. A same-profile retry can reuse the session.
After a returned retry/escalate, claim/packet (native) or claim/prepare (ACP),
create/bind as needed, then dispatch. Do not separately call retry for the same
quality decision. Task findings, gates, source and budgets are retained.

`resume-task` requires verified resolution and a current source. It atomically
removes the stop and opens the original work and descendants as pending, spending
one recovery for environment or one retry of the original cause otherwise. It
preserves history and findings and does not dispatch. An exhausted budget leaves
the stop and state unchanged; never edit counters or silently start over.
For escalating profiles, ordinary recovery cannot bypass a terminal FAIL/BLOCKED
report: use correct, followed by resume-task for a resolved blocker.

For `replace-session`, a single-task agent accepts a plain handoff string.
A multi-task agent requires a JSON object string mapping every assigned task ID
to its own handoff; packets select only the current task's entry. Replacement
itself remains bookkeeping, not backend termination or a budgeted correction.

## Audit corrections: integration and source recovery

After an authorized reintake of a SOURCE_DRIFT-blocked run, a source_reintake stop
retains the old report/history. Use `resume-task TASK RESOLUTION_EVIDENCE`
to reopen drift-blocked work and its dependents, spending the separate recovery
budget. Quality failures are not converted into free source recovery. Environment
stops also use recovery exhaustion, not an unrelated exhausted tests/static budget.

Final integration Judge may execute verify and then review in the same
independent session. Its packet contains all task/source mappings, writer nodes and
predecessor findings. Failed verify may register open task-qualified findings before
review is reachable. Correct the explicit owner using this failed node's dispatch
as evidence; use ordinary retry for non-escalating profiles. Rerun dependent gates.
Final review refreshes original task closures against current bytes without deleting
history or weakening archive freshness. See contracts/common/review-findings.md.

Role migration: legacy `dev-reviewer` is replaced by `judge` (profile, role and contract
paths together). Rebuild graphs/configuration with the new role. Do not rewrite an
active ledger or historical reports: preserve them, finish with their original
bundle or stop/archive and start an explicitly re-intaken run on the new bundle.

## Project transition gates

The profile declares gates at work/docs/verify/review boundaries. Command gates
require project-checks reservation; finish rejects missing/failed/stale evidence.
Final verify repeats every required check. Where independent review is required, the integrated Judge supplies review_checks
for selected criteria; an eligible solo Generalist instead records SELF_REVIEW PASS, never independent APPROVE. Runtime derives gate_results. A blocked gate does not choose
an owner or reset budgets: the coordinator uses existing correction/escalation.
Planning, Decompose and standalone Review retain their own artifact validators.
