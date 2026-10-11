import 'dart:async';

import 'package:core/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../auth_providers.dart';

/// Checks the site and saved session before exposing login or protected routes.
class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});

  void _revealRetry(BuildContext context, bool focused) {
    if (!focused) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        unawaited(
          Scrollable.ensureVisible(context, alignment: 0.5, duration: AppMotion.durationOf(context, AppMotion.fast)),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final stage = ref.watch(authStartupStageProvider);
    final error = auth.isLoading ? null : auth.error;
    final theme = Theme.of(context);
    final status = switch ((stage, error != null)) {
      (AuthStartupStage.site, false) => 'Проверяем доступность AniStar…',
      (AuthStartupStage.session, false) => 'Проверяем сохранённую сессию…',
      (AuthStartupStage.site, true) => 'Не удалось подключиться к AniStar',
      (_, true) => 'Не удалось проверить сессию',
      (_, false) => 'Подготавливаем приложение…',
    };

    return Scaffold(
      body: TvBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: SizedBox(
                      width: 520,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AnistarLogo(size: 96),
                          const SizedBox(height: AppSpacing.md),
                          Text('AniStar TV', style: theme.textTheme.headlineLarge, textAlign: TextAlign.center),
                          const SizedBox(height: AppSpacing.lg),
                          if (error == null) ...[
                            const SizedBox.square(dimension: 42, child: CircularProgressIndicator(strokeWidth: 3)),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          Semantics(
                            key: const ValueKey('startup_status'),
                            liveRegion: true,
                            child: Text(status, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
                          ),
                          if (error != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Semantics(
                              key: const ValueKey('startup_error'),
                              liveRegion: true,
                              child: Text(
                                error is Failure ? error.message : 'Не удалось завершить проверку. Повторите попытку.',
                                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.error),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Builder(
                              builder: (context) => Focus(
                                onFocusChange: (focused) => _revealRetry(context, focused),
                                child: FilledButton.icon(
                                  key: const ValueKey('startup_retry'),
                                  autofocus: true,
                                  onPressed: ref.read(authControllerProvider.notifier).retryRestore,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Попробовать снова'),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
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
