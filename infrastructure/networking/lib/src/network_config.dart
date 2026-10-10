final class NetworkConfig {
  final Uri baseUri;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;

  const NetworkConfig({
    required this.baseUri,
    this.connectTimeout = const Duration(seconds: 8),
    this.receiveTimeout = const Duration(seconds: 20),
    this.sendTimeout = const Duration(seconds: 8),
  });
}
