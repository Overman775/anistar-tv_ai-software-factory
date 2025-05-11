import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart'; // Required for @visibleForTesting
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

class FileLogOutput implements LogOutput {
  static SendPort? _sendPort;
  static final List<String> _logBuffer = [];
  static String? _currentLogFileName;
  static Directory? _logDirectory;
  static ReceivePort? _receivePortForTest; // To allow closing in tests

  @visibleForTesting
  static SendPort? get sendPortForTest => _sendPort;
  @visibleForTesting
  static List<String> get logBufferForTest => _logBuffer;
  @visibleForTesting
  static String? get currentLogFileNameForTest => _currentLogFileName;
  @visibleForTesting
  static Directory? get logDirectoryForTest => _logDirectory;
  @visibleForTesting
  static Isolate? fileIsolate; // To capture spawned isolate
  @visibleForTesting
  static ReceivePort? get receivePortForTest => _receivePortForTest;

  @visibleForTesting
  static Directory Function(String path) directoryCreator = (path) => Directory(path);
  @visibleForTesting
  static File Function(String path) fileCreator = (path) => File(path);

  @visibleForTesting
  static void resetForTest() {
    _sendPort = null;
    _logBuffer.clear();
    _currentLogFileName = null;
    _logDirectory = null;
    _receivePortForTest?.close();
    _receivePortForTest = null;
    fileIsolate = null;
    directoryCreator = (path) => Directory(path); // Reset creators
    fileCreator = (path) => File(path); // Reset creators
    // Note: appLogger might need resetting if it holds state or old LogService instance
    // For simplicity, we assume tests will re-initialize appLogger by calling LogService.initialize
  }

  @override
  Future<void> init() async {
    final appDocsDir = await getApplicationDocumentsDirectory();
    _logDirectory = directoryCreator('${appDocsDir.path}/logs'); // Use creator
    if (!await _logDirectory!.exists()) {
      await _logDirectory!.create(recursive: true);
    }

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    _currentLogFileName = 'app_log_$timestamp.txt';

    _receivePortForTest = ReceivePort(); // Store for potential closing in reset
    fileIsolate = await Isolate.spawn(
      _logIsolateEntryPoint,
      _receivePortForTest!.sendPort,
      // Pass other params if your spawner mock needs them
    );
    _sendPort = await _receivePortForTest!.first as SendPort?;

    // Send initial data to isolate
    if (_sendPort != null) {
      _sendPort!.send({
        'logFilePath': '${_logDirectory!.path}/$_currentLogFileName',
        'initialBuffer': List<String>.from(_logBuffer),
      });
      _logBuffer.clear();
    }

    debugPrint('LogService initialized');
  }

  @override
  void output(OutputEvent event) {
    if (_sendPort == null) {
      // Buffer logs if isolate is not ready yet
      final logEntry = _formatLog(
        event.origin.level,
        event.origin.message,
        event.origin.error,
        event.origin.stackTrace,
      );
      _logBuffer.add(logEntry);
      if (_logBuffer.length > 1000) {
        // Limit buffer size
        _logBuffer.removeAt(0);
      }
    }

    final logEntry = _formatLog(event.origin.level, event.origin.message, event.origin.error, event.origin.stackTrace);
    _sendPort!.send(logEntry);
  }

  String _formatLog(Level level, dynamic message, [dynamic error, StackTrace? stackTrace]) {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
    String logStr = '$timestamp [${level.name.toUpperCase()}] $message';
    if (error != null) {
      logStr += '\nError: $error';
    }
    if (stackTrace != null) {
      logStr += '\nStackTrace: $stackTrace';
    }
    return logStr;
  }

  static Future<List<String>> getLogFiles() async {
    if (_logDirectory == null || !await _logDirectory!.exists()) {
      return [];
    }
    // Use try-catch for safety, as directory listing can fail.
    try {
      final files = await _logDirectory!.list().toList();
      return files
          .where((fsEntity) => fsEntity is File && fsEntity.path.endsWith('.txt'))
          .map((fsEntity) => fsEntity.path.split('/').last)
          .toList()
        ..sort((a, b) => b.compareTo(a)); // Sort by newest first
    } catch (e) {
      debugPrint('Error listing log files (appLogger not ready): $e');

      return [];
    }
  }

  static Future<String> getLogContent(String fileName) async {
    if (_logDirectory == null) {
      return 'Log directory not available.';
    }
    try {
      final file = fileCreator('${_logDirectory!.path}/$fileName'); // Use creator
      if (await file.exists()) {
        return await file.readAsString();
      } else {
        return 'File not found: $fileName';
      }
    } catch (e) {
      debugPrint('Error reading log file $fileName (appLogger not ready): $e');

      return 'Error reading log file: $e';
    }
  }

  @override
  Future<void> destroy() {
    // TODO: implement destroy
    throw UnimplementedError();
  }
}

// Isolate entry point
void _logIsolateEntryPoint(SendPort sendPort) {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  // Use the same fileCreator as the main isolate for consistency,
  // though it's a separate isolate. For tests, this doesn't matter as much
  // as the main isolate's creator being mockable.
  // If direct file operations were complex here, this isolate might also need
  // its file operations to be injectable/testable.
  final File Function(String path) isoFileCreator = FileLogOutput.fileCreator;

  File? logFile;
  List<String> writeBuffer = [];
  Timer? flushTimer;

  receivePort.listen((dynamic data) async {
    if (data is Map && data.containsKey('logFilePath')) {
      // Initialization message from main isolate
      logFile = isoFileCreator(data['logFilePath'] as String); // Use creator
      final initialBuffer = data['initialBuffer'] as List<String>?;
      if (initialBuffer != null && initialBuffer.isNotEmpty) {
        await logFile!.writeAsString('${initialBuffer.join('\n')}\n', mode: FileMode.append);
      }
      debugPrint('Log isolate initialized. Logging to: ${logFile?.path}');
    } else if (data is String && logFile != null) {
      writeBuffer.add(data);
      // Flush buffer if it's large enough or if timer is not active
      if (writeBuffer.length >= 50 || flushTimer == null || !flushTimer!.isActive) {
        _flushLogs(logFile!, writeBuffer);
        writeBuffer.clear();
        flushTimer?.cancel(); // Cancel existing timer
      }
      // Set a timer to flush logs periodically if there's infrequent logging
      flushTimer ??= Timer.periodic(const Duration(seconds: 5), (timer) {
        if (writeBuffer.isNotEmpty && logFile != null) {
          _flushLogs(logFile!, writeBuffer);
          writeBuffer.clear();
        } else if (writeBuffer.isEmpty) {
          timer.cancel(); // Stop timer if buffer is empty
          flushTimer = null;
        }
      });
    } else if (logFile == null) {
      // If logFile is not initialized yet, buffer the message
      if (data is String) {
        // This case should ideally not happen if initialization is correct
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
  } catch (e, s) {
    // If isolate fails to write, print to console.
    // Consider a more robust error reporting mechanism for production isolates.
    debugPrint('Log isolate error writing to file: $e\n$s');
  }
}
