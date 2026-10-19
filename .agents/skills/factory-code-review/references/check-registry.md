# Review Check Registry

Reviewer discovery stays open-ended. Gates below are mandatory minimum
accounting, not search boundaries.

Statuses: `PASS | FINDING | NOT_APPLICABLE | NOT_RUN`.

- `PASS` and `FINDING` require structured evidence.
- `NOT_APPLICABLE` is allowed only for conditional gates and requires reason.
- Universal gates use only `PASS | FINDING | NOT_RUN`.
- `NOT_RUN` requires concrete reason.
- Any `NOT_RUN` makes pipeline `INCOMPLETE`.

## Universal Gates

| Gate | Lens | Mandatory question |
| :--- | :--- | :--- |
| `SYS-INTENT` | `system-design` | Change matches requested intent and scope? |
| `SYS-BOUNDARIES` | `system-design` | Ownership, layers, dependencies, DI stay coherent? |
| `SYS-CONTRACTS` | `system-design` | Public/API/data contracts and callers remain correct? |
| `RUN-BEHAVIOR` | `runtime-safety` | Success, edge cases, transitions, ordering work? |
| `RUN-FAILURES` | `runtime-safety` | Errors, cancellation, retry, lifecycle recover safely? |
| `RUN-SECURITY` | `runtime-safety` | Inputs, auth, URLs, storage, logs respect trust boundaries? |
| `VER-COVERAGE` | `verification-quality` | Tests cover changed observable behavior and failures? |
| `VER-TEST-QUALITY` | `verification-quality` | Tests deterministic and assert behavior, not mocks? |
| `VER-CHANGE-SAFETY` | `verification-quality` | Regression, UI, accessibility, localization evidence sufficient? |

## Semantic gates

The schema defines 19 semantic gate IDs: nine universal and ten conditional.
These are reviewer questions, not 19 commands, tests, or automatic policy checks.
`run_tool_checks.py` records only the commands explicitly supplied by the parent;
it does not select or implement these gates. Protocol validation checks evidence
structure and identity, not whether the selected commands prove application quality.

| Lens | Universal gates | Conditional gates |
| --- | --- | --- |
| `system-design` | `SYS-INTENT`, `SYS-BOUNDARIES`, `SYS-CONTRACTS` | `SYS-DATA`, `SYS-PLATFORM`, `SYS-CLIENT` |
| `runtime-safety` | `RUN-BEHAVIOR`, `RUN-FAILURES`, `RUN-SECURITY` | `RUN-SESSION`, `RUN-PLAYER`, `RUN-ASYNC`, `RUN-UI` |
| `verification-quality` | `VER-COVERAGE`, `VER-TEST-QUALITY`, `VER-CHANGE-SAFETY` | `VER-SDK`, `VER-UI`, `VER-PLATFORM` |

## Conditional gate routing

Activation uses file paths only. No source-word risk regex. The schema owns exact
routing; pass each reviewer its resolved owned gate IDs.

| Gate | Lens | AniStar file routing |
| --- | --- | --- |
| `SYS-DATA` | `system-design` | Data/API/repository/mapper/DTO/model path segments or bounded Dart filename tokens under application, infrastructure and root tests |
| `SYS-PLATFORM` | `system-design` | Android, workspace pubspec/lockfiles, Gradle, Android APK verification and E2E tooling |
| `SYS-CLIENT` | `system-design` | Anistar/networking packages and tests, providers/overrides/transport, runner/container and relevant client/DI ADRs |
| `RUN-SESSION` | `runtime-safety` | Networking/storage, auth/session/cookies/mirrors/origin paths, environment and applicable behavior specifications |
| `RUN-PLAYER` | `runtime-safety` | Player/playback/HLS paths, player tests, fixture media and playback specifications |
| `RUN-ASYNC` | `runtime-safety` | BLoC/Cubit/provider/controller/service/repository bounded Dart filename tokens |
| `RUN-UI` | `runtime-safety` | ui_kit/app/presentation/player and tests, screens/widgets/views/focus/motion, interaction helpers and specifications |
| `VER-SDK` | `verification-quality` | Workspace pubspec/lockfiles, FVM/SDK/version scripts, build/check/generation/E2E wrappers and tooling/version documentation |
| `VER-UI` | `verification-quality` | Same UI paths as `RUN-UI` |
| `VER-PLATFORM` | `verification-quality` | Same platform paths as `SYS-PLATFORM` |

`expected_gates` is a routing aid, not an automatic policy verdict. Account for all scoped paths from the authoritative branch/PR diff, including
deletions and binary files. Feature mode uses current files only.
All lenses run universal intent/boundary/contract, behavior/failure/security and
coverage/test-quality/change-safety gates. Gate evidence may be changed `source`
lines, `binary` evidence, or recorded `tool` command coordinates.

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

Read `docs/01_architecture_principles.md`, `docs/02_project_structure.md`,
`docs/03_codestyle_and_rules.md`, `docs/05_development_and_testing.md` by lens.
Root tests are in `test/`. Android E2E additionally reads
`integration_test/README.md` and `tool/e2e/README.md`.

`static`, `tests`, `deps` are evidence containers, not invented child stages.
If `check` provides one aggregate exit status, record one command and its result.
Use explicit reason for NOT_APPLICABLE. NOT_RUN makes the protocol incomplete.
No policy-grep, graph-check, or context-compiler helper is part of this skill.

## Parent Tools

Exactly three artifacts:

| Tool ID | Parent-selected evidence |
| :--- | :--- |
| `static` | Format/analyzer/DCM relevant to scope |
| `tests` | Changed/affected unit, widget, golden tests |
| `deps` | Dependency/config validation |

Status: `PASS | FAIL | NOT_APPLICABLE | NOT_RUN`. `FAIL` derives from nonzero
exit code. `NOT_APPLICABLE` requires reason, has no commands, and does not block
completeness. `NOT_RUN` requires reason and makes pipeline incomplete. Policy/graph helpers are excluded from this skill and are not tool gates.

Command output uses `stdout_excerpt`, `stderr_excerpt`,
`stdout_truncated`, `stderr_truncated`; excerpt limit is 24 KiB per stream.

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

Choose and explain a profile against the actual change:

| Scope | `static` evidence | `tests` evidence | `deps` evidence |
| --- | --- | --- | --- |
| Applicable application changes | Record `fvm dart run melos run check` once. | Then record fixture `fvm dart run melos run test:e2e`, then `fvm dart run melos run build:android:prod:apk`, serially. | `NOT_APPLICABLE` with reason that enforced resolution was covered by the recorded aggregate; reference that command in QA. |
| Tooling-only changes | Relevant syntax/format or Git whitespace check for the selected files/view; explain any inapplicable Dart checks. | `fvm dart run melos run test:tooling` and affected isolated regressions. Dart quality-gate changes also need their root Dart regression and applicable application checks. | `NOT_APPLICABLE` when dependency inputs/behavior are untouched; otherwise run `fvm dart run melos run get` and validate affected behavior. |
| Documentation-only changes | Check changed references/command names against actual files and scripts; use Git whitespace check for the chosen view when applicable. | `NOT_APPLICABLE` with reason when executable behavior and contracts are unchanged. Run affected contract tests if documentation is consumed by tooling. | `NOT_APPLICABLE` with reason when dependency inputs/behavior are unchanged. |

For immutable branch/PR scope use `git diff --check <base-sha> <head-sha>`.
For feature mode inspect the selected current files, including intended untracked
files. Read-only reference checks can be recorded in QA with exact paths; they
are not fabricated command PASS records. For a family without any applicable
command record `NOT_APPLICABLE` with a scope-specific reason. A required command
not launched because the SDK, DCM, Python or emulators are unavailable is
`NOT_RUN`. Executed command failures retain their nonzero exit and raw evidence.
Execute application tools against the reviewed checkout bytes; if the checkout
does not match the authoritative branch/PR head or selected feature bytes, resolve
an isolated checkout or record `NOT_RUN` with that concrete blocker. Never claim
checks on another checkout establish the reviewed behavior.

Do not rerun `check` under all three containers or fabricate separate child PASS
records from its exit code. The full profile already covers static, test and
dependency work in one aggregate. Additional targeted commands are useful for
diagnosis or affected regressions; they do not replace required final checks.
`check:flutter` intentionally omits DCM and cannot substitute for full `check`.
If a check changes selected feature source bytes, refresh the manifest and
affected evidence before delivery.

Live tests and golden baseline updates require explicit scope. No automatic
upgrades, generation, fixes, iOS/Pods, CI jobs, OpenAPI or l10n
checks are introduced here. Optional graph tooling is navigation/maintenance,
not evidence that application behavior is correct.

## Advisory rule IDs and remaining review

Reviewer verification determines whether a candidate is a finding. Free-form
findings omit `rule_id`. Only a known identical `rule_id + path + line` with
matching substance is eligible for conservative auto-dedupe. The architecture
IDs `BLOCK-CROSS-FEATURE-IMPORT`, `BLOCK-PRESENTATION-API` and
`BLOCK-REPOSITORY-CONTRACT` require semantic review; regex matches do not prove
those boundaries or repository behavior.

The seven stable `REGISTRY_RULE_IDS` label findings; they are not executable
checks or additional gates. Use current AniStar semantics:

| Advisory ID | AniStar meaning and available deterministic support |
| --- | --- |
| `BLOCK-DYNAMIC` | Use `Object?` and type checks. DCM `avoid-dynamic`, analyzer strict modes and dynamic-related lints help; inspect justified interoperability boundaries and generated exclusions. |
| `BLOCK-PRINT` | Application diagnostics use injected `Logger` from app_logging. Analyzer `avoid_print` is an error and cannot be ignored; reviewers also inspect typed logging, ownership and secret/raw HTML/signed URL exposure. This is not a ban on CLI tool output. |
| `BLOCK-IGNORE` | No unjustified suppressions. Analyzer `document_ignores` and `cannot-ignore` support enforcement; reviewers assess the reason and whether it hides a real defect. |
| `BLOCK-CROSS-FEATURE-IMPORT` | Preserve package public APIs and actual architecture boundaries, including no imports from another package's private `src/`. The historical ID does not impose a blanket ban on all cross-feature imports. Analyzer `implementation_imports` and root package-boundary tests provide partial coverage. |
| `BLOCK-PRESENTATION-API` | Presentation consumes domain contracts and feature providers without reaching data/client transport implementations. Root `test/architecture/package_boundaries_test.dart` checks transitive domain/presentation/data boundaries; review consumers and behavior too. |
| `BLOCK-REPOSITORY-CONTRACT` | Repositories use `BaseRepository`, `Result`/`Failure` and established exception mapping. Inspect implementation and consumers; a file name or passing dependency-boundary test cannot prove this contract. |
| `POLICY-UNFINISHED-IMPLEMENTATION` | Report unfinished behavior that violates the requested acceptance contract, such as a reachable placeholder or unimplemented required branch. Do not treat every TODO, abstract declaration or intentional stub/fixture as a violation. |

The actual root `analysis_options.yaml` (included by workspace packages),
`dcm_global.yaml` and `test/architecture/package_boundaries_test.dart` determine
lint/test coverage and exclusions. Deterministic checks support semantic gates;
they do not decide architecture, security, test adequacy, lifecycle correctness
or approval. Those conclusions require scoped source/consumer evidence and QA.
