# Specification

## Objective

Bring every direct package to the newest Flutter 3.44-compatible resolution, restore valid native branding generation, and make the primary TV interface visually consistent without changing content flows.

## Scope

- Upgrade root and nested UI kit dependency locks.
- Add current `flutter_native_splash` configuration backed by existing brand assets.
- Regenerate Android splash and launcher resources.
- Introduce shared TV palette, spacing, radius, motion, backdrop, progress, and state components.
- Refresh catalog cards, series cards, loading/error/empty states, and Log Viewer.
- Preserve keyboard/remote navigation and existing domain/data contracts.
- Add widget coverage for the new shared states and cards.

## Acceptance criteria

1. `flutter pub outdated` reports all direct dependencies at the newest resolvable versions.
2. Native splash and launcher generation complete successfully.
3. Flutter Analyzer and DCM report no findings.
4. All unit, BLoC, and widget tests pass.
5. A development Android APK builds successfully.
6. Graphify and project documentation describe the refreshed UI and native tooling.
