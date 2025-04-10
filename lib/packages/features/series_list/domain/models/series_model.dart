import 'package:freezed_annotation/freezed_annotation.dart';

part 'series_model.freezed.dart';

@freezed
abstract class Series with _$Series {
  const factory Series({
    required String seriesNumber, // Using String as it might contain non-numeric parts like "OVA" or "Special"
    required String title,
    required String dataUrl, // URL or identifier to fetch video links for this series
  }) = _Series;
}
