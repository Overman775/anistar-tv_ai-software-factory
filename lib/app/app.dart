import 'dart:async';

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

  @override
  void initState() {
    super.initState();
    _appRouter = AppRouter(ref.read(loggerProvider));

    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []));
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
