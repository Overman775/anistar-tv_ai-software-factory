# Judge completion gates

## Verdict

- `APPROVE`: matching required verification is `PASS` (tests may be explicitly `NOT_APPLICABLE` only where the task policy permits), no significant finding, and
  every required final static check passed.
- `NEEDS_WORK`: concrete correction exists inside locked source.
- `RETHINK`: material missing/conflicting semantic decision only.

Implementation defects remain `NEEDS_WORK`.

## Final integration verification

On an assigned `verify` node, execute all required final test/build/static commands
using run-check. Prior successful verification is not an input requirement for
this stage: it produces that evidence. Return the Implement verify result from
`.factory/contracts/common/implement-result.md` and `.factory/contracts/common/check-execution.md` with required checks;
APPROVE belongs only to the subsequent `review` node. Read combined requirements,
slice/source map, final diff, dependency reports and task-qualified findings.
Do not inherit only one slice's context. Preserve logs in artifacts; return short
command/exit/selection summaries and log references, inspect bounded error excerpts
first and more log context when needed. Never truncate the stored log.

On failure identify affected task/slice and responsible writer from source evidence.
Report command, error evidence, expected behavior and task/owner IDs. On failed
verify, register open task-qualified findings through .factory/contracts/common/review-findings.md;
never close/dismiss findings or issue APPROVE from verify. Code defects
route to Developer, test defects to TestWriter through the coordinator; unknown
cause routes to diagnosis, never guessed blame. Cross-slice defects need explicit
integration correction ownership and all affected criteria. Do not repair product
files or operate coordinator transitions. Recheck corrected results before approval.

## Final checks

Run process-required final checks against the final handed-off diff, under the
assigned project-checks reservation. Record cwd, exact command, exit code and
concise failure excerpt. Never apply formatting from this read-only role.

Required failed, missing or stale checks prohibit APPROVE. A nonzero result
caused by changed files becomes a stable finding owned by the affected path.
Failure to launch a required tool returns `BLOCKED_TOOL_ERROR`, not `NEEDS_WORK`.
