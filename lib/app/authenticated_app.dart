import 'dart:async';

import 'package:app_logging/providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import 'app_router.dart';

class AuthenticatedApp extends ConsumerStatefulWidget {
  const AuthenticatedApp({super.key});

  @override
  ConsumerState<AuthenticatedApp> createState() => _AuthenticatedAppState();
}

class _AuthenticatedAppState extends ConsumerState<AuthenticatedApp> {
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _appRouter = AppRouter(ref.read(loggerProvider));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []));
  }

  @override
  void dispose() {
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
