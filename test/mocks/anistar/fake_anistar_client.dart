import 'package:anistar/anistar.dart';

/// Contract-only fake: no HTML, transport, session or provider dependencies.
final class FakeAnistarClient implements AnistarClient {
  final List<String> calls = [];
  Object? error;
  String? account;
  Stream<void> expiry = const Stream.empty();
  AnistarCatalogPageDto? pageResult;
  List<AnistarCatalogFilterDto> genreResult = const [];
  AnistarAnimeDetailsDto detailResult = AnistarAnimeDetailsDto(id: 1, slug: '1-anime', title: 'Anime');
  List<AnistarEpisodeDto> episodeResult = [];
  Set<int> watchedResult = {};
  bool favorite = false;
  Future<AnistarAnimeDetailsDto> Function(String)? loadDetails;
  Future<List<AnistarEpisodeDto>> Function(int)? loadEpisodes;
  AnistarCatalogSort? lastSort;
  String? lastPath;

  @override
  Stream<void> get expired => expiry;

  @override
  Future<String?> restore({void Function()? onSessionCheck}) => _reply('restore', () {
    onSessionCheck?.call();

    return account;
  });

  @override
  Future<String> signIn(String username, String password) => _reply('signIn', () => account = username);

  @override
  Future<void> signOut() => _reply('signOut', () => account = null);

  @override
  Future<AnistarCatalogPageDto> catalog(int page, {String? filterPath, AnistarCatalogSort? sort}) =>
      _reply('catalog', () {
        lastSort = sort;
        lastPath = filterPath;

        return pageResult ?? AnistarCatalogPageDto(items: [], page: page, hasNext: false);
      });

  @override
  Future<AnistarCatalogPageDto> favorites(int page) =>
      _reply('favorites', () => pageResult ?? AnistarCatalogPageDto(items: [], page: page, hasNext: false));

  @override
  Future<List<AnistarCatalogFilterDto>> genres() => _reply('genres', () => genreResult);

  @override
  Future<AnistarAnimeDetailsDto> details(String slug) async {
    final result = await _reply('details', () => detailResult);

    return loadDetails?.call(slug) ?? result;
  }

  @override
  Future<List<AnistarEpisodeDto>> episodes(int animeId) async {
    final result = await _reply('episodes', () => episodeResult);

    return loadEpisodes?.call(animeId) ?? result;
  }

  @override
  Future<bool> favoriteStatus({required int animeId, required String slug}) => _reply('favoriteStatus', () => favorite);

  @override
  Future<bool> setFavorite({required int animeId, required String slug, required bool favorite}) =>
      _reply('setFavorite', () => this.favorite = favorite);

  @override
  Future<Set<int>> watchedEpisodes(int animeId) => _reply('watchedEpisodes', () => watchedResult);

  @override
  Future<Set<int>> markWatched({required int animeId, required int episodeNumber}) =>
      _reply('markWatched', () => watchedResult);
  Future<T> _reply<T>(String operation, T Function() value) async {
    calls.add(operation);
    final failure = error;
    if (failure != null) {
      // Tests intentionally inject both expected exceptions and programming errors.
      // ignore: only_throw_errors
      throw failure;
    }

    return value();
  }
}
