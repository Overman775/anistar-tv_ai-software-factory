import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sizer/sizer.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:video_player/video_player.dart';

import '../../domain/models/playback_session.dart';
import '../playback_quality_label.dart';
import 'player_control_button.dart';
import 'player_progress.dart';

class PlayerOverlay extends StatefulWidget {
  const PlayerOverlay({
    required this.title,
    required this.episodeNumber,
    required this.session,
    required this.value,
    required this.onPlayPause,
    required this.onSeek,
    this.onSeekKeyEvent,
    this.onSeekRelative,
    this.previewPosition,
    this.onSelectQuality,
    this.onSelectEpisode,
    this.onPreviousEpisode,
    this.onNextEpisode,
    this.onBack,
    this.onReturnToVideo,
    this.backFocusNode,
    this.playFocusNode,
    super.key,
  });

  final bool Function(KeyEvent)? onSeekKeyEvent;
  final ValueChanged<Duration>? onSeekRelative;
  final Duration? previewPosition;
  final int episodeNumber;
  final VoidCallback? onPreviousEpisode;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onBack;
  final VoidCallback? onReturnToVideo;
  final FocusNode? backFocusNode;
  final FocusNode? playFocusNode;
  final VoidCallback onPlayPause;
  final VoidCallback? onSelectQuality;
  final VoidCallback? onSelectEpisode;
  final ValueChanged<Duration> onSeek;
  final PlaybackSession session;
  final String title;
  final VideoPlayerValue value;

  @override
  State<PlayerOverlay> createState() => _PlayerOverlayState();
}

class _PlayerOverlayState extends State<PlayerOverlay> {
  final _timeline = FocusNode(debugLabel: 'Позиция видео');
  int _transportIndex = 0;
  final _back = FocusNode(debugLabel: 'К сериям');
  final _quality = FocusNode(debugLabel: 'Качество');
  final _episodes = FocusNode(debugLabel: 'Серии');
  final _rewind = FocusNode(debugLabel: 'Назад на 10 секунд');
  final _play = FocusNode(debugLabel: 'Пауза / воспроизведение');
  final _previousEpisode = FocusNode(debugLabel: 'Предыдущая серия');
  final _nextEpisode = FocusNode(debugLabel: 'Следующая серия');
  final _forward = FocusNode(debugLabel: 'Вперёд на 10 секунд');

  bool _timelineFocused = false;

  int get _bufferedPosition => playerBufferedPosition(widget.value.buffered, widget.value.duration);

  String _formatSliderPosition(double value) => formatPlayerTime(Duration(milliseconds: value.round()));

  void _onTimelineFocusChanged(bool focused) => setState(() => _timelineFocused = focused);

  KeyEventResult _handleNavigation(FocusNode node, KeyEvent event) {
    final transport = [
      widget.playFocusNode ?? _play,
      _rewind,
      _forward,
      if (widget.onPreviousEpisode != null) _previousEpisode,
      if (widget.onNextEpisode != null) _nextEpisode,
      if (widget.onSelectEpisode != null) _episodes,
      if (widget.onSelectQuality != null) _quality,
    ];
    final rows = [
      if (widget.onBack != null) [widget.backFocusNode ?? _back],
      [_timeline],
      transport,
    ];
    final current = FocusManager.instance.primaryFocus;
    final row = rows.indexWhere((nodes) => nodes.contains(current));
    if (row < 0) {
      return KeyEventResult.ignored;
    }
    final column = rows[row].indexOf(current ?? node);
    final key = event.logicalKey;
    FocusNode? target;
    var returnToVideo = false;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
      if (current == _timeline) {
        if (widget.onSeekKeyEvent != null) {
          widget.onSeekKeyEvent?.call(event);
        } else if (event is KeyDownEvent || event is KeyRepeatEvent) {
          _seekRelative(Duration(seconds: key == LogicalKeyboardKey.arrowRight ? 10 : -10));
        }

        return KeyEventResult.handled;
      }
      final next = column + (key == LogicalKeyboardKey.arrowRight ? 1 : -1);
      target = rows[row][next.clamp(0, rows[row].length - 1)];
    } else if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) {
      final next = row + (key == LogicalKeyboardKey.arrowDown ? 1 : -1);
      returnToVideo = next < 0 || next >= rows.length;
      if (!returnToVideo) {
        if (row == rows.length - 1) {
          _transportIndex = column;
        }
        target = next == rows.length - 1 ? transport[_transportIndex.clamp(0, transport.length - 1)] : rows[next].first;
      }
    } else {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (returnToVideo) {
        widget.onReturnToVideo?.call();
      } else {
        target?.requestFocus();
      }
    }

    return KeyEventResult.handled;
  }

  void _onSliderChanged(double milliseconds) => widget.onSeek(Duration(milliseconds: milliseconds.round()));

  void _seekBackward() => _seekRelative(const Duration(seconds: -10));

  void _seekForward() => _seekRelative(const Duration(seconds: 10));

  void _seekRelative(Duration offset) {
    final relativeSeek = widget.onSeekRelative;
    if (relativeSeek != null) {
      relativeSeek(offset);

      return;
    }
    final target = widget.value.position + offset;
    widget.onSeek(Duration(milliseconds: playerSeekPosition(target, widget.value.duration)));
  }

  @override
  void dispose() {
    for (final node in [
      _back,
      _quality,
      _episodes,
      _rewind,
      _play,
      _forward,
      _previousEpisode,
      _nextEpisode,
      _timeline,
    ]) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedQuality = widget.session.selectedQuality;
    final value = widget.value;
    final durationMs = playerSliderMaximum(value.duration);
    final position = widget.previewPosition ?? value.position;
    final positionMs = playerSliderPosition(position, value.duration);
    final time = '${formatPlayerTime(position)} / ${formatPlayerTime(value.duration)}';
    final pad = 4.45.h.clamp(24.0, 32.0);
    final gap = AppSpacing.adaptiveTvControlGap;
    final groupGap = 2.23.h.clamp(12.0, 16.0);
    final glyph = 4.17.vmin.clamp(24.0, 30.0);
    final titleStyle = AppTypography.playerTitleOf(context)?.copyWith(color: AppPalette.playerText);
    final episodeStyle = AppTypography.playerEpisodeOf(context)?.copyWith(color: AppPalette.playerMuted);
    final timeStyle = AppTypography.playerTimeOf(context)
        ?.copyWith(color: AppPalette.playerText, fontFeatures: const [FontFeature.tabularFigures()]);

    return Focus(
      canRequestFocus: false,
      onKeyEvent: _handleNavigation,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppPalette.playerShadeTop, Colors.transparent, Colors.transparent, AppPalette.playerShadeBottom],
            stops: [0, 0.32, 0.54, 1],
          ),
        ),
        child: SafeArea(
          minimum: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (widget.onBack != null) ...[
                    PlayerControlButton(
                      buttonKey: 'player-back',
                      label: 'К сериям',
                      focusNode: widget.backFocusNode ?? _back,
                      onPressed: widget.onBack,
                      child: AppIcon(AppIconType.arrowLeft, size: glyph),
                    ),
                    SizedBox(width: groupGap),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
                        Text(
                          'Серия ${widget.episodeNumber}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: episodeStyle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Focus(
                focusNode: _timeline,
                onFocusChange: _onTimelineFocusChanged,
                child: Semantics(
                  label: 'Позиция видео',
                  child: ExcludeFocus(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: _timelineFocused ? 0.84.h.clamp(4.0, 6.0) : 0.42.h.clamp(2.0, 3.0),
                        activeTrackColor: AppPalette.primary,
                        inactiveTrackColor: AppPalette.playerMuted.withValues(alpha: 0.3),
                        secondaryActiveTrackColor: AppPalette.playerMuted.withValues(alpha: 0.6),
                        thumbColor: AppPalette.primary,
                        thumbShape: RoundSliderThumbShape(
                          enabledThumbRadius: _timelineFocused ? 1.25.vmin.clamp(7.0, 9.0) : 0.7.vmin.clamp(4.0, 5.0),
                        ),
                        overlayShape: RoundSliderOverlayShape(overlayRadius: 2.23.vmin.clamp(12.0, 16.0)),
                        padding: EdgeInsets.zero,
                      ),
                      child: SizedBox(
                        height: 48,
                        child: Slider(
                          key: const ValueKey('player-timeline'),
                          value: positionMs.toDouble(),
                          max: durationMs.toDouble(),
                          secondaryTrackValue: _bufferedPosition.toDouble(),
                          onChanged: value.duration.inMilliseconds > 0 ? _onSliderChanged : null,
                          semanticFormatterCallback: _formatSliderPosition,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: groupGap),
              LayoutBuilder(
                builder: (context, constraints) {
                  final largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
                  final split = constraints.maxWidth < 900 || largeText;
                  final transport = <Widget>[
                    PlayerControlButton(
                      buttonKey: 'player-play',
                      label: value.isPlaying ? 'Пауза' : 'Воспроизвести',
                      focusNode: widget.playFocusNode ?? _play,
                      onPressed: widget.onPlayPause,
                      primary: true,
                      child: AppIcon(value.isPlaying ? AppIconType.pause : AppIconType.play, size: glyph),
                    ),
                    SizedBox(width: gap),
                    PlayerControlButton(
                      buttonKey: 'player-rewind',
                      label: 'Назад на 10 секунд',
                      focusNode: _rewind,
                      onPressed: _seekBackward,
                      child: AppIcon(AppIconType.rotateCcw, size: glyph),
                    ),
                    SizedBox(width: gap),
                    PlayerControlButton(
                      buttonKey: 'player-forward',
                      label: 'Вперёд на 10 секунд',
                      focusNode: _forward,
                      onPressed: _seekForward,
                      child: AppIcon(AppIconType.rotateCw, size: glyph),
                    ),
                    if (widget.onPreviousEpisode != null) ...[
                      SizedBox(width: gap),
                      PlayerControlButton(
                        buttonKey: 'player-previous-episode',
                        label: 'Предыдущая серия',
                        focusNode: _previousEpisode,
                        onPressed: widget.onPreviousEpisode,
                        child: AppIcon(AppIconType.skipBack, size: glyph),
                      ),
                    ],
                    if (widget.onNextEpisode != null) ...[
                      SizedBox(width: gap),
                      PlayerControlButton(
                        buttonKey: 'player-next-episode',
                        label: 'Следующая серия',
                        focusNode: _nextEpisode,
                        onPressed: widget.onNextEpisode,
                        child: AppIcon(AppIconType.skipForward, size: glyph),
                      ),
                    ],
                  ];
                  final timer = Text(time, maxLines: 1, softWrap: false, style: timeStyle);
                  final tools = <Widget>[
                    if (widget.onSelectEpisode != null)
                      PlayerControlButton(
                        buttonKey: 'player-episodes',
                        label: 'Серии',
                        focusNode: _episodes,
                        onPressed: widget.onSelectEpisode,
                        child: AppIcon(AppIconType.listVideo, size: glyph),
                      ),
                    if (widget.onSelectEpisode != null && widget.onSelectQuality != null) SizedBox(width: gap),
                    if (widget.onSelectQuality != null)
                      PlayerControlButton(
                        buttonKey: 'player-quality',
                        label: 'Качество: ${selectedQuality.label}',
                        focusNode: _quality,
                        onPressed: widget.onSelectQuality,
                        child: Text(selectedQuality.shortLabel),
                      ),
                  ];

                  if (split) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: transport),
                        SizedBox(height: gap),
                        Row(
                          children: [
                            Expanded(child: timer),
                            SizedBox(width: groupGap),
                            ...tools,
                          ],
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      ...transport,
                      SizedBox(width: groupGap),
                      Expanded(child: timer),
                      SizedBox(width: groupGap),
                      ...tools,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
