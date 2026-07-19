import 'package:app_logger/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../packages/features/common/presentation/widgets/error_screen.dart';
import 'app_routes.dart';

/// Router configuration for the application
class AppRouter {
  static final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

  /// Router instance
  late final GoRouter router;

  final Logger _logger;

  AppRouter(this._logger) {
    router = GoRouter(
      initialLocation: AppRoutes.home,
      observers: [LoggingNavigatorObserver(_logger)],
      routes: $appRoutes,
      errorBuilder: (context, state) {
        _logger.e('Routing error: ${state.error}', error: state.error);

        return ErrorScreen(text: state.error?.message ?? 'Router error');
      },
      navigatorKey: rootNavigatorKey,
    );
  }
}
