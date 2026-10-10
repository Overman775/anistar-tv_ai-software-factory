// Each repeated mark/read observes a new persistence or account transition.
// ignore_for_file: prefer-moving-to-variable

import 'dart:async';

import 'package:anistar_tv/packages/features/watch_history/watched_episodes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storage/providers.dart';

import '../../../mocks/storage/memory_preferences_storage.dart';

void main() {
  late MemoryPreferencesStorage storage;
  late ProviderContainer container;
  String? account;
  final provider = watchedEpisodesProvider(10938);

  ProviderContainer createContainer() => ProviderContainer(
    overrides: [
      sharedPreferencesStorageProvider.overrideWithValue(storage),
      watchHistoryAccountProvider.overrideWith((ref) => account),
    ],
  );

  setUp(() {
    account = 'Алиса';
    storage = MemoryPreferencesStorage();
    container = createContainer();
  });
  tearDown(() => container.dispose());

  test('concurrent marks persist together; restarting restores by episode number', () async {
    await container.read(provider.future);
    final history = container.read(provider.notifier);
    expect(await Future.wait([history.markStarted(2), history.markStarted(1), history.markStarted(2)]), [
      true,
      true,
      true,
    ]);
    expect(storage.writes, 2);
    expect(container.read(provider).requireValue, {1, 2});
    container.dispose();
    container = createContainer();
    expect(await container.read(provider.future), {1, 2});
    expect(await container.read(watchedEpisodesProvider(10939).future), isEmpty);
  });

  test('account switch during a write cannot publish the previous account history', () async {
    await container.read(provider.future);
    final gate = storage.writeGate = Completer<void>();
    final pending = container.read(provider.notifier).markStarted(1);
    await Future<void>.delayed(Duration.zero);
    account = 'Боб';
    container.invalidate(watchHistoryAccountProvider);
    expect(await container.read(provider.future), isEmpty);
    gate.complete();
    await pending;
    expect(container.read(provider).requireValue, isEmpty);
    storage.writeGate = null;
    account = 'Алиса';
    container.invalidate(watchHistoryAccountProvider);
    expect(await container.read(provider.future), {1});
  });

  test('write failure does not publish a mark; subsequent explicit start can retry', () async {
    await container.read(provider.future);
    storage.failWrite = true;
    final history = container.read(provider.notifier);
    expect(await history.markStarted(1), isFalse);
    expect(container.read(provider).requireValue, isEmpty);
    storage.failWrite = false;
    expect(await history.markStarted(1), isTrue);
  });

  test('failed restore never overwrites existing data and anonymous starts are ignored', () async {
    storage.failRead = true;
    await expectLater(container.read(provider.future), throwsStateError);
    expect(await container.read(provider.notifier).markStarted(1), isFalse);
    expect(storage.writes, 0);
    account = null;
    container.invalidate(watchHistoryAccountProvider);
    expect(await container.read(provider.future), isEmpty);
    // Repeat after changing the scope to anonymous; this is a separate guard.
    // ignore: avoid-duplicate-test-assertions
    expect(await container.read(provider.notifier).markStarted(1), isFalse);
    // ignore: avoid-duplicate-test-assertions
    expect(storage.writes, 0);
  });
}
