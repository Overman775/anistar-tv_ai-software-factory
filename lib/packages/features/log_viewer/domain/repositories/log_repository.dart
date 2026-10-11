import 'package:core/data.dart';

abstract interface class LogRepository {
  Future<Result<List<String>, Failure>> getLogFiles();
  Future<Result<String, Failure>> getLogContent(String fileName);
}
