import 'package:core/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../auth_providers.dart';

/// Checks the site and saved session before exposing login or protected routes.
class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final auth = ref.watch(authControllerProvider);
    final stage = ref.watch(authStartupStageProvider);
    final error = auth.isLoading ? null : auth.error;
    final status = switch ((stage, error != null)) {
      (AuthStartupStage.site, false) => 'Проверяем доступность AniStar…',
      (AuthStartupStage.session, false) => 'Проверяем сохранённую сессию…',
      (AuthStartupStage.site, true) => 'Не удалось подключиться к AniStar',
      (_, true) => 'Не удалось проверить сессию',
      (_, false) => 'Подготавливаем приложение…',
    };

    return Scaffold(
      backgroundColor: AppPalette.background,
      body: SafeArea(
        child: error != null
            ? Column(
                children: [
                  const Padding(padding: EdgeInsets.all(AppSpacing.md), child: AnistarLogo(size: 64)),
                  Expanded(
                    child: TvStateView(
                      key: const ValueKey('startup_error'),
                      icon: Icons.error_outline_rounded,
                      title: status,
                      message: error is Failure ? error.message : 'Не удалось завершить проверку. Повторите попытку.',
                      actionKey: const ValueKey('startup_retry'),
                      actionLabel: 'Попробовать снова',
                      onAction: ref.read(authControllerProvider.notifier).retryRestore,
                    ),
                  ),
                ],
              )
            : LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const AnistarLogo(size: 96),
                              const SizedBox(height: AppSpacing.md),
                              Text('AniStar TV', style: textTheme.headlineLarge, textAlign: TextAlign.center),
                              const SizedBox(height: AppSpacing.lg),
                              const SizedBox.square(dimension: 42, child: CircularProgressIndicator(strokeWidth: 3)),
                              const SizedBox(height: AppSpacing.md),
                              Semantics(
                                key: const ValueKey('startup_status'),
                                liveRegion: true,
                                child: Text(status, style: textTheme.titleMedium, textAlign: TextAlign.center),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
