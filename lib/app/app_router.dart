import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../packages/features/favorites/presentation/screens/favorites_screen.dart';
import '../packages/features/home/presentation/screens/home_screen.dart';
import '../packages/features/player/presentation/screens/player_screen.dart';
import 'app_routes.dart';

/// Router configuration for the application
class AppRouter {
  /// Router instance
  late final GoRouter router;

  /// Constructor
  AppRouter() {
    router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: AppRoutes.favorites,
          builder: (context, state) => const FavoritesScreen(),
        ),
        GoRoute(
          path: '${AppRoutes.player}/:id',
          builder: (context, state) {
            final videoId = state.pathParameters['id'] ?? '';
            return PlayerScreen(videoId: videoId);
          },
        ),
      ],
      errorBuilder:
          (context, state) =>
              Scaffold(body: Center(child: Text('Error: ${state.error}'))),
    );
  }
}
