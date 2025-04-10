import 'package:anistar_tv/utils/logger/logging_navigator_observer.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../packages/features/favorites/presentation/screens/favorites_screen.dart';
// Import new feature screens
import '../packages/features/home/presentation/screens/home_screen.dart';
import '../packages/features/movie/presentation/screens/movie_screen.dart';
import '../packages/features/player/presentation/screens/player_screen.dart';
import '../packages/features/series_list/presentation/screens/series_list_screen.dart'; // Import SeriesListScreen
import '../packages/features/video_list/domain/models/video_model.dart';
import '../packages/features/video_list/presentation/screens/video_list_screen.dart'; // Import VideoListScreen
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
          builder: (context, state) => const HomeScreen(), // Use HomeScreen
        ),
        GoRoute(
          path: AppRoutes.favorites, // Path: /favorites
          builder: (context, state) => const FavoritesScreen(), // Use FavoritesScreen
        ),
        GoRoute(
          path: AppRoutes.movie, // Path: /movie, expects MovieModel as extra
          builder: (context, state) {
            final extra = state.extra;
            if (extra is! VideoModel) {
              logger.w('Movie route called without MovieModel in extra');
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.go(AppRoutes.home);
              });
              return const Scaffold(body: Center(child: Text('Movie data is missing')));
            }
            return MovieScreen(movie: extra); // Pass VideoModel to MovieScreen
          },
        ),
        GoRoute(
          path: AppRoutes.player, // Path: /player
          builder: (context, state) {
            // Extract VideoModel from the 'extra' parameter
            final video = state.extra as VideoModel?;
            if (video == null) {
              // Handle error case where VideoModel is missing or not the correct type
              logger.w('Player route called without valid VideoModel in extra');
              // Redirect to home or show an error page
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.go(AppRoutes.home);
              });
              return const Scaffold(body: Center(child: Text('Video data is missing')));
            }
            return PlayerScreen(video: video); // Pass the VideoModel
          },
        ),
        GoRoute(
          path: AppRoutes.seriesList, // Path: /series
          name: AppRoutes.seriesList, // Optional: Add name for named routing
          builder: (context, state) {
            final url = state.extra as String?;
            if (url == null || url.isEmpty) {
              logger.w('SeriesList route called without valid URL in extra');
              // Redirect or show error
              WidgetsBinding.instance.addPostFrameCallback((_) => context.go(AppRoutes.home));
              return const Scaffold(body: Center(child: Text('Series URL is missing')));
            }
            return SeriesListScreen(url: url);
          },
        ),
        GoRoute(
          path: AppRoutes.videoList, // Path: /videos
          name: AppRoutes.videoList, // Optional: Add name for named routing
          builder: (context, state) {
            final dataUrl = state.extra as String?;
            if (dataUrl == null || dataUrl.isEmpty) {
              logger.w('VideoList route called without valid dataUrl in extra');
              // Redirect or show error
              WidgetsBinding.instance.addPostFrameCallback((_) => context.go(AppRoutes.home));
              return const Scaffold(body: Center(child: Text('Video data URL is missing')));
            }
            // Pass dataUrl as baseUrl and define onVideoTap callback
            return VideoListScreen(
              baseUrl: dataUrl,
              onVideoTap: (video) {
                context.push(AppRoutes.seriesList, extra: video.videoUrl);
              },
              // Optionally pass a title based on context if needed
              // title: 'Videos for Series',
            );
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
