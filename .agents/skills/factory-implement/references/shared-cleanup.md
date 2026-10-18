# Shared Cleanup

Runtime state exists only for handoff and resume. Never archive temporary Factory Implement artifacts into persistent code, docs, tasks, or source artifacts.

## Retention Boundary

Keep current run unchanged while any condition is true:

- status is `in_progress`, `waiting_user`, `blocked`, or `needs_planning`;
- run is resumable;
- source drift re-intake, user action, teammate result, retry, or re-review is
  pending;
- a living teammate may still write a declared artifact;
- final/cancellation summary has not captured required data.

Clean current run only after:

- `completed`: final report data captured; or
- `cancelled`: cancellation summary captured and user code changes preserved.

For cancellation: stop new work, terminalize teammates per
`.agents/contracts/common/agent-checkpoint.md#same-run-role-continuation`, capture
summary, set `status: cancelled`, `resumable: false`, then use exact-path procedure.

Cleanup deletes only exact temporary paths declared in `owned_artifacts`, then
`pipeline.md`. `adopted_artifacts` is read-only provenance and always remains
owned by its source run/skill. Never delete:

- production code, tests, generated code, project docs, task source, approved
  plan, or user files;
- unknown `.ai-pipeline/state/` files;
- another skill/run state;
- any path outside `.ai-pipeline/state/`;
- a directory recursively.

## Ownership and Transitions

Same-run `task -> debug -> task` or `explore -> implementation` transitions
keep manifest and owned evidence. Independent new runs clean old terminal state
before creating new state.

Explicit foreign handoff entries require `path`, `from_run_id`, and `reason`.
Never clean foreign manifest or persistent source. Source, approval, hashes, and
gate verdicts do not transfer between run IDs.

When user chooses fresh start:

1. Stop new work. Terminalize previous-run teammates.
2. Capture cancellation summary.
3. Mark previous manifest `cancelled`, `resumable: false`.
4. Run exact-path cleanup.
5. Start new run only after `CLEANUP PASS`.

## Deterministic Procedure

No wildcard deletion. Treat manifest paths as untrusted.

```text
1. Read pipeline.md; retain run_id, terminal status, summary fields,
   owned_artifacts, and adopted_artifacts in parent context.
2. Require status in {completed, cancelled} and resumable=false.
3. Require .ai-pipeline/ and .ai-pipeline/state/ are real directories, not
   symlinks. Require every known teammate terminalized (closed when supported,
   otherwise `retired`). Otherwise CLEANUP FAIL.
4. Validate every adopted object has non-empty path, from_run_id, and reason,
   but never add adopted paths to deletion list. Build deletion list only from
   literal `owned_artifacts` strings. Deduplicate exact strings.
5. For each entry:
   a. require normalized relative direct child of .ai-pipeline/state/;
   b. reject .., empty basename, directory, and symlink;
   c. reject .ai-pipeline/state/pipeline.md in artifact lists;
   d. absent means already clean; regular file may be deleted by exact path;
   e. verify exact path no longer exists.
6. On validation/deletion failure, keep pipeline.md with cleanup=FAIL and report
   exact remaining paths. Retry is idempotent.
7. After every declared path is absent, delete exact
   .ai-pipeline/state/pipeline.md and verify absence.
8. Run non-recursive rmdir on .ai-pipeline/state and optionally .ai-pipeline
   only when empty. Unknown files remain untouched.
9. Report CLEANUP PASS only after declared paths and pipeline.md are absent.
```

Shell-like shape for an already validated literal path:

```bash
test ! -L "$path"
test ! -d "$path"
if test -e "$path"; then rm -- "$path"; fi
test ! -e "$path"
```

Do not translate this into `rm -rf`, `rm .ai-pipeline/state/*`, `find -delete`,
or any pattern-based deletion.

## Cancellation Report

```text
Pipeline cancelled. Runtime state cleanup: CLEANUP PASS|FAIL. Code changes
remain in working tree. Discard them only after explicit user request.
```
