import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:sizer/sizer.dart';

import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'app_icon.dart';
import 'app_layout_scope.dart';
import 'tv_focus_tile.dart';

class TvChoiceTile extends StatelessWidget {
  const TvChoiceTile({
    required this.label,
    required this.onPressed,
    this.focusNode,
    this.selected = false,
    this.autofocus = false,
    this.enabled = true,
    this.busy = false,
    this.adaptiveTv = false,
    super.key,
  });

  /// Includes the tile's vertical padding, keeping virtualized rows unclipped.
  static double rowExtentOf(BuildContext context, {bool adaptiveTv = false}) {
    final adaptive = adaptiveTv && AppLayoutScope.isTvOf(context);
    final style = _textStyle(context, adaptive);
    final textHeight = MediaQuery.textScalerOf(context).scale(style?.fontSize ?? 16) * (style?.height ?? 1.4);
    final minimum = _minimum(adaptive);
    final vertical = _vertical(adaptive);

    return math.max(minimum, textHeight * 2 + vertical * 2) + 8;
  }

  final FocusNode? focusNode;
  final String label;
  final VoidCallback onPressed;
  final bool selected;
  final bool autofocus;
  final bool enabled;
  final bool busy;

  final bool adaptiveTv;

  static double _minimum(bool adaptive) => adaptive ? 8.89.h.clamp(56.0, 64.0) : 56.0;
  static double _vertical(bool adaptive) => adaptive ? 2.23.h.clamp(12.0, 16.0) : 14.0;
  static TextStyle? _textStyle(BuildContext context, bool adaptive) =>
      adaptive ? AppTypography.playerEpisodeOf(context) : Theme.of(context).textTheme.bodyMedium;

  void _reveal(BuildContext context, bool focused) {
    if (focused) {
      unawaited(
        Scrollable.ensureVisible(context, alignment: 0.5, duration: AppMotion.durationOf(context, AppMotion.fast)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final adaptive = adaptiveTv && AppLayoutScope.isTvOf(context);
    final extent = _minimum(adaptive);
    final horizontal = adaptive ? 3.34.h.clamp(18.0, 24.0) : 18.0;
    final vertical = _vertical(adaptive);
    final glyph = adaptive ? 2.78.vmin.clamp(16.0, 20.0) : 24.0;
    final style = _textStyle(context, adaptive)?.copyWith(color: AppPalette.textPrimary);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TvFocusTile(
        variant: TvFocusTileVariant.row,
        selected: selected,
        enabled: enabled,
        busy: busy,
        focusNode: focusNode,
        autofocus: autofocus,
        semanticLabel: label,
        onPressed: onPressed,
        onFocusChanged: (focused) => _reveal(context, focused),
        builder: (context, focused) => Container(
          constraints: BoxConstraints(minHeight: extent),
          padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
          child: Row(
            children: [
              Expanded(
                child: ExcludeSemantics(
                  child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: style),
                ),
              ),
              if (busy)
                const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else if (selected)
                AppIcon(AppIconType.check, color: AppPalette.primary, size: glyph),
            ],
          ),
        ),
      ),
    );
  }
}
