import 'package:anistar_tv/app/app.dart';
import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/e2e_harness.dart';
import 'support/live_harness.dart';

/// Live Android read/login smoke; never mutates favorites or watched episodes.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  E2eHarness.testCase('real mirror check, login, catalog and encrypted session restoration', (tester) async {
    final live = LiveHarness();
    await live.resetSession();
    await live.launch(tester);
    await LiveHarness.login(tester);
    bool catalogVisible() => find.byType(CatalogScreen).evaluate().isNotEmpty;
    await LiveHarness.wait(tester, catalogVisible, 'live login');
    // Read the active scope again after restarting the application below.
    // ignore: prefer-moving-to-variable
    final container = ProviderScope.containerOf(tester.element(find.byType(App)));
    final page = await container.read(catalogRepositoryProvider).getPage(1);
    expect(page.isSuccess, isTrue, reason: page.failureOrNull?.message);
    expect(page.successOrNull?.items.isNotEmpty, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await live.launch(tester);
    await LiveHarness.wait(tester, catalogVisible, 'live session restore');
    expect(live.loginPosts, 1, reason: 'Restore must use encrypted cookies without another login POST');
    // ignore: prefer-moving-to-variable
    final restoredContainer = ProviderScope.containerOf(tester.element(find.byType(App)));
    expect(restoredContainer.read(authControllerProvider).value == LiveHarness.username, isTrue);
    await restoredContainer.read(authControllerProvider.notifier).signOut();
    await tester.pumpWidget(const SizedBox.shrink());
  }, profile: null);
}
