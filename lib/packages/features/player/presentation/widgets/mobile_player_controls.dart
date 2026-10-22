import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:video_player/video_player.dart';

import '../../domain/models/playback_session.dart';
import 'mobile_player_footer.dart';
import 'mobile_player_header.dart';
import 'mobile_player_tools.dart';
import 'mobile_player_transport.dart';

/// Touch controls use the same playback commands as the television overlay.
class MobilePlayerControls extends StatelessWidget {
  const MobilePlayerControls({
    required this.title,
    required this.episodeNumber,
    required this.session,
    required this.value,
    required this.onPlayPause,
    required this.onSeek,
    this.onSeekRelative,
    this.onBack,
    this.onSelectEpisode,
    this.onSelectQuality,
    this.onPreviousEpisode,
    this.onNextEpisode,
    this.onRotate,
    this.onInteractionStart,
    this.onInteractionEnd,
    super.key,
  });

  final String title;
  final int episodeNumber;
  final PlaybackSession session;
  final VideoPlayerValue value;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<Duration>? onSeekRelative;
  final VoidCallback? onBack;
  final VoidCallback? onSelectEpisode;
  final VoidCallback? onSelectQuality;
  final VoidCallback? onPreviousEpisode;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onRotate;
  final VoidCallback? onInteractionStart;
  final VoidCallback? onInteractionEnd;

  void _seekRelative(int seconds) {
    final relativeSeek = onSeekRelative;
    if (relativeSeek != null) {
      relativeSeek(Duration(seconds: seconds));
    } else {
      onSeek(
        Duration(
          milliseconds: (value.position.inMilliseconds + seconds * 1000).clamp(0, value.duration.inMilliseconds),
        ),
      );
    }
  }

  void _seekBackward() => _seekRelative(-10);

  void _seekForward() => _seekRelative(10);

  Widget _buildLayout(BuildContext context, BoxConstraints constraints) => SingleChildScrollView(
    child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: constraints.maxHeight),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          MobilePlayerHeader(
            title: title,
            episodeNumber: episodeNumber,
            onBack: onBack,
            onRotate: onRotate,
            tools: MobilePlayerTools(
              session: session,
              onSelectEpisode: onSelectEpisode,
              onSelectQuality: onSelectQuality,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: MobilePlayerTransport(
              playing: value.isPlaying,
              onPlayPause: onPlayPause,
              onRewind: _seekBackward,
              onForward: _seekForward,
            ),
          ),
          MobilePlayerFooter(
            value: value,
            onSeek: onSeek,
            onPreviousEpisode: onPreviousEpisode,
            onNextEpisode: onNextEpisode,
            onInteractionStart: onInteractionStart,
            onInteractionEnd: onInteractionEnd,
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppPalette.playerShadeTop, Colors.transparent, Colors.transparent, AppPalette.playerShadeBottom],
        stops: [0, 0.32, 0.54, 1],
      ),
    ),
    child: SafeArea(
      minimum: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: LayoutBuilder(builder: _buildLayout),
    ),
  );
}
