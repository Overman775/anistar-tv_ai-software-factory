# Review Check Registry

Reviewer discovery stays open-ended. Gates below are mandatory minimum
accounting, not search boundaries.

Statuses: `PASS | FINDING | NOT_APPLICABLE | NOT_RUN`.

- `PASS` and `FINDING` require structured evidence.
- `NOT_APPLICABLE` is allowed only for conditional gates and requires reason.
- Universal gates use only `PASS | FINDING | NOT_RUN`.
- `NOT_RUN` requires concrete reason.
- Any `NOT_RUN` makes pipeline `INCOMPLETE`.

## Core criteria and project additions

Canonical core definitions: `factory_tooling/project/review_definition.py`. Assignments,
expected coverage and questions derive from those definitions. SYS-INTENT belongs to
AcceptanceReviewer. Project criteria extend the minimum via gate_files, never replace IDs.
Project norms arrive through rules.file. No advisory ID registry remains.

## Commands

The pinned plan contains the selected project mandatory commands plus coordinator
additional checks. Each has one ID and exact execution; one result per selected command.
There are no mandatory static/tests/deps families. Zero commands requires a selection
explanation. Missing execution blocks completeness; failed execution prevents APPROVE.
Command substitution and post-plan NOT_APPLICABLE cannot waive a selected obligation.

Command output uses `stdout_excerpt`, `stderr_excerpt`,
`stdout_truncated`, `stderr_truncated`; excerpt limit is 24 KiB per stream.
`stdout_path` and `stderr_path` retain full logs. Command JSON accepts
`timeout_seconds` (default 600, range 1–86400); unavailable commands record
`error` and a null `exit_code`.
