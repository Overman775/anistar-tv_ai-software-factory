import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_backdrop.dart';
import 'package:flutter_test/flutter_test.dart';

Future<CatalogBackdrop> pumpUntilCatalogBackdrop(WidgetTester tester) async {
  final finder = find.byType(CatalogBackdrop);
  // Picture.toImage completes on the engine raster thread, outside fake time.
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
  expect(finder, findsOneWidget);
  return tester.widget<CatalogBackdrop>(finder);
}
