# Implement acceptance data (coordinator)

Read the shared acceptance principles. This reference owns graph/source schema;
worker result fields belong to `.factory/contracts/common/check-execution.md`.

Implement imports source criteria before dispatch, then assigns concrete check
methods. A direct request or ordinary task uses the same small registry without
requiring Planning/Decompose. Preserve two explicit intake forms:

- With a full parent-plan source registry, task `acceptance_ids` names full parent
  closures; `contributes_to_acceptance_ids` names parent contributions only.
  `local_acceptance_criteria` holds task-local canonical criterion objects, and
  `required_checks.criteria` refers to them as `local:AC-01`. A functional
  contributor can have no parent closures but must have local acceptance. Retain
  task `parent_plan_ref` whenever contributions are declared. Final integration
  still verifies every selected parent AC; local PASS never closes parent AC.
- For a standalone `factory_decompose_task` source with no full parent closure,
  source `acceptance` contains the task's local registry, with
  `acceptance_origin: task_local` and non-empty `parent_plan_ref`. The visible
  parent AC field is `—`. Runtime task `acceptance_ids` refers to that source-local
  registry; these IDs do not claim parent closure. Retain parent contribution
  references as source provenance. This form also serves preparatory tasks.

The orchestrator and reviewer verify semantic translation; the helper does not
infer requirements from natural language. Never present local criteria as
completed parent-plan criteria.

## Workflow data and results

Each source has `acceptance`, a non-empty array of
`{id, applies_to, requirement, verification}`. A canonical approved plan must
match its AC table exactly. An explicitly bounded source may select
`selected_acceptance_ids` alongside `selected_scope`; retained unselected criteria
are outside this run, not PASS. Direct/external source extraction is checked by
the parent. Never select fewer criteria merely to make a failing run pass.

Every task declares non-empty `acceptance_ids` and `required_checks`.
When the source explicitly requires a durable author handoff to a downstream
task, retain that requirement in the source registry at intake (reuse the
matching approved-plan criterion; never alter a locked registry). Assign the
predecessor a required `observation` covering that criterion. Its method must
name the concrete downstream facts and limits derived from that source and
require comparison of the persisted author report with the locked source and
applicable documents: consequential behavior and reasons, paths and interfaces,
and checks and their boundaries.
The observation must identify the author report by run/node/dispatch and its
fields, and distinguish absent information, unknown behavior and checks that
were NOT_RUN. Give the author this expectation in the assignment. The verifier
reads the author report retained by `finish` via
the immutable `dependency_results[author_node].report_ref` when available, or the exact ledger
node report; a separate output file or memory is
not evidence of what `finish` retained. Missing or ambiguous information fails
the observation. Apply this only to handoffs explicitly required by the source;
do not create an extra stage or agent. A Judge assigned to predecessor review
validates the observation against source and report; otherwise the coordinator
does so before acceptance, including in an authorized solo run. Integration covers selected source criteria,
inspecting the retained handoff as historical process evidence rather than final
product verification.
Separate slice-local acceptance from final run acceptance before dispatch. Preserve
applicable mandatory slice checks; place full-project tests/build/static and combined
criteria on final integration. The final independent Judge executes its
`verify` node, then its `review` node; one task's complete receipts remain bound to
that node/dispatch. Never reuse stale slice receipts as proof of final-tree success.
For a single-task run requiring full gates, assign that final verify to Judge
too. Existing required checks cannot be removed to retrofit this policy mid-run.

Example:

```json
{
  "acceptance_ids": ["AC-01"],
  "required_checks": [
    {"id": "restore", "category": "acceptance", "kind": "tests", "criteria": ["AC-01"],
     "method": "Restart scenario in preference_test: restore persisted selection",
     "execution": {"argv": ["flutter", "test", "test/preference_test.dart"], "cwd": ".", "timeout_seconds": 600,
                   "inputs": ["pubspec.yaml", "pubspec.lock", "test/preference_test.dart"]}},
    {"id": "project-check", "category": "project", "kind": "tests", "criteria": [],
     "method": "Full project check according to pinned project profile",
     "execution": {"argv": ["REPLACE_WITH_PROFILE_COMMAND"], "cwd": ".", "timeout_seconds": 1800,
                   "inputs": ["REPLACE_WITH_ACTUAL_COMMAND_INPUTS"]}}
  ]
}
```

A check may cover several criteria; a criterion may require several checks.
Every declared required check must pass. Additional results cannot stand in for
a missing required result. Revision may add required checks but cannot delete
or weaken existing ones. A semantic change uses source re-intake and invalidation.

## Migration and limits

Old plans, source locks, graphs and reports without these fields fail the new
gates; do not silently label them covered. Regenerate staging from the approved
source; revise an approved plan through Planning rather than editing it in place.
Do not upgrade an active ledger in place: preserve/archive its evidence and
re-intake explicitly. This contract does not reset attempts or grant permission
for live calls, golden updates, publication or application installation.

Validators check structure, declared coverage, result consistency and freshness.
The Implement runner executes declared required commands and records actual output,
exit code, timestamps and file hashes; finish/accept require matching receipts.
Failure, timeout, missing executable, changed inputs or unresolved RUNNING cannot
become PASS. A newer attempt supersedes earlier evidence. Logs survive cleanup.
Observations and additional diagnostics remain role evidence reviewed by the parent.
This is local bookkeeping, not tamper-proof attestation or a sandbox against an
agent that can rewrite the ledger. Correct tests, complete inputs and live environment
behavior still need review. See workflow README for interruption/recovery limits.
