import 'package:flutter/foundation.dart';

abstract final class AnistarApiConfig {
  static const _configuredUrl = String.fromEnvironment('ANISTAR_API_URL');

  static Uri baseUri({required bool allowLocalFallback}) =>
      resolve(configuredUrl: _configuredUrl, allowLocalFallback: allowLocalFallback);

  @visibleForTesting
  static Uri resolve({required String configuredUrl, required bool allowLocalFallback, TargetPlatform? platform}) {
    final configured = configuredUrl.trim();
    if (configured.isEmpty && !allowLocalFallback) {
      throw StateError('ANISTAR_API_URL must be configured for the production entry point.');
    }
    final fallback = (platform ?? defaultTargetPlatform) == TargetPlatform.android
        ? 'http://10.0.2.2:8001/'
        : 'http://127.0.0.1:8001/';
    final uri = Uri.parse(configured.isEmpty ? fallback : configured);
    if (!uri.hasAuthority || uri.scheme != 'http' && uri.scheme != 'https') {
      throw StateError('ANISTAR_API_URL must be an absolute HTTP(S) URL.');
    }
    if (!allowLocalFallback && uri.scheme != 'https') {
      throw StateError('ANISTAR_API_URL must use HTTPS for the production entry point.');
    }

    return uri.path.endsWith('/') ? uri : uri.replace(path: '${uri.path}/');
  }
}
