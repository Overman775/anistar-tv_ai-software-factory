import 'package:core/data.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/log_repository.dart';
part 'log_viewer_event.dart';
part 'log_viewer_state.dart';

final class LogViewerBloc extends Bloc<LogViewerEvent, LogViewerState> {
  final LogRepository _repository;
  int _requestGeneration = 0;

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

    final generation = ++_requestGeneration;
    emit(currentState.selecting(event.fileName));
    try {
      final result = await _repository.getLogContent(event.fileName);
      if (isClosed || emit.isDone || generation != _requestGeneration) {
        return;
      }

      result.when(
        failure: (failure) => emit(currentState.withError(fileName: event.fileName, message: failure.message)),
        success: (content) => emit(currentState.withContent(fileName: event.fileName, content: content)),
      );
    } on Object {
      if (isClosed || emit.isDone || generation != _requestGeneration) {
        return;
      }

      emit(currentState.withError(fileName: event.fileName, message: const UnknownFailure().message));
    }
  }

  Future<void> _onStarted(LogViewerStartedEvent event, Emitter<LogViewerState> emit) async {
    final generation = ++_requestGeneration;
    emit(const LogViewerLoadingState());
    try {
      final result = await _repository.getLogFiles();
      if (isClosed || emit.isDone || generation != _requestGeneration) {
        return;
      }

      result.when(
        failure: (failure) => emit(LogViewerErrorState(failure.message)),
        success: (files) => emit(LogViewerLoadedState(logFiles: List.unmodifiable(files))),
      );
    } on Object {
      if (isClosed || emit.isDone || generation != _requestGeneration) {
        return;
      }

      emit(LogViewerErrorState(const UnknownFailure().message));
    }
  }
}
