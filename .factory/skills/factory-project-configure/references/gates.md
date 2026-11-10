# Authoring project gates

Read [project gate contract](../../../contracts/common/project-policy.md#transition-gates),
[result contract](../../../gates/result-contract.md), and the relevant example below.
For conditional judgments also read [decisions](../../../contracts/common/decisions.md).

| Need | Installed example |
| --- | --- |
| Slice commands and ordered dependencies | [authors.yaml](../../../project/examples/gates/roles/authors.yaml) |
| Final commands, predicate applicability, observation | [judge.yaml](../../../project/examples/gates/roles/judge.yaml) |
| Review questions and standalone Review command | [code-review.yaml](../../../project/examples/gates/skills/code-review.yaml) |
| Decomposition script and result protocol | [gate.yaml](../../../project/examples/gates/skills/decompose/gate.yaml), [check.py](../../../project/examples/gates/skills/decompose/check.py) |

## Contract-sensitive choices

A gate has id, at, and exactly one of checks/criteria. Supported project boundaries:
checks at implement.work/docs/verify, decompose.complete and code-review.complete;
criteria at implement.review or code-review.complete. No project planning.complete.
Use slice checks at work/docs; final checks belong to verify. Definition filenames
and role folders do not assign executors. Never override factory obligations.

Choose commands for executable evidence, observation for an evidenced judgment
without execution, criteria for review questions with system-design/runtime-safety/
verification-quality lens. Keep criteria separate from command gates at the same
boundary. Project check and criterion for filters accept paths only.

Commands use argv arrays without shell expansion. cwd, inputs and script paths
are application-relative; inputs lists exact files, including check scripts and
local dependencies outside task scope. timeout_seconds limits one command.
after lists prerequisite check IDs; dependencies must be acyclic and applicable
in the same task. final does not imply execution after every other command.
An observation has no execution. Only predicate decisions can select checks;
choice/score definitions do not select roles, commands or actions automatically.

Use either inline gates or gate_files; each external file contains only gates.
Likewise choose inline decisions or decision_files. External paths start at the
profile directory; no globs or implicit directory loading. A gate with custom code
is a bundle with gate.yaml and its script; reuse the common runner.

For Decompose script stdin/stdout and exit codes, read the
[executable example contract](../../../project/examples/gates/README.md#проектная-проверка-декомпозиции).
Check valid input, rejected work and unavailable/malformed execution. General graph
validation and TaskReviewer approval remain mandatory. For other boundaries use
existing runner/result contracts; do not apply Decompose's JSON protocol universally.

Validate definition connections and applicability before running a command. Run
project checks only within the requested scope and actual permissions. Inspection
and fixtures produce no live acceptance receipt. Report unexecuted commands and
missing prerequisites; never remove a mandatory check merely to make setup green.
