import 'package:anistar_tv/packages/features/search/data/local_search_history_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../mocks/storage/memory_preferences_storage.dart';

void main() {
  test('guest, accounts and origins have isolated histories on shared preferences', () async {
    final storage = MemoryPreferencesStorage();
    final guest = LocalSearchHistoryRepository(storage, scope: 'https://first.test|guest');
    final account = LocalSearchHistoryRepository(storage, scope: 'https://first.test|account:alice');
    final other = LocalSearchHistoryRepository(storage, scope: 'https://second.test|guest');
    await guest.save(['guest-query']);
    await account.save(['account-query']);
    expect((await guest.read()).successOrNull, ['guest-query']);
    expect((await account.read()).successOrNull, ['account-query']);
    expect((await other.read()).successOrNull, isEmpty);
  });

  test('stored history trims, filters invalid entries, deduplicates and limits its snapshot', () async {
    final storage = MemoryPreferencesStorage();
    final repository = LocalSearchHistoryRepository(storage, scope: 'guest');
    await repository.save([
      '  Ёжик ',
      'ежик',
      '',
      List.filled(121, 'x').join(),
      ...List.generate(10, (i) => 'anime-$i'),
    ]);
    final history = (await repository.read()).successOrNull ?? (throw TestFailure('Expected stored search history'));
    expect(history, ['Ёжик', ...List.generate(7, (i) => 'anime-$i')]);
    expect(() => history.add('another'), throwsUnsupportedError);
  });

  test('preference read and write failures return failures without throwing', () async {
    final storage = MemoryPreferencesStorage()..failRead = true;
    final repository = LocalSearchHistoryRepository(storage, scope: 'guest');
    expect((await repository.read()).isFailure, isTrue);
    storage.failWrite = true;
    expect((await repository.save(['query'])).isFailure, isTrue);
  });
}
