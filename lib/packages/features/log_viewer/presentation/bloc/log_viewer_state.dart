part of 'log_viewer_bloc.dart';

@immutable
sealed class LogViewerState extends Equatable {
  @override
  List<Object?> get props => const [];

  const LogViewerState();
}

@immutable
final class LogViewerInitialState extends LogViewerState {
  const LogViewerInitialState();
}

@immutable
final class LogViewerLoadingState extends LogViewerState {
  const LogViewerLoadingState();
}

@immutable
final class LogViewerLoadedState extends LogViewerState {
  final List<String> logFiles;
  final String? selectedLogFile;
  final String? logContent;
  final String? error;

  @override
  List<Object?> get props => [logFiles, selectedLogFile, logContent, error];

  const LogViewerLoadedState({required this.logFiles, this.selectedLogFile, this.logContent, this.error});

  LogViewerLoadedState selecting(String fileName) {
    return LogViewerLoadedState(logFiles: logFiles, selectedLogFile: fileName);
  }

  LogViewerLoadedState withContent({required String fileName, required String content}) {
    return LogViewerLoadedState(logFiles: logFiles, selectedLogFile: fileName, logContent: content);
  }

  LogViewerLoadedState withError({required String fileName, required String message}) {
    return LogViewerLoadedState(logFiles: logFiles, selectedLogFile: fileName, error: message);
  }
}

@immutable
final class LogViewerErrorState extends LogViewerState {
  final String message;

  @override
  List<Object?> get props => [message];

  const LogViewerErrorState(this.message);
}
