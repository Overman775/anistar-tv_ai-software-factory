import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../packages/features/anime/presentation/screens/anime_screen.dart';
import '../packages/features/common/presentation/widgets/error_screen.dart';
import '../packages/features/home/presentation/screens/home_screen.dart';
import '../packages/features/log_viewer/presentation/screens/log_viewer_screen.dart';
import '../packages/features/player/presentation/screens/player_screen.dart';
import 'app_config.dart';

part 'app_routes.g.dart';

/// Routes for the application
class AppRoutes {
  /// Home screen route
  static const String home = '/home';

  /// Movie screen route, relative to its parent.
  static const String anime = 'anime';

  /// Player screen route, relative to its parent.
  static const String player = 'player';

  /// Log Viewer screen route
  static const String logViewer = '/logs';
}

@TypedGoRoute<LogViewerRoute>(path: AppRoutes.logViewer)
class LogViewerRoute extends GoRouteData with $LogViewerRoute {
  const LogViewerRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => AppConfig.isDebugToolsEnabled
      ? const LogViewerScreen()
      : const ErrorScreen(text: 'Просмотр логов доступен только в debug-сборке.');
}

@TypedGoRoute<HomeRoute>(
  path: AppRoutes.home,
  routes: [
    TypedGoRoute<AnimeRoute>(
      path: AppRoutes.anime,
      routes: [TypedGoRoute<PlayerRoute>(path: AppRoutes.player)],
    ),
  ],
)
class HomeRoute extends GoRouteData with $HomeRoute {
  const HomeRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => HomeScreen(
    onAnimeTap: (anime) {
      AnimeRoute(animeId: anime.id, slug: anime.slug, title: anime.title).go(context);
    },
  );
}

class AnimeRoute extends GoRouteData with $AnimeRoute {
  final int animeId;
  final String slug;
  final String title;

  const AnimeRoute({required this.animeId, required this.slug, required this.title});

  @override
  Widget build(BuildContext context, GoRouterState state) => AnimeScreen(
    animeId: animeId,
    slug: slug,
    fallbackTitle: title,
    onEpisodeTap: (episode) {
      PlayerRoute(animeId: animeId, episodeNumber: episode.number, slug: slug, title: title).go(context);
    },
  );
}

class PlayerRoute extends GoRouteData with $PlayerRoute {
  final int animeId;
  final int episodeNumber;
  final String slug;
  final String title;

  const PlayerRoute({required this.animeId, required this.episodeNumber, required this.slug, required this.title});

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      PlayerScreen(animeId: animeId, episodeNumber: episodeNumber, title: title);
}
