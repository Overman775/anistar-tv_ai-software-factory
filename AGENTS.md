# AniStar TV

Flutter Android TV/mobile. CleanArch. Riverpod DI, BLoC, native HLS. FVM, Dart pub workspace, Melos.

## Agents

anistar-flutter-update → SDK/dependencies
impeccable → UI/UX
graphify → architecture/flow

factory-planning → factory-decompose → factory-implement
factory-code-review / factory-code-simplify / factory-github → focused workflows

## BLOCK

- No `dynamic` → `Object?` + type checks.
- No `print` → `Logger`; no credentials, cookies, raw HTML or signed URLs in logs.
- No unjustified ignores or imports from another package’s private `src/`; presentation uses domain contracts.
- Repositories → `BaseRepository`, `Result`/`Failure`.
- No manual generated-file edits.

## Exec

- Clarify missing behavior/scope; resolve routine choices from project patterns.
- Minimal changes; preserve user work; no adjacent refactors.
- Read actual applicable docs; pass their concrete paths to delegated roles; verify before claiming success.
- TV layout/focus/controls/motion → ADR-0008 and linked specs; update regression tests together.
- Commits, push, releases and publication require an explicit request.

## Workflow (fvm)

- Commands and gates: `docs/melos_tooling.md`; versions: `docs/vcs_guidelines.md`.
- Bootstrap: `fvm dart run melos bootstrap --enforce-lockfile`.
- Generate: `fvm dart run melos run generate`; Flutter/Gradle/codegen sequentially.
- Checks: `check` → fixture `test:e2e` → `build:android:prod:apk` through `fvm dart run melos run`.
- Tests in root `test/`; single: `fvm flutter test <file> --reporter=failures-only`.
- Golden updates and live tests require explicit scope; report fresh results and blockers.

## Docs

- **Product:** `PRODUCT.md`
- **Arch/DI:** `docs/01_architecture_principles.md`
- **Decisions:** `docs/adr/README.md`
- **Specifications:** `docs/specs/README.md`
- **Structure:** `docs/02_project_structure.md`
- **Rules:** `docs/03_codestyle_and_rules.md`
- **Network/playback:** `docs/04_network_and_playback.md`
- **Testing:** `docs/05_development_and_testing.md`
- **UI Kit:** `lib/packages/ui_kit/README.md`
- **Core:** `infrastructure/core/README.md`
- **Other docs/packages:** `docs/README.md`

## Style

Concise, direct. Preserve exact commands, paths and technical terms.

## graphify

- `/graphify` → read the installed skill first.
- If `graphify-out/graph.json` exists, start codebase questions with `graphify query`; use `path`/`explain` for relationships/concepts. Dirty graph files do not justify skipping it.
- Graph absent → targeted source search. Wiki index → broad navigation; full report only when needed.
- After code/tooling changes: `graphify update .`.
