import '../../../../core/core.dart';
import '../models/anime_screen_data.dart';

abstract interface class AnimeRepository {
  Future<Either<Failure, AnimeScreenData>> getAnime({required int id, required String slug});
}
