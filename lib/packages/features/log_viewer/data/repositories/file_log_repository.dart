import 'dart:io';

import 'package:app_logging/app_logging.dart';
import 'package:core/data.dart';

import '../../domain/log_failure.dart';
import '../../domain/repositories/log_repository.dart';

final class FileLogRepository implements LogRepository {
  final Future<List<String>> Function() _readFiles;
  final Future<String> Function(String) _readContent;

  FileLogRepository({Future<List<String>> Function()? readFiles, Future<String> Function(String)? readContent})
    : _readFiles = readFiles ?? FileLogOutput.getLogFiles,
      _readContent = readContent ?? FileLogOutput.getLogContent;

  @override
  Future<Result<String, Failure>> getLogContent(String fileName) => _read(() async {
    if (!RegExp(r'^[^/\\]+\.txt$').hasMatch(fileName)) {
      throw const FormatException('Invalid log file name');
    }

    return _readContent(fileName);
  }, 'Не удалось прочитать файл журнала.');

  @override
  Future<Result<List<String>, Failure>> getLogFiles() =>
      _read(() async => List.unmodifiable(await _readFiles()), 'Не удалось загрузить список журналов.');

  Future<Result<T, Failure>> _read<T>(Future<T> Function() read, String message) async {
    try {
      return Result.success(await read());
    } on FileSystemException {
      return Result.failure(LogFailure(message: message));
    } on FormatException {
      return Result.failure(LogFailure(message: message));
    } on Object {
      return const Result.failure(UnknownFailure());
    }
  }
}
