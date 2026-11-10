# Generalist completion gates

## Work and evidence

Same applicable static/test/project gates as separated authors. Report actual
cwd, commands, exit codes, final scope/file hashes, covered behavior, limitations
and docs applicability. Any later write invalidates checks; refresh evidence
against final files. Required test evidence needs nonempty direct test commands.
Write-only stages use the supplied intermediate result; final signals below
apply only after assigned verification completes.

Return `IMPLEMENTED` with evidence, `NEEDS_PLANNING`, `SOURCE_DRIFT`, or a precise
`BLOCKED_*` reason. The orchestrator validates gates. An eligible solo task may
finish with `SELF_REVIEW PASS`; this author never issues independent `APPROVE`.
For a reviewed task, a different Judge session owns that verdict.
If risk/uncertainty grows beyond the assignment, stop dependent writes and report
the cause; do not silently change composition, requirements or verification.
