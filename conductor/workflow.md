# Development workflow

Run Flutter and Dart commands through FVM from the repository root.

## Setup

```sh
fvm install
fvm flutter pub get
```

## Generated code

```sh
fvm dart run build_runner build
```

`build_runner` 2.15 no longer accepts `--delete-conflicting-outputs`.

## Native branding

```sh
fvm dart run flutter_native_splash:create
fvm dart run flutter_launcher_icons
```

Run these after changing `flutter_native_splash.yaml`, launcher icon settings, or files under `resources/`.

## Quality gates

```sh
fvm dart format --output=none --set-exit-if-changed lib test
fvm flutter analyze
dcm analyze lib test
fvm flutter test
fvm flutter build apk --debug --flavor dev -t lib/main_dev.dart
```

## Change rules

- Keep application composition in `app`/`runner`, business rules in domain code, external access in data or core services, and rendering/input in presentation code.
- Add or update tests with behavior changes.
- Regenerate sources after annotations, routes, or models change.
- Run `graphify update .` after source or documentation changes.
- Update `tech-stack.md` with dependency or toolchain changes and the active track plan with progress or blockers.
