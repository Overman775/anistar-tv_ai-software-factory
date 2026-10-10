import 'package:anistar_tv/packages/features/log_viewer/domain/repositories/log_repository.dart';

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
  Future<String> getLogContent(String fileName) {
    final loader = loadContent;
    if (loader != null) {
      return loader(fileName);
    }
    final error = contentError;
    if (error != null) {
      return Future<String>.error(error);
    }

    return Future.value(content);
  }

  @override
  Future<List<String>> getLogFiles() {
    final loader = loadFiles;
    if (loader != null) {
      return loader();
    }
    final error = filesError;
    if (error != null) {
      return Future<List<String>>.error(error);
    }

    return Future.value(files);
  }
}
