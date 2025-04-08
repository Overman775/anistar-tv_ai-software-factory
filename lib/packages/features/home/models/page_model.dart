import 'package:freezed_annotation/freezed_annotation.dart';

import 'video_model.dart';

part 'page_model.freezed.dart';

@freezed
abstract class PageModel with _$PageModel {
  const factory PageModel({required List<VideoModel> videos, required String title, required bool hasMorePages}) =
      _PageModel;
}
