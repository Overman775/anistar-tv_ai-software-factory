import 'package:anistar_tv/utils/logger/logging_navigator_observer.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../packages/features/favorites/presentation/screens/favorites_screen.dart';
// Import new feature screens
import '../packages/features/home/presentation/screens/home_screen.dart';
import '../packages/features/movie/presentation/screens/movie_screen.dart';
import '../packages/features/player/presentation/screens/player_screen.dart';
import '../packages/features/video_list/domain/models/video_model.dart';
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
                  // Navigate to the movie screen when a video is tapped
                  context.go(AppRoutes.movie, extra: video);
                },
              ), // Use HomeScreen
        ),
        GoRoute(
          path: AppRoutes.favorites, // Path: /favorites
          builder: (context, state) => const FavoritesScreen(), // Use FavoritesScreen
        ),
        GoRoute(
          path: AppRoutes.movie, // Path: /movie, expects MovieModel as extra
          builder: (context, state) {
            final extra = state.extra;
            // Check for Movie model instead of VideoModel
            if (extra is! VideoModel) {
              logger.w('Movie route called without Movie model in extra');
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.go(AppRoutes.home);
              });
              return const Scaffold(body: Center(child: Text('Movie data is missing')));
            }
            // Pass the Movie object and the required onMovieTap callback
            return MovieScreen(
              video: extra, // extra is now confirmed to be a Movie
              onMovieTap: (tappedMovie) {
                // Navigate to player screen with title and videoUrl in a Map
                final playerData = {'title': tappedMovie.title, 'videoUrl': tappedMovie.videoUrl};
                context.push(AppRoutes.player, extra: playerData);
                logger.i('Tapped movie: ${tappedMovie.title}, navigating to player.');
              },
            );
          },
        ),
        GoRoute(
          path: AppRoutes.player, // Path: /player, expects Map<String, String> as extra
          builder: (context, state) {
            // Extract Map<String, String> from the 'extra' parameter
            final playerData = state.extra as Map<String, String>?;
            if (playerData == null || !playerData.containsKey('title') || !playerData.containsKey('videoUrl')) {
              // Handle error case where data is missing or not the correct type
              logger.w('Player route called without valid title/videoUrl Map in extra');
              // Redirect to home or show an error page
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.go(AppRoutes.home);
              });
              return const Scaffold(body: Center(child: Text('Player data is missing')));
            }
            // Pass title and videoUrl to PlayerScreen
            return PlayerScreen(title: playerData['title']!, videoUrl: playerData['videoUrl']!);
          },
        ),
      ],
      errorBuilder: (context, state) {
        logger.e('Routing error: ${state.error}', error: state.error);
        return Scaffold(body: Center(child: Text('Error: ${state.error}')));
      },
    );
  }
}
