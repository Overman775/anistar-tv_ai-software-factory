# Shared Finalize

Use after successful `feature`, `task`, `refactor`, or `fix`.
Capture result before removing temporary state.

## Stateless Adaptive Finalize

Use only for `inline_self_review`.

If the user cancels before success, stop writes, preserve the current working
tree and any check evidence, report cancellation, and create/clean no Factory Implement state.

1. Confirm eligibility and route remain valid and no persistent Factory Implement
   state was created.
2. Confirm current hashes match parent-held evidence. Focused tests and each
   complete workspace Analyze/DCM/Format triplet must pass after the final write.
3. Require post-write diff review plus `SELF_REVIEW PASS`.
   Any subsequent write returns to the full final-byte sequence and invalidates
   `SELF_REVIEW PASS`.
4. Emit the common report with `State: NOT_CREATED`,
   `Execution: INLINE_SELF_REVIEW`, `Agents: none`, and
   `Cleanup: NOT_APPLICABLE`.
5. Never invoke `shared-cleanup.md` for a stateless route.

## Stateful Finalize

1. Terminalize every teammate per
   `.agents/contracts/common/agent-checkpoint.md#same-run-role-continuation`: close
   living handles when supported, otherwise record `retired`. Retain `status:
   in_progress`, `resumable: true`, and report `CLEANUP FAIL` only for living or
   unknown non-terminalized agents.

2. Read `pipeline.md` and required reports. Verify every report header matches
   current `run_id` and `source_hash`. Verify Source Gate passed; mutable source
   has current Drift Gate evidence. Successful `feature`, `task`, and `refactor`
   finalization requires `static: PASS | NOT_APPLICABLE`, `tests: PASS`, and
   authoritative Review Gate verdict `APPROVE`: with `review_fix: 0`, require
   `review.md`; with `review_fix > 0`, require `re-review.md` and retain
   `review.md` only as initial finding/fix evidence. Require
   `pipeline.md.gates.review` to match authoritative report. A `fix` workflow
   requires `static: PASS | NOT_APPLICABLE` and may use `review: NOT_RUN` only
   with nonempty `gate_notes.review`. Every `static: NOT_APPLICABLE` requires
   nonempty `gate_notes.static`. Missing, stale, or contradictory evidence keeps
   run resumable and prevents cleanup.

3. Capture final report data in parent context:

   - `run_id`, workflow, execution mode, source ref/hash, and outcome;
   - changed project files/count, excluding temporary state;
   - static, test, review, and source-drift verdicts;
   - agent chain, skipped gates, blockers, unrelated failures;

   Do not copy `execution-brief.md`, analysis, or gate reports into `docs/`,
   `docs/tasks/`, source files, tests, or another archive.

4. If production code, tests, generated project code, or project docs changed,
   run:

```bash
graphify update .
```

   Graphify failure becomes `NOT_RUN` note; it does not invalidate successful
   execution. Do not stage, discard, or reset graph changes.

5. Refresh changed-file count. Only now mark manifest `status: completed`,
   `resumable: false`, and `cleanup: PENDING`.

6. Execute `shared-cleanup.md`. Delete exact declared temporary artifacts,
   verify absence, then delete `pipeline.md` last. Never delete project changes.

7. Emit captured report even when cleanup fails:

```text
Cleanup: PASS
```

or:

```text
Cleanup: FAIL
Notes: CLEANUP FAIL — {remaining paths or living agents}
```

8. Do not stage or commit automatically. Use `factory-github` only for explicitly requested GitHub actions; commits,
   push, PR publication, merge, and release require explicit request. Offer docs work when public contract, setup, or developer
   workflow changed; do not invoke either without explicit request.

Stateful report uses `State: STATEFUL`; use `Execution: FULL_TEAM` for a
full-team follow-up and `Execution: STANDARD` for a normal initial/stateful
pipeline. Existing cleanup semantics remain unchanged. Final report uses
concise `SKILL.md` format and includes mode/source provenance.
