# Developer Contract

Delegated handoff follows `.agents/contracts/common/agent-checkpoint.md`. For long work,
emit progress after target inspection, production write, and verification
boundaries when practical; parent validates checkpoints and explicit failures.

## Required Reading

Read `AGENTS.md`, the source task and active adapter before work. Read the actual
documents below; an index or summary is not a substitute. Report missing required
inputs before dependent action. Include concrete paths of documents actually read
in the parent handoff.

- Applicable sections of `docs/01_architecture_principles.md`,
  `docs/02_project_structure.md` and `docs/03_codestyle_and_rules.md`.
- Affected specifications and ADRs selected through `docs/specs/README.md` and
  `docs/adr/README.md`; owning package READMEs when present.
- Locked task and execution brief; `docs/melos_tooling.md` for delegated commands.

## Input

- Locked execution source: self-contained request/ticket/task or approved plan.
- `.ai-pipeline/state/pipeline.md` and optional `execution-brief.md`.
- Changed-file scope.
- Current correction evidence during a delegated fix pass.

## Allowed Writes

- Production files inside source boundary.
- Required generated files for touched package.
- Requested execution reports under `.ai-pipeline/state/`.

## Forbidden Writes

- Tests.
- Approved plan or source task.
- `implementation-plan.md`.
- Unrelated files or semantic scope expansion.

## Execution Rules

- Preserve unrelated/user changes.
- Follow project architecture and codestyle.
- Reuse established helpers/components/patterns before adding abstractions.
- No imports from another package’s private `src/`, `dynamic`, `print`, unjustified
  ignores, or adjacent refactor; presentation uses domain contracts.
- Implement smallest complete change inside locked boundary.
- Missing technical placement may be resolved through active skill rules;
  missing product, behavior, API, architecture, acceptance, or scope semantics
  must be reported to parent without invention.

## Done Signal

- `IMPLEMENTED`
- `NEEDS_PLANNING`
- `SOURCE_DRIFT`
- `BLOCKED_STATIC_FAILURE`
- `BLOCKED_TOOL_ERROR`

## Evidence

- Source kind/path/hash checked.
- Files changed and commands run.
- Every preflight check required by active skill records `cwd`, exact command,
  and exit code. Developer fixes failures in owned files before returning
  `IMPLEMENTED`; unrelated pre-existing failures are identified explicitly.
- Reports start with `run_id` and `source_hash`.
- Exact directive mode is reported. Explicit no-plan authorizes only bounded
  direct choices; delegated planning routes material choices to parent.
- `NEEDS_PLANNING` names exact behavior/scope/architecture/API/acceptance gap,
  proves all Material Semantic Gap Gate conditions, and reports directive mode.
  Teamlead decides terminal gap versus delegated Factory Planning handoff.
