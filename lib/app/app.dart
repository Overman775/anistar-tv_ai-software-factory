import 'package:anistar/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../packages/features/auth/auth_providers.dart';
import '../packages/features/auth/presentation/login_screen.dart';
import '../packages/features/auth/presentation/startup_screen.dart';
import 'authenticated_app.dart';

/// The protected router only exists while AniStar confirms an authenticated session.
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(authControllerProvider).asData?.value;
    if (account != null) {
      return AuthenticatedApp(key: ValueKey((account, ref.watch(anistarActiveMirrorProvider))));
    }

    return MaterialApp(
      title: 'Anistar TV',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: ref.watch(authStartupStageProvider) == AuthStartupStage.complete
          ? const LoginScreen()
          : const StartupScreen(),
    );
  }
}
