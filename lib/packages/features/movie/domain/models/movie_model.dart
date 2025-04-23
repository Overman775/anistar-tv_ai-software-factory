import 'package:freezed_annotation/freezed_annotation.dart';

part 'movie_model.freezed.dart';

@freezed
abstract class Movie with _$Movie {
  const factory Movie({required String title, String? imageUrl, required bool isViewed, required String videoUrl}) =
      _Movie;
}
