import 'package:flutter/widgets.dart' show NavigatorObserver, Route;
import 'package:logger/logger.dart';

/// Navigator Observer to log route changes
class LoggingNavigatorObserver extends NavigatorObserver {
  final Logger _logger;

  LoggingNavigatorObserver(this._logger);

  @override
  void didPush(Route<Object?> route, Route<Object?>? previousRoute) {
    final currentRouteName = route.settings.name ?? 'Unnamed Route';
    final previousRouteName = previousRoute?.settings.name;
    _logger.d(
      'GoRouter Pushed: $currentRouteName'
      '${previousRouteName != null ? ' from $previousRouteName' : ''}',
    );
  }

  @override
  void didPop(Route<Object?> route, Route<Object?>? previousRoute) {
    final currentRouteName = route.settings.name ?? 'Unnamed Route';
    final previousRouteName = previousRoute?.settings.name;
    _logger.d(
      'GoRouter Popped: $currentRouteName'
      '${previousRouteName != null ? ' to $previousRouteName' : ''}',
    );
  }

  @override
  void didRemove(Route<Object?> route, Route<Object?>? previousRoute) {
    final currentRouteName = route.settings.name ?? 'Unnamed Route';
    final previousRouteName = previousRoute?.settings.name;
    _logger.d(
      'GoRouter Removed: $currentRouteName'
      '${previousRouteName != null ? ' below $previousRouteName' : ''}',
    );
  }

  @override
  void didReplace({Route<Object?>? newRoute, Route<Object?>? oldRoute}) {
    final oldRouteName = oldRoute?.settings.name ?? 'Unnamed Route';
    final newRouteName = newRoute?.settings.name ?? 'Unnamed Route';
    _logger.d('GoRouter Replaced: $oldRouteName with $newRouteName');
  }
}
