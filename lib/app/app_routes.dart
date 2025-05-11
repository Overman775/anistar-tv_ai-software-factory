import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../packages/features/home/presentation/screens/home_screen.dart';
import '../packages/features/log_viewer/presentation/screens/log_viewer_screen.dart'; // Added import
import '../packages/features/movie/presentation/screens/movie_screen.dart';
import '../packages/features/player/presentation/screens/player_screen.dart';

part 'app_routes.g.dart';

/// Routes for the application
class AppRoutes {
  /// Home screen route
  static const String home = '/home'; // Updated path

  /// Favorites screen route
  static const String favorites = '/favorites'; // Path remains the same

  /// Movie screen route, relative to its parent (e.g., home or favorites)
  static const String movie = 'movie'; // Now expects MovieModel as extra, relative path

  /// Player screen route, relative to its parent (e.g., home or favorites)
  static const String player = 'player'; // Path for the player, relative path

  /// Log Viewer screen route
  static const String logViewer = '/logs'; // Top-level route for log viewer
}

@TypedGoRoute<LogViewerRoute>(path: AppRoutes.logViewer)
class LogViewerRoute extends GoRouteData {
  const LogViewerRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const LogViewerScreen();
  }
}

@TypedGoRoute<HomeRoute>(
  path: AppRoutes.home,
  routes: [
    TypedGoRoute<MovieRoute>(path: AppRoutes.movie, routes: [TypedGoRoute<PlayerRoute>(path: AppRoutes.player)]),
  ],
)
class HomeRoute extends GoRouteData {
  const HomeRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return HomeScreen(
      onVideoTap: (video) {
        MovieRoute(title: video.title, videoUrl: video.videoUrl).go(context);
      },
    );
  }
}

class MovieRoute extends GoRouteData {
  const MovieRoute({required this.title, required this.videoUrl});

  final String title;
  final String videoUrl;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return MovieScreen(
      title: title,
      videoUrl: videoUrl,
      onMovieTap: (tappedMovie) {
        PlayerRoute(title: title, videoUrl: videoUrl).go(context);
      },
    );
  }
}

class PlayerRoute extends GoRouteData {
  const PlayerRoute({required this.title, required this.videoUrl});

  final String title;
  final String videoUrl;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return PlayerScreen(title: title, videoUrl: videoUrl);
  }
}
