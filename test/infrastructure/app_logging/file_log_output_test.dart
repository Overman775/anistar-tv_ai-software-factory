import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:app_logging/app_logging.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('anistar-log-test-');
  });
  tearDown(() async => directory.delete(recursive: true));

  test('delayed worker readiness has no deadline and closing preserves accepted message order', () async {
    final observations = ReceivePort();
    final events = StreamIterator<Object?>(observations);
    addTearDown(() async {
      await events.cancel();
      observations.close();
    });
    final output = FileLogOutput(directory: directory, workerEntrypoint: _controlledWorker(observations.sendPort))
      ..output(OutputEvent(LogEvent(Level.info, 'before-init'), const []));
    final timers = <Duration>[];
    final initialization = runZoned(
      output.init,
      zoneSpecification: ZoneSpecification(
        createTimer: (self, parent, zone, duration, callback) {
          timers.add(duration);

          return parent.createTimer(zone, duration, callback);
        },
      ),
    );
    final control = await _nextWorkerEvent(events, 'Worker control stream closed before announcing readiness');
    if (control is! SendPort) {
      fail('Worker must announce its control port before readiness');
    }
    var initialized = false;
    unawaited(initialization.then((_) => initialized = true));
    output.output(OutputEvent(LogEvent(Level.info, 'while-waiting'), const []));
    final closing = output.destroy();
    output.output(OutputEvent(LogEvent(Level.info, 'after-close'), const []));
    await Future<void>.value();
    expect(initialized, isFalse, reason: 'Readiness must wait for the worker handshake');
    control.send('ready');
    await initialization;
    expect(timers, isEmpty, reason: 'Debugger pauses must not install a wall-clock readiness deadline');
    final accepted = await _nextWorkerEvent(events, 'Worker closed without reporting accepted entries');
    expect(accepted, isA<List<String>>());
    if (accepted is! List<String>) {
      fail('Worker must report accepted entries before acknowledging close');
    }
    expect(accepted.map((entry) => entry.split(' ').last), ['before-init', 'while-waiting']);
    await closing;
    await output.destroy();
  });

  test('worker error before readiness fails initialization and close without creating a log', () async {
    final output = FileLogOutput(directory: directory, workerEntrypoint: _failingWorker);
    await expectLater(
      output.init(),
      throwsA(isA<RemoteError>().having((error) => error.toString(), 'message', contains('worker failed'))),
    );
    output.output(OutputEvent(LogEvent(Level.info, 'after-failure'), const []));
    await expectLater(output.destroy(), throwsA(isA<RemoteError>()));
    expect(await FileLogOutput.getLogFiles(), isEmpty);
  });

  test('worker exit before readiness fails initialization and close without hanging', () async {
    final output = FileLogOutput(directory: directory, workerEntrypoint: _exitingWorker);
    final exited = throwsA(isA<StateError>());
    await expectLater(output.init(), exited);
    await expectLater(output.destroy(), exited);
    expect(await FileLogOutput.getLogFiles(), isEmpty);
  });

  test('close during initialization flushes early messages in order and is idempotent', () async {
    final output = FileLogOutput(directory: directory);
    for (var i = 0; i < 123; i++) {
      output.output(OutputEvent(LogEvent(Level.info, 'entry-$i'), const []));
    }
    final initialization = output.init();
    final closing = output.destroy();
    output.output(OutputEvent(LogEvent(Level.info, 'after-close'), const []));
    await initialization;
    await closing;
    await output.destroy();
    final files = await FileLogOutput.getLogFiles();
    expect(files, hasLength(1));
    final content = await FileLogOutput.getLogContent(files.single);
    expect(
      content.split('\n').where((line) => line.isNotEmpty).map((line) => line.split(' ').last),
      List.generate(123, (i) => 'entry-$i'),
    );
    expect(content, isNot(contains('after-close')));
  });

  test('independent outputs cannot write into or close each other', () async {
    final first = FileLogOutput(directory: directory);
    final second = FileLogOutput(directory: directory);
    await first.init();
    await second.init();
    first.output(OutputEvent(LogEvent(Level.info, 'first'), const []));
    await first.destroy();
    second.output(OutputEvent(LogEvent(Level.info, 'second'), const []));
    await second.destroy();
    final files = await FileLogOutput.getLogFiles();
    expect(files, hasLength(2));
    final contents = await Future.wait(files.map(FileLogOutput.getLogContent));
    final oneFile = hasLength(1);
    expect(contents.where((content) => content.contains('first')), oneFile);
    expect(contents.where((content) => content.contains('second')), oneFile);
    expect(contents.any((content) => content.contains('first') && content.contains('second')), isFalse);
  });

  test('reader preserves error-like content and throws for a disappeared selected file', () async {
    final output = FileLogOutput(directory: directory);
    await output.init();
    await output.destroy();
    final file = File('${directory.path}/manual.txt');
    const text = 'Error reading log file: Invalid log file name.';
    await file.writeAsString(text);
    expect(await FileLogOutput.getLogContent('manual.txt'), text);
    await file.delete();
    await expectLater(FileLogOutput.getLogContent('manual.txt'), throwsA(isA<FileSystemException>()));
  });

  test('missing log directory is empty but a directory read failure propagates', () async {
    final child = Directory('${directory.path}/logs');
    final output = FileLogOutput(directory: child);
    await output.init();
    await output.destroy();
    await child.delete(recursive: true);
    expect(await FileLogOutput.getLogFiles(), isEmpty);
    await File(child.path).writeAsString('not a directory');
    await expectLater(FileLogOutput.getLogFiles(), throwsA(isA<FileSystemException>()));
  });

  test('log reader rejects directory traversal', () async {
    final output = FileLogOutput(directory: directory);
    await output.init();
    await output.destroy();
    await expectLater(FileLogOutput.getLogContent('../outside.txt'), throwsFormatException);
    await expectLater(FileLogOutput.getLogContent(r'..\outside.txt'), throwsFormatException);
  });
}

Future<Object?> _nextWorkerEvent(StreamIterator<Object?> events, String failureReason) async {
  if (!await events.moveNext()) {
    fail(failureReason);
  }

  return events.current;
}

void Function((SendPort, String)) _controlledWorker(SendPort observer) => (configuration) {
  final (parent, _) = configuration;
  final messages = ReceivePort();
  final entries = <String>[];
  observer.send(messages.sendPort);
  messages.listen((message) {
    if (message == 'ready') {
      parent.send(messages.sendPort);
    } else if (message is String) {
      entries.add(message);
    } else if (message is SendPort) {
      observer.send(entries);
      message.send(true);
      messages.close();
    }
  });
};

Never _failingWorker((SendPort, String) configuration) => throw StateError('worker failed before readiness');

Never _exitingWorker((SendPort, String) configuration) => Isolate.exit();
