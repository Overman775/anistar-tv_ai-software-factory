import 'package:anistar_tv/packages/features/series_list/domain/models/series_model.dart';

abstract class SeriesListRepository {
  /// Fetches the list of series available for a specific anime title URL.
  ///
  /// Throws an exception if fetching or parsing fails.
  Future<List<Series>> getSeriesList(String url);
}
