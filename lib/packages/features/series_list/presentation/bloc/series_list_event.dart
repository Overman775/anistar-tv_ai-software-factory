part of 'series_list_bloc.dart';

@freezed
sealed class SeriesListEvent with _$SeriesListEvent {
  const factory SeriesListEvent.load({required String url}) = LoadSeriesList;
}
