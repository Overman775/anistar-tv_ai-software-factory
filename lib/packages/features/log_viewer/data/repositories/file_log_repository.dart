import 'package:app_logger/app_logger.dart';
import '../../domain/repositories/log_repository.dart';

final class FileLogRepository implements LogRepository {
  const FileLogRepository();

  @override
  Future<String> getLogContent(String fileName) => FileLogOutput.getLogContent(fileName);

  @override
  Future<List<String>> getLogFiles() => FileLogOutput.getLogFiles();
}
