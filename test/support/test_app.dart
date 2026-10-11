import 'package:anistar_tv/packages/features/player/presentation/player_route_observer.dart';
import 'package:app_logging/app_logging.dart';
import 'package:app_logging/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

const compactTvSize = Size(960, 540);
const wideTvSize = Size(1280, 720);

/// Uses the production TV theme and resets the view after every test.
Future<void> pumpTvApp(
  WidgetTester tester,
  Widget child, {
  Size size = compactTvSize,
  List<Override> overrides = const [],
  bool wrapInScaffold = true,
}) async {
  setTvView(tester, size: size);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [loggerProvider.overrideWithValue(AppLogger.logger), ...overrides],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorObservers: [PlayerRouteObserver()],
        theme: AppTheme.darkTheme,
        home: wrapInScaffold ? Scaffold(body: child) : child,
      ),
    ),
  );
  // Decode local branding outside the fake clock so first-frame goldens include it.
  await tester.runAsync(
    () => precacheImage(Assets.images.anistarLogo.provider(), tester.element(find.byType(MaterialApp).first)),
  );
}

void setTvView(WidgetTester tester, {Size size = compactTvSize}) {
  final view = tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(view.reset);
}
