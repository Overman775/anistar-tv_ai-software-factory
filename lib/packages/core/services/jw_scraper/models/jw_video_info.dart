/// Data model representing a JW Player video and its poster.
class JwVideoInfo {
  final String videoUrl;
  final String? posterUrl;

  JwVideoInfo({required this.videoUrl, this.posterUrl});

  @override
  String toString() => 'JwVideoInfo(videoUrl: \$videoUrl, posterUrl: \$posterUrl)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JwVideoInfo &&
          runtimeType == other.runtimeType &&
          videoUrl == other.videoUrl &&
          posterUrl == other.posterUrl;

  @override
  int get hashCode => videoUrl.hashCode ^ (posterUrl?.hashCode ?? 0);
}
