import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../packages/features/anime/presentation/screens/anime_screen.dart';
import '../packages/features/auth/auth_providers.dart';
import '../packages/features/catalog/domain/models/anime_summary.dart';
import '../packages/features/catalog/domain/models/catalog_filter.dart';
import '../packages/features/catalog/presentation/screens/catalog_screen.dart';
import '../packages/features/catalog/presentation/screens/genres_screen.dart';
import '../packages/features/common/presentation/widgets/error_screen.dart';
import '../packages/features/home/presentation/screens/home_screen.dart';
import '../packages/features/log_viewer/presentation/screens/log_viewer_screen.dart';
import '../packages/features/player/presentation/screens/player_screen.dart';
import 'app_config.dart';
import 'app_navigation_page.dart';
part 'app_routes.g.dart';

/// Routes for the application
class AppRoutes {
  /// Home screen route
  static const String home = '/home';

  /// Movie screen route, relative to its parent.
  static const String anime = 'anime';

  /// Player screen route, relative to its parent.
  static const String player = 'player';

  /// Log Viewer screen route
  static const String logViewer = '/logs';
}

@TypedGoRoute<LogViewerRoute>(path: AppRoutes.logViewer)
class LogViewerRoute extends GoRouteData with $LogViewerRoute {
  const LogViewerRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => AppConfig.isDebugToolsEnabled
      ? const LogViewerScreen()
      : const ErrorScreen(text: 'Просмотр логов доступен только в debug-сборке.');
}

@TypedGoRoute<HomeRoute>(
  path: AppRoutes.home,
  routes: [
    TypedGoRoute<AnimeRoute>(
      path: AppRoutes.anime,
      routes: [TypedGoRoute<PlayerRoute>(path: AppRoutes.player)],
    ),
  ],
)
class HomeRoute extends GoRouteData with $HomeRoute {
  const HomeRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => Consumer(
    builder: (context, ref, _) => HomeScreen(
      accountName: ref.watch(authControllerProvider).value,
      onOpenGenres: () => const GenresRoute().push<void>(context),
      onSignOut: () => unawaited(_signOut(context, ref)),
      onOpenLogs: AppConfig.isDebugToolsEnabled ? () => const LogViewerRoute().push<void>(context) : null,
      onAnimeTap: (anime) {
        AnimeRoute(animeId: anime.id, slug: anime.slug, title: anime.title, $extra: anime).go(context);
      },
    ),
  );
}

class AnimeRoute extends GoRouteData with $AnimeRoute {
  final int animeId;
  final String slug;
  final String title;
  final AnimeSummary? $extra;

  const AnimeRoute({required this.animeId, required this.slug, required this.title, this.$extra});

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      AppNavigationPage(context: context, key: state.pageKey, child: build(context, state));

  @override
  Widget build(BuildContext context, GoRouterState state) => AnimeScreen(
    animeId: animeId,
    slug: slug,
    fallbackTitle: title,
    fallbackPosterUri: $extra?.id == animeId ? $extra?.posterUri : null,
    onFilterTap: (filter) => FilterRoute(path: filter.path, title: filter.label).push<void>(context),
    onEpisodeTap: (episode) {
      unawaited(
        PlayerRoute(
          animeId: animeId,
          episodeNumber: episode.number,
          slug: slug,
          title: title,
          $extra: $extra,
        ).push<void>(context),
      );
    },
  );
}

class PlayerRoute extends GoRouteData with $PlayerRoute {
  final int animeId;
  final int episodeNumber;
  final String slug;
  final String title;
  final AnimeSummary? $extra;

  const PlayerRoute({
    required this.animeId,
    required this.episodeNumber,
    required this.slug,
    required this.title,
    this.$extra,
  });

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      AppNavigationPage(context: context, key: state.pageKey, player: true, child: build(context, state));

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      PlayerScreen(animeId: animeId, episodeNumber: episodeNumber, title: title);
}

Future<void> _signOut(BuildContext context, WidgetRef ref) async {
  final failure = await ref.read(authControllerProvider.notifier).signOut();
  if (failure != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
  }
}

@TypedGoRoute<GenresRoute>(path: '/genres')
class GenresRoute extends GoRouteData with $GenresRoute {
  const GenresRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => GenresScreen(
    onSelected: (filter) => FilterRoute(path: filter.path, title: filter.label).push<void>(context),
  );
}

@TypedGoRoute<FilterRoute>(path: '/browse')
class FilterRoute extends GoRouteData with $FilterRoute {
  final String path;
  final String title;

  const FilterRoute({required this.path, required this.title});

  @override
  Widget build(BuildContext context, GoRouterState state) => CatalogScreen(
    key: ValueKey(path),
    filter: CatalogFilter(label: title, path: path),
    onBack: () => context.pop(),
    onOpenGenres: () => const GenresRoute().push<void>(context),
    onAnimeTap: (anime) =>
        AnimeRoute(animeId: anime.id, slug: anime.slug, title: anime.title, $extra: anime).push<void>(context),
  );
}
