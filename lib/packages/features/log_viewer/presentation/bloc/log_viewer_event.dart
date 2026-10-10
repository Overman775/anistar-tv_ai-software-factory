part of 'log_viewer_bloc.dart';

@immutable
sealed class LogViewerEvent extends Equatable {
  @override
  List<Object?> get props => [runtimeType];

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
  List<Object?> get props => [runtimeType, fileName];

  const LogFileSelectedEvent(this.fileName);
}
