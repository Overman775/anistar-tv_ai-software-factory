/// A ready-to-play source. Headers and optional expiry belong to this URI.
/// The adapter preserves the original signed URI; consumers do not rebuild it.
final class AnistarVideoSourceDto {
  final int height;
  final Uri manifestUri;
  final Map<String, String> httpHeaders;
  final DateTime? expiresAt;

  AnistarVideoSourceDto({
    required this.height,
    required this.manifestUri,
    Map<String, String> httpHeaders = const {},
    this.expiresAt,
  }) : httpHeaders = Map.unmodifiable(httpHeaders);
}
