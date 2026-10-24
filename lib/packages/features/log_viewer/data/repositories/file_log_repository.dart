import 'dart:io';

import 'package:app_logging/app_logging.dart';
import 'package:core/data.dart';
import 'package:networking/networking.dart';

import '../../domain/log_failure.dart';
import '../../domain/repositories/log_repository.dart';

final class FileLogRepository extends BaseRepository implements LogRepository {
  final Future<List<String>> Function() _readFiles;
  final Future<String> Function(String) _readContent;

  FileLogRepository({Future<List<String>> Function()? readFiles, Future<String> Function(String)? readContent})
    : _readFiles = readFiles ?? FileLogOutput.getLogFiles,
      _readContent = readContent ?? FileLogOutput.getLogContent;

  @override
  Future<Result<String, Failure>> getLogContent(String fileName) => makeApiCall(() async {
    if (!RegExp(r'^[^/\\]+\.txt$').hasMatch(fileName)) {
      throw const LogFailure(message: 'Не удалось прочитать файл журнала.');
    }

    try {
      return await _readContent(fileName);
    } on FileSystemException catch (_, stackTrace) {
      Error.throwWithStackTrace(const LogFailure(message: 'Не удалось прочитать файл журнала.'), stackTrace);
    } on FormatException catch (_, stackTrace) {
      Error.throwWithStackTrace(const LogFailure(message: 'Не удалось прочитать файл журнала.'), stackTrace);
    }
  });

  @override
  Future<Result<List<String>, Failure>> getLogFiles() => makeApiCall(() async {
    try {
      return List.unmodifiable(await _readFiles());
    } on FileSystemException catch (_, stackTrace) {
      Error.throwWithStackTrace(const LogFailure(message: 'Не удалось загрузить список журналов.'), stackTrace);
    } on FormatException catch (_, stackTrace) {
      Error.throwWithStackTrace(const LogFailure(message: 'Не удалось загрузить список журналов.'), stackTrace);
    }
  });
}
