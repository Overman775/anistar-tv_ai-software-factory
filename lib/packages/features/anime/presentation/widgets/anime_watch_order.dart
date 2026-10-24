import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../domain/models/anime_part.dart';

class AnimeWatchOrder extends StatelessWidget {
  const AnimeWatchOrder({required this.parts, required this.currentId, this.onSelected, this.focusNodes, super.key});

  final List<AnimePart> parts;
  final int currentId;
  final ValueChanged<AnimePart>? onSelected;
  final Map<int, FocusNode>? focusNodes;

  void _open(AnimePart part) {
    if (part.id != currentId) {
      onSelected?.call(part);
    }
  }

  void _reveal(BuildContext context, bool focused) {
    if (focused) {
      unawaited(
        Scrollable.ensureVisible(context, alignment: 0.5, duration: AppMotion.durationOf(context, AppMotion.standard)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppSectionHeader(title: 'Порядок просмотра', titleStyle: AppContentTypography.sectionTitleOf(context)),
      const SizedBox(height: AppSpacing.md),
      for (final (index, part) in parts.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Builder(
            builder: (partContext) {
              final current = part.id != null && part.id == currentId;
              final label = '${part.label}${current ? ', Открыто' : ''}';
              if (!part.canOpen || onSelected == null) {
                return Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text(label));
              }

              return TvFocusTile(
                variant: TvFocusTileVariant.row,
                semanticLabel: label,
                focusNode: focusNodes?.putIfAbsent(index, () => FocusNode(debugLabel: part.label)),
                selected: current,
                onPressed: () => _open(part),
                onFocusChanged: (focused) => _reveal(partContext, focused),
                builder: (context, focused) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
                ),
              );
            },
          ),
        ),
    ],
  );
}
