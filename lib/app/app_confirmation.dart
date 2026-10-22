import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

bool get supportsAppExit => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

Future<void> confirmAppExit(BuildContext context) async {
  if (!supportsAppExit || ModalRoute.of(context)?.isCurrent != true) {
    return;
  }
  final confirmed = await showAppConfirmation(
    context,
    title: 'Выйти из приложения?',
    message: 'Аккаунт будет сохранён. Вы сможете продолжить после следующего запуска.',
    confirmLabel: 'Выйти',
    cancelLabel: 'Остаться',
  );
  if (confirmed && context.mounted) {
    await SystemNavigator.pop();
  }
}

Future<bool> showAppConfirmation(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Отмена',
}) async =>
    await showAppActionSheet<bool>(
      context: context,
      builder: (sheetContext) => AppActionSheet(
        title: title,
        mobileHeightFactor: 0.65,
        child: _AppConfirmation(message: message, confirmLabel: confirmLabel, cancelLabel: cancelLabel),
      ),
    ) ??
    false;

class _AppConfirmation extends StatefulWidget {
  const _AppConfirmation({required this.message, required this.confirmLabel, required this.cancelLabel});

  final String message;
  final String confirmLabel;
  final String cancelLabel;

  @override
  State<_AppConfirmation> createState() => _AppConfirmationState();
}

class _AppConfirmationState extends State<_AppConfirmation> {
  final _cancelFocus = FocusNode(debugLabel: 'Отмена подтверждения');
  final _confirmFocus = FocusNode(debugLabel: 'Подтверждение');
  final _scroll = ScrollController();

  KeyEventResult _handleKey(KeyEvent event) {
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.arrowUp && key != LogicalKeyboardKey.arrowDown) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (key == LogicalKeyboardKey.arrowDown && _cancelFocus.hasFocus) {
        _confirmFocus.requestFocus();
      } else if (key == LogicalKeyboardKey.arrowUp && _confirmFocus.hasFocus) {
        _cancelFocus.requestFocus();
      } else if (_scroll.hasClients) {
        final position = _scroll.position;
        final direction = key == LogicalKeyboardKey.arrowUp ? -1 : 1;
        final target = (position.pixels + direction * position.viewportDimension * 0.8).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
        unawaited(position.moveTo(target, duration: AppMotion.durationOf(context, AppMotion.fast)));
      }
    }

    return KeyEventResult.handled;
  }

  void _reveal(BuildContext target, bool focused) {
    if (!focused) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (target.mounted) {
        unawaited(Scrollable.ensureVisible(target, duration: AppMotion.durationOf(target, AppMotion.fast)));
      }
    });
  }

  @override
  void dispose() {
    _cancelFocus.dispose();
    _confirmFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    onKeyEvent: (_, event) => _handleKey(event),
    child: ListView(
      controller: _scroll,
      children: [
        Text(widget.message, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.lg),
        Builder(
          builder: (actionContext) => AppButton(
            key: const ValueKey('confirmation-cancel'),
            focusNode: _cancelFocus,
            autofocus: true,
            variant: AppButtonVariant.neutral,
            label: widget.cancelLabel,
            onPressed: () => Navigator.of(context).pop(false),
            onFocusChanged: (focused) => _reveal(actionContext, focused),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Builder(
          builder: (actionContext) => AppButton(
            key: const ValueKey('confirmation-confirm'),
            focusNode: _confirmFocus,
            variant: AppButtonVariant.danger,
            label: widget.confirmLabel,
            onPressed: () => Navigator.of(context).pop(true),
            onFocusChanged: (focused) => _reveal(actionContext, focused),
          ),
        ),
      ],
    ),
  );
}
