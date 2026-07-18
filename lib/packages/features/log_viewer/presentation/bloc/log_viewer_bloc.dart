import 'package:anistar_tv/packages/features/log_viewer/domain/repositories/log_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'log_viewer_event.dart';
part 'log_viewer_state.dart';

final class LogViewerBloc extends Bloc<LogViewerEvent, LogViewerState> {
  final LogRepository _repository;

  LogViewerBloc({required this._repository}) : super(const LogViewerInitialState()) {
    on<LogViewerStartedEvent>(_onStarted);
    on<LogFileSelectedEvent>(_onFileSelected);
  }

  Future<void> _onFileSelected(LogFileSelectedEvent event, Emitter<LogViewerState> emit) async {
    final currentState = state;
    if (currentState is! LogViewerLoadedState) {
      emit(const LogViewerErrorState('Log files are not loaded yet.'));

      return;
    }

    emit(currentState.selecting(event.fileName));
    try {
      final content = await _repository.getLogContent(event.fileName);
      if (isClosed || emit.isDone) return;

      emit(currentState.withContent(fileName: event.fileName, content: content));
    } on Object catch (error) {
      if (isClosed || emit.isDone) return;

      emit(currentState.withError(fileName: event.fileName, message: 'Failed to load log content: $error'));
    }
  }

  Future<void> _onStarted(LogViewerStartedEvent event, Emitter<LogViewerState> emit) async {
    emit(const LogViewerLoadingState());
    try {
      final files = await _repository.getLogFiles();
      if (isClosed || emit.isDone) return;

      emit(LogViewerLoadedState(logFiles: files));
    } on Object catch (error) {
      if (isClosed || emit.isDone) return;

      emit(LogViewerErrorState('Failed to fetch log files: $error'));
    }
  }
}
