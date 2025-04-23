import 'package:freezed_annotation/freezed_annotation.dart';

part 'jw_video_info.freezed.dart';

@freezed
abstract class JwVideoInfo with _$JwVideoInfo {
  const factory JwVideoInfo({
    required String videoUrl,
    required String title,
    String? posterUrl,
    required bool isViewed,
  }) = _JwVideoInfo;
}
