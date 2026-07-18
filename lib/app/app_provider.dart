import 'package:api/api.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../packages/core/core.dart';
import '../packages/features/anime/data/repositories/anistar_anime_repository.dart';
import '../packages/features/anime/domain/repositories/anime_repository.dart';
import '../packages/features/catalog/data/repositories/anistar_catalog_repository.dart';
import '../packages/features/catalog/domain/repositories/catalog_repository.dart';
import '../packages/features/player/data/repositories/anistar_playback_repository.dart';
import '../packages/features/player/domain/repositories/playback_repository.dart';

/// Global dependency injection provider
class AppProvider extends StatelessWidget {
  const AppProvider({
    required this.apiBaseUri,
    required this.logger,
    required this.sharedPreferences,
    required this.secureStorage,
    required this.child,
    super.key,
  });

  final Uri apiBaseUri;
  final Widget child;
  final Logger logger;
  final SharedPreferencesStorage sharedPreferences;
  final SecureStorage secureStorage;

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      Provider<Logger>.value(value: logger),
      Provider<SharedPreferencesStorage>.value(value: sharedPreferences),
      Provider<SecureStorage>.value(value: secureStorage),
      Provider<NetworkConfig>.value(value: NetworkConfig(baseUri: apiBaseUri)),
      Provider<Dio>(
        create: (context) => DioClient.create(config: context.read<NetworkConfig>(), logger: logger),
        dispose: (_, dio) => dio.close(force: true),
      ),
      Provider<HttpClient>(
        create: (context) => HttpClient(config: context.read<NetworkConfig>()),
        dispose: (_, client) => client.close(),
      ),
      Provider<AnimeClient>(create: (context) => AnimeClient(context.read<Dio>())),
      Provider<VideoClient>(create: (context) => VideoClient(context.read<Dio>())),
      Provider<CatalogRepository>(create: (context) => AnistarCatalogRepository(context.read<AnimeClient>(), logger)),
      Provider<AnimeRepository>(create: (context) => AnistarAnimeRepository(context.read<AnimeClient>(), logger)),
      Provider<PlaybackRepository>(
        create: (context) =>
            AnistarPlaybackRepository(context.read<VideoClient>(), context.read<NetworkConfig>().baseUri, logger),
      ),
    ],
    child: child,
  );
}
