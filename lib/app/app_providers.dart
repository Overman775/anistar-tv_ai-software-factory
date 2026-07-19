import 'package:api/api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../packages/core/core.dart';
import '../packages/features/anime/data/repositories/anistar_anime_repository.dart';
import '../packages/features/anime/domain/repositories/anime_repository.dart';
import '../packages/features/catalog/data/repositories/anistar_catalog_repository.dart';
import '../packages/features/catalog/domain/repositories/catalog_repository.dart';
import '../packages/features/player/data/repositories/anistar_playback_repository.dart';
import '../packages/features/player/domain/repositories/playback_repository.dart';

/// App-composition providers. Feature code depends on abstractions only.
final loggerProvider = Provider<Logger>((ref) => throw UnimplementedError('Logger must be overridden by the runner.'));

final networkConfigProvider = Provider<NetworkConfig>(
  (ref) => throw UnimplementedError('NetworkConfig must be overridden by the runner.'),
);

final sharedPreferencesStorageProvider = Provider<SharedPreferencesStorage>(
  (ref) => throw UnimplementedError('SharedPreferencesStorage must be overridden by the runner.'),
);

final secureStorageProvider = Provider<SecureStorage>(
  (ref) => throw UnimplementedError('SecureStorage must be overridden by the runner.'),
);

final dioProvider = Provider<Dio>((ref) {
  final dio = DioClient.create(config: ref.watch(networkConfigProvider), logger: ref.watch(loggerProvider));
  ref.onDispose(() => dio.close(force: true));

  return dio;
});

final httpClientProvider = Provider<HttpClient>((ref) {
  final client = HttpClient(config: ref.watch(networkConfigProvider));
  ref.onDispose(client.close);

  return client;
});

final animeClientProvider = Provider<AnimeClient>((ref) => AnimeClient(ref.watch(dioProvider)));
final videoClientProvider = Provider<VideoClient>((ref) => VideoClient(ref.watch(dioProvider)));

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => AnistarCatalogRepository(ref.watch(animeClientProvider), ref.watch(loggerProvider)),
);

final animeRepositoryProvider = Provider<AnimeRepository>(
  (ref) => AnistarAnimeRepository(ref.watch(animeClientProvider), ref.watch(loggerProvider)),
);

final playbackRepositoryProvider = Provider<PlaybackRepository>(
  (ref) => AnistarPlaybackRepository(
    ref.watch(videoClientProvider),
    ref.watch(networkConfigProvider).baseUri,
    ref.watch(loggerProvider),
  ),
);
