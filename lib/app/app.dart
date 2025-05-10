import 'package:anistar_tv/packages/ui_kit/lib/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_router.dart';

/// Root widget of the application
class App extends StatefulWidget {
  /// Constructor
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _appRouter = AppRouter();

    // Configure system UI for TV
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [], // Hide all system overlays for TV
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Anistar TV',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // TV apps typically use dark theme
      routerConfig: _appRouter.router,
    );
  }
}
