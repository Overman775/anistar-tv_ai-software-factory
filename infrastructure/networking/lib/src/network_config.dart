final class NetworkConfig {
  final Uri baseUri;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;

  /// Paths explicitly safe to show in diagnostics. Queries are always omitted.
  final Set<String> loggablePaths;

  const NetworkConfig({
    required this.baseUri,
    this.connectTimeout = const Duration(seconds: 8),
    this.receiveTimeout = const Duration(seconds: 20),
    this.sendTimeout = const Duration(seconds: 8),
    this.loggablePaths = const {},
  });
}
