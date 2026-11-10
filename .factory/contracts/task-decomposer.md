# Task Decomposer Contract

Owner: factory-decompose only. Read the assigned source and actual required project
documents; worker handoff follows common/worker-rules.md.

## Input

Locked approved plan, decomposition-source.json, exact assigned artifact paths,
source tuple, capability/AC coverage and relevant existing evidence.

## Allowed writes

Exact assigned staging envelopes and Markdown, their temporary siblings, and the
assigned checkpoint under `.factory/memory/staging/checkpoints/`; never approved plan
or published tasks.

## Result

Saved generation envelope under generation-contract; NEEDS_PLANNING or source blocker when meaning is missing.
Do not invent behavior, revise plan meaning, publish tasks or start implementation.
The coordinator validates artifacts and owns approval/publication/retry budgets.
Execution procedure and mandatory reference routes: `.factory/roles/task-decomposer.md`.
