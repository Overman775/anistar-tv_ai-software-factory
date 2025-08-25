part of 'log_viewer_cubit.dart';

abstract class LogViewerState extends Equatable {
  @override
  List<Object?> get props => [];

  const LogViewerState();
}

class LogViewerInitial extends LogViewerState {}

class LogViewerLoading extends LogViewerState {}

class LogViewerLoaded extends LogViewerState {
  final List<String> logFiles;
  final String? selectedLogFile;
  final String? logContent;
  final String? error;

  @override
  List<Object?> get props => [logFiles, selectedLogFile, logContent, error];

  const LogViewerLoaded({required this.logFiles, this.selectedLogFile, this.logContent, this.error});

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

  @override
  List<Object?> get props => [message];

  const LogViewerError(this.message);
}
