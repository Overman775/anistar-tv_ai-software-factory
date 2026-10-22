// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$logViewerRoute, $homeRoute, $genresRoute, $filterRoute];

RouteBase get $logViewerRoute =>
    GoRouteData.$route(path: '/logs', hasOverriddenOnExit: false, factory: $LogViewerRoute._fromState);

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
  hasOverriddenOnExit: false,
  factory: $HomeRoute._fromState,
  routes: [
    GoRouteData.$route(
      path: 'anime',
      hasOverriddenOnExit: false,
      factory: $AnimeRoute._fromState,
      routes: [GoRouteData.$route(path: 'player', hasOverriddenOnExit: false, factory: $PlayerRoute._fromState)],
    ),
  ],
);

mixin $HomeRoute on GoRouteData {
  static HomeRoute _fromState(GoRouterState state) => HomeRoute(
    destination:
        _$convertMapValue('destination', state.uri.queryParameters, _$HomeDestinationEnumMap._$fromName) ??
        HomeDestination.home,
  );

  HomeRoute get _self => this as HomeRoute;

  @override
  String get location => GoRouteData.$location(
    '/home',
    queryParams: {
      if (_self.destination != HomeDestination.home) 'destination': _$HomeDestinationEnumMap[_self.destination],
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

const _$HomeDestinationEnumMap = {
  HomeDestination.home: 'home',
  HomeDestination.favorites: 'favorites',
  HomeDestination.genres: 'genres',
  HomeDestination.search: 'search',
};

mixin $AnimeRoute on GoRouteData {
  static AnimeRoute _fromState(GoRouterState state) => AnimeRoute(
    animeId: int.parse(state.uri.queryParameters['anime-id']!),
    slug: state.uri.queryParameters['slug']!,
    title: state.uri.queryParameters['title']!,
    destination:
        _$convertMapValue('destination', state.uri.queryParameters, _$HomeDestinationEnumMap._$fromName) ??
        HomeDestination.home,
    $extra: state.extra as AnimeSummary?,
  );

  AnimeRoute get _self => this as AnimeRoute;

  @override
  String get location => GoRouteData.$location(
    '/home/anime',
    queryParams: {
      'anime-id': _self.animeId.toString(),
      'slug': _self.slug,
      'title': _self.title,
      if (_self.destination != HomeDestination.home) 'destination': _$HomeDestinationEnumMap[_self.destination],
    },
  );

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) => context.replace(location, extra: _self.$extra);
}

mixin $PlayerRoute on GoRouteData {
  static PlayerRoute _fromState(GoRouterState state) => PlayerRoute(
    animeId: int.parse(state.uri.queryParameters['anime-id']!),
    episodeNumber: int.parse(state.uri.queryParameters['episode-number']!),
    slug: state.uri.queryParameters['slug']!,
    title: state.uri.queryParameters['title']!,
    destination:
        _$convertMapValue('destination', state.uri.queryParameters, _$HomeDestinationEnumMap._$fromName) ??
        HomeDestination.home,
    $extra: state.extra as AnimeSummary?,
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
      if (_self.destination != HomeDestination.home) 'destination': _$HomeDestinationEnumMap[_self.destination],
    },
  );

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) => context.replace(location, extra: _self.$extra);
}

T? _$convertMapValue<T>(String key, Map<String, String> map, T? Function(String) converter) {
  final value = map[key];
  return value == null ? null : converter(value);
}

extension<T extends Enum> on Map<T, String> {
  T? _$fromName(String? value) => entries.where((element) => element.value == value).firstOrNull?.key;
}

RouteBase get $genresRoute =>
    GoRouteData.$route(path: '/genres', hasOverriddenOnExit: false, factory: $GenresRoute._fromState);

mixin $GenresRoute on GoRouteData {
  static GenresRoute _fromState(GoRouterState state) => const GenresRoute();

  @override
  String get location => GoRouteData.$location('/genres');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $filterRoute =>
    GoRouteData.$route(path: '/browse', hasOverriddenOnExit: false, factory: $FilterRoute._fromState);

mixin $FilterRoute on GoRouteData {
  static FilterRoute _fromState(GoRouterState state) => FilterRoute(
    path: state.uri.queryParameters['path']!,
    title: state.uri.queryParameters['title']!,
    destination:
        _$convertMapValue('destination', state.uri.queryParameters, _$HomeDestinationEnumMap._$fromName) ??
        HomeDestination.genres,
  );

  FilterRoute get _self => this as FilterRoute;

  @override
  String get location => GoRouteData.$location(
    '/browse',
    queryParams: {
      'path': _self.path,
      'title': _self.title,
      if (_self.destination != HomeDestination.genres) 'destination': _$HomeDestinationEnumMap[_self.destination],
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
