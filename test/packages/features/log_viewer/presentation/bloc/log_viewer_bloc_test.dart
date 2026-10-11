import 'dart:async';

import 'package:anistar_tv/packages/features/log_viewer/presentation/bloc/log_viewer_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../mocks/features/log_viewer/fake_log_repository.dart';

void main() {
  test('value identity distinguishes lifecycle states and still deduplicates equal content', () {
    expect(const LogViewerInitialState(), isNot(const LogViewerLoadingState()));
    expect(const LogViewerLoadingState(), isNot(const LogViewerInitialState()));
    expect(const LogViewerLoadedState(logFiles: ['latest.log']), const LogViewerLoadedState(logFiles: ['latest.log']));
    expect(const LogViewerErrorState('unavailable'), const LogViewerErrorState('unavailable'));
    expect(const LogViewerErrorState('unavailable'), isNot(const LogViewerErrorState('denied')));
  });

  test('refreshing the list invalidates a pending file response', () async {
    final content = Completer<String>();
    var listRequests = 0;
    final bloc = LogViewerBloc(
      repository: FakeLogRepository(
        loadFiles: () async => ++listRequests == 1 ? ['old.txt'] : ['new.txt'],
        loadContent: (_) => content.future,
      ),
    );
    addTearDown(bloc.close);
    final firstList = bloc.stream.firstWhere((state) => state is LogViewerLoadedState);
    bloc.add(const LogViewerStartedEvent());
    await firstList;
    bloc.add(const LogFileSelectedEvent('old.txt'));
    await Future<void>.delayed(Duration.zero);
    final refreshed = bloc.stream.firstWhere(
      (state) => state is LogViewerLoadedState && state.logFiles.contains('new.txt'),
    );
    bloc.add(const LogViewerStartedEvent());
    await refreshed;
    content.complete('obsolete file');
    await Future<void>.delayed(Duration.zero);
    expect((bloc.state as LogViewerLoadedState).logFiles, ['new.txt']);
    expect((bloc.state as LogViewerLoadedState).selectedLogFile, isNull);
  });

  test('a late file response cannot replace the most recent selection', () async {
    final first = Completer<String>();
    final second = Completer<String>();
    final bloc = LogViewerBloc(
      repository: FakeLogRepository(
        files: const ['first.txt', 'second.txt'],
        loadContent: (name) => name == 'first.txt' ? first.future : second.future,
      ),
    );
    addTearDown(bloc.close);
    final loaded = bloc.stream.firstWhere((state) => state is LogViewerLoadedState);
    bloc.add(const LogViewerStartedEvent());
    await loaded;
    bloc.add(const LogFileSelectedEvent('first.txt'));
    await Future<void>.delayed(Duration.zero);
    bloc.add(const LogFileSelectedEvent('second.txt'));
    await Future<void>.delayed(Duration.zero);
    second.complete('new content');
    await Future<void>.delayed(Duration.zero);
    first.complete('stale content');
    await Future<void>.delayed(Duration.zero);
    expect((bloc.state as LogViewerLoadedState).selectedLogFile, 'second.txt');
    expect((bloc.state as LogViewerLoadedState).logContent, 'new content');
  });

  test('pending content cannot emit after bloc disposal', () async {
    final content = Completer<String>();
    final bloc = LogViewerBloc(
      repository: FakeLogRepository(files: ['log.txt'], loadContent: (_) => content.future),
    );
    final loaded = bloc.stream.firstWhere((state) => state is LogViewerLoadedState);
    bloc.add(const LogViewerStartedEvent());
    await loaded;
    bloc.add(const LogFileSelectedEvent('log.txt'));
    await Future<void>.delayed(Duration.zero);
    final closing = bloc.close();
    content.complete('late content');
    await closing;
    expect(bloc.isClosed, isTrue);
    expect((bloc.state as LogViewerLoadedState).logContent, isNull);
  });

  group(LogViewerBloc, () {
    blocTest<LogViewerBloc, LogViewerState>(
      'loads the available log files',
      build: () => LogViewerBloc(repository: FakeLogRepository(files: const ['latest.log', 'older.log'])),
      act: (bloc) => bloc.add(const LogViewerStartedEvent()),
      expect: () => const <LogViewerState>[
        LogViewerLoadingState(),
        LogViewerLoadedState(logFiles: ['latest.log', 'older.log']),
      ],
    );

    blocTest<LogViewerBloc, LogViewerState>(
      'loads the selected log content',
      build: () => LogViewerBloc(repository: FakeLogRepository(content: 'application log')),
      seed: () => const LogViewerLoadedState(logFiles: ['latest.log']),
      act: (bloc) => bloc.add(const LogFileSelectedEvent('latest.log')),
      expect: () => const <LogViewerState>[
        LogViewerLoadedState(logFiles: ['latest.log'], selectedLogFile: 'latest.log'),
        LogViewerLoadedState(logFiles: ['latest.log'], selectedLogFile: 'latest.log', logContent: 'application log'),
      ],
    );

    blocTest<LogViewerBloc, LogViewerState>(
      'keeps the file selection when content loading fails',
      build: () => LogViewerBloc(repository: FakeLogRepository(contentError: StateError('file unavailable'))),
      seed: () => const LogViewerLoadedState(logFiles: ['latest.log']),
      act: (bloc) => bloc.add(const LogFileSelectedEvent('latest.log')),
      expect: () => const <LogViewerState>[
        LogViewerLoadedState(logFiles: ['latest.log'], selectedLogFile: 'latest.log'),
        LogViewerLoadedState(
          logFiles: ['latest.log'],
          selectedLogFile: 'latest.log',
          error: 'Не удалось выполнить запрос.',
        ),
      ],
    );

    blocTest<LogViewerBloc, LogViewerState>(
      'exposes repository failures as an error state',
      build: () => LogViewerBloc(repository: FakeLogRepository(filesError: StateError('storage unavailable'))),
      act: (bloc) => bloc.add(const LogViewerStartedEvent()),
      expect: () => <LogViewerState>[
        const LogViewerLoadingState(),
        const LogViewerErrorState('Не удалось выполнить запрос.'),
      ],
    );
  });
}
