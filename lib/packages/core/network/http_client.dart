import 'package:http/http.dart' as http;

import 'network_config.dart';

/// Small HTTP client for endpoints that do not belong to the OpenAPI contract.
final class HttpClient {
  final Uri _baseUri;
  final http.Client _client;

  HttpClient({required NetworkConfig config, http.Client? client})
    : _baseUri = config.baseUri,
      _client = client ?? http.Client();

  Future<http.Response> get(String path, {Map<String, String>? headers}) =>
      _client.get(_baseUri.resolve(path), headers: headers);

  void close() => _client.close();
}
