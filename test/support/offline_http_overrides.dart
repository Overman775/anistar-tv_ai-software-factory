import 'dart:io';

final class OfflineHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw StateError('HTTP is disabled in unit/widget tests. Inject a fixture adapter or fake.');
}
