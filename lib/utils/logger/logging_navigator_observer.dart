import 'package:flutter/widgets.dart' show Route, NavigatorObserver;

import 'logger.dart';

/// Navigator Observer to log route changes
class LoggingNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<Object?> route, Route<Object?>? previousRoute) {
    // Use route.settings.name which might be null, provide a fallback.
    final currentRouteName = route.settings.name ?? 'Unnamed Route';
    final previousRouteName = previousRoute?.settings.name;
    logger.d(
      'GoRouter Pushed: $currentRouteName'
      '${previousRouteName != null ? ' from $previousRouteName' : ''}',
    );
  }

  @override
  void didPop(Route<Object?> route, Route<Object?>? previousRoute) {
    final currentRouteName = route.settings.name ?? 'Unnamed Route';
    final previousRouteName = previousRoute?.settings.name;
    logger.d(
      'GoRouter Popped: $currentRouteName'
      '${previousRouteName != null ? ' to $previousRouteName' : ''}',
    );
  }

  @override
  void didRemove(Route<Object?> route, Route<Object?>? previousRoute) {
    final currentRouteName = route.settings.name ?? 'Unnamed Route';
    final previousRouteName = previousRoute?.settings.name;
    logger.d(
      'GoRouter Removed: $currentRouteName'
      '${previousRouteName != null ? ' below $previousRouteName' : ''}',
    );
  }

  @override
  void didReplace({Route<Object?>? newRoute, Route<Object?>? oldRoute}) {
    final oldRouteName = oldRoute?.settings.name ?? 'Unnamed Route';
    final newRouteName = newRoute?.settings.name ?? 'Unnamed Route';
    logger.d('GoRouter Replaced: $oldRouteName with $newRouteName');
  }
}
