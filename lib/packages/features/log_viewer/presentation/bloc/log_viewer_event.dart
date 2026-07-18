part of 'log_viewer_bloc.dart';

@immutable
sealed class LogViewerEvent extends Equatable {
  @override
  List<Object?> get props => const [];

  const LogViewerEvent();
}

@immutable
final class LogViewerStartedEvent extends LogViewerEvent {
  const LogViewerStartedEvent();
}

@immutable
final class LogFileSelectedEvent extends LogViewerEvent {
  final String fileName;

  @override
  List<Object?> get props => [fileName];

  const LogFileSelectedEvent(this.fileName);
}
