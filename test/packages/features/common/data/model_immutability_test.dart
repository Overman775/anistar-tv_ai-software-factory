import 'package:anistar/anistar.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_details.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_episode.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_screen_data.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/catalog_filter.dart';
import 'package:anistar_tv/packages/features/player/domain/models/playback_episode.dart';
import 'package:anistar_tv/packages/features/player/domain/models/playback_quality.dart';
import 'package:anistar_tv/packages/features/player/domain/models/playback_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DTO collections take immutable snapshots including nested sources', () {
    final headers = {'Token': 'first'};
    final source = AnistarVideoSourceDto(
      height: 720,
      manifestUri: Uri.parse('https://cdn.test/video'),
      httpHeaders: headers,
    );
    final sources = [source];
    final episode = AnistarEpisodeDto(number: 1, title: 'One', sources: sources);
    final items = [const AnistarAnimeSummaryDto(id: 1, slug: '1-anime', title: 'Anime')];
    final page = AnistarCatalogPageDto(items: items, page: 1, hasNext: false);
    final genres = ['Comedy'];
    final filters = [const AnistarCatalogFilterDto(label: 'Comedy', path: '/comedy/')];
    final details = AnistarAnimeDetailsDto(id: 1, slug: '1-anime', title: 'Anime', genres: genres, filters: filters);
    headers['Token'] = 'second';
    sources.clear();
    items.clear();
    genres.clear();
    filters.clear();
    expect(episode.sources.single.httpHeaders, {'Token': 'first'});
    expect(page.items.single.slug, '1-anime');
    expect(details.genres, ['Comedy']);
    expect(details.filters.single.path, '/comedy/');
    _listProtected(episode.sources, source);
    _listProtected(page.items, page.items.single);
    _listProtected(details.genres, 'Other');
    _listProtected(details.filters, details.filters.single);
    expect(() => source.httpHeaders['Token'] = 'changed', throwsUnsupportedError);
  });

  test('domain query results protect lists maps and sets from callers and inputs', () {
    final summaries = [const AnimeSummary(id: 1, slug: '1-anime', title: 'Anime')];
    final page = AnimePage(items: summaries, page: 1, hasNext: false);
    final genres = ['Comedy'];
    final filters = [const CatalogFilter(label: 'Comedy', path: '/comedy/')];
    final details = AnimeDetails(
      id: 1,
      slug: '1-anime',
      title: 'Anime',
      genres: genres,
      filters: filters,
      isOngoing: false,
    );
    final episodes = [const AnimeEpisode(number: 1, title: 'One')];
    final screen = AnimeScreenData(details: details, episodes: episodes);
    final qualities = [PlaybackQuality.low, PlaybackQuality.high];
    final playbackEpisodes = [
      const PlaybackEpisode(number: 1, title: 'One', isWatched: true),
      const PlaybackEpisode(number: 3, title: 'Three'),
    ];
    final headers = {'Token': 'first'};
    final session = PlaybackSession(
      manifestUri: Uri.parse('https://cdn.test/video'),
      requestedQuality: PlaybackQuality.high,
      selectedQuality: PlaybackQuality.high,
      availableQualities: qualities,
      episodes: playbackEpisodes,
      httpHeaders: headers,
    );
    summaries.clear();
    genres.clear();
    filters.clear();
    episodes.clear();
    qualities.clear();
    playbackEpisodes.clear();
    headers.clear();
    expect(page.items.single.posterUri, isNull);
    expect(screen.details.genres, ['Comedy']);
    expect(screen.episodes.single.number, 1);
    expect(session.episodeNumbers, [1, 3]);
    expect(session.watchedEpisodes, {1});
    expect(session.httpHeaders, {'Token': 'first'});
    _listProtected(page.items, page.items.single);
    _listProtected(details.genres, 'Other');
    _listProtected(details.filters, details.filters.single);
    _listProtected(screen.episodes, screen.episodes.single);
    _listProtected(session.availableQualities, PlaybackQuality.low);
    _listProtected(session.episodeNumbers, 9);
    expect(() => session.watchedEpisodes.add(3), throwsUnsupportedError);
    expect(() => session.httpHeaders['Token'] = 'changed', throwsUnsupportedError);
    final next = AnimePage(items: [], page: 2, hasNext: false);
    expect(next.items, isEmpty);
    expect(page.items, hasLength(1));
  });
}

void _listProtected<T>(List<T> list, T value) {
  expect(() => list.add(value), throwsUnsupportedError);
  expect(() => list[0] = value, throwsUnsupportedError);
}
