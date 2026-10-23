// Each repeated mark/read observes a new persistence or account transition.

import 'dart:async';

import 'package:anistar_tv/packages/features/watch_history/watch_history_providers.dart';
import 'package:anistar_tv/packages/features/watch_history/watched_episodes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:networking/networking.dart';

import '../../../mocks/features/fake_watched_episodes_repository.dart';

void main() {
  late FakeWatchedEpisodesRepository repository;
  late ProviderContainer container;
  String? account;
  final provider = watchedEpisodesProvider(10938);

  ProviderContainer createContainer() => ProviderContainer(
    overrides: [
      watchedEpisodesRepositoryProvider.overrideWithValue(repository),
      watchHistoryAccountProvider.overrideWith((ref) => account),
    ],
  );

  setUp(() {
    account = 'Алиса';
    repository = FakeWatchedEpisodesRepository();
    container = createContainer();
  });
  tearDown(() => container.dispose());

  test('concurrent marks are confirmed by site; a new client reads the site history', () async {
    await container.read(provider.future);
    final history = container.read(provider.notifier);
    expect(await Future.wait([history.markStarted(2), history.markStarted(1), history.markStarted(2)]), [
      true,
      true,
      true,
    ]);
    expect(repository.writes, 2);
    expect(container.read(provider).requireValue, {1, 2});
    container.dispose();
    container = createContainer();
    expect(await container.read(provider.future), {1, 2});
    expect(await container.read(watchedEpisodesProvider(10939).future), isEmpty);
  });

  test('account switch during a site write cannot publish the previous account history', () async {
    await container.read(provider.future);
    final gate = repository.writeGate = Completer<void>();
    final pending = container.read(provider.notifier).markStarted(1);
    await Future<void>.delayed(Duration.zero);
    final oldRepository = repository;
    repository = FakeWatchedEpisodesRepository();
    container.updateOverrides([
      watchedEpisodesRepositoryProvider.overrideWithValue(repository),
      watchHistoryAccountProvider.overrideWith((ref) => account),
    ]);
    account = 'Боб';
    container.invalidate(watchHistoryAccountProvider);
    expect(await container.read(provider.future), isEmpty);
    gate.complete();
    await pending;
    expect(container.read(provider).requireValue, isEmpty);
    repository.writeGate = null;
    repository = oldRepository;
    container.updateOverrides([
      watchedEpisodesRepositoryProvider.overrideWithValue(repository),
      watchHistoryAccountProvider.overrideWith((ref) => account),
    ]);
    account = 'Алиса';
    container.invalidate(watchHistoryAccountProvider);
    expect(await container.read(provider.future), {1});
  });

  test('write failure does not publish a mark; subsequent explicit start can retry', () async {
    await container.read(provider.future);
    repository.failWrite = true;
    final history = container.read(provider.notifier);
    expect(await history.markStarted(1), isFalse);
    expect(container.read(provider).requireValue, isEmpty);
    repository.failWrite = false;
    expect(await history.markStarted(1), isTrue);
  });

  test('failed restore never overwrites existing data and anonymous starts are ignored', () async {
    repository
      ..failRead = true
      ..failWrite = true;
    await expectLater(container.read(provider.future), throwsA(isA<RequestFailure>()));
    expect(await container.read(provider.notifier).markStarted(1), isFalse);
    expect(repository.writes, 1);
    repository
      ..failRead = false
      ..failWrite = false;
    expect(await container.read(provider.notifier).markStarted(1), isTrue);
    final writes = repository.writes;
    account = null;
    container.invalidate(watchHistoryAccountProvider);
    expect(await container.read(provider.future), isEmpty);
    // Repeat after changing the scope to anonymous; this is a separate guard.
    expect(await container.read(provider.notifier).markStarted(1), isFalse);
    expect(repository.writes, writes);
  });
}
