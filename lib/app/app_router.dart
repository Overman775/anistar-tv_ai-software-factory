import 'package:anistar_tv/utils/logger/logging_navigator_observer.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../packages/features/favorites/presentation/screens/favorites_screen.dart';
// Import new feature screens
import '../packages/features/home/presentation/screens/home_screen.dart';
import '../packages/features/movie/presentation/screens/movie_screen.dart';
import '../utils/logger/logger.dart'; // Import the logger
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
          path: AppRoutes.movie, // Path: /movie/:movieId
          builder: (context, state) {
            // Extract movieId from path parameters
            final movieId = state.pathParameters['movieId'] ?? '';
            if (movieId.isEmpty) {
              // Handle error case where movieId is missing
              logger.w('Movie route called without movieId');
              // Redirect to home or show an error page
              // For simplicity, redirecting home here
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.go(AppRoutes.home);
              });
              return const Scaffold(body: Center(child: Text('Movie ID is missing')));
            }
            return MovieScreen(movieId: movieId); // Use MovieScreen
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
