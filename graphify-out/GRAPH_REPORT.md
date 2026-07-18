# Graph Report - anistar_tv  (2026-07-18)

## Corpus Check
- 102 files · ~13,812 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 774 nodes · 1046 edges · 48 communities (43 shown, 5 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 9 edges (avg confidence: 0.91)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `c5cff544`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- log_viewer_bloc.dart
- video_list_screen.dart
- file_log_output.dart
- app.dart
- app_palette.dart
- Anistar TV Architecture
- app_routes.dart
- package:logger/logger.dart
- movie_screen.dart
- shared_preferences_storage.dart
- fake_log_repository.dart
- package:flutter/material.dart
- video_list_bloc_test.dart
- app_provider.dart
- StatelessWidget
- jw_player_scraper_service.dart
- @freezed
- Anistar TV Product
- video_card.dart
- tv_state_view.dart
- video_list_remote_datasource.dart
- video_list_repository_impl.dart
- movie_card.dart
- app_theme.dart
- Dart Code Metrics
- jw_player_scraper_service_test.dart
- movie_series_repository.dart
- ui_kit.dart
- home_screen.dart
- MainActivity
- Product Guidelines
- Dart and Flutter DevTools Configuration
- UI Kit Package
- package:anistar_api/anistar_api.dart
- Specification
- package:flutter_test/flutter_test.dart
- ADR-0001: Use AniStar Parser and generated OpenAPI client
- anime_card.dart
- anime_metadata_chip.dart
- StatelessWidget
- generate_anistar_api.sh
- catalog_tail.dart
- index.md
- plan.md
- ValueChanged

## God Nodes (most connected - your core abstractions)
1. `LogViewerBloc` - 13 edges
2. `CatalogBloc` - 11 edges
3. `CatalogRepository` - 10 edges
4. `CatalogMoreRequested` - 9 edges
5. `CatalogStarted` - 8 edges
6. `_CatalogScreenState` - 8 edges
7. `LogViewerState` - 8 edges
8. `AnimeRepository` - 7 edges
9. `CatalogState` - 7 edges
10. `LogViewerStartedEvent` - 7 edges

## Surprising Connections (you probably didn't know these)
- `Flutter Application Dependencies` --semantically_similar_to--> `Application Libraries`  [INFERRED] [semantically similar]
  pubspec.yaml → conductor/tech-stack.md
- `Graphify Workflow` --conceptually_related_to--> `Development Workflow`  [INFERRED]
  README.md → conductor/workflow.md
- `Flutter Code Generation Tooling` --conceptually_related_to--> `Development Workflow`  [INFERRED]
  pubspec.yaml → conductor/workflow.md
- `AnimeScreenTest` --implements--> `AnimeRepository`  [EXTRACTED]
  test/packages/features/anime/presentation/screens/anime_screen_test.dart → lib/packages/features/anime/domain/repositories/anime_repository.dart
- `CatalogBlocTest` --implements--> `CatalogRepository`  [EXTRACTED]
  test/packages/features/catalog/presentation/bloc/catalog_bloc_test.dart → lib/packages/features/catalog/domain/repositories/catalog_repository.dart

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Dependency Refresh Governance** — conductor_tracks_dependency_tv_ui_refresh_spec, conductor_tracks_dependency_tv_ui_refresh_plan, conductor_tech_stack_application_libraries, pubspec_flutter_dependencies [INFERRED 0.95]
- **Project Quality Pipeline** — conductor_workflow_quality_gates, conductor_tracks_dependency_tv_ui_refresh_acceptance, readme_quick_start [INFERRED 0.85]

## Communities (48 total, 5 thin omitted)

### Community 0 - "log_viewer_bloc.dart"
Cohesion: 0.08
Nodes (47): @immutable, Bloc, Equatable, CatalogBloc, CatalogEvent, CatalogMoreRequested, CatalogStarted, CatalogFailure (+39 more)

### Community 1 - "video_list_screen.dart"
Cohesion: 0.08
Nodes (23): ../bloc/catalog_bloc.dart, ../bloc/catalog_event.dart, ../bloc/catalog_state.dart, _bloc, build, _buildState, _columnCount, createState (+15 more)

### Community 2 - "file_log_output.dart"
Cohesion: 0.05
Nodes (42): @visibleForTesting, dart:io, dart:isolate, File?, _currentLogFileName, currentLogFileNameForTest, destroy, fileIsolate (+34 more)

### Community 3 - "app.dart"
Cohesion: 0.20
Nodes (9): ../../domain/models/playback_quality.dart, ../../domain/models/playback_session.dart, ../../domain/repositories/playback_repository.dart, _api, _baseUri, createSession, _fromApiQuality, _toApiQuality (+1 more)

### Community 4 - "app_palette.dart"
Cohesion: 0.05
Nodes (36): AppConfig, flavor, isDevFlavor, AnistarApiConfig, _configuredUrl, AppMotion, AppPalette, AppRadii (+28 more)

### Community 5 - "Anistar TV Architecture"
Cohesion: 0.10
Nodes (24): Project Context, Android Toolchain, Application Libraries, Flutter 3.44 Runtime, Local TV UI Kit, Dependency and TV UI Refresh Track, Refresh Acceptance Criteria, Flutter 3.44 Compatibility Constraints (+16 more)

### Community 6 - "app_routes.dart"
Cohesion: 0.13
Nodes (21): @TypedGoRoute, GoRouteData, anime, animeId, AnimeRoute, AppRoutes, build, episodeNumber (+13 more)

### Community 7 - "package:logger/logger.dart"
Cohesion: 0.09
Nodes (21): build, LogViewerScreen, build, _buildBody, _buildFloatingActions, _buildLoadedBody, _buildLogContent, _buildShareAction (+13 more)

### Community 8 - "movie_screen.dart"
Cohesion: 0.08
Nodes (26): Future, AnistarAnimeRepository, AnimeRepository, getAnime, animeId, AnimeScreen, _AnimeScreenState, build (+18 more)

### Community 9 - "shared_preferences_storage.dart"
Cohesion: 0.11
Nodes (17): dart:async, FlutterSecureStorage, clear, containsKey, remove, SecureStorage, _storage, clear (+9 more)

### Community 10 - "fake_log_repository.dart"
Cohesion: 0.11
Nodes (16): FileLogRepository, getLogContent, getLogFiles, getLogContent, getLogFiles, LogRepository, Object?, package:anistar_tv/packages/features/log_viewer/domain/repositories/log_repository.dart (+8 more)

### Community 11 - "package:flutter/material.dart"
Cohesion: 0.33
Nodes (5): IconData, AnimeMetadataChip, build, icon, label

### Community 12 - "video_list_bloc_test.dart"
Cohesion: 0.07
Nodes (28): animeId, build, _buildFuture, _controller, _controlsTimer, _controlsVisible, createState, dispose (+20 more)

### Community 13 - "app_provider.dart"
Cohesion: 0.18
Nodes (10): catalog_event.dart, catalog_state.dart, _loadGeneration, _logger, _onMoreRequested, _onStarted, _page, _repository (+2 more)

### Community 14 - "StatelessWidget"
Cohesion: 0.14
Nodes (13): AnimeCard, CatalogHeading, PlayerOverlay, PlayerView, build, child, TvBackdrop, build (+5 more)

### Community 15 - "jw_player_scraper_service.dart"
Cohesion: 0.18
Nodes (10): Exception, int?, AnistarApiException, _fallbackMessage, fromDio, message, retryAfter, statusCode (+2 more)

### Community 16 - "@freezed"
Cohesion: 0.05
Nodes (34): anime_details.dart, anime_episode.dart, anime_summary.dart, AnimeDetails, description, genres, id, isOngoing (+26 more)

### Community 17 - "Anistar TV Product"
Cohesion: 0.20
Nodes (11): Anistar TV Product, Modernization Goals, Product Success Criteria, Video Catalog Experience, Flutter 3.44 Modernization Track, Completed Quality and Build Gate, Generator Compatibility Finding, Modernization Implementation Plan (+3 more)

### Community 18 - "video_card.dart"
Cohesion: 0.22
Nodes (8): build, itemCount, build, ErrorScreen, text, package:flutter/material.dart, package:ui_kit/ui_kit.dart, main

### Community 19 - "tv_state_view.dart"
Cohesion: 0.25
Nodes (7): actionLabel, build, icon, message, onAction, title, TvStateView

### Community 20 - "video_list_remote_datasource.dart"
Cohesion: 0.22
Nodes (8): appLogger, main, runApplication, appLogger, main, runApplication, package:logger/logger.dart, runner/runner.dart

### Community 21 - "video_list_repository_impl.dart"
Cohesion: 0.22
Nodes (8): AnistarPlaybackRepository, createSession, PlaybackRepository, _initialize, PlayerScreen, _PlayerScreenState, ../models/playback_quality.dart, ../models/playback_session.dart

### Community 22 - "movie_card.dart"
Cohesion: 0.25
Nodes (7): ../../domain/models/anime_episode.dart, autofocus, build, episode, EpisodeCard, onFocusChanged, onTap

### Community 23 - "app_theme.dart"
Cohesion: 0.29
Nodes (6): app_palette.dart, AppTheme, _createTheme, darkTheme, lightTheme, static final ThemeData

### Community 24 - "Dart Code Metrics"
Cohesion: 0.33
Nodes (6): BLoC Lint Rules, Dart Code Metrics, Flutter Lint Rules, flutter_lints, Static Analysis Configuration, Strict Dart Analysis

### Community 25 - "jw_player_scraper_service_test.dart"
Cohesion: 0.18
Nodes (10): app_routes.dart, GoRouter, _logger, rootNavigatorKey, router, NavigatorState, package:anistar_tv/packages/features/common/presentation/widgets/error_screen.dart, package:anistar_tv/utils/logger/logging_navigator_observer.dart (+2 more)

### Community 26 - "movie_series_repository.dart"
Cohesion: 0.05
Nodes (42): AnimeApi, AnistarApi, ../app/app.dart, ../app/app_provider.dart, ../../domain/models/anime_details.dart, ../../domain/models/anime_page.dart, ../../domain/models/anime_summary.dart, ../../domain/repositories/anime_repository.dart (+34 more)

### Community 27 - "ui_kit.dart"
Cohesion: 0.29
Nodes (6): ./src/theme/app_palette.dart, ./src/theme/app_theme.dart, ./src/widgets/tv_backdrop.dart, ./src/widgets/tv_focusable.dart, ./src/widgets/tv_progress_view.dart, ./src/widgets/tv_state_view.dart

### Community 28 - "home_screen.dart"
Cohesion: 0.05
Nodes (40): Duration, apiValue, PlaybackQuality, availableQualities, manifestUri, PlaybackSession, requestedQuality, selectedQuality (+32 more)

### Community 30 - "Product Guidelines"
Cohesion: 0.67
Nodes (3): Product Guidelines, Safe Viewer Diagnostics, TV-First User Experience

### Community 36 - "package:anistar_api/anistar_api.dart"
Cohesion: 0.22
Nodes (8): didPop, didPush, didRemove, didReplace, _logger, LoggingNavigatorObserver, NavigatorObserver, package:flutter/widgets.dart

### Community 37 - "Specification"
Cohesion: 0.20
Nodes (7): AniStar Parser OpenAPI and playback integration, Decisions, Implementation plan, Acceptance criteria, Objective, Scope, Specification

### Community 38 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.06
Nodes (32): app_router.dart, FocusNode, App, _appRouter, _AppState, build, createState, initState (+24 more)

### Community 39 - "ADR-0001: Use AniStar Parser and generated OpenAPI client"
Cohesion: 0.07
Nodes (24): ADR-0001: AniStar Parser и OpenAPI-клиент, Контекст, Последствия, Решение, Статус, Архитектурные решения, API и HLS, Endpoint parser (+16 more)

### Community 40 - "anime_card.dart"
Cohesion: 0.25
Nodes (7): anime, autofocus, build, _buildImageError, _buildImagePlaceholder, onFocusChanged, onTap

### Community 41 - "anime_metadata_chip.dart"
Cohesion: 0.06
Nodes (39): Completer, fake_catalog_repository.dart, fake_log_repository.dart, AnistarCatalogRepository, CatalogRepository, getPage, ../models/anime_page.dart, package:anistar_tv/packages/features/anime/domain/models/anime_details.dart (+31 more)

### Community 42 - "StatelessWidget"
Cohesion: 0.25
Nodes (7): anime_metadata_chip.dart, ../../domain/models/anime_screen_data.dart, AnimeHero, build, data, onPlayFirstEpisode, package:cached_network_image/cached_network_image.dart

### Community 43 - "generate_anistar_api.sh"
Cohesion: 0.33
Nodes (5): output_path, project_root, required_version, schema_path, generate_anistar_api.sh script

### Community 45 - "catalog_tail.dart"
Cohesion: 0.33
Nodes (5): build, CatalogTail, error, onRetry, VoidCallback?

### Community 49 - "ValueChanged"
Cohesion: 0.33
Nodes (5): build, HomeScreen, onAnimeTap, package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart, ValueChanged

## Knowledge Gaps
- **398 isolated node(s):** `logger`, `_appRouter`, `createState`, `initState`, `build` (+393 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `PlaybackSession` connect `home_screen.dart` to `video_list_bloc_test.dart`?**
  _High betweenness centrality (0.018) - this node is a cross-community bridge._
- **Why does `CatalogRepository` connect `anime_metadata_chip.dart` to `log_viewer_bloc.dart`, `video_list_screen.dart`, `movie_series_repository.dart`, `app_provider.dart`?**
  _High betweenness centrality (0.017) - this node is a cross-community bridge._
- **Why does `LogViewerBloc` connect `log_viewer_bloc.dart` to `package:logger/logger.dart`?**
  _High betweenness centrality (0.014) - this node is a cross-community bridge._
- **What connects `logger`, `_appRouter`, `createState` to the rest of the system?**
  _398 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `log_viewer_bloc.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.08081632653061224 - nodes in this community are weakly interconnected._
- **Should `video_list_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.08333333333333333 - nodes in this community are weakly interconnected._
- **Should `file_log_output.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.046511627906976744 - nodes in this community are weakly interconnected._