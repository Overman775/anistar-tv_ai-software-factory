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
  final void Function((SendPort, String)) _workerEntrypoint;
  final List<String> _buffer = [];
  Future<void>? _initialization;
  Future<void>? _shutdown;
  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _workerEvents;
  bool _closed = false;

  FileLogOutput({this._directory, void Function((SendPort, String))? workerEntrypoint})
    : _workerEntrypoint = workerEntrypoint ?? _startLogWriter;

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
    final List<FileSystemEntity> files;
    try {
      // ignore: avoid_slow_async_io, directory listing must not block the UI isolate.
      files = await directory.list(followLinks: false).toList();
    } on FileSystemException catch (error) {
      if (error.osError?.errorCode == 2) {
        // The logger may not have created its directory yet.
        return [];
      }
      rethrow;
    }

    return files
        .whereType<File>()
        .where((file) => file.path.endsWith('.txt'))
        .map((file) => file.uri.pathSegments.last)
        .toList()
      ..sort((a, b) => b.compareTo(a));
  }

  static Future<String> getLogContent(String fileName) async {
    if (!RegExp(r'^[^/\\]+\.txt$').hasMatch(fileName)) {
      throw const FormatException('Invalid log file name');
    }
    final directory = _logDirectory;
    if (directory == null) {
      throw const FileSystemException('Log directory not available');
    }
    // Missing files and read errors propagate to the repository boundary.

    return File('${directory.path}/$fileName').readAsString();
  }

  @override
  Future<void> destroy() {
    _closed = true;

    return _shutdown ??= _close();
  }

  Future<void> _initialize() async {
    try {
      final directory = _directory ?? Directory('${(await getApplicationCacheDirectory()).path}/logs');
      await directory.create(recursive: true);
      _logDirectory = directory;
      final name = 'app_log_${DateTime.now().microsecondsSinceEpoch}.txt';
      final events = ReceivePort();
      _workerEvents = events;
      _isolate = await Isolate.spawn(
        _workerEntrypoint,
        (events.sendPort, '${directory.path}/$name'),
        onError: events.sendPort,
        onExit: events.sendPort,
      );
      final ready = Completer<SendPort>();
      var hasFailed = false;
      events.listen((event) {
        if (event is SendPort) {
          if (!ready.isCompleted) {
            ready.complete(event);
          }

          return;
        }
        if (hasFailed || event == null && _closed && ready.isCompleted) {
          return;
        }
        hasFailed = true;
        final error = switch (event) {
          [final String message, final String stack] => RemoteError(message, stack),
          _ => StateError('Log writer exited before completing its work'),
        };
        if (!ready.isCompleted) {
          ready.completeError(error);
        } else {
          _closed = true;
          _releaseWorker();
          Zone.current.handleUncaughtError(error, StackTrace.current);
        }
      });
      // A debugger may pause the child isolate before its entrypoint. Readiness
      // has no wall-clock deadline; worker errors and exit still fail init.
      final port = await ready.future;
      _sendPort = port;
      _buffer
        ..forEach(port.send)
        ..clear();
    } on Object {
      _closed = true;
      _releaseWorker();
      rethrow;
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
      _releaseWorker();
    }
  }

  void _releaseWorker() {
    _workerEvents?.close();
    _workerEvents = null;
    _sendPort = null;
    _buffer.clear();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
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
