import 'package:anistar_tv/packages/features/log_viewer/domain/repositories/log_repository.dart';
import 'package:anistar_tv/utils/logger/file_log_output.dart';

final class FileLogRepository implements LogRepository {
  const FileLogRepository();

  @override
  Future<String> getLogContent(String fileName) => FileLogOutput.getLogContent(fileName);

  @override
  Future<List<String>> getLogFiles() => FileLogOutput.getLogFiles();
}
