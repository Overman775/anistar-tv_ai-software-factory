import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../domain/models/anime_summary.dart';
import '../../domain/models/catalog_filter.dart';
import 'catalog_inspector_rating.dart';

class CatalogInspectorCopy extends StatelessWidget {
  const CatalogInspectorCopy({
    required this.anime,
    this.opacity = const AlwaysStoppedAnimation(1),
    this.actions,
    this.lastGenreFocus,
    this.onGenreTap,
    this.genreFocus,
    this.onGenreTop,
    this.onGenreRight,
    this.onGenreBottom,
    super.key,
  });

  final AnimeSummary anime;
  final Animation<double> opacity;
  final Widget? actions;
  final FocusNode? lastGenreFocus;
  final void Function(AnimeSummary, CatalogFilter)? onGenreTap;
  final Map<String, FocusNode>? genreFocus;
  final ValueChanged<FocusNode>? onGenreTop;
  final ValueChanged<FocusNode>? onGenreRight;
  final VoidCallback? onGenreBottom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final secondary = theme.bodyMedium?.copyWith(color: AppPalette.textSecondary);
    final update = anime.updateMessage;
    final nodes = <FocusNode>[];
    final genres = _genres(secondary, nodes);

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        primary: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeTransition(
                  opacity: opacity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: AppSpacing.sm,
                    children: [
                      Text(anime.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.headlineMedium),
                      Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (anime.rating != null) CatalogInspectorRating(rating: anime.rating),
                          if (anime.seriesInfo case final value?) Text(value, style: secondary),
                          if (anime.voiceover case final value?) Text(value, style: secondary),
                          if (anime.publicationDate case final value?) Text(value, style: secondary),
                        ],
                      ),
                      if (genres.isNotEmpty)
                        Focus(
                          canRequestFocus: false,
                          onKeyEvent: (_, event) => _genreKey(event, nodes),
                          child: Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.xs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: genres,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  // Intrinsic height excludes the description so only mandatory rows can require scrolling.
                  child: SizedOverflowBox(
                    size: Size.zero,
                    child: FadeTransition(
                      opacity: opacity,
                      child: _CatalogDescription(description: anime.description, style: secondary),
                    ),
                  ),
                ),
                FadeTransition(
                  opacity: opacity,
                  child: update == null
                      ? ExcludeSemantics(child: Text(' ', style: theme.bodyMedium))
                      : Text(update, style: theme.bodyMedium),
                ),
                if (actions case final actions?) ...[const SizedBox(height: AppSpacing.sm), actions],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _genres(TextStyle? style, List<FocusNode> nodes) {
    final labels = anime.genres;
    final onTap = onGenreTap;
    if (onTap == null || anime.genreFilters.isEmpty) {
      return [for (final label in labels) Text(label, style: style)];
    }
    final filters = {for (final filter in anime.genreFilters) filter.label.toLowerCase(): filter};
    final matches = labels.map((label) => filters[label.toLowerCase()]).toList(growable: false);
    final lastActive = matches.lastIndexWhere((filter) => filter != null);

    return [
      for (final (index, filter) in matches.indexed)
        if (filter == null)
          Text(labels[index], style: style)
        else
          _genreButton(filter, onTap, _genreNode(filter, index, nodes, last: index == lastActive)),
    ];
  }

  FocusNode? _genreNode(CatalogFilter filter, int index, List<FocusNode> nodes, {required bool last}) {
    final focus = (last ? lastGenreFocus : null) ?? genreFocus?.putIfAbsent('${filter.path}:$index', FocusNode.new);
    if (focus != null) nodes.add(focus);

    return focus;
  }

  KeyEventResult _genreKey(KeyEvent event, List<FocusNode> nodes) {
    final index = nodes.indexWhere((node) => node.hasPrimaryFocus);
    if (index < 0) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.arrowLeft &&
        key != LogicalKeyboardKey.arrowRight &&
        key != LogicalKeyboardKey.arrowUp &&
        key != LogicalKeyboardKey.arrowDown) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final current = nodes[index];
      if (key == LogicalKeyboardKey.arrowLeft) {
        nodes.elementAtOrNull(index - 1)?.requestFocus();
      } else if (key == LogicalKeyboardKey.arrowRight) {
        final next = nodes.elementAtOrNull(index + 1);
        if (next == null) {
          onGenreRight?.call(current);
        } else {
          next.requestFocus();
        }
      } else {
        final down = key == LogicalKeyboardKey.arrowDown;
        final neighbor = _verticalGenre(current, nodes, down: down);
        if (neighbor != null) {
          neighbor.requestFocus();
        } else if (down) {
          onGenreBottom?.call();
        } else {
          onGenreTop?.call(current);
        }
      }
    }

    return KeyEventResult.handled;
  }

  FocusNode? _verticalGenre(FocusNode current, List<FocusNode> nodes, {required bool down}) {
    final origin = current.rect.center;
    var vertical = double.infinity;
    var horizontal = double.infinity;
    FocusNode? nearest;
    for (final node in nodes) {
      if (node.context == null || !node.canRequestFocus) continue;
      final center = node.rect.center;
      final y = down ? center.dy - origin.dy : origin.dy - center.dy;
      if (y < 0.5) continue;
      final x = (center.dx - origin.dx).abs();
      if (y < vertical - 0.5 || (y <= vertical + 0.5 && x < horizontal)) {
        nearest = node;
        vertical = y;
        horizontal = x;
      }
    }

    return nearest;
  }

  Widget _genreButton(CatalogFilter filter, void Function(AnimeSummary, CatalogFilter) onTap, FocusNode? focusNode) {
    focusNode?.debugLabel = filter.label;

    return Builder(
      builder: (context) => AppButton(
        key: ValueKey(filter.path),
        focusNode: focusNode,
        label: filter.label,
        variant: AppButtonVariant.metadata,
        icon: const AppIcon(AppIconType.listFilter, size: 16),
        onFocusChanged: (focused) {
          if (focused) {
            unawaited(Scrollable.ensureVisible(context, duration: AppMotion.durationOf(context, AppMotion.fast)));
          }
        },
        onPressed: () => onTap(anime, filter),
      ),
    );
  }
}

class _CatalogDescription extends StatelessWidget {
  const _CatalogDescription({required this.description, required this.style});

  final String? description;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final description = this.description;
    if (description == null) return const SizedBox.shrink();
    final resolvedStyle = DefaultTextStyle.of(context).style.merge(style);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final painter = TextPainter(
            text: TextSpan(text: description, style: resolvedStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          );
          final lines = (constraints.maxHeight / painter.preferredLineHeight).floor();
          if (lines < 1) {
            painter.dispose();

            return Semantics(label: description);
          }
          painter.maxLines = lines;
          final text = _fitDescription(painter, description, constraints, resolvedStyle);
          painter.dispose();

          return Align(
            alignment: Alignment.topLeft,
            child: Text(text, style: resolvedStyle, maxLines: lines, semanticsLabel: description),
          );
        },
      ),
    );
  }

  String _fitDescription(TextPainter painter, String description, BoxConstraints constraints, TextStyle style) {
    painter.layout(maxWidth: constraints.maxWidth);
    if (!painter.didExceedMaxLines && painter.height <= constraints.maxHeight) {
      return description;
    }

    final boundaries = [0, ...RegExp(r'\s+').allMatches(description).map((match) => match.start)];
    var low = 0;
    var high = boundaries.length;
    while (low + 1 < high) {
      final middle = (low + high) ~/ 2;
      final candidate = '${description.substring(0, boundaries[middle]).trimRight()}…';
      painter
        ..text = TextSpan(text: candidate, style: style)
        ..layout(maxWidth: constraints.maxWidth);
      if (painter.didExceedMaxLines || painter.height > constraints.maxHeight) {
        high = middle;
      } else {
        low = middle;
      }
    }

    return '${description.substring(0, boundaries[low]).trimRight()}…';
  }
}
