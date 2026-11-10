# Project policy boundary

Factory roles, permissions, process transitions, source/AC identities and evidence
semantics stay in the common base. `.factory/factory.yaml` explicitly selects one
local `project` YAML. That profile owns project documents, additional rules,
commands, conditional review gates and optional skill-specific instructions/checks. Runtime model,
adapter and tool grants remain in factory.yaml; project text grants no authority.

Before dependent work, the coordinator runs:

```bash
sh .factory/tools/python.sh .factory/tools/project.py context --process PROCESS --audience coordinator --scope PATH
```

Repeat `--scope` for every affected path. No scope means unknown: conservatively
include conditional rules, then resolve scope before dependent writes/checks.
Read actual documents named by selected rules; an index is navigation only.
Preserve the output with the process evidence. Missing files, unknown fields or
applicability, duplicate IDs and drift block dependent work. The command only
reads; it neither starts Implement nor invokes project commands.

Worker context.py resolves the same profile for process, role, stage and scope.
Deliver its full packet. Rule selectors remain visible: a server rule does not
become a UI-wide rule merely because both scopes share one Developer assignment.
Explicit assignment reads supplement the profile; they cannot remove obligations.
Profile data never overrides the worker role or introduces new roles/stages.

## Documents and task-specific reading

`rules.coordinator` and `rules.worker` are lists with the same selector/source
contract. Group membership determines the recipient; only worker rules allow
`for.roles`. Omitted groups are empty; IDs remain unique across both groups.
To share a material, reference it in each group with a distinct ID. The resolver
selects one group via `--audience`; it does not merge recipients.

Optional documents catalog: ID -> {path, category?}; rule.documents lists exact
IDs. Category is metadata, never a loading target. No catalog is valid when no
rule references it. Missing selected files block; unrelated entries are not read.

Do not derive required reading from review gate selectors. Select domain documents
from the task and source evidence; pass exact paths through read.
No discovery section. Follow [Project discovery](code-discovery.md) to find
task-specific specs, ADRs and business material. Record selection reasons in task
context; pass exact paths through the existing assignment/node read list. Distinguish
current requirements, authorized changes and historical evidence. Extra reads do
not replace pinned policy or waive mandatory reading. Resolve missing context with
the coordinator before dependent work; preserve earlier packet history.

## Transition gates

Project gates group evidence obligations by boundary: implement.work/docs/verify
for checks, implement.review and code-review.complete for review criteria.
Code Review also accepts its own command gates at code-review.complete; commands
are selected into a pinned review plan, not into an Implement task.
A gate supplements core stage contracts; it cannot remove them or grant authority.
Commands produce receipts; review produces evidenced conclusions; the gate determines
whether transition is permitted. Corrections remain coordinator-owned with existing
retry/escalation budgets. Skill publication gates remain owned by each skill.

Project gate_files explicitly lists local YAML files; each contains gates only.
Inline gates is an alternative, never mixed with gate_files. Resolve through the
profile loader; do not glob directories or copy every gate file into context.
Checks and criteria are resolved from gates[].checks/criteria. Work-stage checks
require project-checks reservation and passing receipts before finish; WRITES_READY
cannot waive them. Final verify repeats all required checks after all writers.

Definitions may use decision_files: explicit local bundles containing decisions only,
or inline decisions, never both. Files are pinned with the policy. The coordinator
still supplies task policy_decisions; no external decision provider is connected.

## Checks and change control

Use `project.py checks TASK.json [--final]` to populate project required_checks.
Add task acceptance checks separately. Apply [Decisions](decisions.md) when
recording applicability answers or assigning their evaluation to an agent.
Unknown is not false. The last integration task, or sole task of a one-task run,
receives final checks. The ledger rejects omitted/changed mandatory commands and
enforces declared order under the shared project-checks reservation.
Profile execution.inputs are a minimum: add exact files read by each command outside
task scope. Command identity stays fixed; required inputs cannot be removed.

Profile, connected gate files and rule bytes are frozen with configuration. Applicable normative
project documents are frozen at Implement intake; missing/drifted policy stops
dependent work. Reference documents marked `usage: reference` remain evidence,
not mutable acceptance rules. Their packet hash records the bytes actually read.
Changing policy needs explicit re-intake with preserved history, never hot reload.

Standalone review pins `project_policy` from the accepted base before reading
candidate policy. Capture it with `project.py --workspace ROOT review-policy
--revision FULL_BASE_SHA`; copy the JSON into the manifest before calculating
scope_hash. Branch/PR baseline matches base_sha. Feature review requires a prior
accepted policy snapshot with explicit provenance. Missing baseline blocks review;
candidate YAML cannot disable its own gates. Process-specific output/receipts stay
separate. Reviewing factory runtime itself requires a separate accepted tool copy;
do not execute candidate helpers as the authority checking their own changes.

## Current boundary

One local profile; no implicit discovery, external includes, network packages,
callbacks or plugin runtime. Conditional selectors use paths, not code execution.
`*` stays within one directory; `**` crosses directories. Explicit `path_regex`
retains existing exact selectors. Unsupported fields fail rather than disappearing.
Artifact headings/columns and source formats remain the existing factory formats.

Generalist, universal backend/frontend/mobile roles, vertical slices and final
independent Judge retain their contracts. Profile selection does not prove model
quality, runtime tool availability or live application verification.

Factory Python commands use `sh .factory/tools/python.sh` on macOS/Linux;
on native Windows replace that prefix with `.\.factory\tools\python.cmd`.
Use the project launcher, not system Python or shell activation. If unavailable,
report setup pending; do not install dependencies while doing an unrelated task.
