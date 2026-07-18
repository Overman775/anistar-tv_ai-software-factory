import 'package:test/test.dart';
import 'package:anistar_api/anistar_api.dart';

/// tests for VideoApi
void main() {
  final instance = AnistarApi().getVideoApi();

  group(VideoApi, () {
    // Get a rewritten HLS manifest
    //
    // Returns an HLS manifest whose resources use short-lived signed API paths.
    //
    //Future<String> getHlsManifest(int animeId, int episodeNumber, { QualityType quality }) async
    test('test getHlsManifest', () async {
      // TODO
    });

    // Stream a signed HLS resource
    //
    // Used by URLs embedded in the rewritten manifest. Flutter applications normally do not call this operation directly.
    //
    //Future<Uint8List> getHlsResource(int animeId, int episodeNumber, String token, { String range }) async
    test('test getHlsResource', () async {
      // TODO
    });

    // Get HLS playback information
    //
    // Returns a JSON contract for Flutter. Resolve `manifest_path` against the API base URL and pass the resulting URL to an HLS-capable player.
    //
    //Future<PlaybackInfo> getPlaybackInfo(int animeId, int episodeNumber, { QualityType quality }) async
    test('test getPlaybackInfo', () async {
      // TODO
    });
  });
}
