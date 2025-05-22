// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$logViewerRoute, $homeRoute];

RouteBase get $logViewerRoute => GoRouteData.$route(path: '/logs', factory: $LogViewerRouteExtension._fromState);

extension $LogViewerRouteExtension on LogViewerRoute {
  static LogViewerRoute _fromState(GoRouterState state) => const LogViewerRoute();

  String get location => GoRouteData.$location('/logs');

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $homeRoute => GoRouteData.$route(
  path: '/home',

  factory: $HomeRouteExtension._fromState,
  routes: [
    GoRouteData.$route(
      path: 'movie',

      factory: $MovieRouteExtension._fromState,
      routes: [GoRouteData.$route(path: 'player', factory: $PlayerRouteExtension._fromState)],
    ),
  ],
);

extension $HomeRouteExtension on HomeRoute {
  static HomeRoute _fromState(GoRouterState state) => const HomeRoute();

  String get location => GoRouteData.$location('/home');

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $MovieRouteExtension on MovieRoute {
  static MovieRoute _fromState(GoRouterState state) =>
      MovieRoute(title: state.uri.queryParameters['title']!, videoUrl: state.uri.queryParameters['video-url']!);

  String get location => GoRouteData.$location('/home/movie', queryParams: {'title': title, 'video-url': videoUrl});

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

extension $PlayerRouteExtension on PlayerRoute {
  static PlayerRoute _fromState(GoRouterState state) =>
      PlayerRoute(title: state.uri.queryParameters['title']!, videoUrl: state.uri.queryParameters['video-url']!);

  String get location =>
      GoRouteData.$location('/home/movie/player', queryParams: {'title': title, 'video-url': videoUrl});

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}
