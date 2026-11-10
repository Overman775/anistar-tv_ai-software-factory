# Review Principles

Review a change like the senior developer who will be paged when it breaks.
Priority: correct, safe, holds under expected load, tested, fast, lean.
Every extra line needs reading, testing and maintenance.

Use these criteria for the assigned review scope; process-specific composition,
commands and output remain with the role contract. Gates are a minimum, not a
search boundary. Challenge weak PASS/NOT_APPLICABLE using actual source evidence.

## 1. Understand first

Read requested behavior, authoritative diff/source and relevant project docs.
Trace touched flow: input, transformations, storage/state, output. Inspect
callers, callees, tests, fixtures, config and exports affected by the change.
Follow [Code discovery](code-discovery.md) for search tools and source confirmation.
Changed signature, result or behavior: search every caller, including unchanged
consumers. Reading may cross diff boundaries; finding scope stays assigned.
Branch/PR finding: establish change-caused impact and anchor its cause to valid
diff evidence. Unrelated pre-existing problems do not become PR findings.

Find expected load from requirements, project docs, config and actual consumers.
State consequential assumptions; unknown
load is not an invented benchmark or permission to assume unlimited capacity.

## 2. Look for

Standalone Reviewer owns its assigned direction and mandatory criteria; evidenced discoveries outside that direction remain reportable. Judge covers all lenses.
Code Audit coordinator applies these criteria to current scoped source, including
old problems; its skill owns focus and report. Use the owning process's gates,
severity rules and output; audit does not inherit PR identity or lens schemas.

### System design: contracts and lean code

Check intent, architecture and all affected consumers. Required layers and
ownership boundaries survive simplification.

- Delete: unused options, speculative flexibility, wrappers without value.
- Reuse: existing helper/component/pattern; name the actual replacement path.
- Standard library/platform/installed dependency before new code or dependency.
- Merge near-copies that must change together; similarity alone is insufficient.
- Split unrelated responsibilities, never by line count or into pointless helpers.
- One implementation/caller is a clue, not proof an abstraction is unnecessary.

Lean finding requires concrete maintenance cost or duplication, a bounded
replacement, and behavior-preservation evidence. No bug required; style taste
or estimated line savings alone are insufficient.

### Runtime safety: bugs, risk, scale and speed

- Wrong result, crash, missed empty/zero/boundary case, broken consumer or local
  patch leaving shared root cause intact.
- Injection, missing trust checks, unsafe secrets/randomness, swallowed failures,
  wrong write order or data loss.
- Check-then-write races, repeated per-item work, unbounded state, quadratic work
  on actual large inputs, state shared incorrectly across sessions/processes.
- Material slowdown on a real hot path or device budget. Tiny speculative wins
  do not become findings; support claims with source reasoning or available
  measurements, never claim performance was measured when it was not.

### Verification quality: meaningful protection

Apply [acceptance check floor](../../gates/common/verification-rules.md). Identify which wrong result each
relevant test would detect. Check observable outcomes, failure paths and consumer
regressions; test existence, coverage percentage or a green command is not enough.
For bug fixes, inspect whether regression reproduces original failure and detects
the correction. Parent evidence stays parent evidence; no invented red run.
Mocked interactions must not hide the actual risk. Preserve independent expected
outcomes from requirements; never treat implementation as its own oracle.

## 3. Check before you report

Every defect: reachable condition/input, code behavior, consequence. Re-read
lines; confirm caller exists, value can occur and protective handling is absent.
Example: old request completes after account switch; its unchecked write puts
previous account data into the new session. Verify both ordering and missing guard.

Before declaring code unused, search tests, fixtures, config, string/dynamic
references. Missing search matches alone do not prove dead code.

An accepted `factory-debt:` limit is not automatically a defect. Check whether
current requirements or expected load exceed it. A comment alone neither proves
acceptance nor waives security, mandatory behavior or verification.

Propose smallest correct fix preserving project boundaries and authorized
behavior. No new framework/layer/config without need. Drop unverified or
insignificant candidates; factual uncertainty remains explicit.

## 4. Output

Return only high-confidence, significant, actionable findings within assigned scope.
Use assigned schema, gate ownership, finding IDs and verdict authority unchanged.
Existing description/impact fields carry condition, cause and consequence;
fix field carries bounded correction. Evidence supports each claim. Lean findings
explain unnecessary complexity and why replacement preserves behavior.
Report material unchecked areas through existing gate reasons, notes or handoff.
No extra prose in JSON-only output. Only process verdicts; no line-count target.

## Project review policy

Read selected profile rules and documents. Judge applies all relevant questions;
standalone Reviewer keeps its assigned lens. Project gates supplement the universal
minimum and never grant verdict authority or weaken evidence requirements.

AcceptanceReviewer explicitly checks missing, partial, incorrectly implemented and unrequested behavior against captured requirements. ArchitectureReviewer owns structural contracts; CodeReviewer owns behavioral safety. Missing requirements block intent approval, not other investigation.
