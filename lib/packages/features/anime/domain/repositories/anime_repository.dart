import '../models/anime_screen_data.dart';

abstract interface class AnimeRepository {
  Future<AnimeScreenData> getAnime({required int id, required String slug});
}
