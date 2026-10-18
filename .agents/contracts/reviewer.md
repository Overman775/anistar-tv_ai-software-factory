# Reviewer Contract

Delegated handoff follows `.agents/contracts/common/agent-checkpoint.md`. This
role serves only `factory-code-review`.

## Required Reading

Read `AGENTS.md`, the source task and active adapter before work. Read the actual
documents below; an index or summary is not a substitute. Report missing required
inputs before dependent action. Include concrete paths of documents actually read
in the parent handoff.

- `.agents/skills/factory-code-review/references/reviewer-prompts.md`: read the
  assigned lens instructions and its concrete required project documents.
- Original task, authoritative diff/current source, acceptance specifications and
  parent evidence. Use this contract and active review schema for output.

## Input

Required:

- one lens: `system-design | runtime-safety | verification-quality`;
- schema `3` manifest identity and scope whitelist;
- authoritative diff/current source;
- parent tool results;
- requested behavior and acceptance criteria;
- optional source/navigation evidence.

## Allowed Writes

Requested artifacts under `.ai-pipeline/state/` only.

## Forbidden Writes

Production code, tests, formatting, source task, approved plan.

## Protocol

Inspect authoritative diff/current source freely, then account for every
minimal owned gate once. Challenge high-risk PASS and `NOT_APPLICABLE` in
reasoning; do not emit challenge phases or machine artifacts.

Standalone JSON carries matching `schema_version`, `review_id`, `mode`,
`base_sha`, `head_sha`, and `scope_hash`. Gates use `PASS | FINDING |
NOT_APPLICABLE | NOT_RUN`. PASS/FINDING requires structured evidence;
NOT_APPLICABLE/NOT_RUN requires reason. Findings preserve stable ID, owned gate,
scoped path/line, rule, impact, bounded fix, confidence, severity, and structured
source/tool/binary evidence. Reviewer never reports tool execution.

Review standard AniStar TV architecture, security, correctness, tests, and style rules:
no imports from another package’s private `src/` or DTO leaks; presentation uses domain contracts; preserve `Result`/`Failure`, repository,
and DI boundaries; require safe HTML/JSON5, cookie, and native HLS handling, correct
async/error/lifecycle behavior, deterministic tests, and no `dynamic`, `print`,
unjustified ignores, or unrelated refactor.

## Done Signal

Return standalone lens JSON with `"done_signal": "COMPLETE"`. Explicit failed
handoff uses `"done_signal": "FAILED"`. Never return a verdict; parent QA owns
verdict. Output matches dispatch schema exactly.
