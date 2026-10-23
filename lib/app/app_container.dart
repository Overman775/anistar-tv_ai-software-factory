import 'package:anistar/html.dart';
import 'package:anistar/providers.dart';
import 'package:app_logging/app_logging.dart';
import 'package:app_logging/providers.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:networking/networking.dart';
import 'package:networking/providers.dart';
import 'package:storage/providers.dart';
import 'package:storage/storage.dart';

import '../packages/features/anime/anime_providers.dart';
import '../packages/features/anime/data/repositories/anistar_anime_repository.dart';
import '../packages/features/auth/auth_providers.dart';
import '../packages/features/auth/data/anistar_auth_repository.dart';
import '../packages/features/catalog/catalog_providers.dart';
import '../packages/features/catalog/data/repositories/anistar_catalog_repository.dart';
import '../packages/features/favorites/data/anistar_favorites_repository.dart';
import '../packages/features/favorites/favorites_providers.dart';
import '../packages/features/log_viewer/data/repositories/file_log_repository.dart';
import '../packages/features/log_viewer/log_viewer_providers.dart';
import '../packages/features/player/data/repositories/anistar_playback_repository.dart';
import '../packages/features/player/player_providers.dart';
import '../packages/features/search/data/anistar_search_repository.dart';
import '../packages/features/search/data/local_search_history_repository.dart';
import '../packages/features/search/search_providers.dart';
import '../packages/features/watch_history/data/repositories/anistar_watched_episodes_repository.dart';
import '../packages/features/watch_history/watch_history_providers.dart';
import '../packages/features/watch_history/watched_episodes.dart';
import 'app_config.dart';

/// The application owns concrete bindings; features declare their interfaces.
List<Override> createAppOverrides({
  required Logger logger,
  required Uri mirrorUri,
  required SharedPreferencesStorage preferences,
  required SecureStorage secureStorage,
  AnistarMirrorManager? mirrorManager,
}) => [
  loggerProvider.overrideWithValue(logger),
  logRepositoryProvider.overrideWith((ref) => FileLogRepository()),
  anistarMirrorManagerProvider.overrideWithValue(mirrorManager),
  if (mirrorManager == null)
    networkConfigProvider.overrideWithValue(
      NetworkConfig(baseUri: mirrorUri, loggablePaths: AppConfig.networkLoggablePaths),
    )
  else
    networkConfigProvider.overrideWith(
      (ref) =>
          NetworkConfig(baseUri: ref.watch(anistarActiveMirrorProvider), loggablePaths: AppConfig.networkLoggablePaths),
    ),
  sharedPreferencesStorageProvider.overrideWithValue(preferences),
  secureStorageProvider.overrideWithValue(secureStorage),
  favoritesAccountProvider.overrideWith((ref) {
    final account = ref.watch(authAccessProvider).account;
    final origin = ref.watch(anistarActiveMirrorProvider).origin;

    return account == null ? null : '$origin|$account';
  }),
  watchHistoryAccountProvider.overrideWith((ref) {
    final account = ref.watch(authAccessProvider).account;
    final origin = ref.watch(anistarActiveMirrorProvider).origin;

    return account == null ? null : '$origin|$account';
  }),
  watchedEpisodesRepositoryProvider.overrideWith(
    (ref) => AnistarWatchedEpisodesRepository(
      ref.watch(anistarClientProvider),
      ref.watch(loggerProvider),
      () => ref.read(authAccessProvider).account,
    ),
  ),
  searchRepositoryProvider.overrideWith(
    (ref) => AnistarSearchRepository(ref.watch(anistarClientProvider), ref.watch(loggerProvider)),
  ),
  searchHistoryRepositoryProvider.overrideWith((ref) {
    final origin = ref.watch(anistarActiveMirrorProvider).origin;
    final account = ref.watch(authAccessProvider).account;
    final identity = account == null ? 'guest' : 'account:$account';

    return LocalSearchHistoryRepository(
      preferences,
      scope: '${Uri.encodeComponent(origin)}.${Uri.encodeComponent(identity)}',
    );
  }),
  authRepositoryProvider.overrideWith(
    (ref) => AnistarAuthRepository(ref.watch(anistarClientProvider), ref.watch(loggerProvider)),
  ),
  favoritesRepositoryProvider.overrideWith(
    (ref) => AnistarFavoritesRepository(
      ref.watch(anistarClientProvider),
      ref.watch(loggerProvider),
      () => ref.read(authAccessProvider).account,
    ),
  ),
  catalogBrowseRepositoryProvider.overrideWith(
    (ref) => AnistarCatalogRepository(ref.watch(anistarClientProvider), ref.watch(loggerProvider)),
  ),
  catalogRepositoryProvider.overrideWith(
    (ref) => AnistarCatalogRepository(ref.watch(anistarClientProvider), ref.watch(loggerProvider)),
  ),
  animeRepositoryProvider.overrideWith(
    (ref) => AnistarAnimeRepository(
      ref.watch(anistarClientProvider),
      ref.watch(loggerProvider),
      () => ref.read(authAccessProvider).canUseAccount,
    ),
  ),
  playbackRepositoryProvider.overrideWith(
    (ref) => AnistarPlaybackRepository(
      ref.watch(anistarClientProvider),
      ref.watch(loggerProvider),
      () => ref.read(authAccessProvider).canUseAccount,
    ),
  ),
];
