import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

/// A playback control shares the UI Kit input path on TV and touch devices.
class PlayerControlButton extends StatelessWidget {
  const PlayerControlButton({
    required this.buttonKey,
    required this.label,
    required this.child,
    required this.onPressed,
    this.focusNode,
    this.primary = false,
    super.key,
  });

  final String buttonKey;
  final String label;
  final Widget child;
  final VoidCallback? onPressed;
  final FocusNode? focusNode;
  final bool primary;

  void _activate() => onPressed?.call();

  Widget _buildState(BuildContext context, TvFocusState state) {
    final tv = AppLayoutScope.isTvOf(context);
    final extent = switch ((primary, tv)) {
      (true, false) => AppSizes.touchControl + AppSpacing.md,
      (_, true) => AppSizes.tvControl,
      _ => AppSizes.touchControl,
    };
    final glyphSize = switch ((primary, tv)) {
      (true, false) => 36.0,
      (_, true) => 30.0,
      _ => 26.0,
    };

    final active = state.focused || state.hovered;
    final background = switch ((primary, tv, active)) {
      (true, false, _) || (true, _, true) => AppPalette.primary,
      (true, _, _) => AppPalette.playerText,
      (_, _, true) => AppPalette.focusSurface,
      _ => AppPalette.playerSurface,
    };
    final foreground = switch ((primary, tv, active)) {
      (true, false, _) || (true, _, true) => AppPalette.onPrimary,
      (true, _, _) => AppPalette.playerOnLight,
      _ => AppPalette.playerText,
    };
    final pressedBackground = primary ? AppPalette.primarySoft : AppPalette.surfaceElevated;

    return AppFocusBorder(
      focused: state.focused,
      child: AnimatedContainer(
        duration: AppMotion.durationOf(context, state.focused ? AppMotion.fast : AppMotion.focusExit),
        curve: state.focused ? AppMotion.enterCurve : AppMotion.exitCurve,
        constraints: BoxConstraints(minWidth: extent, minHeight: extent),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: AppFocusStyle.decoration(
          focused: active,
          pressed: state.pressed,
          restingColor: background,
        ).copyWith(color: state.pressed ? pressedBackground : background, border: const Border()),
        child: Opacity(
          opacity: onPressed == null ? 0.45 : 1,
          child: IconTheme(
            data: IconThemeData(color: foreground, size: glyphSize),
            child: DefaultTextStyle.merge(
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: foreground, fontWeight: FontWeight.w600),
              child: Center(widthFactor: 1, heightFactor: 1, child: ExcludeSemantics(child: child)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    excludeFromSemantics: true,
    child: TvFocusable(
      key: ValueKey(buttonKey),
      focusNode: focusNode,
      enabled: onPressed != null,
      semanticLabel: label,
      onPressed: _activate,
      stateBuilder: _buildState,
    ),
  );
}
