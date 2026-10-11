import 'package:integration_test/integration_test.dart';

import '../test/app/navigation_motion_test.dart' as navigation;
import '../test/support/test_bootstrap.dart';

/// Exercise the same frame-by-frame poster checks on Android's image decoder
/// and renderer, without a live account or external image requests.
Future<void> main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  await runTestSuite(navigation.decodedPosterTests);
}
