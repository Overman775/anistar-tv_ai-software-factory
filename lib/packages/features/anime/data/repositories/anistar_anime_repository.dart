import 'package:api/api.dart';
import '../../../../core/core.dart';
import '../../domain/models/anime_screen_data.dart';
import '../../domain/repositories/anime_repository.dart';
import '../mappers/anime_screen_data_mapper.dart';

final class AnistarAnimeRepository extends BaseRepository implements AnimeRepository {
  final AnimeClient _api;

  AnistarAnimeRepository(this._api, [super.logger]);

  @override
  Future<Either<Failure, AnimeScreenData>> getAnime({required int id, required String slug}) => makeApiCall(() async {
    final responses = await Future.wait([
      _api.getApiAnimeSlug(slug: slug),
      _api.getApiAnimeAnimeIdEpisodes(animeId: id),
    ]);
    final detail = responses[0] as AnimeDetailDto;
    final episodes = responses[1] as List<EpisodeInfoDto>;

    return toAnimeScreenData(detail, episodes);
  });
}
