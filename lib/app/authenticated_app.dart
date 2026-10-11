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
  AppDeviceProfile? _appliedProfile;

  @override
  void initState() {
    super.initState();
    _appRouter = AppRouter(ref.read(loggerProvider));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profile = AppLayoutScope.profileOf(context);
    if (_appliedProfile == profile) {
      return;
    }
    _appliedProfile = profile;
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        profile == AppDeviceProfile.tv ? SystemUiMode.manual : SystemUiMode.edgeToEdge,
        overlays: profile == AppDeviceProfile.tv ? [] : null,
      ),
    );
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
    theme: AppLayoutScope.isTvOf(context) ? AppTheme.lightTheme : AppTheme.mobileLightTheme,
    darkTheme: AppLayoutScope.isTvOf(context) ? AppTheme.darkTheme : AppTheme.mobileDarkTheme,
    themeMode: ThemeMode.dark,
    routerConfig: _appRouter.router,
  );
}
