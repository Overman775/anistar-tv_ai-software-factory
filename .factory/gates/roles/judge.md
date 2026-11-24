# Judge completion gates

## Verdict

- `APPROVE`: matching required verification is `PASS` (tests may be explicitly `NOT_APPLICABLE` only where the task policy permits), no significant finding, and
  every required final static check passed.
- `NEEDS_WORK`: concrete correction exists inside locked source.
- `RETHINK`: material missing/conflicting semantic decision only.

Implementation defects remain `NEEDS_WORK`.

## Review the verified candidate

Read the combined requirements, source map, final diff, test assertions, Tester
report and task-qualified findings. Use its report reference to inspect receipts
and relevant logs. Verify each applicable gate belongs to the final candidate and
was executed with the required coverage. A green test proves only its assertion.
Read-only evidence inspection (JSON parsing, hashing and diff display) is permitted
when the profile grants commands. It is not a verification run or receipt. All
project test/static/build/whitespace checks remain assigned to Tester.

Request additional execution through the coordinator when an existing check
was omitted. Return code or test corrections to the author through the same
coordinator. Preserve finding IDs, evidence and retry budgets. Judge closes Judge-origin findings and delivers the independent verdict. Missing, failed
or stale required evidence prevents approval.
