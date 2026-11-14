# AniStar exploration context

## Project Context

You work in a Flutter modular monorepo (Melos) using:

- **State:** `flutter_bloc` (BLoC/Cubit), `flutter_riverpod` (DI)
- **Routing:** `go_router`
- **Network/playback:** `dio`, HTML/JSON5 parsing, shared cookie session, native HLS
- **Arch:** Clean Architecture; features in `lib/packages/features/`, shared infrastructure in `infrastructure/`, UI Kit in `lib/packages/ui_kit/`

When analyzing, follow the Clean Architecture layers: **Presentation → Domain → Data**.

## Required Reading (read EVERY time before analysis)

1. `docs/01_architecture_principles.md` — Clean Architecture layers, DI strategy, BLoC rules, Provider lifecycle
2. `docs/02_project_structure.md` — folder structure, feature module layout, file naming

## Optional Reading (read when relevant to the task)

- `docs/03_codestyle_and_rules.md` — naming conventions, anti-patterns, member order
- `docs/04_network_and_playback.md` — HTML/JSON5, DTOs, cookies and native HLS contracts
- `docs/specs/README.md` and `docs/adr/README.md` — select applicable specifications and decisions, then read their concrete files
- `docs/adr/0008-youtube-tv-interaction-reference.md` and its linked specifications — TV layout, focus, controls and motion
- `docs/melos_tooling.md` and `docs/vcs_guidelines.md` — commands and versions
- Affected package README — public API and ownership
