import 'dart:async';

import 'package:anistar/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../packages/features/anime/domain/models/anime_episode.dart';
import '../packages/features/anime/domain/models/anime_part.dart';
import '../packages/features/anime/presentation/screens/anime_screen.dart';
import '../packages/features/auth/auth_providers.dart';
import '../packages/features/catalog/domain/models/anime_summary.dart';
import '../packages/features/catalog/domain/models/catalog_filter.dart';
import '../packages/features/catalog/presentation/screens/catalog_screen.dart';
import '../packages/features/catalog/presentation/screens/genres_screen.dart';
import '../packages/features/common/presentation/widgets/error_screen.dart';
import '../packages/features/home/presentation/home_destination.dart';
import '../packages/features/home/presentation/mobile/mobile_home_shell.dart';
import '../packages/features/home/presentation/screens/home_screen.dart';
import '../packages/features/home/presentation/screens/tv_route_shell.dart';
import '../packages/features/log_viewer/presentation/screens/log_viewer_screen.dart';
import '../packages/features/player/presentation/screens/player_screen.dart';
import 'app_config.dart';
import 'app_confirmation.dart';
import 'app_navigation_page.dart';
part 'app_mobile_route_shell.dart';
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
      : ErrorScreen(
          text: 'Просмотр логов доступен только в debug-сборке.',
          onReturnHome: () => const HomeRoute().go(context),
        );
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
  final HomeDestination destination;

  const HomeRoute({this.destination = HomeDestination.home});

  @override
  Widget build(BuildContext context, GoRouterState state) => Consumer(
    builder: (context, ref, _) => HomeScreen(
      destination: destination,
      onDestinationSelected: (value) => HomeRoute(destination: value).go(context),
      accountName: ref.watch(authAccessProvider).account,
      accountImageUrl: _accountImageUrl(ref),
      onOpenGenres: () => const GenresRoute().push<void>(context),
      onGenreSelected: (filter) => FilterRoute(path: filter.path, title: filter.label).push<void>(context),
      onSignOut: ref.watch(authAccessProvider).canUseAccount ? () => unawaited(_signOut(context, ref)) : null,
      onSignIn: ref.watch(authAccessProvider).canUseAccount
          ? null
          : ref.read(authControllerProvider.notifier).requestSignIn,
      onRootBack: supportsAppExit ? () => unawaited(confirmAppExit(context)) : null,
      onOpenLogs: AppConfig.isDebugToolsEnabled ? () => const LogViewerRoute().push<void>(context) : null,
      onAnimeTap: (anime) => _openHomeAnime(context, anime, destination),
    ),
  );
}

class AnimeRoute extends GoRouteData with $AnimeRoute {
  final int animeId;
  final String slug;
  final String title;
  final AnimeSummary? $extra;
  final HomeDestination destination;

  const AnimeRoute({
    required this.animeId,
    required this.slug,
    required this.title,
    this.destination = HomeDestination.home,
    this.$extra,
  });

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      AppNavigationPage(context: context, key: state.pageKey, child: build(context, state));

  @override
  Widget build(BuildContext context, GoRouterState state) => _RouteShell(
    destination: destination,
    title: title,
    builder: (onOpenNavigation) => AnimeScreen(
      embedded: !AppLayoutScope.isTvOf(context),
      onOpenNavigation: onOpenNavigation,
      animeId: animeId,
      slug: slug,
      fallbackTitle: title,
      fallbackPosterUri: $extra?.id == animeId ? $extra?.posterUri : null,
      onFilterTap: (filter) => FilterRoute(path: filter.path, title: filter.label).push<void>(context),
      onPartTap: (part) => _openAnimePart(context, part, animeId, destination),
      onEpisodeTap: (episode) => _openEpisode(context, episode, animeId, destination, slug, title, $extra),
    ),
  );
}

class PlayerRoute extends GoRouteData with $PlayerRoute {
  final HomeDestination destination;
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
    this.destination = HomeDestination.home,
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
  if (ModalRoute.of(context)?.isCurrent != true) {
    return;
  }
  final confirmed = await showAppConfirmation(
    context,
    title: 'Выйти из аккаунта?',
    message: 'Для следующего просмотра понадобится снова войти в аккаунт AniStar.',
    confirmLabel: 'Выйти из аккаунта',
    cancelLabel: 'Остаться',
  );
  if (!confirmed || !context.mounted) {
    return;
  }
  final failure = await ref.read(authControllerProvider.notifier).signOut();
  if (failure != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
  }
}

@TypedGoRoute<GenresRoute>(path: '/genres')
class GenresRoute extends GoRouteData with $GenresRoute {
  const GenresRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => _RouteShell(
    destination: HomeDestination.genres,
    title: 'Жанры',
    builder: (onOpenNavigation) => GenresScreen(
      embedded: true,
      onOpenNavigation: onOpenNavigation,
      onSelected: (filter) => FilterRoute(path: filter.path, title: filter.label).push<void>(context),
    ),
  );
}

@TypedGoRoute<FilterRoute>(path: '/browse')
class FilterRoute extends GoRouteData with $FilterRoute {
  final String path;
  final String title;
  final HomeDestination destination;

  const FilterRoute({required this.path, required this.title, this.destination = HomeDestination.genres});

  @override
  Widget build(BuildContext context, GoRouterState state) => Consumer(
    builder: (context, ref, _) {
      final mobile = !AppLayoutScope.isTvOf(context);
      final catalog = CatalogScreen(
        key: ValueKey(path),
        embedded: true,
        accountName: ref.watch(authAccessProvider).account,
        filter: CatalogFilter(label: title, path: path),
        onTabSelected: (favorite) =>
            HomeRoute(destination: favorite ? HomeDestination.favorites : HomeDestination.home).go(context),
        onOpenGenres: () => const HomeRoute(destination: HomeDestination.genres).go(context),
        onOpenLogs: _logsAction(context),
        onAnimeTap: (anime) => _openAnime(context, anime, destination),
      );

      return mobile
          ? _AppMobileRouteShell(destination: destination, title: title, content: catalog)
          : _RouteShell(
              destination: destination,
              title: title,
              builder: (onNavigation) => CatalogScreen(
                key: ValueKey(path),
                embedded: true,
                filter: CatalogFilter(label: title, path: path),
                onOpenNavigation: onNavigation,
                onAnimeTap: (anime) => _openAnime(context, anime, destination),
              ),
            );
    },
  );
}

VoidCallback? _logsAction(BuildContext context) =>
    AppConfig.isDebugToolsEnabled ? () => const LogViewerRoute().push<void>(context) : null;

void _openHomeAnime(BuildContext context, AnimeSummary anime, HomeDestination destination) {
  AnimeRoute(
    animeId: anime.id,
    slug: anime.slug,
    title: anime.title,
    destination: destination,
    $extra: anime,
  ).go(context);
}

void _openAnimePart(BuildContext context, AnimePart part, int animeId, HomeDestination destination) {
  final id = part.id;
  final partSlug = part.slug;
  if (id != null && partSlug != null && id != animeId) {
    unawaited(AnimeRoute(animeId: id, slug: partSlug, title: part.label, destination: destination).push<void>(context));
  }
}

void _openEpisode(
  BuildContext context,
  AnimeEpisode episode,
  int animeId,
  HomeDestination destination,
  String slug,
  String title,
  AnimeSummary? extra,
) {
  unawaited(
    PlayerRoute(
      animeId: animeId,
      episodeNumber: episode.number,
      destination: destination,
      slug: slug,
      title: title,
      $extra: extra,
    ).push<void>(context),
  );
}

void _openAnime(BuildContext context, AnimeSummary anime, HomeDestination destination) {
  unawaited(
    AnimeRoute(
      animeId: anime.id,
      slug: anime.slug,
      title: anime.title,
      destination: destination,
      $extra: anime,
    ).push<void>(context),
  );
}

String? _accountImageUrl(WidgetRef ref) {
  final access = ref.watch(authAccessProvider);
  if (access is! AuthenticatedAccess) {
    return null;
  }
  final session = ref.watch(authControllerProvider).value;
  final profile = ref.watch(authProfileStateProvider);
  if (profile.account != access.account ||
      profile.origin != ref.watch(anistarActiveMirrorProvider) ||
      profile.contextGeneration != session?.profileContextGeneration) {
    return null;
  }

  return profile.profile?.imageUri?.toString();
}

class _RouteShell extends ConsumerWidget {
  const _RouteShell({required this.destination, required this.title, required this.builder});

  final HomeDestination destination;
  final String title;
  final Widget Function(VoidCallback? onOpenNavigation) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppLayoutScope.isTvOf(context)
      ? TvRouteShell(
          destination: destination,
          accountName: ref.watch(authAccessProvider).account,
          accountImageUrl: _accountImageUrl(ref),
          onDestinationSelected: (value) => HomeRoute(destination: value).go(context),
          onSignOut: ref.watch(authAccessProvider).canUseAccount ? () => unawaited(_signOut(context, ref)) : null,
          onSignIn: ref.watch(authAccessProvider).canUseAccount
              ? null
              : ref.read(authControllerProvider.notifier).requestSignIn,
          onOpenLogs: _logsAction(context),
          builder: builder,
        )
      : _AppMobileRouteShell(destination: destination, title: title, content: builder(null));
}
