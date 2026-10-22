import 'dart:async';

import 'package:flutter/services.dart';

import 'package:material_ui/material_ui.dart';

import '../theme/app_palette.dart';
import 'app_button.dart';
import 'app_icon.dart';

class TvStateView extends StatelessWidget {
  const TvStateView({
    required this.icon,
    required this.title,
    super.key,
    this.message,
    this.actionLabel,
    this.onAction,
    this.actionFocusNode,
    this.actionKey,
    this.actionIcon = Icons.refresh_rounded,
    this.autofocusAction = true,
    this.actionBusy = false,
    this.actionEnabled = true,
  });

  final FocusNode? actionFocusNode;
  final Key? actionKey;
  final IconData actionIcon;
  final bool autofocusAction;
  final bool actionBusy;
  final bool actionEnabled;
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  KeyEventResult _scrollFeedback(BuildContext context, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp => -1,
      LogicalKeyboardKey.arrowDown => 1,
      _ => 0,
    };
    if (direction == 0) {
      return KeyEventResult.ignored;
    }
    final position = Scrollable.of(context).position;
    final target = (position.pixels + direction * position.viewportDimension * 0.8).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target == position.pixels) {
      return KeyEventResult.ignored;
    }
    unawaited(
      position.moveTo(target, duration: AppMotion.durationOf(context, AppMotion.fast), curve: AppMotion.enterCurve),
    );

    return KeyEventResult.handled;
  }

  void _revealAction(BuildContext context, bool focused) {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final actionText = actionLabel;
    final messageText = message;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: Builder(
          builder: (scrollContext) => Focus(
            canRequestFocus: false,
            onKeyEvent: (_, event) => _scrollFeedback(scrollContext, event),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0),
              child: Center(
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
                          child: AppIcon.fromMaterial(icon, size: 34, color: colorScheme.primary),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Semantics(
                          liveRegion: true,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
                              if (messageText != null) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  messageText,
                                  style: theme.textTheme.bodyLarge?.copyWith(color: AppPalette.textSecondary),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (actionText != null && onAction != null) ...[
                          const SizedBox(height: AppSpacing.lg),
                          Builder(
                            builder: (actionContext) => Focus(
                              canRequestFocus: false,
                              onFocusChange: (focused) => _revealAction(actionContext, focused),
                              child: AppButton(
                                key: actionKey,
                                autofocus: autofocusAction,
                                focusNode: actionFocusNode,
                                onPressed: () => onAction?.call(),
                                enabled: actionEnabled,
                                busy: actionBusy,
                                icon: AppIcon.fromMaterial(actionIcon),
                                label: actionText,
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
    );
  }
}
