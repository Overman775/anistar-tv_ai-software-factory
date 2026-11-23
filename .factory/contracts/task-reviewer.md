# Task Reviewer Contract

Owner: factory-decompose only. Read the assigned source and actual required project
documents; worker handoff follows common/worker-rules.md.

## Input

Locked approved plan, decomposition-source.json, exact assigned artifact paths,
source tuple, capability/AC coverage and relevant existing evidence.

## Allowed writes

Only in repair mode, edit assigned staging task Markdown and task_result.json.
Source lock, approved plan, code and published tasks stay read-only.

## Result

Identity-bound review JSON under `.factory/gates/skills/decompose/review-contract.md`; one repair and focused recheck, or NEEDS_PLANNING/source blocker.
Do not invent behavior, revise plan meaning, publish tasks or start implementation.
The coordinator validates artifacts and owns approval/publication/retry budgets.
Execution procedure and mandatory reference routes: `.factory/roles/task-reviewer.md`.
