# AniStar project requirements

Read `AGENTS.md` and pass its path to delegated roles.
Architect and delegated `code-explorer` read full
`docs/01_architecture_principles.md` and `docs/02_project_structure.md`.
Architecture is a quality gate, not optional context optimization. Bounded
lookup limits apply to feature-code exploration, not these canonical sources. For AniStar TV, also read `PRODUCT.md`, select
applicable decisions through `docs/adr/README.md` and specifications through
`docs/specs/README.md`, and read the concrete affected documents. TV behavior,
focus, controls, layout, and motion follow ADR-0008 and its linked specifications.
Use `docs/README.md` and owning package READMEs for other affected contracts.
Local verification commands come from `docs/melos_tooling.md`; version and Git
policy comes from `docs/vcs_guidelines.md`. Planned checks use
`fvm dart run melos run check`, fixture `test:e2e`, and
`build:android:prod:apk` sequentially. Include affected goldens in the task scope
when the expected behavior changes. Live tests require explicit scope. Planning
itself does not execute these checks.
