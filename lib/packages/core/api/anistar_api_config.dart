import 'package:flutter/foundation.dart';

abstract final class AnistarApiConfig {
  static const _configuredUrl = String.fromEnvironment('ANISTAR_API_URL');

  static Uri get baseUri {
    final configured = _configuredUrl.trim();
    final fallback = defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8001/'
        : 'http://127.0.0.1:8001/';
    final uri = Uri.parse(configured.isEmpty ? fallback : configured);

    return uri.path.endsWith('/') ? uri : uri.replace(path: '${uri.path}/');
  }
}
