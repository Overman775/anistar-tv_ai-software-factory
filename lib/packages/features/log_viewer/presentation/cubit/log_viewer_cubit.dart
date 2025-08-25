import 'package:anistar_tv/utils/logger/file_log_output.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'log_viewer_state.dart';

class LogViewerCubit extends Cubit<LogViewerState> {
  // LogService is now fully static, so no instance needed here.
  // final LogService _logService;

  LogViewerCubit(/*this._logService*/) : super(LogViewerInitial()) {
    // Remove _logService from constructor
    fetchLogFiles();
  }

  Future<void> fetchLogFiles() async {
    emit(LogViewerLoading());
    try {
      final files = await FileLogOutput.getLogFiles(); // Use static access
      if (files.isEmpty) {
        emit(const LogViewerLoaded(logFiles: [], error: 'No log files found.'));
      } else {
        emit(LogViewerLoaded(logFiles: files));
        // Optionally, load the newest log by default
        // if (files.isNotEmpty) {
        //   await loadLogContent(files.first);
        // }
      }
    } catch (e) {
      emit(LogViewerError('Failed to fetch log files: $e'));
    }
  }

  Future<void> loadLogContent(String fileName) async {
    if (state is! LogViewerLoaded) {
      // Should not happen if UI calls this only when files are loaded
      emit(const LogViewerError('Log files not loaded yet.'));

      return;
    }

    final currentState = state as LogViewerLoaded;
    emit(
      currentState.copyWith(logContent: null, error: null, clearError: true, selectedLogFile: fileName),
    ); // Show loading for content

    try {
      final content = await FileLogOutput.getLogContent(fileName); // Use static access
      emit(currentState.copyWith(selectedLogFile: fileName, logContent: content));
    } catch (e) {
      emit(currentState.copyWith(selectedLogFile: fileName, error: 'Failed to load log content: $e'));
    }
  }
}
