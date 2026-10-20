import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storage/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final calls = <MethodCall>[];
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);

      return call.method == 'containsKey' ? true : null;
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('iOS storage operations use flavor service and private unsynchronized unlocked Keychain', () async {
    final storage = SecureStorage();
    await storage.set('session', 'fixture');
    await storage.get('session');
    await storage.containsKey('session');
    await storage.remove('session');
    expect(calls.map((call) => call.method), ['write', 'read', 'containsKey', 'delete']);
    const flavor = String.fromEnvironment('FLUTTER_APP_FLAVOR');
    for (final call in calls) {
      final arguments = call.arguments as Map<Object?, Object?>;
      final options = arguments['options'];
      expect(options, isA<Map<Object?, Object?>>());
      if (options is! Map<Object?, Object?>) {
        fail('Secure storage options must be a map');
      }
      expect(options['accountName'], flavor == 'dev' ? 'com.anistar.tv.dev' : 'com.anistar.tv');
      expect(options['accessibility'], 'unlocked');
      expect(options['synchronizable'], 'false');
      expect(options['groupId'], isNull);
    }
  });
}
