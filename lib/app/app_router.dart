import 'package:anistar_tv/utils/logger/logging_navigator_observer.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../packages/features/home/presentation/screens/home_screen.dart';
import '../packages/features/player/presentation/screens/player_screen.dart';
import '../utils/logger/logger.dart'; // Import the logger
import 'app_routes.dart';

/// Router configuration for the application
class AppRouter {
  /// Router instance
  late final GoRouter router;

  /// Constructor
  AppRouter() {
    router = GoRouter(
      initialLocation: AppRoutes.home,
      observers: [LoggingNavigatorObserver()], // Add the observer
      routes: [
        GoRoute(path: AppRoutes.home, builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '${AppRoutes.player}/:id',
          builder: (context, state) {
            final videoId = state.pathParameters['id'] ?? '';
            return PlayerScreen(videoId: videoId);
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
