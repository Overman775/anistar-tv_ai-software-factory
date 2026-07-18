import 'package:anistar_api/anistar_api.dart';
import 'package:anistar_tv/packages/core/api/anistar_api_config.dart';
import 'package:anistar_tv/packages/core/services/secure_storage.dart';
import 'package:anistar_tv/packages/core/services/shared_preferences_storage.dart';
import 'package:anistar_tv/packages/features/anime/data/repositories/anistar_anime_repository.dart';
import 'package:anistar_tv/packages/features/anime/domain/repositories/anime_repository.dart';
import 'package:anistar_tv/packages/features/catalog/data/repositories/anistar_catalog_repository.dart';
import 'package:anistar_tv/packages/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:anistar_tv/packages/features/player/data/repositories/anistar_playback_repository.dart';
import 'package:anistar_tv/packages/features/player/domain/repositories/playback_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

/// Global dependency injection provider
class AppProvider extends StatelessWidget {
  const AppProvider({
    super.key,
    required this.logger,
    required this.sharedPreferences,
    required this.secureStorage,
    required this.child,
  });

  static AnistarApi _createApi() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AnistarApiConfig.baseUri.toString(),
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 8),
      ),
    );

    return AnistarApi(dio: dio, interceptors: []);
  }

  final Widget child;
  final Logger logger;
  final SharedPreferencesStorage sharedPreferences;
  final SecureStorage secureStorage;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<Logger>.value(value: logger),
        Provider<SharedPreferencesStorage>.value(value: sharedPreferences),
        Provider<SecureStorage>.value(value: secureStorage),
        Provider<AnistarApi>(create: (_) => _createApi(), dispose: (_, api) => api.dio.close(force: true)),
        Provider<CatalogRepository>(
          create: (context) => AnistarCatalogRepository(context.read<AnistarApi>().getAnimeApi()),
        ),
        Provider<AnimeRepository>(
          create: (context) => AnistarAnimeRepository(context.read<AnistarApi>().getAnimeApi()),
        ),
        Provider<PlaybackRepository>(
          create: (context) =>
              AnistarPlaybackRepository(context.read<AnistarApi>().getVideoApi(), AnistarApiConfig.baseUri),
        ),
      ],
      child: child,
    );
  }
}
