abstract interface class LogRepository {
  Future<List<String>> getLogFiles();

  Future<String> getLogContent(String fileName);
}
