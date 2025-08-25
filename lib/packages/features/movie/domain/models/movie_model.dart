import 'package:freezed_annotation/freezed_annotation.dart';

part 'movie_model.freezed.dart';

@freezed
abstract class MovieModel with _$MovieModel {
  const factory MovieModel({
    required String title,
    String? imageUrl,
    required bool isViewed,
    required String videoUrl,
  }) = _MovieModel;
}
