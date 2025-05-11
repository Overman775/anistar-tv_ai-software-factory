part of 'log_viewer_cubit.dart';

abstract class LogViewerState extends Equatable {
  const LogViewerState();

  @override
  List<Object?> get props => [];
}

class LogViewerInitial extends LogViewerState {}

class LogViewerLoading extends LogViewerState {}

class LogViewerLoaded extends LogViewerState {
  final List<String> logFiles;
  final String? selectedLogFile;
  final String? logContent;
  final String? error;

  const LogViewerLoaded({required this.logFiles, this.selectedLogFile, this.logContent, this.error});

  @override
  List<Object?> get props => [logFiles, selectedLogFile, logContent, error];

  LogViewerLoaded copyWith({
    List<String>? logFiles,
    String? selectedLogFile,
    String? logContent,
    String? error,
    bool clearSelectedFile = false,
    bool clearContent = false,
    bool clearError = false,
  }) {
    return LogViewerLoaded(
      logFiles: logFiles ?? this.logFiles,
      selectedLogFile: clearSelectedFile ? null : selectedLogFile ?? this.selectedLogFile,
      logContent: clearContent ? null : logContent ?? this.logContent,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class LogViewerError extends LogViewerState {
  final String message;

  const LogViewerError(this.message);

  @override
  List<Object?> get props => [message];
}
