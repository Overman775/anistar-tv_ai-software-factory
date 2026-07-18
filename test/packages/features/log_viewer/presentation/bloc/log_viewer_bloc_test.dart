import 'package:anistar_tv/packages/features/log_viewer/presentation/bloc/log_viewer_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_log_repository.dart';

void main() {
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
          error: 'Failed to load log content: Bad state: file unavailable',
        ),
      ],
    );

    blocTest<LogViewerBloc, LogViewerState>(
      'exposes repository failures as an error state',
      build: () => LogViewerBloc(repository: FakeLogRepository(filesError: StateError('storage unavailable'))),
      act: (bloc) => bloc.add(const LogViewerStartedEvent()),
      expect: () => <LogViewerState>[
        const LogViewerLoadingState(),
        const LogViewerErrorState('Failed to fetch log files: Bad state: storage unavailable'),
      ],
    );
  });
}
