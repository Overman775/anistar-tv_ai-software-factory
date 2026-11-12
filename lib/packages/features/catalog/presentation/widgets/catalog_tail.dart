import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

class CatalogTail extends StatelessWidget {
  const CatalogTail({required this.onRetry, super.key, this.error, this.focusNode, this.retrying = false});

  final String? error;
  final FocusNode? focusNode;
  final bool retrying;
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
      focusNode: focusNode,
      onPressed: onRetry,
      semanticLabel: retrying ? message : 'Повторить загрузку. $message',
      builder: (context, focused) => AnimatedContainer(
        duration: AppMotion.durationOf(context, AppMotion.fast),
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (retrying) return const CircularProgressIndicator();
              final largeText = MediaQuery.textScalerOf(context).scale(16) > 16;
              final dense = constraints.maxWidth < 180 && largeText;
              final compact = constraints.maxHeight < 180 || dense;
              var retryLabel = compact ? 'Повторить' : 'Нажмите OK, чтобы повторить';
              if (dense) retryLabel = 'Ещё раз';
              final retry = Text(
                retryLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppPalette.textSecondary),
              );

              final errorText = Semantics(
                liveRegion: true,
                child: Text(
                  dense ? 'Сбой' : message,
                  maxLines: dense ? 1 : 4,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppPalette.warning),
                ),
              );

              return Padding(
                padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: compact ? AppSpacing.xs : AppSpacing.sm,
                  children: [
                    if (!dense)
                      AppIcon.fromMaterial(Icons.refresh_rounded, color: AppPalette.warning, size: compact ? 24 : 38),
                    if (dense) errorText else Flexible(child: errorText),
                    if (compact) Flexible(child: retry) else retry,
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
