import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/app_focus_style.dart';
import '../theme/app_palette.dart';
import 'tv_focusable.dart';

class TvChoiceTile extends StatelessWidget {
  const TvChoiceTile({
    required this.label,
    required this.onPressed,
    this.focusNode,
    this.selected = false,
    this.autofocus = false,
    super.key,
  });

  /// Includes the tile's vertical padding, keeping virtualized rows unclipped.
  static double rowExtentOf(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    final textHeight = MediaQuery.textScalerOf(context).scale(style?.fontSize ?? 16) * (style?.height ?? 1.4);

    return math.max(56, textHeight + 24) + 8;
  }

  final FocusNode? focusNode;
  final String label;
  final VoidCallback onPressed;
  final bool selected;
  final bool autofocus;

  void _reveal(BuildContext context, bool focused) {
    if (focused) {
      unawaited(
        Scrollable.ensureVisible(context, alignment: 0.5, duration: AppMotion.durationOf(context, AppMotion.fast)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TvFocusable(
        focusNode: focusNode,
        autofocus: autofocus,
        semanticLabel: label,
        onPressed: onPressed,
        onFocusChanged: (focused) => _reveal(context, focused),
        builder: (context, focused) => AnimatedContainer(
          duration: AppMotion.durationOf(context, AppMotion.fast),
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: AppFocusStyle.decoration(focused: focused, selected: selected),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppPalette.textPrimary),
                ),
              ),
              if (selected) const Icon(Icons.check, color: AppPalette.textPrimary),
            ],
          ),
        ),
      ),
    ),
  );
}
