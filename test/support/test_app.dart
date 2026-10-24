import 'package:anistar_tv/packages/features/player/presentation/player_route_observer.dart';
import 'package:app_logging/app_logging.dart';
import 'package:app_logging/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import 'test_app_viewport.dart';

export 'test_app_viewport.dart';

const compactTvSize = Size(960, 540);
const wideTvSize = Size(1280, 720);

/// Uses the production TV theme and resets the view after every test.
Future<void> pumpTvApp(
  WidgetTester tester,
  Widget child, {
  Size size = compactTvSize,
  double devicePixelRatio = 1,
  double? textScale,
  bool? disableAnimations,
  List<Override> overrides = const [],
  bool wrapInScaffold = true,
}) async {
  final viewport = TestAppViewport.tv(
    logicalSize: size,
    devicePixelRatio: devicePixelRatio,
    textScale: textScale ?? 1,
    disableAnimations: disableAnimations ?? false,
  );
  setTestViewport(tester, viewport);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [loggerProvider.overrideWithValue(AppLogger.logger), ...overrides],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorObservers: [PlayerRouteObserver()],
        theme: AppTheme.darkTheme,
        builder: (context, content) {
          final inherited = MediaQuery.of(context);
          final media = textScale == null && disableAnimations == null
              ? inherited
              : inherited.copyWith(
                  textScaler: textScale == null ? null : TextScaler.linear(viewport.textScale),
                  disableAnimations: disableAnimations,
                );

          return MediaQuery(
            data: media,
            child: content ?? (throw StateError('MaterialApp did not provide a navigator')),
          );
        },
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
  setTestViewport(tester, TestAppViewport.tv(logicalSize: size));
}

/// Uses the production responsive root and touch theme with logical dimensions.
Future<void> pumpMobileApp(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
  double devicePixelRatio = 1,
  double textScale = 1,
  bool disableAnimations = false,
  List<Override> overrides = const [],
  bool wrapInScaffold = true,
}) async {
  final viewport = TestAppViewport.mobile(
    logicalSize: size,
    devicePixelRatio: devicePixelRatio,
    textScale: textScale,
    disableAnimations: disableAnimations,
  );
  setTestViewport(tester, viewport);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [loggerProvider.overrideWithValue(AppLogger.logger), ...overrides],
      child: AppResponsiveRoot(
        profile: AppDeviceProfile.mobile,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorObservers: [PlayerRouteObserver()],
          theme: AppTheme.mobileDarkTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(viewport.textScale),
              disableAnimations: viewport.disableAnimations,
            ),
            child: child ?? (throw StateError('MaterialApp did not provide a navigator')),
          ),
          home: wrapInScaffold ? Scaffold(body: child) : child,
        ),
      ),
    ),
  );
  await tester.runAsync(
    () => precacheImage(Assets.images.anistarLogo.provider(), tester.element(find.byType(MaterialApp).first)),
  );
}

/// Match the focused rail control by its public FocusNode identity.
String? focusedControlLabel(WidgetTester tester) {
  final primary = FocusManager.instance.primaryFocus;
  const labels = {
    'catalog-tab-false': 'Главная',
    'catalog-search': 'Поиск',
    'catalog-tab-true': 'Избранное',
    'catalog-genres': 'Жанры',
    'catalog-account': 'Выйти из аккаунта',
    'catalog-logs': 'Открыть логи',
    'catalog-sign-in': 'Войти',
  };
  for (final entry in labels.entries) {
    final control = find.byKey(ValueKey(entry.key));
    if (control.evaluate().isNotEmpty && tester.widget<TextButton>(control).focusNode == primary) {
      return entry.value;
    }
  }

  return primary?.debugLabel;
}
