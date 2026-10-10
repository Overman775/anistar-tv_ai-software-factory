import 'package:anistar/anistar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('both entry points use the direct HTTPS mirror by default', () {
    expect(AnistarMirrorConfig.resolve(''), Uri.parse('https://v30.astar.bz/'));
    expect(AnistarMirrorConfig.resolve('https://mirror.test'), Uri.parse('https://mirror.test/'));
  });

  test('mirror configuration rejects unsafe or ambiguous origins', () {
    for (final value in [
      'http://mirror.test',
      'mirror.test',
      'https://user:pass@mirror.test',
      'https://mirror.test/api',
      'https://mirror.test/?a=1',
    ]) {
      expect(() => AnistarMirrorConfig.resolve(value), throwsStateError);
    }
  });
}
