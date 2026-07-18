import 'package:test/test.dart';
import 'package:anistar_api/anistar_api.dart';

// tests for PlaybackInfo
void main() {
  final instance = PlaybackInfoBuilder();
  // TODO add properties to the builder and call build()

  group(PlaybackInfo, () {
    // int animeId
    test('to test the property `animeId`', () async {
      // TODO
    });

    // int episodeNumber
    test('to test the property `episodeNumber`', () async {
      // TODO
    });

    // QualityType requestedQuality
    test('to test the property `requestedQuality`', () async {
      // TODO
    });

    // QualityType selectedQuality
    test('to test the property `selectedQuality`', () async {
      // TODO
    });

    // BuiltList<QualityType> availableQualities
    test('to test the property `availableQualities`', () async {
      // TODO
    });

    // API-relative HLS manifest path; resolve it against the configured API base URL
    // String manifestPath
    test('to test the property `manifestPath`', () async {
      // TODO
    });

    // int segmentTokenTtlSeconds
    test('to test the property `segmentTokenTtlSeconds`', () async {
      // TODO
    });
  });
}
