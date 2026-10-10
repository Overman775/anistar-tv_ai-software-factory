import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

class CatalogTail extends StatelessWidget {
  const CatalogTail({required this.onRetry, super.key, this.error});

  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error;

    if (message == null) {
      return const DecoratedBox(
        decoration: BoxDecoration(color: AppPalette.surface, borderRadius: AppRadii.large),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return TvFocusable(
      onPressed: onRetry,
      semanticLabel: 'Повторить загрузку каталога',
      builder: (context, focused) => AnimatedContainer(
        duration: AppMotion.fast,
        decoration: BoxDecoration(
          color: AppPalette.surface,
          borderRadius: AppRadii.large,
          border: Border.fromBorderSide(
            BorderSide(
              color: focused ? Theme.of(context).colorScheme.primary : AppPalette.outline,
              width: focused ? 4 : 1,
            ),
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.refresh_rounded, color: AppPalette.warning, size: 38),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppPalette.warning),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text('Нажмите OK, чтобы повторить', style: TextStyle(color: AppPalette.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
