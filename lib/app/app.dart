import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:ui_kit/ui_kit.dart';

import 'app_router.dart';

/// Root widget of the application
class App extends StatefulWidget {
  const App({required this.logger, super.key});

  final Logger logger;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _appRouter = AppRouter(widget.logger);

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
