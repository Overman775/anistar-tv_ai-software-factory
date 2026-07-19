import 'dart:async';

import 'package:app_logger/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';

import 'app_providers.dart';
import 'app_router.dart';

/// Root widget of the application
class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  late final AppRouter _appRouter;
  late final bool Function(KeyEvent event) _remoteKeyHandler;

  @override
  void initState() {
    super.initState();
    _appRouter = AppRouter(ref.read(loggerProvider));
    _remoteKeyHandler = _logRemoteKey;
    HardwareKeyboard.instance.addHandler(_remoteKeyHandler);

    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []));
  }

  bool _logRemoteKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      final keyName = key.debugName ?? key.keyLabel;
      ref.read(loggerProvider).debugFor<App>('Remote key pressed: $keyName');
    }

    // This is telemetry only; Focus and feature handlers still own the event.
    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_remoteKeyHandler);
    _appRouter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Anistar TV',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: ThemeMode.dark,
    routerConfig: _appRouter.router,
  );
}
