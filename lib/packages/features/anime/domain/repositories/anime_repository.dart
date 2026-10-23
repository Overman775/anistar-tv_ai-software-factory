import 'package:core/data.dart';

import '../models/anime_screen_data.dart';

// Repository identity is required for DI and interchangeable implementations.
abstract interface class AnimeRepository {
  Future<Result<AnimeScreenData, Failure>> getAnime({required int id, required String slug});
}
