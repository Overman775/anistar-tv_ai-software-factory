# AniStar review policy

Expected load: catalogue size, scrolling, request repetition, source/account switches, playback and device limits.

Preserve deterministic tests and DI boundaries; prevent DTO leaks and unrelated
refactoring. Detailed project norms and domain reading follow below.

- `system-design`: read `docs/01_architecture_principles.md` and
  `docs/02_project_structure.md` fully, affected specifications selected through
  `docs/specs/README.md`, relevant decisions through `docs/adr/README.md`, and
  owning package READMEs. Trace contracts and consumers, DI and real layer
  boundaries; do not infer correctness from file placement alone.
- `runtime-safety`: read `docs/03_codestyle_and_rules.md` and affected behavior
  specifications. Use the additional reading below for
  network/session, client transport, TV/mobile/motion, repositories and logging.
  Check late async answers, disposal, transport,
  cookies/origin transitions and sanitized logging.
- `verification-quality`: read `docs/05_development_and_testing.md`, acceptance
  specifications, related tests and helpers in root `test/`; Android E2E reads
  `integration_test/README.md` and `tool/e2e/README.md`. Commands come from
  `docs/melos_tooling.md`; use fresh run evidence supplied with the task. Check oracle
  strength and regressions for behavior, rather than implementation mirroring.
  Assess UI, accessibility and localization evidence for the affected behavior
  under `VER-CHANGE-SAFETY`, using existing AniStar contracts and capabilities.

## Criteria and additional reading

For standalone Code Review, use the assigned criteria from the pinned review
policy. Judge and Audit use their own process contracts with these project norms.
Factory Review criteria live in
`.factory/factory_tooling/project/review_definition.py`; project questions and path selectors
live in `.factory/project/gates/skills/code-review.yaml`. Do not maintain a second
catalog here or recalculate routing from this prose. AcceptanceReviewer owns intent
and requirement coverage; each reviewer answers its assigned criteria and may report
other evidenced defects. Protocol validation does not prove semantic correctness.

For `VER-CHANGE-SAFETY`, assess regression, UI, accessibility and localization
against the actual changed behavior and existing product contracts. This does
not introduce localization generation, a new localization framework or a new
command gate; unavailable applicable evidence must be reported explicitly.

| Changed area | Additional reading and review |
| --- | --- |
| `lib/packages/ui_kit`, presentation, focus, motion | `lib/packages/ui_kit/README.md`, `docs/adr/0008-youtube-tv-interaction-reference.md`, `docs/specs/06_tv_interaction.md`, `docs/specs/08_motion.md`; D-pad, OK/hold/Back, restoration, loading/empty/error, reduced motion and player lifecycle. Mobile uses its separate `docs/specs/10_mobile_interaction.md` contract |
| player/playback/native HLS | `docs/04_network_and_playback.md`, affected playback specification selected through `docs/specs/README.md`; lifecycle/disposal, late events, separate native transport |
| client/DTO/DI/transport | `docs/adr/0009-single-anistar-client-and-dio.md`, `docs/adr/0010-normalized-anistar-contract.md`, `infrastructure/anistar/README.md`; consumer contracts, `AnistarClient`/`HtmlAnistarClient`, HTML/JSON5, cookies and mirrors; do not assume an owned REST API |
| auth/session/cookies/origin/mirrors/storage | `docs/04_network_and_playback.md`, `infrastructure/networking/README.md`, `infrastructure/storage/README.md`, `infrastructure/anistar/README.md`; logout, account/origin switches, late responses, cleanup |
| core/repositories | `infrastructure/core/README.md`; `BaseRepository`, `Result`/`Failure`, domain contracts and package public APIs |
| logging | `infrastructure/app_logging/README.md`, `docs/adr/0005-centralize-runtime-logging.md`; never include credentials, cookies, passwords, raw HTML or signed URLs |
| Android/build/SDK/pubspec/lockfiles | docs/melos_tooling.md and docs/vcs_guidelines.md; tooling scripts, architecture tests, Android fixture E2E and production APK as applicable |

## AniStar deterministic commands

Run from the frozen checkout root, serially, using current `pubspec.yaml`,
`scripts/with_python.sh`, `scripts/test_tooling.sh` and `docs/melos_tooling.md` as
the command authorities. Melos owns quality commands; Lefthook owns Git hooks.
The table describes available coverage; it does not claim that any command has
run or passed.

| Command | Actual coverage |
| --- | --- |
| `fvm dart run melos run check` | SDK pin and enforced lockfile; maintained Dart format; strict Flutter analyzer; fatal DCM style/warnings; unit/widget/architecture coverage; golden comparison; Python tooling; app version agreement. Fail-fast aggregate. |
| `fvm dart run melos run format:check` | Maintained Dart formatting without writes; Melos preparation verifies the SDK pin and enforced lockfile. |
| `fvm dart run melos run analyze` | Flutter analyzer with `--no-pub --fatal-infos`, after Melos verifies the SDK pin and enforced lockfile. |
| `fvm dart run melos run dcm` | DCM over `lib infrastructure test integration_test tool/quality`, with `--fatal-style --fatal-warnings`, after Melos verifies the SDK pin and enforced lockfile. |
| `fvm dart run melos run test:unit` | Central root `test/` unit/widget/architecture suite excluding golden tags, concurrency 4, coverage for app and all six workspace packages. |
| `fvm dart run melos run test:goldens` | Central golden comparison, concurrency 1; no baseline updates. |
| `fvm dart run melos run test:tooling` | Python quality/APK verifier, E2E runner, version and Factory regressions; graphify regressions only when its local interpreter is configured. |
| `fvm dart run melos run get` | Workspace resolution with `--enforce-lockfile`; no dependency upgrade or vulnerability verdict. |
| `fvm dart run melos run version:check --include-private` | Stable X.Y.Z+N in the root pubspec; no version bump. |
| `fvm dart run melos run test:e2e` | TV then mobile Android fixture suites on prepared separate emulators. |
| `fvm dart run melos run build:android:prod:apk` | Production release APK with AOT freshness verification; local build, no publication. |

`test:coverage` aliases the same coverage-enabled suite as `test:unit`; do not
run both as independent coverage checks. Default test seed is `20261010`, with
`ANISTAR_TEST_SEED` override. Root `test/` owns package tests: do not invent
per-package test discovery, `melos exec` test loops or LCOV merging. A targeted
regression uses `fvm flutter test <root-test-path> --reporter=failures-only`.

Choose and explain commands against the actual change. These columns describe
coverage, not required artifact families; record each selected command once:

| Scope | Static checks | Tests and build | Dependencies |
| --- | --- | --- | --- |
| Applicable application changes | Record `fvm dart run melos run check` once. | Then record fixture `fvm dart run melos run test:e2e`, then `fvm dart run melos run build:android:prod:apk`, serially. | No separate command when the recorded aggregate already covers enforced resolution; explain this choice and reference the aggregate. |
| Tooling-only changes | Relevant syntax/format or Git whitespace check for the selected files/view; explain any inapplicable Dart checks. | `fvm dart run melos run test:tooling` and affected isolated regressions. Dart quality-gate changes also need their root Dart regression and applicable application checks. | Explain omission when dependency inputs/behavior are untouched; otherwise run `fvm dart run melos run get` and validate affected behavior. |
| Documentation-only changes | Check changed references/command names against actual files and scripts; use Git whitespace check for the chosen view when applicable. | Explain omission when executable behavior and contracts are unchanged. Run affected contract tests if documentation is consumed by tooling. | Explain omission when dependency inputs/behavior are unchanged. |

For immutable branch/PR scope use `git diff --check <base-sha> <head-sha>`.
For feature mode inspect the selected current files, including intended untracked
files. Read-only reference checks can be recorded in QA with exact paths; they
are not fabricated command PASS records. Explain omitted checks in the command
selection reason. A selected mandatory command cannot be replaced with `NOT_APPLICABLE`. A required command
not launched because the SDK, DCM, Python or emulators are unavailable is
`NOT_RUN`. Executed command failures retain their nonzero exit and raw evidence.
Execute application tools against the reviewed checkout bytes; if the checkout
does not match the authoritative branch/PR head or selected feature bytes, resolve
an isolated checkout or record `NOT_RUN` with that concrete blocker. Never claim
checks on another checkout establish the reviewed behavior.

Do not fabricate separate child PASS records from the aggregate exit code.
The full profile already covers static, test and dependency work in one aggregate. Additional targeted commands are useful for
diagnosis or affected regressions; they do not replace required final checks.
`check:flutter` intentionally omits DCM and cannot substitute for full `check`.
If a check changes selected feature source bytes, refresh the manifest and
affected evidence before delivery.

Live tests require explicit scope. Review golden updates against the expected
behavior and affected paths of the current task. No automatic upgrades,
generation, fixes, iOS/Pods, CI jobs, OpenAPI or l10n
checks are introduced here. Optional graph tooling is navigation/maintenance,
not evidence that application behavior is correct.

## Project review norms

These norms apply through project instructions. Criteria define mandatory answers;
review remains open to other evidenced defects. No advisory ID registry is needed.

| Norm | AniStar meaning and available deterministic support |
| --- | --- |
| Dynamic typing | Use `Object?` and type checks. DCM `avoid-dynamic`, analyzer strict modes and dynamic-related lints help; inspect justified interoperability boundaries and generated exclusions. |
| Logging | Application diagnostics use injected `Logger` from app_logging. Analyzer `avoid_print` is an error and cannot be ignored; reviewers also inspect typed logging, ownership and secret/raw HTML/signed URL exposure. This is not a ban on CLI tool output. |
| Suppressions | No unjustified suppressions. Analyzer `document_ignores` and `cannot-ignore` support enforcement; reviewers assess the reason and whether it hides a real defect. |
| Package boundaries | Preserve package public APIs and actual architecture boundaries, including no imports from another package's private `src/`. This does not impose a blanket ban on all cross-feature imports. Analyzer `implementation_imports` and root package-boundary tests provide partial coverage. |
| Presentation boundaries | Presentation consumes domain contracts and feature providers without reaching data/client transport implementations. Root `test/architecture/package_boundaries_test.dart` checks transitive domain/presentation/data boundaries; review consumers and behavior too. |
| Repository contracts | Repositories use `BaseRepository`, `Result`/`Failure` and established exception mapping. Inspect implementation and consumers; a file name or passing dependency-boundary test cannot prove this contract. |
| Unfinished required behavior | Report unfinished behavior that violates the requested acceptance contract, such as a reachable placeholder or unimplemented required branch. Do not treat every TODO, abstract declaration or intentional stub/fixture as a violation. |

The actual root `analysis_options.yaml` (included by workspace packages),
`dcm_global.yaml` and `test/architecture/package_boundaries_test.dart` determine
lint/test coverage and exclusions. Deterministic checks support semantic gates;
they do not decide architecture, security, test adequacy, lifecycle correctness
or approval. Those conclusions require scoped source/consumer evidence and QA.
