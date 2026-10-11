import 'package:app_logging/app_logging.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../packages/features/common/presentation/widgets/error_screen.dart';
import '../packages/features/player/presentation/player_route_observer.dart';
import 'app_routes.dart';

/// Router configuration for the application
class AppRouter {
  final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

  /// Router instance
  late final GoRouter router;

  final Logger _logger;

  AppRouter(this._logger) {
    router = GoRouter(
      initialLocation: AppRoutes.home,
      observers: [LoggingNavigatorObserver(_logger), PlayerRouteObserver()],
      routes: $appRoutes,
      errorBuilder: (context, state) {
        _logger.e('Routing error: ${state.error}', error: state.error);

        return ErrorScreen(text: state.error?.message ?? 'Router error');
      },
      navigatorKey: rootNavigatorKey,
    );
  }

  void dispose() => router.dispose();
}
