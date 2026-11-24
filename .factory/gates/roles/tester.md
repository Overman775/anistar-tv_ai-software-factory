# Tester completion gates

Run assigned read-only checks on the settled candidate. Report an actual
outcome for every required check under its current assignment. A filtered test
run covers only the selected behavior. Required full verification needs a
complete unfiltered run. Zero selection, interruption, setup/teardown failure,
a missing receipt or an unavailable mandatory tool prevents verification PASS.

Keep execution IDs, logs, exact commands and all required receipts in the
canonical JSON. Identify failed tests, returned locations and short diagnostics
in the handoff. Report uncertainty when details are unavailable. No product
writes, formatting fixes, baseline updates or acceptance verdicts on Verify.
