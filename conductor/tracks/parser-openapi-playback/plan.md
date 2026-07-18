# Implementation plan

- [x] Audit the parser architecture, API contract, Flutter guidance, and current app flow.
- [x] Regenerate and validate the parser OpenAPI JSON/YAML without contract drift.
- [x] Vendor the canonical schema and generate the initial `dart-dio` client.
- [x] Add reproducible generation tooling and generated-code lint boundaries.
- [x] Introduce API configuration, error mapping, repositories, and domain models.
- [x] Rebuild catalog pagination and anime detail/episode loading around the API.
- [x] Replace WebView playback with native HLS playback and TV controls.
- [x] Remove legacy scraping services, packages, models, and routes.
- [x] Add repository, BLoC/controller, routing, widget, and playback tests.
- [x] Run generation, formatting, Analyzer, DCM, tests, and Android build.
- [x] Synchronize README, architecture/context docs, track status, and Graphify.

## Decisions

- `openapi-generator` 7.23.0 with the stable `dart-dio` generator is pinned for regeneration.
- Generated models are transport types only; feature code depends on immutable application-owned models.
- `manifest_path` is session data and is never persisted or replaced with an upstream CDN URL.
- The native player uses the parser's HLS proxy so manifest resources retain the backend security boundary.
