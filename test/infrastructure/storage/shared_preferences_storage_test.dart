import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storage/storage.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('round-trips every supported preference type', () async {
    final storage = SharedPreferencesStorage();
    await storage.set('bool', true);
    await storage.set('int', 7);
    await storage.set('double', 1.5);
    await storage.set('string', 'value');
    await storage.set('list', const ['one', 'two']);

    expect(await storage.get('bool', false), isTrue);
    expect(await storage.get('int', 0), 7);
    expect(await storage.get<double>('double', 0), 1.5);
    expect(await storage.get('string', ''), 'value');
    expect(await storage.get('list', const <String>[]), ['one', 'two']);
  });

  test('returns the supplied default for a missing or mismatched value', () async {
    SharedPreferences.setMockInitialValues({'number': 7});
    final storage = SharedPreferencesStorage();

    expect(await storage.get('number', 'fallback'), 'fallback');
    expect(await storage.get('missing', false), isFalse);
  });

  test('rejects unsupported values before persisting them', () async {
    final storage = SharedPreferencesStorage();

    await expectLater(storage.set('unsupported', Object()), throwsUnsupportedError);
    expect(await storage.containsKey('unsupported'), isFalse);
  });

  test('removes, checks and clears the cached preference store', () async {
    final storage = SharedPreferencesStorage();
    await storage.set('first', 'value');
    await storage.set('second', 2);
    expect(await storage.containsKey('first'), isTrue);
    expect(await storage.remove('first'), isTrue);
    expect(await storage.containsKey('first'), isFalse);
    expect(await storage.clear(), isTrue);
    expect(await storage.containsKey('second'), isFalse);
  });

  test('reuses the initialized plugin instance', () async {
    final storage = SharedPreferencesStorage();

    expect(await storage.init(), same(await storage.init()));
  });
}
