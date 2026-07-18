import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

class TvStateView extends StatelessWidget {
  const TvStateView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final actionText = actionLabel;
    final messageText = message;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppPalette.surface.withValues(alpha: 0.84),
            borderRadius: AppRadii.large,
            border: Border.all(color: AppPalette.outline.withValues(alpha: 0.8)),
            boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 32, offset: Offset(0, 18))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.primary.withValues(alpha: 0.36)),
                ),
                child: Icon(icon, size: 34, color: colorScheme.primary),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
              if (messageText != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  messageText,
                  style: theme.textTheme.bodyLarge?.copyWith(color: AppPalette.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
              if (actionText != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  autofocus: true,
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(actionText),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
