import '../models/series_model.dart';
import '../repositories/series_list_repository.dart';

class GetSeriesListUseCase {
  final SeriesListRepository _repository;

  GetSeriesListUseCase(this._repository);

  Future<List<Series>> call(String url) async {
    return _repository.getSeriesList(url);
  }
}
