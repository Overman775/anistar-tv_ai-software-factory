import 'dart:async';

import 'package:anistar/anistar.dart';
import 'package:anistar_tv/packages/features/anime/data/repositories/anistar_anime_repository.dart';
import 'package:anistar_tv/packages/features/auth/data/anistar_auth_repository.dart';
import 'package:anistar_tv/packages/features/catalog/data/repositories/anistar_catalog_repository.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/catalog_filter.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/catalog_sort.dart';
import 'package:anistar_tv/packages/features/favorites/data/anistar_favorites_repository.dart';
import 'package:anistar_tv/packages/features/player/data/repositories/anistar_playback_repository.dart';
import 'package:anistar_tv/packages/features/player/domain/models/playback_failure.dart';
import 'package:anistar_tv/packages/features/player/domain/models/playback_quality.dart';
import 'package:anistar_tv/packages/features/watch_history/data/repositories/anistar_watched_episodes_repository.dart';
import 'package:app_logging/app_logging.dart';
import 'package:core/data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:networking/networking.dart';

import '../../../../mocks/anistar/fake_anistar_client.dart';
import '../../../../mocks/app_logging/capturing_log_output.dart';

void main() {
  late FakeAnistarClient client;
  setUp(() => client = FakeAnistarClient());

  test('catalog and favorites retain metadata, slug and contextual favorite flags', () async {
    final summaries = [
      for (final (index, favorite) in [null, false, true].indexed)
        AnistarAnimeSummaryDto(
          id: index + 1,
          slug: '${index + 1}-anime',
          title: 'Anime',
          rating: switch (index) {
            0 => 0,
            1 => null,
            _ => double.nan,
          },
          isFavorite: favorite,
        ),
    ];
    client.pageResult = AnistarCatalogPageDto(items: summaries, page: 1, hasNext: true);
    final catalog = _success(await AnistarCatalogRepository(client).getPage(1));
    final favorites = _success(await AnistarFavoritesRepository(client, null, _account).getPage(1));
    expect(catalog.items.map((item) => item.isFavorite), [null, false, true]);
    expect(catalog.items.map((item) => item.rating), [0, null, null]);
    expect(catalog.items.map((item) => item.posterUri), [null, null, null]);
    expect(catalog.items.map((item) => item.slug), ['1-anime', '2-anime', '3-anime']);
    expect(favorites.items.every((item) => item.isFavorite == true), isTrue);
  });

  test('empty successes differ from failures and response page must match request', () async {
    final catalog = AnistarCatalogRepository(client);
    final favorites = AnistarFavoritesRepository(client, null, _account);
    // Re-read after changing the fake response; caching would hide the behavior under test.
    // ignore: prefer-moving-to-variable
    final emptyCatalog = await catalog.getPage(1);
    expect(emptyCatalog.successOrNull?.items, isEmpty);
    // Re-read after changing the fake response; caching would hide the behavior under test.
    // ignore: prefer-moving-to-variable
    final emptyFavorites = await favorites.getPage(1);
    expect(emptyFavorites.successOrNull?.items, isEmpty);
    client.pageResult = AnistarCatalogPageDto(items: [], page: 2, hasNext: false);
    // Re-read after changing the fake response; caching would hide the behavior under test.
    // ignore: prefer-moving-to-variable
    final wrongCatalog = await catalog.getPage(1);
    // Re-read after changing the fake response; caching would hide the behavior under test.
    // ignore: prefer-moving-to-variable
    expect(wrongCatalog.failureOrNull, isA<RequestFailure>());
    // Re-read after changing the fake response; caching would hide the behavior under test.
    // ignore: prefer-moving-to-variable
    final wrongFavorites = await favorites.getPage(1);
    // Re-read after changing the fake response; caching would hide the behavior under test.
    // ignore: prefer-moving-to-variable
    expect(wrongFavorites.failureOrNull, isA<RequestFailure>());
  });

  test('genres are protected and popularity maps to rating while visits maps to views', () async {
    client.genreResult = [const AnistarCatalogFilterDto(label: 'Comedy', path: '/comedy/')];
    final repository = AnistarCatalogRepository(client);
    final genres = _success(await repository.getGenres());
    client.genreResult.clear();
    expect(genres.single.path, '/comedy/');
    expect(genres.clear, throwsUnsupportedError);
    const filter = CatalogFilter(label: 'Comedy', path: '/comedy/');
    await repository.getFilteredPage(filter, 1, sort: (criterion: CatalogSortCriterion.popularity, ascending: true));
    final popularity = client.lastSort;
    expect(popularity?.criterion, AnistarSortCriterion.rating);
    expect(popularity?.ascending, isTrue);
    await repository.getFilteredPage(filter, 2, sort: (criterion: CatalogSortCriterion.visits, ascending: false));
    expect(client.lastSort?.criterion, AnistarSortCriterion.views);
    expect(client.lastPath, filter.path);
  });

  test('all numeric repository inputs fail without invoking the client', () async {
    final catalog = AnistarCatalogRepository(client);
    final favorites = AnistarFavoritesRepository(client, null, _account);
    final anime = AnistarAnimeRepository(client, null, _canUseAccount);
    final playback = AnistarPlaybackRepository(client, null, _canUseAccount);
    final history = AnistarWatchedEpisodesRepository(client, null, _account);
    final results = await Future.wait([
      catalog.getPage(0),
      catalog.getFilteredPage(const CatalogFilter(label: 'x', path: '/comedy/'), -1),
      favorites.getPage(0),
      favorites.getStatus(animeId: 0, slug: '1-anime'),
      favorites.setFavorite(animeId: -1, slug: '1-anime', favorite: true),
      anime.getAnime(id: 0, slug: '1-anime'),
      playback.createSession(animeId: 0, episodeNumber: 1),
      playback.createSession(animeId: 1, episodeNumber: 0),
      history.getWatched(0),
      history.markStarted(animeId: -1, episodeNumber: 1),
      history.markStarted(animeId: 1, episodeNumber: 0),
    ]);
    expect(results.every((result) => result.isFailure), isTrue);
    expect(client.calls, isEmpty);
  });

  test('anime starts both branches concurrently and requires their complete success', () async {
    final details = Completer<AnistarAnimeDetailsDto>();
    final episodes = Completer<List<AnistarEpisodeDto>>();
    client
      ..loadDetails = ((_) => details.future)
      ..loadEpisodes = ((_) => episodes.future);
    final pending = AnistarAnimeRepository(client, null, _canUseAccount).getAnime(id: 1, slug: '1-anime');
    await Future<void>.delayed(Duration.zero);
    expect(client.calls, ['details', 'episodes']);
    details.complete(client.detailResult);
    episodes.complete([
      AnistarEpisodeDto(number: 3, title: 'Three', sources: []),
      AnistarEpisodeDto(number: 1, title: 'One', sources: []),
    ]);
    final screen = _success(await pending);
    expect(screen.episodes.map((item) => item.number), [1, 3]);
    expect(screen.details.posterUri, isNull);
    expect(screen.details.slug, '1-anime');
  });

  for (final branch in ['details', 'episodes', 'both']) {
    test('anime preserves the original $branch failure and consumes both branch errors', () async {
      final details = Completer<AnistarAnimeDetailsDto>();
      final episodes = Completer<List<AnistarEpisodeDto>>();
      client
        ..loadDetails = ((_) => details.future)
        ..loadEpisodes = ((_) => episodes.future);
      final pending = AnistarAnimeRepository(client, null, _canUseAccount).getAnime(id: 1, slug: '1-anime');
      await Future<void>.delayed(Duration.zero);
      const failure = AnistarClientException(AnistarClientErrorCategory.timeout, 'Safe timeout');
      if (branch != 'episodes') {
        details.completeError(failure);
      } else {
        details.complete(client.detailResult);
      }
      if (branch != 'details') {
        episodes.completeError(failure);
      } else {
        episodes.complete([]);
      }
      final result = await pending;
      expect(result.failureOrNull, isA<TimeoutFailure>());
      expect(result.successOrNull, isNull);
    });
  }

  test('inconsistent detail identity and invalid mandatory values fail in release code', () async {
    final repository = AnistarAnimeRepository(client, null, _canUseAccount);
    client.detailResult = AnistarAnimeDetailsDto(id: 2, slug: '2-anime', title: 'Anime');
    // Re-read after changing the fake response; caching would hide the behavior under test.
    // ignore: prefer-moving-to-variable
    final wrongId = await repository.getAnime(id: 1, slug: '1-anime');
    expect(wrongId.isFailure, isTrue);
    client.detailResult = AnistarAnimeDetailsDto(id: 1, slug: '1-anime', title: '');
    // Re-read after changing the fake response; caching would hide the behavior under test.
    // ignore: prefer-moving-to-variable
    final emptyTitle = await repository.getAnime(id: 1, slug: '1-anime');
    expect(emptyTitle.failureOrNull, isA<RequestFailure>());
    client.pageResult = AnistarCatalogPageDto(
      items: [const AnistarAnimeSummaryDto(id: 0, slug: '', title: '')],
      page: 1,
      hasNext: false,
    );
    expect((await AnistarCatalogRepository(client).getPage(1)).isFailure, isTrue);
  });

  test('playback transfers per-source URI headers and expiry without HTML assumptions', () async {
    final expiry = DateTime.utc(2031);
    final low = AnistarVideoSourceDto(
      height: 360,
      manifestUri: Uri.parse('https://cdn.test/low?signature=%2B'),
      httpHeaders: {'Token': 'low'},
    );
    final high = AnistarVideoSourceDto(
      height: 720,
      manifestUri: Uri.parse('https://cdn.test/high?signature=a%2Fb'),
      httpHeaders: {'Token': 'high'},
      expiresAt: expiry,
    );
    client.episodeResult = [
      AnistarEpisodeDto(number: 4, title: 'Four', sources: [low]),
      AnistarEpisodeDto(number: 1, title: 'One', sources: [high, low], isWatched: true),
      AnistarEpisodeDto(
        number: 9,
        title: 'Nine',
        sources: [AnistarVideoSourceDto(height: 1080, manifestUri: Uri.parse('https://cdn.test/unsupported'))],
      ),
    ];
    final repository = AnistarPlaybackRepository(client, null, _canUseAccount);
    final session = _success(await repository.createSession(animeId: 1, episodeNumber: 1));
    expect(session.manifestUri, same(high.manifestUri));
    expect(session.httpHeaders, {'Token': 'high'});
    expect(session.expiresAt, expiry);
    expect(session.availableQualities, [PlaybackQuality.low, PlaybackQuality.high]);
    expect(session.episodeNumbers, [1, 4, 9]);
    expect(session.watchedEpisodes, {1});
    expect(session.previousEpisode(4), 1);
    expect(session.nextEpisode(4), 9);
    final fallback = _success(await repository.createSession(animeId: 1, episodeNumber: 4));
    expect(fallback.requestedQuality, PlaybackQuality.high);
    expect(fallback.selectedQuality, PlaybackQuality.low);
    expect(fallback.httpHeaders, {'Token': 'low'});
    expect(fallback.expiresAt, isNull);
    expect((await repository.createSession(animeId: 1, episodeNumber: 9)).failureOrNull, isA<PlaybackFailure>());
    expect((await repository.createSession(animeId: 1, episodeNumber: 2)).isFailure, isTrue);
  });

  test('nonpositive or duplicate episode numbers cannot become playback or screen data', () async {
    for (final numbers in [
      [0],
      [1, 1],
    ]) {
      client.episodeResult = [
        for (final number in numbers) AnistarEpisodeDto(number: number, title: 'Episode', sources: []),
      ];
      expect(
        (await AnistarPlaybackRepository(
          client,
          null,
          _canUseAccount,
        ).createSession(animeId: 1, episodeNumber: 1)).isFailure,
        isTrue,
      );
      expect(
        (await AnistarAnimeRepository(client, null, _canUseAccount).getAnime(id: 1, slug: '1-anime')).isFailure,
        isTrue,
      );
    }
  });

  test('favorites and history use confirmed values and protect returned watched sets', () async {
    final favorites = AnistarFavoritesRepository(client, null, _account);
    expect((await favorites.getStatus(animeId: 1, slug: '1-anime')).successOrNull, isFalse);
    expect((await favorites.setFavorite(animeId: 1, slug: '1-anime', favorite: true)).successOrNull, isTrue);
    client.watchedResult = {1, 3};
    final history = AnistarWatchedEpisodesRepository(client, null, _account);
    final watched = _success(await history.getWatched(1));
    // Re-read after changing the fake response; caching would hide the behavior under test.
    // ignore: prefer-moving-to-variable
    final marked = _success(await history.markStarted(animeId: 1, episodeNumber: 3));
    client.watchedResult.clear();
    expect(watched, {1, 3});
    expect(marked, {1, 3});
    expect(() => watched.add(9), throwsUnsupportedError);
    // Re-read after changing the fake response; caching would hide the behavior under test.
    // ignore: prefer-moving-to-variable
    final unconfirmed = await history.markStarted(animeId: 1, episodeNumber: 3);
    expect(unconfirmed.isFailure, isTrue);
  });

  test('auth restore success null and expiry remain separate from operation failures', () async {
    final expiry = StreamController<void>();
    addTearDown(expiry.close);
    client.expiry = expiry.stream;
    final repository = AnistarAuthRepository(client);
    final restore = await repository.restore();
    expect(restore.isSuccess, isTrue);
    expect(restore.successOrNull, isNull);
    expect((await repository.signIn('account', 'password')).successOrNull, 'account');
    final event = repository.expired.first;
    expiry.add(null);
    await event;
    expect((await repository.signOut()).isSuccess, isTrue);
  });

  for (final (category, matcher) in <(AnistarClientErrorCategory, Matcher)>[
    (AnistarClientErrorCategory.timeout, isA<TimeoutFailure>()),
    (AnistarClientErrorCategory.connection, isA<ConnectionFailure>()),
    (AnistarClientErrorCategory.server, isA<ServerFailure>()),
    (AnistarClientErrorCategory.request, isA<RequestFailure>()),
  ]) {
    test('all six repositories map ${category.name} once through the shared contract', () async {
      client.error = AnistarClientException(category, 'Safe message');
      final operations = <Future<Result<Object?, Failure>> Function()>[
        () => AnistarCatalogRepository(client).getPage(1),
        () => AnistarCatalogRepository(client).getGenres(),
        () => AnistarAnimeRepository(client, null, _canUseAccount).getAnime(id: 1, slug: '1-anime'),
        () => AnistarPlaybackRepository(client, null, _canUseAccount).createSession(animeId: 1, episodeNumber: 1),
        () => AnistarFavoritesRepository(client, null, _account).getPage(1),
        () => AnistarFavoritesRepository(client, null, _account).getStatus(animeId: 1, slug: '1-anime'),
        () =>
            AnistarFavoritesRepository(client, null, _account).setFavorite(animeId: 1, slug: '1-anime', favorite: true),
        () => AnistarAuthRepository(client).restore(),
        () => AnistarAuthRepository(client).signIn('account', 'password'),
        () => AnistarAuthRepository(client).signOut(),
        () => AnistarWatchedEpisodesRepository(client, null, _account).getWatched(1),
        () => AnistarWatchedEpisodesRepository(client, null, _account).markStarted(animeId: 1, episodeNumber: 1),
      ];
      for (final operation in operations) {
        final result = await operation();
        expect(result.failureOrNull, matcher);
        expect(result.successOrNull, isNull);
      }
    });
  }

  test('unexpected errors stay UnknownFailure with safe UI messages', () async {
    client.error = StateError('password=private; Cookie=secret; signed/url');
    final output = CapturingLogOutput();
    final logger = Logger(filter: ProductionFilter(), level: Level.all, output: output);
    addTearDown(logger.close);
    final result = await AnistarAuthRepository(client, logger).signIn('account', 'private');
    expect(result.failureOrNull, isA<UnknownFailure>());
    expect(result.failureOrNull?.message, 'Не удалось выполнить запрос.');
    expect(output.messages.join(), contains('Unexpected repository error'));
    final diagnostics = [...output.messages, ...output.errors].join();
    expect(diagnostics, isNot(contains('private')));
    expect(diagnostics, isNot(contains('secret')));
  });
}

T _success<T>(Result<T, Failure> result) =>
    result.when(failure: (failure) => fail(failure.message), success: (value) => value);

String _account() => 'test';
bool _canUseAccount() => true;
