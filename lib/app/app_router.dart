import 'package:anistar_tv/packages/features/common/presentation/widgets/error_screen.dart';
import 'package:anistar_tv/utils/logger/logging_navigator_observer.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../packages/features/favorites/presentation/screens/favorites_screen.dart';
import '../packages/features/home/presentation/screens/home_screen.dart';
import '../packages/features/movie/presentation/screens/movie_screen.dart'; // Added import
import '../packages/features/player/presentation/screens/player_screen.dart'; // Added import
import '../packages/features/video_list/domain/models/video_model.dart'; // Added import
import '../utils/logger/logger.dart';
import 'app_routes.dart';

/// Router configuration for the application
class AppRouter {
  /// Router instance
  late final GoRouter router;

  /// Constructor
  AppRouter() {
    router = GoRouter(
      initialLocation: AppRoutes.home, // Updated initial location
      observers: [LoggingNavigatorObserver()], // Add the observer
      routes: [
        GoRoute(
          path: AppRoutes.home, // Path: /home
          builder:
              (context, state) => HomeScreen(
                onVideoTap: (video) {
                  // Navigate to the movie screen under home
                  context.go('${AppRoutes.home}/${AppRoutes.movie}', extra: video);
                },
              ),
          routes: _buildMovieAndPlayerRoutes(AppRoutes.home),
        ),
        GoRoute(
          path: AppRoutes.favorites, // Path: /favorites
          builder: (context, state) => const FavoritesScreen(), // Removed onVideoTap
          routes: _buildMovieAndPlayerRoutes(AppRoutes.favorites),
        ),
      ],
      errorBuilder: (context, state) {
        logger.e('Routing error: ${state.error}', error: state.error);
        return ErrorScreen(text: state.error?.message ?? 'Router error');
      },
    );
  }

  List<RouteBase> _buildMovieAndPlayerRoutes(String parentPath) {
    return [
      GoRoute(
        path: AppRoutes.movie, // Relative path: 'movie'
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! VideoModel) {
            logger.w('Movie route called without VideoModel in extra under $parentPath');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // Go to the parent path if data is missing
              context.go(parentPath);
            });
            return const ErrorScreen(text: 'Movie data is missing');
          }
          return MovieScreen(
            video: extra,
            onMovieTap: (tappedMovie) {
              final playerData = {'title': tappedMovie.title, 'videoUrl': tappedMovie.videoUrl};
              // Use push to navigate to the player, ensuring the path is correctly formed
              context.push('$parentPath/${AppRoutes.movie}/${AppRoutes.player}', extra: playerData);
              logger.i('Tapped movie: ${tappedMovie.title}, navigating to player under $parentPath.');
            },
          );
        },
        routes: [
          GoRoute(
            path: AppRoutes.player, // Relative path: 'player'
            builder: (context, state) {
              final playerData = state.extra as Map<String, String>?;
              if (playerData == null || !playerData.containsKey('title') || !playerData.containsKey('videoUrl')) {
                logger.w(
                  'Player route called without valid title/videoUrl Map in extra under $parentPath/${AppRoutes.movie}',
                );
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  // Go to the parent movie path if data is missing
                  context.go(
                    '$parentPath/${AppRoutes.movie}',
                    extra: state.extra,
                  ); // Attempt to preserve movie extra if possible
                });
                return const ErrorScreen(text: 'Player data is missing');
              }
              return PlayerScreen(title: playerData['title']!, videoUrl: playerData['videoUrl']!);
            },
          ),
        ],
      ),
    ];
  }
}
