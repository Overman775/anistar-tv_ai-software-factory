# Review run contract

Run the accepted factory CLI from the reviewed workspace. If the candidate changes review tooling, invoke the CLI from the independent accepted installation. `cli review run`
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

The new run and its frozen inputs, attempts, command receipts and QA live in SQLite. Use the returned run ID in a fresh CLI process. Host adapters own launch and observation.

| Operation | Input and result |
| --- | --- |
| `init` | `--input REQUEST --run NAME` captures a reviewed subject. |
| `status` | `--run RUN` returns independent directions, checks and unresolved command reservations. |
| `assignment` | `--id DIRECTION --run RUN --request KEY` reserves one ticket. |
| `bind`, `packet` | Supply the direction, run, dispatch and observed handle. Only the assigned direction's evidence is delivered. |
| `note`, `submit` | The original dispatch records a partial observation or returned result. For submission provide `--input FILE`. |
| `check` | Supply the declared check ID and stable request. The receipt covers the pinned command and input files. |
| `reconcile-check` | After observing the original process and child stopped, supply `--id`, `--original-request`, evidence and a new request key. A missing exit result is BLOCKED. |
| `cancel` | Supply the owner reason after reconciling outstanding checks and workers. History remains available. |
| `finish`, `report` | QA supplies its assessed evidence via `--input FILE`. Read the resulting Markdown from the run. |
| `history`, `clean` | The completed run retains attempts, observations and results by ID. |

Reuse a mutation key only for identical input. Reconcile an unknown process against its actual host handle. Observed failure can release the affected direction within its retry budget. Capture changed scope, head or mandatory inputs as a new review.
