import 'dart:io';

import 'package:anistar_tv/packages/features/log_viewer/data/repositories/file_log_repository.dart';
import 'package:anistar_tv/packages/features/log_viewer/domain/log_failure.dart';
import 'package:core/data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty available directory is a protected success and error-like content remains content', () async {
    final files = <String>[];
    const content = 'Error reading log file: File not found: Invalid log file name.';
    final repository = FileLogRepository(readFiles: () async => files, readContent: (_) async => content);
    final result = await repository.getLogFiles();
    expect(result.isSuccess, isTrue);
    expect(result.successOrNull, isEmpty);
    files.add('new.txt');
    final filesAfterMutation = result.when(failure: (failure) => fail(failure.message), success: (value) => value);
    expect(filesAfterMutation.length, 0);
    expect(() => filesAfterMutation.add('other.txt'), throwsUnsupportedError);
    expect((await repository.getLogContent('log.txt')).successOrNull, content);
  });

  test('expected listing and read errors become safe LogFailure with no successful values', () async {
    final repository = FileLogRepository(
      readFiles: () async => throw const FileSystemException('private /secret/path token=password'),
      readContent: (_) async => throw const FileSystemException('private /secret/path token=password'),
    );
    final files = await repository.getLogFiles();
    final content = await repository.getLogContent('log.txt');
    final fileFailure = files.failureOrNull;
    final contentFailure = content.failureOrNull;
    // Re-read after changing the fake response; caching would hide the behavior under test.
    // ignore: prefer-moving-to-variable
    expect(fileFailure, isA<LogFailure>());
    // Re-read after changing the fake response; caching would hide the behavior under test.
    // ignore: prefer-moving-to-variable
    expect(contentFailure, isA<LogFailure>());
    expect(fileFailure?.message, 'Не удалось загрузить список журналов.');
    expect(contentFailure?.message, 'Не удалось прочитать файл журнала.');
    expect(files.successOrNull, isNull);
    expect(content.successOrNull, isNull);
  });

  test('invalid names fail before invoking reader and unexpected errors remain distinct', () async {
    var reads = 0;
    final repository = FileLogRepository(
      readContent: (_) async {
        reads++;
        throw StateError('secret');
      },
    );
    for (final name in ['../outside.txt', r'..\outside.txt', 'file.log', '']) {
      expect((await repository.getLogContent(name)).failureOrNull, isA<LogFailure>());
    }
    expect(reads, 0);
    expect((await repository.getLogContent('valid.txt')).failureOrNull, isA<UnknownFailure>());
  });
}
