# Assigned check execution

Implement command nodes require an existing project-checks reservation and profile
command capability. This file grants neither. Read actual project command definitions
and `.factory/skills/factory-implement/references/project-checks.md` before commands.
Run required commands with `sh .factory/tooling/bin/python.sh .factory/tooling/bin/workflow.py run-check NODE CHECK_ID --request REQUEST_ID --dispatch DISPATCH_ID`.
Copy its returned result unchanged into checks, or select its execution ID in
`prepare-report` and leave it out of draft checks. Do not do both: duplicate
selected check IDs are rejected. CLI ok:true means a saved record,
not a successful check: inspect result.result. Do not call claim/bind/finish/retry.

Keep and wait on the host command session. Never duplicate a yielded/running
command. FAIL/BLOCKED or lost process state returns to the coordinator for diagnosis;
no blind retries or stale-lock removal. The CLI waits outside the ledger lock. Use the same request ID after lost output.
Intentional reruns use a new ID. The coordinator reconciles process ownership
before releasing the resource. Use foreground commands within the runner tree.

Verify supplies all required checks plus applicable static/tests/docs evidence or
justified not_applicable reasons; high risk cannot skip tests. Required checks
cannot be waived via not_applicable. Review performs its assigned final checks.
Later writes or changed inputs invalidate prior evidence. Self-review is never an
independent APPROVE. Correct assertions and nonzero test selection need inspection.

`verify` returns each required check's exact `id/category/kind/criteria/method`, plus
`execution`, command/cwd/exit code, `execution_id` and the log reference returned
by `workflow.py run-check NODE CHECK_ID --request REQUEST_ID --dispatch DISPATCH_ID`, or an observation. Copy runner results
unchanged; do not manufacture command evidence. Required commands need an
`execution` definition before intake. `argv` is an argument array (no implicit
shell), `cwd` is workspace-relative, timeout is a positive integer in seconds
(up to 86400). Optional `inputs` lists exact additional files to hash, including
test sources, wrappers, package locks and command definitions outside task scope.
Use an exact test identity/scenario and expected effect in `method`; a suite's
name alone is not proof of meaningful coverage. The runner checks actual execution
and captures logs. The parent checks test selection (including zero tests),
assertions, complete input selection and artifact contents. Register all applicable
mandatory project commands in `required_checks`; additional results cannot replace them.

For selected tests, attach evidence of the exact selector, selected and completed
tests/counts, and the runner's full/filtered scope when available. Inspect the
actual log/report; absent selection evidence or zero selected tests cannot prove
success. A filtered run cannot satisfy a required full-suite gate. Retain late,
setup and teardown errors, incomplete streams and unknown terminal outcomes;
a zero process exit alone does not override them. Keep runner receipts unchanged:
put this detail in accompanying evidence, not invented receipt fields.

An observation uses `kind: observation`, `result: PASS`, and evidence such as
screenshots and comparison notes; never invent a shell command for visual review.
For a required durable-handoff observation, inspect the actual retained author
report and its source as specified in the assigned method. Cite its run, node,
dispatch and fields and the concrete facts checked. An absent fact is not an
unknown, and neither means a check was NOT_RUN. Return missing or ambiguous facts
to the coordinator; do not pass the observation on a source document alone.
Observations do not replace mandatory project test/static/build commands.
One `verify` must supply the complete required check set for its assigned task.
Slice tasks declare local behavior/regression gates; final integration declares
the full project test/build/static set and is verified by the independent
Judge before its review. Never silently drop an existing required check. Current conservative
source/file snapshots and later-write invalidation apply to all its results.
For a multi-task run, integration rechecks all selected criteria on final files,
including joint behavior. References to another source use `source-id:AC-01` in
the integration task; source-local AC identities remain unchanged.

Additional records have unique IDs and `category: additional`. A non-successful
extra check blocks PASS until diagnosed. Record a `resolution` with disposition
`invalid_check`, `out_of_scope`, or `not_run`, and a concrete `reason` if it is
not a blocking product defect. `not_run` is only for an actually unexecuted check;
never relabel a failing test. Invalid diagnostics need explanation; unmet behavior
within scope needs correction. Additional passed checks remain in the report.

Report discovered defects in `findings`: `id`, `blocking` (boolean), `status`,
description and evidence. An open blocking finding forbids PASS even when found
by an additional check. `fixed` or `dismissed` needs `evidence` and review of the
actual correction or reason. Preserve stable IDs through retries; do not omit
unresolved findings in a new report. Implement Judge findings use the
separate shared review-findings contract and persistent registry. Classification
and findings from other roles still require parent/reviewer reconciliation.

Runner receipts cover declared commands/inputs, not all external state. The ledger
is not a tamper-proof sandbox. Observations/additional diagnostics still require
honest evidence; full command recovery belongs to the coordinator.


An assigned check may declare registered ordered `execution.stages` and an empty
`argv`. The runner executes each registered read-only full stage once and records distinct
child receipts, command results, input hashes and logs under the parent execution.
Use `check-results EXECUTION_ID` to retrieve the parent and child results. Copy each actual receipt ID into `prepare-report`; a parent receipt alone cannot
satisfy child gates. A stage that never ran has no receipt. Judge uses its own
assignment. A `codegen` command may declare exact owned `outputs`; the runner
records before/after hashes and checks immutability of other declared inputs.

A registered composite test stage supplies one log record
`FACTORY_TEST_SELECTION {"mode":"full","selected":N,"completed":N}` from its
actual test runner or wrapper. N is positive and reflects completed tests. A
missing, filtered or incomplete selection blocks the composite. Generation
with declared outputs uses a separate assigned writer command.
