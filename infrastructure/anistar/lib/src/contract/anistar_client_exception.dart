/// Expected failure with a safe message. Contains no transport/session details.
final class AnistarClientException implements Exception {
  final AnistarClientErrorCategory category;
  final String message;

  const AnistarClientException(this.category, this.message);

  @override
  String toString() => 'AnistarClientException(${category.name}): $message';
}

enum AnistarClientErrorCategory { timeout, connection, server, request }
