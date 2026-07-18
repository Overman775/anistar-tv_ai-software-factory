# Specification

## Objective

Modernize the existing Anistar TV codebase around Flutter 3.44.2 while preserving current user-visible behavior and establishing enforceable quality, architecture, test, and documentation standards.

## Scope

- Pin FVM and SDK constraints to Flutter 3.44.2 / Dart 3.12.2.
- Install and configure the current Graphify tooling and build a project index.
- Upgrade direct dependencies and generators to compatible maintained versions.
- Resolve generator, compile, analyzer, linter, and DCM findings.
- Add a meaningful initial automated test suite.
- Refactor high-coupling presentation and composition code toward explicit module boundaries.
- Remove confirmed commented-out, dead, duplicate, or obsolete artifacts.
- Replace generic/stale documentation with project-specific setup and architecture guidance.

## Non-goals

- Redesigning the product UI or changing content providers without a compatibility need.
- Adding cloud services, analytics, release signing, or deployment credentials.
- Changing production endpoints or scraping behavior without tests that preserve the current contract.

## Acceptance criteria

1. `.fvmrc` pins Flutter 3.44.2 and all SDK constraints accept Dart 3.12 / Flutter 3.44.
2. `flutter pub get` and `build_runner build` succeed.
3. Dart format check, Flutter analyzer, and DCM report no actionable findings in owned source and tests.
4. Automated tests exist and pass for core parsing/state/storage-independent behavior.
5. A development Android APK builds from `lib/main_dev.dart`.
6. README and architecture documentation match the implemented layout and commands.
7. Graphify outputs are refreshed after final source changes, with local cache/state ignored.
8. Pre-existing uncommitted user work is preserved.
