---
name: factory-code-simplify
description: "Use when user asks to simplify AniStar TV code or review for over-engineering: simplify code, code simplification, find bloat, what can we delete, reduce complexity, reuse existing helpers, Ponytail review, Simplify review, упрости код, ревью на упрощение, что можно удалить, найди лишний код, раздутый код, переусложнение. Read-only simplification findings by default. Avoid normal correctness/security review uses factory-code-review, implementation uses factory-implement."
---

# Factory Code Simplify

Read-only simplification audit for AniStar TV code. Find removable complexity, duplicate logic, avoidable custom code, missed reuse, dead flexibility, and invalid `factory-debt`.

## Core Rules

- Do not edit production code, tests, docs, prompts, configs, generated files.
- If user asks to apply fixes, first produce simplification report, then route
  selected findings to `factory-implement` `refactor` workflow with
  `Source: simplify-driven`. Hand off the report as
  `.ai-pipeline/state/simplify-report.md` or inline when short. Include scope, source revision/hash and behavior constraints in the handoff; execution owns edits, tests and review. Existing user authorization to apply selected fixes is sufficient; commit, push and publication still require explicit instruction.
- Default output is findings only.
- Scope is simplification only. Do not perform normal correctness, security, test coverage, or style review unless issue directly creates unnecessary complexity.
- Preserve behavior. Suggest only changes that keep features, outputs, validation, error handling, security, accessibility, and tests intact.
- Prefer clarity over code golf. Dense one-liners, nested ternaries, clever abstractions, or hidden control flow are not simplification.
- Clean result is valid. If code is already lean, say so.

## Required Reading

Read before execution:

1. `AGENTS.md`
2. Relevant project docs from `docs/01_architecture_principles.md`, `docs/02_project_structure.md`, `docs/03_codestyle_and_rules.md`, `docs/05_development_and_testing.md`, `lib/packages/ui_kit/README.md`
3. Scope files or diff
4. Select behavior specifications through `docs/specs/README.md` and decisions through `docs/adr/README.md`; read affected package READMEs. For TV focus/controls/motion read ADR-0008 and linked specifications. Use graphify according to `AGENTS.md`.
5. Existing nearby helpers, components, extensions, mappers, repositories, widgets before claiming duplication

## Modes

| User asks | Mode | Scope |
| :--- | :--- | :--- |
| simplify changed code, review simplification, Ponytail review | `diff` | current branch/PR diff |
| simplify feature/module/folder | `scope` | requested path or package |
| audit project for bloat, what can we delete from repo | `audit` | ranked top findings, cap 20 |
| collect debt, factory-debt ledger | `debt` | `factory-debt` markers only |

If target ambiguous, ask one concise question.

## Factory Minimality Ladder

Use this ladder for each candidate finding:

1. Does this code need to exist at all?
2. Is there already a helper, extension, component, mapper, repository pattern, or widget in this codebase?
3. Does Dart, Flutter, UI Kit, Melos/FVM, or platform API already cover it?
4. Does an already-installed dependency cover it without adding new ownership?
5. Can the same behavior be expressed with fewer files or less control flow while staying readable?
6. Only then suggest a local rewrite.

The ladder shortens solutions, not investigation. Read the touched flow first.

## Tags

Use these tags in findings:

- `delete`: dead code, unused flexibility, speculative feature, wrapper with no value.
- `reuse`: existing project helper, extension, mapper, component, or pattern replaces custom code.
- `dart`: Dart core/collection/language feature replaces custom implementation.
- `flutter-native`: Flutter widget/API replaces custom implementation.
- `uikit`: existing UI Kit component/token/pattern replaces local UI code.
- `project-pattern`: existing CleanArch/BLoC/repository/navigation/error-handling pattern replaces bespoke logic.
- `yagni`: abstraction with one implementation, config nobody sets, layer with one caller, scaffold for later.
- `shrink`: same behavior, less nesting/duplication/control flow, still readable.
- `debt`: `factory-debt` marker missing clear ceiling or revisit trigger.

## Boundaries

Never suggest removing:

- trust-boundary validation;
- error handling that prevents data loss or bad UX;
- security checks;
- accessibility basics;
- tests that protect non-trivial logic;
- logging required by product/project conventions;
- session/origin invalidation, late-response guards, focus restoration, or player resource cleanup;
- useful abstraction with multiple real callers or clear ownership boundary.

Never simplify `.md`, `.yaml`, `.json`, `.env`, `.agents/**`, prompts, generated files, or configuration semantics unless user explicitly scopes those files.

Generated Dart is out of scope by default: skip `.freezed.dart`, `.g.dart`, generated localization files, `assets.gen.dart`, files under `generate/`. Mention skipped generated files in `Notes` only when relevant.

## Process

1. Resolve mode and scope.
2. Collect diff or requested files.
3. Record source diff before/after the read-only audit; preserve existing user changes.
4. Filter generated/read-only files before analysis unless user explicitly scoped them.
5. Search for existing reuse options before writing findings.
6. Classify candidates with tags.
7. Drop weak findings unless impact and replacement are concrete.
8. Rank findings by highest simplification value and lowest behavior risk.
9. Print final Russian report.

For `audit` mode, sample broadly but cap final report at top 20 findings.

For `debt` mode, scan source files for `factory-debt:` comments. Flag entries without both:

- why current shortcut is acceptable;
- concrete revisit trigger.

## Finding Shape

Each finding must include:

- tag;
- file and line if known; omit line when unknown, never use line `0`;
- what is overbuilt;
- replacement;
- behavior risk: `low | medium | high`;
- estimated saving: `small | medium | large`;
- verification needed.

Do not report vague findings like "this may be simpler" without a replacement.

## Output

Use this final format:

```text
Factory Code Simplify

Mode: {diff|scope|audit|debt}
Scope: {branch/path/module}
Verdict: LEAN | CAN_SIMPLIFY | OVERBUILT

Findings:
1. [{tag}] {file}:{line}
   Cut: {what is unnecessary}
   Replace: {concrete replacement}
   Risk: {low|medium|high}
   Save: {small|medium|large}
   Verify: {command/test/check}

Net:
- lines: -{rough_count_or_unknown}
- deps: -{count_or_0}
- abstractions: -{count_or_0}

Notes:
- {scope limits, skipped files, or why clean}
```

If no findings:

```text
Factory Code Simplify

Mode: {mode}
Scope: {scope}
Verdict: LEAN
Findings: none
Net: 0
Notes: Код уже достаточно прямой. Упрощение ради упрощения не нужно.
```
