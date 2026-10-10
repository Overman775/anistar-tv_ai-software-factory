import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:video_player/video_player.dart';

import '../../domain/models/playback_session.dart';

class PlayerOverlay extends StatefulWidget {
  const PlayerOverlay({
    required this.title,
    required this.episodeNumber,
    required this.session,
    required this.value,
    required this.onPlayPause,
    required this.onSeek,
    this.onSelectQuality,
    this.onSelectEpisode,
    this.onBack,
    this.onReturnToVideo,
    this.backFocusNode,
    this.playFocusNode,
    super.key,
  });

  static String _format(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');

    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  final int episodeNumber;
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
  final _back = FocusNode(debugLabel: 'К сериям');
  final _quality = FocusNode(debugLabel: 'Качество');
  final _episodes = FocusNode(debugLabel: 'Серии');
  final _rewind = FocusNode(debugLabel: 'Назад на 10 секунд');
  final _play = FocusNode(debugLabel: 'Пауза / воспроизведение');
  final _forward = FocusNode(debugLabel: 'Вперёд на 10 секунд');

  KeyEventResult _handleNavigation(FocusNode node, KeyEvent event) {
    final rows = [
      [if (widget.onBack != null) widget.backFocusNode ?? _back, _quality, _episodes],
      [_rewind, widget.playFocusNode ?? _play, _forward],
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
      final next = column + (key == LogicalKeyboardKey.arrowRight ? 1 : -1);
      target = rows[row][next.clamp(0, rows[row].length - 1)];
    } else if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) {
      final next = row + (key == LogicalKeyboardKey.arrowDown ? 1 : -1);
      returnToVideo = next < 0 || next >= rows.length;
      if (!returnToVideo) {
        target = rows[next][column.clamp(0, rows[next].length - 1)];
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
    final target = widget.value.position + offset;
    final durationMs = widget.value.duration.inMilliseconds;
    widget.onSeek(Duration(milliseconds: target.inMilliseconds.clamp(0, durationMs)));
  }

  @override
  void dispose() {
    for (final node in [_back, _quality, _episodes, _rewind, _play, _forward]) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final durationMs = value.duration.inMilliseconds;
    const spacing = SizedBox(width: AppSpacing.lg);
    final quality = widget.session.selectedQuality.apiValue;
    final positionMs = value.position.inMilliseconds.clamp(0, durationMs == 0 ? 1 : durationMs);
    final menuStyle = TextButton.styleFrom(foregroundColor: Colors.white).copyWith(
      side: WidgetStateProperty.resolveWith(
        (states) =>
            BorderSide(color: states.contains(WidgetState.focused) ? AppPalette.primary : Colors.transparent, width: 2),
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.focused) ? AppPalette.surfaceElevated : const Color(0x80141B2D),
      ),
    );

    return Focus(
      canRequestFocus: false,
      onKeyEvent: _handleNavigation,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xC9000000), Color(0x00000000), Color(0xE8000000)],
            stops: [0, 0.48, 1],
          ),
        ),
        child: SafeArea(
          minimum: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Серия ${widget.episodeNumber} • ${quality}p',
                style: const TextStyle(color: AppPalette.textSecondary),
              ),
              const Spacer(),
              Row(
                children: [
                  if (widget.onBack != null) ...[
                    TextButton.icon(
                      key: const ValueKey('player-back'),
                      style: menuStyle,
                      focusNode: widget.backFocusNode ?? _back,
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('К сериям'),
                    ),
                    spacing,
                  ],
                  TextButton.icon(
                    key: const ValueKey('player-quality'),
                    style: menuStyle,
                    focusNode: _quality,
                    onPressed: widget.onSelectQuality,
                    icon: const Icon(Icons.settings),
                    label: Text('Качество: ${quality}p'),
                  ),
                  spacing,
                  TextButton.icon(
                    key: const ValueKey('player-episodes'),
                    style: menuStyle,
                    focusNode: _episodes,
                    onPressed: widget.onSelectEpisode,
                    icon: const Icon(Icons.video_library_outlined),
                    label: const Text('Серии'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xB8141B2D),
                  borderRadius: AppRadii.large,
                  border: Border.fromBorderSide(BorderSide(color: Colors.white.withValues(alpha: 0.12))),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            focusNode: _rewind,
                            iconSize: 30,
                            onPressed: _seekBackward,
                            tooltip: 'Назад на 10 секунд',
                            icon: const Icon(Icons.replay_10_rounded),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          IconButton.filled(
                            key: const ValueKey('player-play'),
                            focusNode: widget.playFocusNode ?? _play,
                            iconSize: 38,
                            onPressed: widget.onPlayPause,
                            tooltip: value.isPlaying ? 'Пауза' : 'Воспроизвести',
                            icon: Icon(value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          IconButton(
                            focusNode: _forward,
                            iconSize: 30,
                            onPressed: _seekForward,
                            tooltip: 'Вперёд на 10 секунд',
                            icon: const Icon(Icons.forward_10_rounded),
                          ),
                          spacing,
                          Text(PlayerOverlay._format(value.position), style: const TextStyle(color: Colors.white)),
                          Expanded(
                            child: ExcludeFocus(
                              child: Slider(
                                value: positionMs.toDouble(),
                                max: durationMs <= 0 ? 1 : durationMs.toDouble(),
                                onChanged: _onSliderChanged,
                              ),
                            ),
                          ),
                          Text(PlayerOverlay._format(value.duration), style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Row(
                        children: [
                          Icon(Icons.gamepad_outlined, size: 20, color: AppPalette.textSecondary),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              '←/→ перемотка · OK пауза · ↑/↓ меню · Back к сериям',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: AppPalette.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
