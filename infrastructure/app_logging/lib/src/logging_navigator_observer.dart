import 'package:flutter/widgets.dart' show NavigatorObserver, Route;
import 'package:logger/logger.dart';

/// Logs route changes without coupling routing to a concrete router package.
class LoggingNavigatorObserver extends NavigatorObserver {
  final Logger _logger;

  LoggingNavigatorObserver(this._logger);

  @override
  void didPush(Route<Object?> route, Route<Object?>? previousRoute) {
    _log('Pushed', route, previousRoute, 'from');
  }

  @override
  void didPop(Route<Object?> route, Route<Object?>? previousRoute) {
    _log('Popped', route, previousRoute, 'to');
  }

  @override
  void didRemove(Route<Object?> route, Route<Object?>? previousRoute) {
    _log('Removed', route, previousRoute, 'below');
  }

  @override
  void didReplace({Route<Object?>? newRoute, Route<Object?>? oldRoute}) {
    _logger.d(
      'GoRouter Replaced: ${oldRoute?.settings.name ?? 'Unnamed Route'} with ${newRoute?.settings.name ?? 'Unnamed Route'}',
    );
  }

  void _log(String action, Route<Object?> route, Route<Object?>? previousRoute, String relation) {
    final previous = previousRoute?.settings.name;
    _logger.d(
      'GoRouter $action: ${route.settings.name ?? 'Unnamed Route'}${previous == null ? '' : ' $relation $previous'}',
    );
  }
}
