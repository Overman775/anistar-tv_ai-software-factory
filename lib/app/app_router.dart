import 'package:anistar_tv/packages/features/common/presentation/widgets/error_screen.dart';
import 'package:anistar_tv/utils/logger/logging_navigator_observer.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../utils/logger/logger.dart';
import 'app_routes.dart';

/// Router configuration for the application
class AppRouter {
  /// Router instance
  late final GoRouter router;

  static final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

  /// Constructor
  AppRouter() {
    router = GoRouter(
      initialLocation: AppRoutes.home,
      observers: [LoggingNavigatorObserver()],
      routes: $appRoutes,
      errorBuilder: (context, state) {
        logger.e('Routing error: ${state.error}', error: state.error);
        return ErrorScreen(text: state.error?.message ?? 'Router error');
      },
      navigatorKey: rootNavigatorKey,
    );
  }
}
