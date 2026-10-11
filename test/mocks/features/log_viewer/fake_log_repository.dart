import 'package:anistar_tv/packages/features/log_viewer/domain/repositories/log_repository.dart';
import 'package:core/data.dart';

final class FakeLogRepository implements LogRepository {
  final List<String> files;
  final String content;
  final Object? filesError;
  final Object? contentError;
  final Future<String> Function(String)? loadContent;
  final Future<List<String>> Function()? loadFiles;

  FakeLogRepository({
    this.files = const [],
    this.content = '',
    this.filesError,
    this.contentError,
    this.loadContent,
    this.loadFiles,
  });

  @override
  Future<Result<String, Failure>> getLogContent(String fileName) async {
    try {
      final loader = loadContent;
      if (loader != null) {
        return Result.success(await loader(fileName));
      }
      final error = contentError;
      if (error != null) {
        return const Result.failure(UnknownFailure());
      }

      return Result.success(content);
    } on Object {
      return const Result.failure(UnknownFailure());
    }
  }

  @override
  Future<Result<List<String>, Failure>> getLogFiles() async {
    try {
      final loader = loadFiles;
      if (loader != null) {
        return Result.success(List.unmodifiable(await loader()));
      }
      final error = filesError;
      if (error != null) {
        return const Result.failure(UnknownFailure());
      }

      return Result.success(List.unmodifiable(files));
    } on Object {
      return const Result.failure(UnknownFailure());
    }
  }
}
