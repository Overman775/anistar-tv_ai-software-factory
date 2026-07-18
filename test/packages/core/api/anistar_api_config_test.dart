import 'package:anistar_tv/packages/core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('development entry point can use the local parser fallback', () {
    expect(
      AnistarApiConfig.resolve(configuredUrl: '', allowLocalFallback: true, platform: TargetPlatform.android),
      Uri.parse('http://10.0.2.2:8001/'),
    );
  });

  test('production entry point requires an explicit endpoint', () {
    expect(() => AnistarApiConfig.resolve(configuredUrl: '', allowLocalFallback: false), throwsStateError);
  });

  test('production entry point accepts and normalizes an explicit HTTPS endpoint', () {
    expect(
      AnistarApiConfig.resolve(configuredUrl: 'https://parser.example.com/api', allowLocalFallback: false),
      Uri.parse('https://parser.example.com/api/'),
    );
  });
}
