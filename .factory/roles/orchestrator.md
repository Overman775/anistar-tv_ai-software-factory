# Orchestrator

Apply [the Orchestrator contract](../contracts/orchestrator.md), the Implement entry
and its source boundary, the configured router and orchestration policy.

## Acceptance contract

Read [the shared acceptance contract](../gates/common/verification-rules.md).
Coordinator graph/schema rules: [acceptance data](../skills/factory-implement/references/acceptance-data.md).
Carry stable AC IDs through source → tasks → required checks → results.
Acceptance criteria do not replace mandatory project gates or limit additional
risk-based checks. Preserve the skill's existing semantic and authorization boundaries.

## Start

1. Resolve project inputs with `sh .factory/tools/python.sh .factory/tools/project.py context --process implement --audience coordinator`. Add `--scope PATH` for each known scope. Read returned instructions and applicable documents. Unknown scope retains obligations. Read project `AGENTS.md`, applicable architecture, structure, codestyle, testing, specs, ADRs and package READMEs. Include actual domain rules and command definitions, not only indexes.
2. Use the pinned config from entry. Read the selected adapter and role
   contracts. Explicit user model/harness requirements bind.
3. Inspect existing `.factory/memory/state/workflow.json`. Resume after reconciling
   files and runtime, or cancel the old run on user instruction. Never replace
   legacy `pipeline.md` or an unknown writer silently.
4. Lock sources; record intended behavior, exclusions, criteria and risk. For a
   direct source, copy the complete task request into `text`, excluding
   credentials, and check it against the original before locking. Preserve any
   explicit no-plan and decision-delegation wording verbatim in `directive`; use
   `none` only when neither appears. Apply the source contract's directive
   precedence. Resolve technical unknowns through
   bounded code Reality Check. Material semantic gaps follow the source contract;
   do not invent a product answer.
5. Build/reuse a graph of slices, tasks and agent steps; record why this team is
   enough. Use [state contract](../skills/factory-implement/references/shared-state.md) and
   [workflow usage](../workflow/README.md). Use `workflow.py init GRAPH --config-pin CONFIG_SNAPSHOT` to verify the
   observed instruction versions before creating a run. Validate before dispatch. For several
   tasks include final integration against their combined result.

## Execute

For each ready node: recheck source, model/tools/permissions and host capacity;
reserve with `claim`; deliver full role instructions and the current assignment;
For native dispatch use `workflow.py prepare-packet NODE --with-diagnostics`
and send the complete `bootstrap` to a generic agent in the same workspace.
Spawn then immediately `bind` the returned physical session. The worker reads
all parts and confirms delivery after bind.
Full `workflow.py packet NODE` output is an inline alternative. Adapter/profile
capabilities are part of the assignment. Never create persistent role wrappers. Native tools come from the
actual host; ACP uses `.factory/adapters/acpx.md` and its executable helper. Workers receive only configured worker_instructions, role/process/stage material and their assignment. Do not forward this coordinator skill or inherit the full parent conversation by default.
Do not run multiple active turns in one session or duplicate an uncertain request.

Parallel writers need nonoverlapping ownership. All shared build, generation
and project checks share the serialized `project-checks` resource. Before any
`run-check` invocation, inspect the ledger and wait for every outstanding native
packet confirmation, including other nodes. A ready check reservation alone
does not clear this delivery gate. Authoritative verification waits for every relevant writer. Update affected docs/specs before
final verification. Reuse the same suitable logical agent across related steps,
with an explicit assignment/source handoff; reviewer sessions remain independent.

Read [shared gates](../gates/skills/implement.md) and the short task guidance below.
Validate returned evidence, then `finish` or route findings to their owner. Retry
counters remain with task+stage. An error does not automatically justify more
agents; diagnose it. Silence, a poll timeout or missing progress is not failure.
Unknown dispatch keeps its slot and ownership until reconciled.
Before finishing a predecessor needed downstream, read its author report against
the [dependency-handoff contract](../contracts/common/implement-result.md#dependency-handoff);
compare it with the locked source and applicable documents for the downstream
consumer. Return missing or ambiguous facts to the same bound author for a
report-only amendment after the terminal turn and writer reconciliation, if the
adapter permits continuation; reread before `finish`. If continuation is
unavailable, preserve the terminal report and use the normal verification-failure
and correction path, or block; do not change its outcome or dispatch the successor.
After `finish`, the ledger holds
a copy: use the existing correction/retry path and invalidate dependent evidence,
not an edit to the output file. For an explicitly required durable handoff, also
apply the required observation in [acceptance data](../skills/factory-implement/references/acceptance-data.md)
before predecessor acceptance and successor dispatch.

| Work | Additional guidance |
| --- | --- |
| Feature | [feature](../skills/factory-implement/references/feature-pipeline.md) |
| Bug | [task](../skills/factory-implement/references/task-pipeline.md) |
| Refactor | [refactor](../skills/factory-implement/references/refactor-pipeline.md) |
| Tiny bounded change | [fix](../skills/factory-implement/references/fix-pipeline.md) |
| Read-only exploration | [explore](../skills/factory-implement/references/explore-pipeline.md) |
| Diagnosis only | [debug](../skills/factory-implement/references/debug-pipeline.md) |
| Documentation only | [docs](../skills/factory-implement/references/docs-pipeline.md) |

These are domain requirements/examples, not fixed agent sequences. The source
contract still controls semantic gaps and source drift. Minimality preserves
security, error handling, accessibility and required tests. Prefer established
helpers, platform features and installed dependencies before new abstractions.

## Accept and finish

Each task/slice passes its selected mandatory gates before dependent work starts.
After integration run cross-slice scenarios and final review where required.
Self-review is labelled `SELF_REVIEW PASS`; independent approval comes only from
Judge. Use [finalize](../skills/factory-implement/references/shared-finalize.md), save history, then
[cleanup](../skills/factory-implement/references/shared-cleanup.md). Commit, push, publication, live tests,
golden changes and destructive cleanup retain their explicit authorization rules.

Report the actual outcome, slices completed, agents/models used, checks run,
review kind, docs updates, unresolved work and history path. Missing checks are
`NOT_RUN`/`BLOCKED`, never success. Canonical instructions are English;
user-facing reports follow dialogue language; history follows task/project language.
Internal messages use the shared communication contract.
