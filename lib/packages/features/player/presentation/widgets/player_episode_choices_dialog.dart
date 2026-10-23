import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../domain/models/playback_episode.dart';

class PlayerEpisodeChoicesDialog extends StatefulWidget {
  const PlayerEpisodeChoicesDialog({
    required this.episodes,
    required this.selected,
    required this.watchedEpisodeNumbers,
    super.key,
  });

  final List<PlaybackEpisode> episodes;
  final int selected;
  final Set<int> watchedEpisodeNumbers;

  @override
  State<PlayerEpisodeChoicesDialog> createState() => _PlayerEpisodeChoicesDialogState();
}

class _PlayerEpisodeChoicesDialogState extends State<PlayerEpisodeChoicesDialog> {
  static const _minimumEpisodeHeight = 92.0;

  final GlobalKey _selectedEpisodeKey = GlobalKey();
  late final List<PlaybackEpisode> _episodes = widget.episodes.toList()
    ..sort((left, right) => right.number.compareTo(left.number));
  ScrollController? _scrollController;

  Widget _episodeCard(BuildContext context, PlaybackEpisode episode) {
    final isCurrent = episode.number == widget.selected;
    final isWatched = episode.isWatched || widget.watchedEpisodeNumbers.contains(episode.number);
    final title = episode.title.trim();
    final label = 'Серия ${episode.number}';
    final semanticLabel = [
      label,
      if (title.isNotEmpty && title != label) title,
      if (isCurrent) 'текущая',
      if (isWatched) 'просмотрена',
    ].join(', ');

    return MediaCard(
      key: isCurrent ? _selectedEpisodeKey : ValueKey('player-episode-${episode.number}'),
      variant: MediaCardVariant.episode,
      label: label,
      caption: title.isEmpty || title == label ? null : title,
      semanticLabel: semanticLabel,
      imageUrl: episode.previewUri?.toString(),
      episodeHeight: _minimumEpisodeHeight,
      selected: isCurrent,
      autofocus: isCurrent,
      badges: [if (isWatched) const AppIcon(AppIconType.check, size: 20, color: AppPalette.success)],
      onPressed: () => Navigator.of(context).pop(episode.number),
    );
  }

  double _episodeHeight(BuildContext context, PlaybackEpisode episode, double width) {
    final label = 'Серия ${episode.number}';
    final title = episode.title.trim();
    final caption = title.isEmpty || title == label ? null : title;
    final copyWidth = math.max<double>(1, width - AppSpacing.md * 2);
    final titleHeight = _textHeight(
      context: context,
      text: label,
      style: AppContentTypography.episodeTitleOf(context)
          ?.copyWith(color: AppPalette.textPrimary, fontWeight: FontWeight.w600),
      maxWidth: copyWidth,
    );
    final captionHeight = caption == null
        ? 0.0
        : _textHeight(
                context: context,
                text: caption,
                style: AppContentTypography.episodeCaptionOf(context)?.copyWith(color: AppPalette.textSecondary),
                maxWidth: copyWidth,
              ) +
              AppSpacing.xs;

    return math.max(_minimumEpisodeHeight, AppSpacing.xxl + AppSpacing.md + titleHeight + captionHeight);
  }

  double _initialScrollOffset(BuildContext context, BoxConstraints constraints) {
    final selectedIndex = _episodes.indexWhere((episode) => episode.number == widget.selected);
    if (selectedIndex < 0) {
      return 0;
    }
    final heights = _episodes.map((episode) => _episodeHeight(context, episode, constraints.maxWidth)).toList();
    final selectedHeight = heights[selectedIndex];
    final selectedOffset = heights
        .take(selectedIndex)
        .fold<double>(0, (total, height) => total + height + AppSpacing.md);
    final contentHeight =
        heights.fold<double>(0, (total, height) => total + height) + math.max(0, heights.length - 1) * AppSpacing.md;
    final maxScrollExtent = math.max(0, contentHeight - constraints.maxHeight);

    return (selectedOffset - (constraints.maxHeight - selectedHeight) / 2).clamp(0, maxScrollExtent).toDouble();
  }

  double _textHeight({
    required BuildContext context,
    required String text,
    required TextStyle? style,
    required double maxWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 2,
    )..layout(maxWidth: maxWidth);
    final height = painter.height;
    painter.dispose();

    return height;
  }

  @override
  void dispose() {
    _scrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppActionSheet(
    title: 'Выбор серии',
    expandChild: true,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final scrollController = _scrollController ??= ScrollController(
          initialScrollOffset: _initialScrollOffset(context, constraints),
        );

        return ListView.separated(
          key: const PageStorageKey('player-episode-choices'),
          controller: scrollController,
          scrollCacheExtent: const ScrollCacheExtent.viewport(1),
          padding: EdgeInsets.zero,
          itemCount: _episodes.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) => _episodeCard(context, _episodes[index]),
        );
      },
    ),
  );
}
