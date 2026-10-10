import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

/// Buffers early messages and writes them serially outside the UI isolate.
final class FileLogOutput implements LogOutput {
  static Directory? _logDirectory;

  final Directory? _directory;
  final List<String> _buffer = [];
  Future<void>? _initialization;
  Future<void>? _shutdown;
  Isolate? _isolate;
  SendPort? _sendPort;
  bool _closed = false;

  FileLogOutput({this._directory});

  @override
  Future<void> init() {
    if (_closed) {
      return _initialization ?? Future<void>.value();
    }

    return _initialization ??= _initialize();
  }

  @override
  void output(OutputEvent event) {
    if (_closed) {
      return;
    }
    final origin = event.origin;
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
    final entry =
        '$timestamp [${origin.level.name.toUpperCase()}] ${origin.message}'
        '${origin.error == null ? '' : '\nError: ${origin.error}'}'
        '${origin.stackTrace == null ? '' : '\nStackTrace: ${origin.stackTrace}'}';
    final port = _sendPort;
    if (port != null) {
      port.send(entry);
    } else {
      _buffer.add(entry);
      if (_buffer.length > 1000) {
        _buffer.removeAt(0);
      }
    }
  }

  static Future<List<String>> getLogFiles() async {
    final directory = _logDirectory;
    if (directory == null) {
      return [];
    }
    try {
      // ignore: avoid_slow_async_io, log discovery must not block the UI isolate.
      if (!await directory.exists()) {
        return [];
      }
      // ignore: avoid_slow_async_io, directory listing must not block the UI isolate.
      final files = await directory.list(followLinks: false).toList();

      return files
          .whereType<File>()
          .where((file) => file.path.endsWith('.txt'))
          .map((file) => file.uri.pathSegments.last)
          .toList()
        ..sort((a, b) => b.compareTo(a));
    } on FileSystemException catch (error) {
      debugPrint('Error listing log files: $error');

      return [];
    }
  }

  static Future<String> getLogContent(String fileName) async {
    if (!RegExp(r'^[^/\\]+\.txt$').hasMatch(fileName)) {
      return 'Invalid log file name.';
    }
    final directory = _logDirectory;
    if (directory == null) {
      return 'Log directory not available.';
    }
    try {
      final file = File('${directory.path}/$fileName');

      // ignore: avoid_slow_async_io, reading logs must not block the UI isolate.
      return await file.exists() ? await file.readAsString() : 'File not found: $fileName';
    } on FileSystemException catch (error) {
      debugPrint('Error reading log file: $error');

      return 'Error reading log file: $error';
    }
  }

  @override
  Future<void> destroy() {
    _closed = true;

    return _shutdown ??= _close();
  }

  Future<void> _initialize() async {
    final directory = _directory ?? Directory('${(await getApplicationCacheDirectory()).path}/logs');
    await directory.create(recursive: true);
    _logDirectory = directory;
    final name = 'app_log_${DateTime.now().microsecondsSinceEpoch}.txt';
    final ready = ReceivePort();
    try {
      _isolate = await Isolate.spawn(_startLogWriter, (ready.sendPort, '${directory.path}/$name'));
      final port = await ready.first.timeout(const Duration(seconds: 5)) as SendPort;
      _sendPort = port;
      _buffer
        ..forEach(port.send)
        ..clear();
    } finally {
      ready.close();
    }
  }

  Future<void> _close() async {
    final finished = ReceivePort();
    try {
      // Initialization may still be waiting for the directory or worker. Wait
      // before closing so it cannot resurrect resources after destruction.
      await _initialization;
      final port = _sendPort;
      if (port != null) {
        port.send(finished.sendPort);
        await finished.first.timeout(const Duration(seconds: 5));
      }
    } finally {
      finished.close();
      _sendPort = null;
      _buffer.clear();
      _isolate?.kill(priority: Isolate.immediate);
      _isolate = null;
    }
  }
}

void _startLogWriter((SendPort, String) configuration) => unawaited(_writeLogs(configuration));

Future<void> _writeLogs((SendPort, String) configuration) async {
  final (parent, path) = configuration;
  final messages = ReceivePort();
  final file = File(path);
  final buffer = <String>[];
  parent.send(messages.sendPort);
  final timer = Timer.periodic(const Duration(seconds: 5), (_) => messages.sendPort.send(null));
  try {
    // Awaiting writes in one loop preserves order. Close is a message in the
    // same queue and acknowledges only after every accepted entry is flushed.
    await for (final message in messages) {
      if (message is String) {
        buffer.add(message);
        if (buffer.length < 50) {
          continue;
        }
      }
      if (buffer.isNotEmpty) {
        try {
          await file.writeAsString('${buffer.join('\n')}\n', mode: FileMode.append, flush: true);
        } on FileSystemException catch (error) {
          debugPrint('Error writing log file: $error');
        }
        buffer.clear();
      }
      if (message is SendPort) {
        message.send(true);
        break;
      }
    }
  } finally {
    timer.cancel();
    messages.close();
  }
}
