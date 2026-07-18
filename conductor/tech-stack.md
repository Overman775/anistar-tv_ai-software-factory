# Technical stack

## Runtime

- Flutter 3.44.2, pinned with FVM.
- Dart 3.12.2.
- Android application with Kotlin/Gradle host code.

## Application libraries

- go_router with generated typed routes.
- flutter_bloc for catalog state and provider for application composition.
- dio and generated packages/anistar_api for AniStar Parser OpenAPI.
- video_player for native HLS playback.
- shared_preferences and flutter_secure_storage for persistence.
- Local path package lib/packages/ui_kit for TV palette, spacing, themes, backdrops and reusable states.

Exact dependency constraints are authoritative in pubspec.yaml and the nested UI kit pubspec.yaml.

## Quality and tooling

- flutter_lints with strict casts, inference and raw types.
- DCM for common, Flutter and BLoC-specific rules.
- flutter_test, bloc_test and HTTP contract mocks.
- build_runner for typed routes; the generated API package runs its own built_value_generator.
- OpenAPI Generator 7.23.0 for a reproducible parser client.
- flutter_native_splash and flutter_launcher_icons for generated Android branding resources.
- Graphify 0.9.19 for the project knowledge graph.

## Android toolchain

- Java 17.
- Android NDK 28.2.13676358.
- Gradle 8.14, Android Gradle Plugin 8.11.1 and Kotlin 2.2.20.
- AGP 9 migration is a separate Android-host evaluation.
- Native splash uses the existing logo without AI alteration and a dark TV-safe background.

## Generated sources

Files ending in .g.dart and the whole packages/anistar_api client are generated. Regenerate rather than hand-edit them.
