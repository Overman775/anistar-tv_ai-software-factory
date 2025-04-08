import 'package:freezed_annotation/freezed_annotation.dart';

part 'video_model.freezed.dart';

/// Model representing a video
@freezed
abstract class VideoModel with _$VideoModel {
  /// Constructor
  const factory VideoModel({
    /// Unique identifier for the video
    required String id,

    /// Title of the video
    required String title,

    /// Description of the video
    required String description,

    /// URL to the video thumbnail image
    required Uri thumbnailUrl,

    /// URL to the video file
    required String videoUrl,

    /// Duration of the video
    required Duration duration,

    /// Category of the video
    required String category,

    /// Rating of the video (optional)
    double? rating,
  }) = _VideoModel;
}
