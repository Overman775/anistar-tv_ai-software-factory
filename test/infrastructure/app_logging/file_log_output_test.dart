import 'dart:io';

import 'package:app_logging/app_logging.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('anistar-log-test-');
  });
  tearDown(() async => directory.delete(recursive: true));

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
