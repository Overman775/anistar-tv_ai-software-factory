# Specification

## Objective

Replace the app's legacy AniStar HTML and JW Player scraping with the typed AniStar Parser API, generated from its current OpenAPI contract, and deliver a TV-first catalog, anime detail, episode selection, and HLS playback flow.

## Scope

- Vendor the parser's canonical `openapi.json` and generate a reproducible `dart-dio` client.
- Keep generated DTOs behind repositories and application-owned domain models.
- Configure the parser base URL through `--dart-define=ANISTAR_API_URL=...` with a local Android-emulator default.
- Load paginated anime, anime metadata, and episodes from the generated client.
- Start every playback through `getPlaybackInfo` and resolve its fresh `manifest_path` against the API base URL.
- Replace the embedded web player with a native HLS-capable player and TV remote controls.
- Remove legacy scraper dependencies and obsolete models after their replacement is covered.
- Refresh the catalog/detail/player UX, error handling, documentation, and tests.

## Acceptance criteria

1. The vendored schema matches a freshly generated parser schema and the generated client can be reproduced with one documented command.
2. No application data source scrapes AniStar HTML or constructs direct AniStar/CDN playback URLs.
3. Catalog pagination, anime detail, episodes, playback quality fallback, retry, and remote navigation are represented in tests.
4. The player consumes the parser manifest URL and restores system UI/orientation safely when closed.
5. Flutter Analyzer, DCM, tests, and a development Android APK build all pass.
6. Project context, Graphify outputs, and operational instructions describe the new API boundary.
