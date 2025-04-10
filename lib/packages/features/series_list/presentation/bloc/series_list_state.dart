part of 'series_list_bloc.dart';

@freezed
sealed class SeriesListState with _$SeriesListState {
  const factory SeriesListState.initial() = SeriesListInitial;
  const factory SeriesListState.loading() = SeriesListLoading;
  const factory SeriesListState.loaded({required List<Series> series}) = SeriesListLoaded;
  const factory SeriesListState.error({required String message}) = SeriesListError;
}
