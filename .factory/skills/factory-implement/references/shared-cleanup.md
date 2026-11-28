# Cleanup

Keep active, blocked and unknown work. Preserve terminal archives and
planning/decomposition `.factory/memory/staging/`.

After actual worker termination, save additional required evidence in the run's
history directory, archive the completed/cancelled run, then invoke `cli workflow clean`.
Keep packets while downstream work may need them. Cleanup verifies terminal history
and each removal path against the run inventory. It removes only exact registered
working copies of transport, checks and attachments with verified ownership and
hashes, then releases the current run slot in the workflow database.
It removes directories only when empty.
Reject symlinks, directories, traversal, foreign paths and ambiguous ownership.
Unknown files remain. Do not delete application code, tests, docs, source tasks,
approved plans, another skill's state or any history record.

For an old `pipeline.md`, do not translate or delete it automatically. Reconcile
its original run and use that version's ownership/terminalization procedure.
The operating system releases the workflow lock when its holder exits. Keep the lock file in place.

If history writing, runtime termination or exact deletion fails, report the
remaining path/reason and preserve resumability. No `rm -rf`, wildcard deletion,
recursive pruning, or cleanup of another run to make a new start succeed.
