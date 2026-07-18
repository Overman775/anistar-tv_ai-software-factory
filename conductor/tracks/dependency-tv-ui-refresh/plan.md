# Implementation plan

- [x] Audit direct, development, transitive, and nested UI kit dependencies.
- [x] Upgrade all compatible dependency resolutions.
- [x] Restore and generate Android native splash resources.
- [x] Regenerate Android launcher icons.
- [x] Add shared TV design tokens and reusable backdrop/state components.
- [x] Refresh catalog, series, error, loading, empty, and log viewer widgets.
- [x] Add widget tests for shared states and focusable cards.
- [x] Run final code generation, quality gates, tests, and Android build.
- [x] Refresh documentation and Graphify outputs.

## Compatibility note

`build_runner 2.15.2` is published but not currently resolvable with the Flutter 3.44 dependency graph; 2.15.1 is the newest compatible resolution. The Android host remains on Flutter 3.44's supported AGP 8.11.1 baseline.
