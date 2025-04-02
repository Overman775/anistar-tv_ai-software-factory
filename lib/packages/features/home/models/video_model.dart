import 'dart:core';

/// Model representing a video
class VideoModel {
  /// Unique identifier for the video
  final String id;

  /// Title of the video
  final String title;

  /// Description of the video
  final String description;

  /// URL to the video thumbnail image
  final Uri thumbnailUrl;

  /// URL to the video file
  final String videoUrl;

  /// Duration of the video
  final Duration duration;

  /// Category of the video
  final String category;

  /// Constructor
  const VideoModel({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.videoUrl,
    required this.duration,
    required this.category,
  });

  /// Create a copy of this VideoModel with the given fields replaced with new values
  VideoModel copyWith({
    String? id,
    String? title,
    String? description,
    Uri? thumbnailUrl,
    String? videoUrl,
    Duration? duration,
    String? category,
  }) {
    return VideoModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      duration: duration ?? this.duration,
      category: category ?? this.category,
    );
  }
}
