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
      errorBuilder: (context, _) {
        _logger.e('Unable to open application route');

        return ErrorScreen(
          text: 'Не удалось открыть страницу. Вернитесь на главную и выберите аниме заново.',
          onReturnHome: () => context.go(AppRoutes.home),
        );
      },
      navigatorKey: rootNavigatorKey,
    );
  }

  void dispose() => router.dispose();
}
