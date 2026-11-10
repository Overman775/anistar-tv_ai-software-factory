# Cleanup

Keep active, blocked and unknown work. Preserve terminal archives and
planning/decomposition `.factory/memory/staging/`.

After actual worker termination, save additional required evidence in the run's
history directory, archive the completed/cancelled run, then invoke `workflow.py clean`.
Keep packets while downstream work may need them. Cleanup verifies the bundle
and every removal path, then removes packed loose copies and its exact workflow.json.
It removes directories only when empty.
Reject symlinks, directories, traversal, foreign paths and ambiguous ownership.
Unknown files remain. Do not delete application code, tests, docs, source tasks,
approved plans, another skill's state or any history record.

For an old `pipeline.md`, do not translate or delete it automatically. Reconcile
its original run and use that version's ownership/terminalization procedure.
Starting the new ledger over legacy state is blocked. A stale lock similarly
requires confirming its owning process has stopped; elapsed time is insufficient.

If history writing, runtime termination or exact deletion fails, report the
remaining path/reason and preserve resumability. No `rm -rf`, wildcard deletion,
recursive pruning, or cleanup of another run to make a new start succeed.
