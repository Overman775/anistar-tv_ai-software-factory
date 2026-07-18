// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$logViewerRoute, $homeRoute];

RouteBase get $logViewerRoute => GoRouteData.$route(path: '/logs', factory: $LogViewerRoute._fromState);

mixin $LogViewerRoute on GoRouteData {
  static LogViewerRoute _fromState(GoRouterState state) => const LogViewerRoute();

  @override
  String get location => GoRouteData.$location('/logs');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $homeRoute => GoRouteData.$route(
  path: '/home',
  factory: $HomeRoute._fromState,
  routes: [
    GoRouteData.$route(
      path: 'anime',
      factory: $AnimeRoute._fromState,
      routes: [GoRouteData.$route(path: 'player', factory: $PlayerRoute._fromState)],
    ),
  ],
);

mixin $HomeRoute on GoRouteData {
  static HomeRoute _fromState(GoRouterState state) => const HomeRoute();

  @override
  String get location => GoRouteData.$location('/home');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $AnimeRoute on GoRouteData {
  static AnimeRoute _fromState(GoRouterState state) => AnimeRoute(
    animeId: int.parse(state.uri.queryParameters['anime-id']!),
    slug: state.uri.queryParameters['slug']!,
    title: state.uri.queryParameters['title']!,
  );

  AnimeRoute get _self => this as AnimeRoute;

  @override
  String get location => GoRouteData.$location(
    '/home/anime',
    queryParams: {'anime-id': _self.animeId.toString(), 'slug': _self.slug, 'title': _self.title},
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $PlayerRoute on GoRouteData {
  static PlayerRoute _fromState(GoRouterState state) => PlayerRoute(
    animeId: int.parse(state.uri.queryParameters['anime-id']!),
    episodeNumber: int.parse(state.uri.queryParameters['episode-number']!),
    slug: state.uri.queryParameters['slug']!,
    title: state.uri.queryParameters['title']!,
  );

  PlayerRoute get _self => this as PlayerRoute;

  @override
  String get location => GoRouteData.$location(
    '/home/anime/player',
    queryParams: {
      'anime-id': _self.animeId.toString(),
      'episode-number': _self.episodeNumber.toString(),
      'slug': _self.slug,
      'title': _self.title,
    },
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}
