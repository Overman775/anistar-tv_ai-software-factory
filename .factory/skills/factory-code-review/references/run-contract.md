# Review run contract

Run from the reviewed workspace with the Factory Python launcher. `scripts/review_run.py`
is the local lifecycle entry point, not an agent scheduler or server. Host adapters own
spawn/wait/session operations. All three assignments use the configured reviewer role default, recorded in each assignment.

## Request

Input extends the manifest in scope-and-modes.md with:

```json
{
  "context": {
    "sources": [{"id":"task", "locator":"issue:123", "captured_at":"ISO timestamp", "content":"Accepted task or incident text"}],
    "requirements": [{"id":"AC1", "source_id":"task", "text":"Required observable outcome"}],
    "limitations": [],
    "pr": null
  },
  "command_selection_reason": "Why the selected commands cover this change; name unchecked areas",
  "additional_checks": [],
  "source_evidence": {}
}
```

For PR mode, context.pr is `{url,title,body,captured_at,head_sha}`; title and body
are the actual read text (body may be empty). Sources retain tracker/thread/user
provenance. Empty requirements require an explicit limitation and block intent approval,
not other investigation. Contradictions must be resolved from authorized sources or
retained as limitations and NOT_RUN for affected criteria.

Additional checks: `{id,method,execution:{argv,cwd,timeout_seconds,inputs},after:[]}`.
Inputs are exact paths relative to reviewed workspace; cwd is also workspace-relative.
Use explicit argv, no shell interpolation. Project `gates[].checks` at
`code-review.complete` use the same command contract (level: slice); no decisions yet.
Project selectors choose mandatory commands; no post-plan NOT_APPLICABLE waiver.
An empty selected list is valid with explanation. Additional IDs cannot collide with policy.

Source evidence: path -> `{content,sha256}` for exact contextual files (unchanged
consumers, implementation search locations). Bytes must match checkout at intake and
remain unchanged. Include command inputs outside diff. Missing source/requirements
must not be converted into invented positive evidence.

`init` generates schema 4, scope_hash, complete assignments and planned checks.
The hash binds context, assignments, commands, source evidence and accepted policy.
Changes to any require a new run. Branch/PR checkout must be clean and at head_sha;
use a separate checkout instead of resetting user work. Capture branch/PR diff with git diff --no-ext-diff --no-color BASE...HEAD; intake
compares it to the actual checkout comparison. Full diff validation remains.

## Local lifecycle

- `init --input REQUEST --run RUN`: creates a new directory; never overwrites.
- `status --run RUN`: derives status from current validated artifacts, no second status ledger.
- `assignment --id DIRECTION --run RUN`: emits assignment JSON for context.py.
- `check --id CHECK --run RUN`: executes exact pinned command after dependency PASS.
- `submit --id DIRECTION --input RESULT --run RUN`: preserves one returned attempt;
  explicit failed/invalid output permits one recovery. Healthy results cannot be replaced. Recovery retains valid findings from an incomplete
  attempt; only evidenced QA can dismiss or change their interpretation.
- `finish --input QA --run RUN`: preserves QA and writes final-N/result.json + report.md.
  Incomplete results retain valid findings. Final folders preserve history, not cached approvals.

Manifest, local input hashes, attempt results and logs live only in RUN. Calls acquire
an OS-owned lock in `.review.lock`; the file must remain in place. An interrupted check
leaves `.check-in-progress`. A matching, validated saved attempt clears the marker after
freshness checks. Otherwise inspect the command and logs, confirm it stopped and start a
new review. A legacy `.busy` has no owner identity. Identify the old owner PID and verify
that all its child commands stopped; then run `review_run.py recover-legacy --run RUN
--legacy-owner-pid PID`. The command requires a dead owner PID, an empty marker and successful
freshness and interrupted-check validation before it removes `.busy`. PID
verification is available on POSIX only. The operator identifies the correct
owner and verifies that its children stopped.
Recovery accepts a lock whose inputs still match. It also accepts a lock-only
upgrade from the three exact versions of `command_worker.py`, `review_run.py`
and this contract in Lab `dfe5cfba`, when all other recorded inputs still match
and none of the changed files is a reviewed source, diff or command input.
Runs with broader drift, including runs pinned to an unmodified
`211d3162` factory, need new intake. Their old marker and input lock stay in place.
A validated BLOCKED attempt retains its concrete execution error and may be
retried within the existing attempt limit.
Never treat elapsed time as failure. No distributed lease,
remote queue, automatic retry of unknown execution or background model process exists.
A command changing pinned bytes blocks the run; review is not an autofix mechanism.
Recovery is for the same inputs. Changed revision requires new identity and fresh review.

Standalone low-level protocol helpers are validation/diagnostic tools. Finish through
review_run.py to enforce local input freshness as well as artifact validation.
