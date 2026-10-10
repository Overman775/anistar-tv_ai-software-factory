abstract final class AnistarMirrorConfig {
  static const _configuredUrl = String.fromEnvironment('ANISTAR_MIRROR_URL');

  static Uri get baseUri => resolve(_configuredUrl);

  static Uri resolve(String configuredUrl) {
    final value = configuredUrl.trim();
    final uri = Uri.tryParse(value.isEmpty ? 'https://v30.astar.bz/' : value);
    if (uri == null ||
        uri.scheme != 'https' ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.path != '' && uri.path != '/') {
      throw StateError('ANISTAR_MIRROR_URL must be an HTTPS site origin.');
    }

    return uri.replace(path: '/');
  }
}
