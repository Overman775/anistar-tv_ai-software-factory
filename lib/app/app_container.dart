import 'package:anistar/anistar.dart';
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
import '../packages/features/player/data/repositories/anistar_playback_repository.dart';
import '../packages/features/player/player_providers.dart';
import '../packages/features/watch_history/anistar_watched_episodes_repository.dart';
import '../packages/features/watch_history/watched_episodes.dart';
import '../packages/features/watch_history/watched_episodes_repository.dart';

/// The application owns concrete bindings; features declare their interfaces.
List<Override> createAppOverrides({
  required Logger logger,
  required Uri mirrorUri,
  required SharedPreferencesStorage preferences,
  required SecureStorage secureStorage,
  AnistarMirrorManager? mirrorManager,
}) => [
  loggerProvider.overrideWithValue(logger),
  anistarMirrorManagerProvider.overrideWithValue(mirrorManager),
  if (mirrorManager == null)
    networkConfigProvider.overrideWithValue(NetworkConfig(baseUri: mirrorUri))
  else
    networkConfigProvider.overrideWith((ref) => NetworkConfig(baseUri: ref.watch(anistarActiveMirrorProvider))),
  sharedPreferencesStorageProvider.overrideWithValue(preferences),
  secureStorageProvider.overrideWithValue(secureStorage),
  watchHistoryAccountProvider.overrideWith((ref) => ref.watch(authControllerProvider).value),
  watchedEpisodesRepositoryProvider.overrideWith(
    (ref) => AnistarWatchedEpisodesRepository(ref.watch(anistarSourceProvider), ref.watch(loggerProvider)),
  ),
  authRepositoryProvider.overrideWith((ref) => AnistarAuthRepository(ref.watch(anistarAuthServiceProvider))),
  favoritesRepositoryProvider.overrideWith(
    (ref) => AnistarFavoritesRepository(ref.watch(anistarSourceProvider), ref.watch(loggerProvider)),
  ),
  catalogBrowseRepositoryProvider.overrideWith(
    (ref) => AnistarCatalogRepository(ref.watch(anistarSourceProvider), ref.watch(loggerProvider)),
  ),
  catalogRepositoryProvider.overrideWith(
    (ref) => AnistarCatalogRepository(ref.watch(anistarSourceProvider), ref.watch(loggerProvider)),
  ),
  animeRepositoryProvider.overrideWith(
    (ref) => AnistarAnimeRepository(ref.watch(anistarSourceProvider), ref.watch(loggerProvider)),
  ),
  playbackRepositoryProvider.overrideWith(
    (ref) => AnistarPlaybackRepository(ref.watch(anistarSourceProvider), ref.watch(loggerProvider)),
  ),
];
