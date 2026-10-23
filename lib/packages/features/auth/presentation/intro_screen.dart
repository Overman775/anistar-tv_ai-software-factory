import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../auth_providers.dart';
import 'login_brand.dart';

/// The explicit choice before the sign-in form for a confirmed unauthenticated user.
class IntroScreen extends ConsumerWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTv = AppLayoutScope.isTvOf(context);
    final textTheme = Theme.of(context).textTheme;
    final controller = ref.read(authControllerProvider.notifier);
    final actions = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Смотрите аниме на AniStar TV', style: textTheme.headlineMedium, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Войдите в аккаунт или продолжите без входа.',
          style: textTheme.bodyLarge?.copyWith(color: AppPalette.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xxl),
        AppButton(
          key: const ValueKey('intro_sign_in'),
          autofocus: isTv,
          label: 'Войти',
          onPressed: controller.requestSignIn,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          key: const ValueKey('intro_guest'),
          variant: AppButtonVariant.neutral,
          label: 'Продолжить без входа',
          onPressed: controller.enterAnonymous,
        ),
      ],
    );

    return Scaffold(
      backgroundColor: AppPalette.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final padding = isTv ? (constraints.maxWidth * 0.05).clamp(24.0, 96.0) : AppSpacing.lg;
            final horizontal = isTv && constraints.maxWidth >= 760;
            final brand = LoginBrand(vertical: horizontal);

            return SingleChildScrollView(
              padding: EdgeInsets.all(padding),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - padding * 2).clamp(0.0, double.infinity),
                ),
                child: Center(
                  child: horizontal
                      ? Row(
                          children: [
                            Expanded(child: brand),
                            const SizedBox(width: AppSpacing.xxxl),
                            Expanded(
                              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: actions),
                            ),
                          ],
                        )
                      : ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              brand,
                              const SizedBox(height: AppSpacing.xxxl),
                              actions,
                            ],
                          ),
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
