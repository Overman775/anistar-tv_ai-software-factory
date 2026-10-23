import 'package:anistar/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../packages/features/auth/auth_providers.dart';
import '../packages/features/auth/presentation/intro_screen.dart';
import '../packages/features/auth/presentation/login_screen.dart';
import '../packages/features/auth/presentation/startup_screen.dart';
import 'authenticated_app.dart';

/// Browsing routes exist only for explicit guest access or a confirmed account.
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(authAccessProvider);
    if (access.canBrowse) {
      return AuthenticatedApp(
        key: ValueKey((access.runtimeType, access.account, ref.watch(anistarActiveMirrorProvider))),
      );
    }

    final loginRequested = ref.watch(authControllerProvider).value?.loginRequested ?? false;
    final home = switch (ref.watch(authStartupStageProvider)) {
      AuthStartupStage.complete => loginRequested ? const LoginScreen(canCancel: true) : const IntroScreen(),
      _ => const StartupScreen(),
    };

    return MaterialApp(
      title: 'Anistar TV',
      debugShowCheckedModeBanner: false,
      theme: AppLayoutScope.isTvOf(context) ? AppTheme.lightTheme : AppTheme.mobileLightTheme,
      darkTheme: AppLayoutScope.isTvOf(context) ? AppTheme.darkTheme : AppTheme.mobileDarkTheme,
      themeMode: ThemeMode.dark,
      home: home,
    );
  }
}
