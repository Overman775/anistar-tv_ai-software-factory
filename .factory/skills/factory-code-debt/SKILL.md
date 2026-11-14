---
name: factory-code-debt
description: "Collect explicit technical-debt comments into a read-only ledger of limits and revisit triggers. Use for list deferred work, debt ledger, factory-debt, collect technical debt, deferred compromises. Includes legacy shortcut/ponytail markers. Unmarked code problems belong to factory-code-audit; PR review belongs to factory-code-review."
---

# Factory Code Debt

Read `.factory/contracts/common/project-policy.md`. Before dependent work, resolve
project inputs with `sh .factory/tooling/bin/python.sh .factory/tooling/bin/project.py context --process code-debt --audience coordinator`
(add `--scope PATH` for every known scope path). Read the returned instructions and
actual applicable documents. Unknown scope retains obligations; it never waives them.


Every deliberate shortcut has a limit and a reason to revisit it. Collect marked
decisions into one ledger so a deferral cannot quietly become permanent.

Read [communication](../../contracts/common/communication.md). One-shot inventory
of explicit markers, not a search for every defect or proof the project has no debt.

## Scan

1. Read project `AGENTS.md`; resolve named path or current project repo by default.
   No established project root: clarify. Default markers: `factory-debt:`,
   `shortcut:`, older `ponytail:`. Use a user's custom marker when specified;
   report the actual marker set and scope.
2. Find literal marker candidates, including untracked and hidden source files;
   skip `.git`, ignored dependencies, build output and caches. From scope root:

   ```bash
   rg --hidden --line-number --no-heading --glob '!.git' -F -e 'factory-debt:' -e 'shortcut:' -e 'ponytail:' .
   ```

   Do not require a comment prefix on the marker's line: block comments may span
   lines; SQL/HTML and other languages use different delimiters. Step 3 decides
   whether each candidate is a real comment.
   Custom marker: search the exact supplied token, adding no colon or syntax
   (`rg -F -- 'MARKER' .`, with the same hidden/ignore flags). Pass it as a literal
   argument; never interpolate user text as shell code or an unescaped regex.
   Exit 1 with no diagnostics means no matches; errors/inaccessible files mean
   incomplete scan. Retrieve truncated output before claiming a complete ledger.
3. Inspect each match and adjacent comment lines. Keep real deferrals only;
   exclude string literals, documentation examples, copied instructions and
   keyboard-shortcut descriptions. A text hit is a candidate, not a ledger row.
   One actual marker produces one row, grouped by file; no top-20 cap.
4. Extract stated decision, ceiling and revisit trigger exactly. Missing details
   stay unknown; never invent a deadline, owner, approval or implementation plan.
   Owner requested: use available blame/history as attribution, not proof of ownership.

## Output

Scope, marker set and scan completeness first. One row per marker:

`<file>:<line> | marker | decision | ceiling | revisit trigger | flags`

Retain exact paths/markers; reader-facing prose follows communication.
Flags: `no-limit` for missing ceiling; `no-trigger` for no actionable revisit
condition or upgrade path. "Later" alone is not a trigger. Preserve original
wording when a useful normalized summary would otherwise imply new facts.

End with totals: markers, missing limits, missing triggers; then skipped areas
and scan errors. No hits after a complete scan: "No marked debt in scanned scope."
An incomplete scan never becomes an empty clean ledger.

## Boundaries

Read and report only. No marker edits, automatic closure, tickets or production
changes. Comment presence does not authorize the compromise. Unmarked defects
and whether limits are already exceeded require [Code Audit](../factory-code-audit/SKILL.md).

Return ledger in chat by default. An explicit save request authorizes writing
the requested report; use an unoccupied path when none specified. No extra
confirmation for already authorized saving. Saving creates no recurring monitor.

If the user authorizes addressing selected debt, pass exact rows/current source
and known limits to [Factory Implement](../factory-implement/SKILL.md) through
normal source intake. The marker alone is not an execution specification:
resolve missing desired behavior through existing intake/planning rules.
Implementation owns code, tests and review; audit/debt adds no approval gate.
