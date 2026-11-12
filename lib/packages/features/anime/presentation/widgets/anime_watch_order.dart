import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../domain/models/anime_part.dart';

class AnimeWatchOrder extends StatelessWidget {
  const AnimeWatchOrder({required this.parts, required this.currentId, this.onSelected, this.focusNodes, super.key});

  final List<AnimePart> parts;
  final int currentId;
  final ValueChanged<AnimePart>? onSelected;
  final Map<AnimePart, FocusNode>? focusNodes;

  void _reveal(BuildContext context, bool focused) {
    if (focused && ModalRoute.isCurrentOf(context) != false) {
      unawaited(
        Scrollable.ensureVisible(context, alignment: 0.5, duration: AppMotion.durationOf(context, AppMotion.standard)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: AppSpacing.lg,
    children: [
      AppSectionHeader(title: 'Смотреть также', titleStyle: AppContentTypography.sectionTitleOf(context)),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final part in parts)
            if (part.label.trim().isNotEmpty)
              Builder(
                builder: (partContext) {
                  final id = part.id;
                  final current = id == currentId;
                  final label = '${part.label}${current ? ', Открыто' : ''}';
                  final open = onSelected;
                  final style = Theme.of(partContext).textTheme.bodyLarge?.copyWith(fontSize: 16);
                  if (id == null || !part.canOpen || open == null) return Text(label, style: style);

                  return TvFocusable(
                    semanticLabel: label,
                    focusNode: focusNodes?.putIfAbsent(part, () => FocusNode(debugLabel: part.label)),
                    selected: current,
                    onPressed: () {
                      if (!current) open(part);
                    },
                    onFocusChanged: (focused) => _reveal(partContext, focused),
                    builder: (context, focused) => AppFocusBorder(
                      focused: focused,
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          color: AppPalette.surfaceElevated,
                          borderRadius: AppRadii.medium,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: AppSizes.touchControl),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            widthFactor: 1,
                            heightFactor: 1,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                              child: ExcludeSemantics(child: Text(label, style: style)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
        ],
      ),
    ],
  );
}
