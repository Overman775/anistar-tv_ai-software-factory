import 'dart:async';

import 'package:app_logging/providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../packages/features/auth/auth_providers.dart';
import '../packages/features/auth/presentation/login_screen.dart';
import 'app_router.dart';

class AuthenticatedApp extends ConsumerStatefulWidget {
  const AuthenticatedApp({super.key});

  @override
  ConsumerState<AuthenticatedApp> createState() => _AuthenticatedAppState();
}

class _AuthenticatedAppState extends ConsumerState<AuthenticatedApp> {
  late final AppRouter _appRouter;
  AppDeviceProfile? _appliedProfile;
  Route<void>? _loginRoute;

  @override
  void initState() {
    super.initState();
    _appRouter = AppRouter(ref.read(loggerProvider));
  }

  void _syncLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final navigator = _appRouter.rootNavigatorKey.currentState;
      if (navigator == null) return;
      final requested = ref.read(authControllerProvider).value?.loginRequested == true;
      final current = _loginRoute;
      if (requested && current == null) {
        final route = MaterialPageRoute<void>(builder: (_) => const LoginScreen(canCancel: true));
        _loginRoute = route;
        unawaited(
          navigator.push<void>(route).then((_) {
            if (!mounted || !identical(_loginRoute, route)) return;
            _loginRoute = null;
            if (ref.read(authControllerProvider).value?.loginRequested == true) {
              unawaited(ref.read(authControllerProvider.notifier).cancelSignIn());
            }
          }),
        );
      } else if (!requested && current != null) {
        _loginRoute = null;
        if (current.isCurrent) {
          navigator.pop();
        } else if (current.isActive) {
          navigator.removeRoute(current);
        }
      }
    });
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
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      if (previous?.value?.loginRequested != next.value?.loginRequested) _syncLogin();
    });

    return MaterialApp.router(
      title: 'Anistar TV',
      debugShowCheckedModeBanner: false,
      theme: AppLayoutScope.isTvOf(context) ? AppTheme.lightTheme : AppTheme.mobileLightTheme,
      darkTheme: AppLayoutScope.isTvOf(context) ? AppTheme.darkTheme : AppTheme.mobileDarkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: _appRouter.router,
    );
  }
}
