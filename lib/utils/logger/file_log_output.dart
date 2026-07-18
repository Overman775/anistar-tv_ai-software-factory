import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

class FileLogOutput implements LogOutput {
  @visibleForTesting
  // ignore: avoid-global-state
  static Isolate? fileIsolate;

  @visibleForTesting
  // ignore: avoid-global-state
  static Directory Function(String path) directoryCreator = Directory.new;

  @visibleForTesting
  // ignore: avoid-global-state
  static File Function(String path) fileCreator = File.new;

  static SendPort? _sendPort;
  static final List<String> _logBuffer = [];
  static String? _currentLogFileName;
  static Directory? _logDirectory;
  static ReceivePort? _receivePortForTest;

  @visibleForTesting
  static SendPort? get sendPortForTest => _sendPort;
  static List<String> get logBufferForTest => _logBuffer;
  @visibleForTesting
  static String? get currentLogFileNameForTest => _currentLogFileName;
  @visibleForTesting
  static Directory? get logDirectoryForTest => _logDirectory;
  @visibleForTesting
  static ReceivePort? get receivePortForTest => _receivePortForTest;

  @visibleForTesting
  static void resetForTest() {
    _sendPort = null;
    _logBuffer.clear();
    _currentLogFileName = null;
    _logDirectory = null;
    _receivePortForTest?.close();
    _receivePortForTest = null;
    fileIsolate = null;
    directoryCreator = Directory.new;
    fileCreator = File.new;
  }

  @override
  Future<void> init() async {
    final dir = await getApplicationCacheDirectory();
    _logDirectory = directoryCreator('${dir.path}/logs');
    final logDir = _logDirectory;
    // ignore: avoid_slow_async_io, initialization must not block the UI isolate.
    if (logDir != null && !await logDir.exists()) {
      await logDir.create(recursive: true);
    }

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    _currentLogFileName = 'app_log_$timestamp.txt';

    _receivePortForTest = ReceivePort();
    fileIsolate = await Isolate.spawn(_logIsolateEntryPoint, _receivePortForTest?.sendPort);
    _sendPort = await _receivePortForTest?.first as SendPort?;

    if (_sendPort != null) {
      _sendPort?.send({
        'logFilePath': '${_logDirectory?.path}/$_currentLogFileName',
        'initialBuffer': List<String>.from(_logBuffer),
      });
      _logBuffer.clear();
    }

    debugPrint('LogService initialized');
  }

  @override
  void output(OutputEvent event) {
    final logEntry = _formatLog(event.origin.level, event.origin.message, event.origin.error, event.origin.stackTrace);
    if (_sendPort == null) {
      _logBuffer.add(logEntry);
      if (_logBuffer.length > 1000) {
        _logBuffer.removeAt(0);
      }
    }

    _sendPort?.send(logEntry);
  }

  static Future<List<String>> getLogFiles() async {
    final logDir = _logDirectory;
    // ignore: avoid_slow_async_io, log discovery must not block the UI isolate.
    if (logDir == null || !await logDir.exists()) {
      return [];
    }
    try {
      // ignore: avoid_slow_async_io, directory listing must not block the UI isolate.
      final files = await logDir.list().toList();

      return files
          .where((fsEntity) => fsEntity is File && fsEntity.path.endsWith('.txt'))
          .map((fsEntity) => fsEntity.path.split('/').last)
          .toList()
        ..sort((a, b) => b.compareTo(a));
    } on FileSystemException catch (e) {
      debugPrint('Error listing log files (appLogger not ready): $e');

      return [];
    }
  }

  static Future<String> getLogContent(String fileName) async {
    if (_logDirectory == null) {
      return 'Log directory not available.';
    }
    try {
      final file = fileCreator('${_logDirectory?.path}/$fileName');

      // ignore: avoid_slow_async_io, reading logs must not block the UI isolate.
      return await file.exists() ? await file.readAsString() : 'File not found: $fileName';
    } on FileSystemException catch (e) {
      debugPrint('Error reading log file $fileName (appLogger not ready): $e');

      return 'Error reading log file: $e';
    }
  }

  @override
  Future<void> destroy() async {
    _sendPort = null;
    _receivePortForTest?.close();
    _receivePortForTest = null;
    fileIsolate?.kill(priority: Isolate.immediate);
    fileIsolate = null;
  }

  String _formatLog(Level level, Object? message, [Object? error, StackTrace? stackTrace]) {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
    var logStr = '$timestamp [${level.name.toUpperCase()}] $message';
    if (error != null) {
      logStr += '\nError: $error';
    }
    if (stackTrace != null) {
      logStr += '\nStackTrace: $stackTrace';
    }

    return logStr;
  }
}

void _logIsolateEntryPoint(SendPort? sendPort) {
  final receivePort = ReceivePort();
  sendPort?.send(receivePort.sendPort);

  final isoFileCreator = FileLogOutput.fileCreator;

  File? logFile;
  final writeBuffer = <String>[];
  Timer? flushTimer;

  receivePort.listen((Object? data) {
    if (data is Map && data.containsKey('logFilePath')) {
      logFile = isoFileCreator(data['logFilePath'] as String);
      final initialBuffer = data['initialBuffer'] as List<String>?;
      if (initialBuffer != null && initialBuffer.isNotEmpty) {
        unawaited(
          Future.microtask(() async {
            final nonNullableLogFile = logFile;
            if (nonNullableLogFile != null) {
              await nonNullableLogFile.writeAsString('${initialBuffer.join('\n')}\n', mode: FileMode.append);
            }
          }),
        );
      }
      debugPrint('Log isolate initialized. Logging to: ${logFile?.path}');
    } else if (data is String && logFile != null) {
      writeBuffer.add(data);
      if (writeBuffer.length >= 50 || flushTimer == null || !(flushTimer?.isActive ?? false)) {
        final nonNullableLogFile = logFile;
        if (nonNullableLogFile != null) {
          unawaited(_flushLogs(nonNullableLogFile, writeBuffer));
        }
        writeBuffer.clear();
        flushTimer?.cancel();
        flushTimer = null;
      }
      flushTimer ??= Timer.periodic(const Duration(seconds: 5), (timer) {
        final nonNullableLogFile = logFile;
        if (writeBuffer.isNotEmpty && nonNullableLogFile != null) {
          unawaited(_flushLogs(nonNullableLogFile, writeBuffer));
          writeBuffer.clear();
        } else if (writeBuffer.isEmpty) {
          timer.cancel();
          flushTimer = null;
        }
      });
    } else if (logFile == null) {
      if (data is String) {
        debugPrint('Log isolate: logFile not initialized, buffering message: $data');
        writeBuffer.add(data);
      }
    }
  });
}

Future<void> _flushLogs(File logFile, List<String> logs) async {
  if (logs.isEmpty) return;
  try {
    await logFile.writeAsString('${logs.join('\n')}\n', mode: FileMode.append);
  } on FileSystemException catch (e, s) {
    debugPrint('Log isolate error writing to file: $e\n$s');
  }
}
