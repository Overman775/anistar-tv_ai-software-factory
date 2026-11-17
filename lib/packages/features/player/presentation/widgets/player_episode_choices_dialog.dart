import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sizer/sizer.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../domain/models/playback_episode.dart';

class PlayerEpisodeChoicesDialog extends StatefulWidget {
  const PlayerEpisodeChoicesDialog({
    required this.episodes,
    required this.selected,
    required this.watchedEpisodeNumbers,
    this.showWatched = true,
    super.key,
  });

  final List<PlaybackEpisode> episodes;
  final int selected;
  final Set<int> watchedEpisodeNumbers;
  final bool showWatched;

  @override
  State<PlayerEpisodeChoicesDialog> createState() => _PlayerEpisodeChoicesDialogState();
}

class _PlayerEpisodeChoicesDialogState extends State<PlayerEpisodeChoicesDialog> {
  double _minimumEpisodeHeight(BuildContext context) =>
      AppLayoutScope.isTvOf(context) ? 12.78.h.clamp(80.0, 92.0) : 92.0;

  double _rowGap(BuildContext context) => AppLayoutScope.isTvOf(context) ? 2.23.h.clamp(12.0, 16.0) : AppSpacing.md;

  final GlobalKey _selectedEpisodeKey = GlobalKey();
  late final List<PlaybackEpisode> _episodes = widget.episodes.toList()
    ..sort((left, right) => right.number.compareTo(left.number));
  late final _initialFocusEpisode =
      _episodes.where((episode) => episode.number == widget.selected).firstOrNull ?? _episodes.firstOrNull;
  Size? _lastViewport;
  int? _focusedEpisode;
  ScrollController? _scrollController;

  Widget _episodeCard(BuildContext context, PlaybackEpisode episode) {
    final isCurrent = episode.number == widget.selected;
    final isWatched =
        widget.showWatched && (episode.isWatched || widget.watchedEpisodeNumbers.contains(episode.number));
    final caption = EpisodeCaption(number: episode.number, title: episode.title);
    final description = caption.descriptiveTitle;
    final semanticLabel = [
      caption.numberLabel,
      ?description,
      if (isCurrent) 'текущая',
      if (isWatched) 'просмотрена',
    ].join(', ');

    return MediaCard(
      key: isCurrent ? _selectedEpisodeKey : ValueKey('player-episode-${episode.number}'),
      variant: MediaCardVariant.episode,
      label: caption.numberLabel,
      caption: description,
      semanticLabel: semanticLabel,
      imageUrl: episode.previewUri?.toString(),
      episodeHeight: _minimumEpisodeHeight(context),
      selected: isCurrent,
      autofocus: episode == _initialFocusEpisode,
      onFocusChanged: (focused) {
        if (focused) {
          _focusedEpisode = episode.number;
        } else if (_focusedEpisode == episode.number) {
          _focusedEpisode = null;
        }
      },
      isWatched: isWatched,
      onPressed: () => Navigator.of(context).pop(episode.number),
    );
  }

  double _episodeHeight(BuildContext context, PlaybackEpisode episode, double width) {
    final caption = EpisodeCaption(number: episode.number, title: episode.title);

    return MediaCardMetrics(
      width: width,
      label: caption.numberLabel,
      caption: caption.descriptiveTitle,
      showCaption: true,
      minimumHeight: _minimumEpisodeHeight(context),
      titleStyle: AppContentTypography.episodeTitleOf(context)
          ?.copyWith(color: AppPalette.textPrimary, fontWeight: FontWeight.w600),
      captionStyle: AppContentTypography.episodeCaptionOf(context)?.copyWith(color: AppPalette.textSecondary),
      textScaler: MediaQuery.textScalerOf(context),
      direction: Directionality.of(context),
    ).episodeHeight;
  }

  double _scrollOffset(BuildContext context, BoxConstraints constraints, int episodeNumber) {
    final selectedIndex = _episodes.indexWhere((episode) => episode.number == episodeNumber);
    if (selectedIndex < 0) {
      return 0;
    }
    final gap = _rowGap(context);
    var contentHeight = 0.0;
    var selectedOffset = 0.0;
    var selectedHeight = 0.0;
    for (var index = 0; index < _episodes.length; index++) {
      final height = _episodeHeight(context, _episodes[index], constraints.maxWidth);
      if (index == selectedIndex) {
        selectedOffset = contentHeight;
        selectedHeight = height;
      }
      contentHeight += height;
      if (index < _episodes.length - 1) contentHeight += gap;
    }
    final maxScrollExtent = math.max(0, contentHeight - constraints.maxHeight);

    return (selectedOffset - (constraints.maxHeight - selectedHeight) / 2).clamp(0, maxScrollExtent).toDouble();
  }

  void _revealAfterResize(BuildContext context, BoxConstraints constraints) {
    final viewport = constraints.biggest;
    if (_lastViewport == viewport) return;
    final previous = _lastViewport;
    _lastViewport = viewport;
    if (previous == null || !AppLayoutScope.isTvOf(context)) return;
    final focused = FocusManager.instance.primaryFocus;
    final focusedEpisode = _focusedEpisode;
    final controller = _scrollController;
    if (controller == null || !controller.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          controller != _scrollController ||
          !controller.hasClients ||
          FocusManager.instance.primaryFocus != focused)
        return;
      final targetContext = focusedEpisode != null ? focused?.context : _selectedEpisodeKey.currentContext;
      if (targetContext != null && targetContext.mounted) {
        unawaited(Scrollable.ensureVisible(targetContext, alignment: 0.5));
        return;
      }
      final target = _scrollOffset(context, constraints, focusedEpisode ?? widget.selected);
      controller.jumpTo(target.clamp(controller.position.minScrollExtent, controller.position.maxScrollExtent));
    });
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
    adaptiveTv: true,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final scrollController = _scrollController ??= ScrollController(
          initialScrollOffset: _scrollOffset(context, constraints, widget.selected),
        );
        _revealAfterResize(context, constraints);

        return ListView.separated(
          key: const PageStorageKey('player-episode-choices'),
          controller: scrollController,
          scrollCacheExtent: const ScrollCacheExtent.viewport(1),
          padding: EdgeInsets.zero,
          itemCount: _episodes.length,
          separatorBuilder: (_, _) => SizedBox(height: _rowGap(context)),
          itemBuilder: (context, index) {
            final card = _episodeCard(context, _episodes[index]);
            return AppLayoutScope.isTvOf(context) ? _RetainedEpisode(child: card) : card;
          },
        );
      },
    ),
  );
}

class _RetainedEpisode extends StatefulWidget {
  const _RetainedEpisode({required this.child});

  final Widget child;

  @override
  State<_RetainedEpisode> createState() => _RetainedEpisodeState();
}

class _RetainedEpisodeState extends State<_RetainedEpisode> with AutomaticKeepAliveClientMixin {
  bool _focused = false;

  @override
  bool get wantKeepAlive => _focused;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Focus(
      canRequestFocus: false,
      onFocusChange: (focused) {
        if (_focused == focused) return;
        _focused = focused;
        updateKeepAlive();
      },
      child: widget.child,
    );
  }
}
