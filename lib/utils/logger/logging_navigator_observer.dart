import 'package:flutter/widgets.dart' show Route, NavigatorObserver;

import 'logger.dart';

/// Navigator Observer to log route changes
class LoggingNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Use route.settings.name which might be null, provide a fallback.
    final currentRouteName = route.settings.name ?? 'Unnamed Route';
    final previousRouteName = previousRoute?.settings.name;
    logger.d(
      'GoRouter Pushed: $currentRouteName'
      '${previousRouteName != null ? ' from $previousRouteName' : ''}',
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final currentRouteName = route.settings.name ?? 'Unnamed Route';
    final previousRouteName = previousRoute?.settings.name;
    logger.d(
      'GoRouter Popped: $currentRouteName'
      '${previousRouteName != null ? ' to $previousRouteName' : ''}',
    );
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final currentRouteName = route.settings.name ?? 'Unnamed Route';
    final previousRouteName = previousRoute?.settings.name;
    logger.d(
      'GoRouter Removed: $currentRouteName'
      '${previousRouteName != null ? ' below $previousRouteName' : ''}',
    );
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final oldRouteName = oldRoute?.settings.name ?? 'Unnamed Route';
    final newRouteName = newRoute?.settings.name ?? 'Unnamed Route';
    logger.d('GoRouter Replaced: $oldRouteName with $newRouteName');
  }
}
