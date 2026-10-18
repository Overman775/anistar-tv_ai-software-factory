---
name: factory-code-review
description: Review AniStar TV changes with three semantic lenses and local parent-owned tools.
---

# Factory Code Review

Read-only flow:

```text
scope/diff -> parent local tools -> 3 lens reviewers -> QA
-> thin structural validator -> current report
```

## Boundaries

- Parent owns scope, manifest, and Static/Tests/Deps execution.
- Reviewers freely inspect source, then account for minimal owned gates.
- QA attacks high-risk PASS/NOT_APPLICABLE and proposed verdict in reasoning.
- Validator checks structure and causal evidence. Shared workspace is trusted.
- No policy-grep, graph-check, or context-compiler helper is included.
- No external executor, handoff, receipt, signature, key, risk-keyword
  activation, machine challenge phase, candidate/exclusion ledger, severity
  inference, or machine root-cause protocol.
- Only schema `3` current artifacts and current report are accepted.

## Required Reading

1. Active project instructions and runtime adapter.
2. `.agents/contracts/common/agent-checkpoint.md`.
3. `.agents/contracts/reviewer.md`.
4. `references/scope-and-modes.md`.
5. `references/check-registry.md`.
6. `references/reviewer-prompts.md`.
7. `references/qa-and-reporting.md`.

## Execution

1. Resolve branch, PR, or feature scope. Persist schema `3` manifest and
   authoritative diff for branch/PR.
2. Parent selects and executes applicable local Static/Tests/Deps commands with
   `run_tool_checks.py` against the reviewed checkout bytes (see check registry).
   Result contains raw `argv/cwd/exit_code` plus bounded
   stdout/stderr excerpts. Inapplicable family records `NOT_APPLICABLE`.
3. Capture requested behavior and acceptance criteria from source before dispatch.
   Lens identity is `review_id + base_sha + head_sha + scope_hash + canonical
   lens`; lock is that identity plus authoritative diff. Pass intent context to
   exactly three independent canonical `reviewer` agents in one review run:
   `system-design`, `runtime-safety`, `verification-quality`. Respect actual
   concurrency: sequential invocations or waves are valid.
   If intent context is unavailable, `SYS-INTENT` is `NOT_RUN`; it cannot guess PASS.
   Apply `.agents/contracts/common/agent-checkpoint.md#same-run-role-continuation`:
   valid `COMPLETE` terminalizes lens; retry only same `FAILED`/invalid lens once;
   never restart healthy lenses. Exhausted recovery preserves healthy outputs and
   returns partial `INCOMPLETE` without synthesized findings. New identity uses
   fresh lenses. QA remains parent-owned.
4. QA reads original source, tool failures, and lens outputs. It returns verdict,
   optional added findings, explained severity overrides/manual merges, and notes.
5. Run `validate_review_protocol.py`. Publish only its JSON and Markdown.

## Status

- Missing/malformed artifact, missing gate, invalid evidence, source drift, or `NOT_RUN`
  gives `INCOMPLETE`.
- Tool `NOT_APPLICABLE` requires reason and does not block completeness.
- Universal semantic gates cannot be `NOT_APPLICABLE`; conditional gates can.
- Executed tool `FAIL` remains complete evidence but requires `NEEDS_WORK`.
- QA-added finding uses a current routed gate and full normal finding evidence;
  malformed QA additions make pipeline incomplete while valid findings remain visible.
- Critical/High findings prohibit `APPROVE`.
- Valid findings remain visible under `INCOMPLETE`; malformed findings do not.
- Auto-dedupe only identical known `rule_id + path + line` with matching
  substance. Free-form findings never auto-merge.
- Severity is reviewer judgment. QA override requires written reason.
- Report internals show only failing executed commands with bounded, escaped evidence.

## Validation Command

```bash
python3 .agents/skills/factory-code-review/scripts/validate_review_protocol.py \
  --manifest .ai-pipeline/state/review-manifest.json \
  --lens-output .ai-pipeline/state/review-system-design.json \
  --lens-output .ai-pipeline/state/review-runtime-safety.json \
  --lens-output .ai-pipeline/state/review-verification-quality.json \
  --tool-result .ai-pipeline/state/review-tool-static.json \
  --tool-result .ai-pipeline/state/review-tool-tests.json \
  --tool-result .ai-pipeline/state/review-tool-deps.json \
  --qa-output .ai-pipeline/state/review-qa.json \
  --output .ai-pipeline/state/review-validation.json \
  --report-output .ai-pipeline/state/review-final.md
```

Keep the report local. GitHub publication, commits, push, merge and releases
require an explicit user request.
