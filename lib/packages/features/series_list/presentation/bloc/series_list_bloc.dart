import 'package:anistar_tv/packages/features/series_list/domain/models/series_model.dart';
import 'package:anistar_tv/packages/features/series_list/domain/usecases/get_series_list_usecase.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'series_list_bloc.freezed.dart';
part 'series_list_event.dart';
part 'series_list_state.dart';

class SeriesListBloc extends Bloc<SeriesListEvent, SeriesListState> {
  final GetSeriesListUseCase _getSeriesListUseCase;

  SeriesListBloc({required GetSeriesListUseCase getSeriesListUseCase})
    : _getSeriesListUseCase = getSeriesListUseCase,
      super(const SeriesListState.initial()) {
    on<LoadSeriesList>(_onLoadSeriesList);
  }

  Future<void> _onLoadSeriesList(LoadSeriesList event, Emitter<SeriesListState> emit) async {
    // Emit loading state only if the current state is initial
    // to avoid flickering on refresh.
    if (state is SeriesListInitial) {
      emit(const SeriesListState.loading());
    }
    try {
      // Use the injected use case to fetch the series list
      final series = await _getSeriesListUseCase(event.url);
      emit(SeriesListState.loaded(series: series));
    } catch (e) {
      // Emit error state if fetching fails
      // Consider logging the error e.g., using a Logger service
      // logger.severe('Failed to load series list: \$e');
      emit(SeriesListState.error(message: e.toString()));
    }
  }
}
