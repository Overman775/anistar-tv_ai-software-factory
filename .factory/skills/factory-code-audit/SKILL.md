---
name: factory-code-audit
description: "Read-only quality audit of an existing project, package or subsystem: bugs, safety, load, tests, speed and unnecessary complexity. Use for audit this codebase, find bloat, what can we simplify, audit the project, find issues, simplify the module. PR/branch change review uses factory-code-review; marked debt inventory uses factory-code-debt."
---

# Factory Code Audit

Read `.factory/contracts/common/project-policy.md`. Before dependent work, resolve
project inputs with `sh .factory/tooling/bin/python.sh .factory/tooling/bin/project.py context --process code-audit --audience coordinator`
(add `--scope PATH` for every known scope path). Read the returned instructions and
actual applicable documents. Unknown scope retains obligations; it never waives them.


Audit the whole repo like the senior developer who just inherited it and
will be paged when it breaks. Correct, safe, holds under load, tested, fast,
lean. Every extra line must be read, tested and fixed later. Give the requested
report in full.

Read [communication](../../contracts/common/communication.md) for language and
format; [shared review criteria](../../contracts/common/review-principles.md) for
professional checks, project reading routes and finding evidence.

## Boundaries and routing

- Current-source audit, including old problems; no diff required. Coordinator
  performs one audit, no mandatory reviewer team, Code Review gates or schemas.
- PR/branch/diff review: use [Code Review](../factory-code-review/SKILL.md).
  "Simplify this module" stays here with lean-only focus. Full quality audit is
  default; name any requested narrower focus. Marked debt inventory:
  [Code Debt](../factory-code-debt/SKILL.md).
- Read and report only. No code/test/config/prompt edits, formatting, generation,
  dependency changes or automatic fixes. Return report in chat; persist only
  when requested or required by an authorized handoff, using an unoccupied path.
- Read project instructions before commands. Run applicable non-mutating checks
  only within available permissions; record actual commands/results. Missing
  tools limit evidence, not permission to install them. Audit is not release approval.

## 1. Map first

- Resolve named folder, package or repo. No target: current project repo.
  Unknown project root or conflicting targets: clarify before dependent work.
- Read `AGENTS.md`, README, dependencies, build/deploy config, entry points and
  tests. Follow selected profile reading routes and actual architecture, behavior
  and verification contracts.
- Establish current source: HEAD if available, dirty/untracked scope, and content
  hashes for cited files. Never reset/stash changes. Recheck cited bytes before
  final report/handoff; changed evidence must be revalidated or marked stale.
- Trace main flows end to end: inputs, state/storage, output. Read high-risk
  paths fully: auth, data writes, background work, shared/session state.
- Establish expected load from project evidence. State material assumptions.
- Large repo: go deep where errors cost most, not file by file. List inspected
  flows and uninspected areas. A sampled audit cannot certify the whole repo.
- Skip dependencies, build output and generated source by default. Read generated
  contracts when needed to understand behavior; fix recommendations target their
  maintained source. Read docs/config as evidence. Changes to their semantics or
  factory instructions require explicit scope; do not propose unrelated rewrites.

## 2. Look for

Apply all shared criteria to scoped current source; narrow only when requested.
The common contract owns review criteria; the profile owns project constraints.

1. **Bug:** wrong result, crash, edge case, inconsistent callers or duplicated rules.
2. **Risk:** security hole, trust-boundary failure, swallowed error or data loss.
3. **Scale:** races, repeated work, unbounded state or cost exceeding expected load.
4. **Missing test:** risky logic without a test that detects its failure.
   Apply [acceptance](../../gates/common/verification-rules.md); one test is a floor,
   never a ceiling or substitute for required project suites.
5. **Speed:** actual slow paths; distinguish source reasoning from measurements.
6. **Lean:** delete, reuse, standard library/platform, unnecessary abstraction,
   merge or split by responsibility. Preserve project layers and observable behavior.

## 3. Check before you report

Use shared finding verification: concrete condition/cause/consequence for defects;
concrete redundancy, bounded replacement and preservation evidence for lean findings.
Search all relevant callers, tests, fixtures, config and dynamic references before
calling code unused. No style taste, vague worries or line-count targets.

Check a documented shortcut against present requirements and expected load.
`factory-debt:`, `shortcut:` and older `ponytail:` comments are evidence of a
stated limit, not automatic proof of approval. A complete ledger belongs to Code Debt.

Propose the smallest correct fix. Preserve validation, data-loss handling, security,
accessibility, required tests/logging and project boundaries. Preserve the project's documented lifecycle, state and resource invariants.

## 4. Output

Reader's language under communication. Start with what the repo/subsystem does
in two or three sentences, scope/focus, source identity and assumed load.

Findings, most important first; omit empty groups:

- **Must fix:** bug, security, data loss, failure at expected load.
- **Should fix:** risky code without a meaningful test, real slowness, duplication,
  mixed responsibilities or code without a current purpose.
- **Nice to have:** concrete smaller improvements with demonstrated value.

Number findings across groups, at most 20. Disclose count and importance of
confirmed findings omitted by the cap; never present the cap as complete coverage.
Keep numbers stable within the report and handoff.
Each finding: path/current line, evidence, and four parts:
what this is; problem; bounded fix; consequence if skipped.
Include required verification. Do not quote secrets in evidence.

Example (language follows reader; code stays exact):

2. **Orders land on the wrong day** (`billing/close_day.py:L40-52`)
   - **What this is:** At midnight this job closes the day and bills all orders of that day.
   - **Problem:** It takes "today" from the server clock, which runs in UTC. An order placed
     at 00:30 in Berlin is billed on the day before.
   - **Fix:** Compute the day once in the shop's time zone:
     `datetime.now(ZoneInfo("Europe/Berlin")).date()`. One line, nothing else changes.
   - **If we skip it:** Late orders show the wrong date, and accounting fixes them by hand.

End with:
- `Verdict:` health of inspected scope or what to fix first; incomplete when
  material evidence is unavailable/stale. No PR approval or release verdict.
- `Lean:` estimated reductions only when supported; otherwise unknown.
- `Checked:` inspected flows and actually executed commands with cwd/exit code.
- `Not checked:` skipped areas, unavailable checks and limits.

No findings: say none found in inspected scope, state checks and limits.
Never equate missing evidence, sampling or unavailable tools with a clean whole repo.

## Apply selected findings

If fixes are authorized, hand selected findings to
[Factory Implement](../factory-implement/SKILL.md) through its normal source intake:
report/inline findings, scope, current revision/hashes, evidence, required behavior,
preserved invariants and verification needs. Revalidate source before edits.
Bug correction uses task guidance; behavior-preserving simplification uses refactor
guidance. Material behavior/API/architecture gaps follow source intake/planning.
Do not route every audit fix as refactor. Existing authorization suffices within
its scope; this handoff adds no confirmation requirement. Commit, push and
publication follow existing explicit authorization rules.
