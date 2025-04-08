import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../../../../app/app_routes.dart';
import '../../../video_list/domain/models/video_model.dart';
import '../widgets/player_controls.dart';

/// Screen for playing videos
class PlayerScreen extends StatefulWidget {
  /// ID of the video to play
  final String videoId;

  /// Constructor
  const PlayerScreen({super.key, required this.videoId});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _controller;
  bool _isControlsVisible = true;
  bool _isPlaying = false;
  late VideoModel _video;
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();

    // Configure system UI for fullscreen video
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [], // Hide all system overlays for fullscreen
    );

    // Load the video after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVideo();
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controlsTimer?.cancel();

    // Restore system UI when leaving the player
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);

    super.dispose();
  }

  Future<void> _loadVideo() async {
    final videoService = Provider.of<VideoService>(context, listen: false);
    final video = videoService.getVideoById(widget.videoId);

    if (video == null) {
      // Video not found, go back to home
      if (mounted) {
        context.go(AppRoutes.home);
      }
      return;
    }

    _video = video;

    // Initialize the video player
    _controller = VideoPlayerController.networkUrl(Uri.parse(video.videoUrl));

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isPlaying = true;
          _controller!.play();
        });
      }

      // Auto-hide controls after 5 seconds
      _startControlsTimer();

      // Listen to player state changes
      _controller!.addListener(_onVideoStateChanged);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading video: $e')));
      }
    }
  }

  void _onVideoStateChanged() {
    if (_controller == null) return;

    final isPlaying = _controller!.value.isPlaying;
    if (isPlaying != _isPlaying) {
      setState(() {
        _isPlaying = isPlaying;
      });
    }

    // Show controls when video ends
    if (_controller!.value.position >= _controller!.value.duration) {
      _showControls();
    }
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _isPlaying) {
        setState(() {
          _isControlsVisible = false;
        });
      }
    });
  }

  void _showControls() {
    setState(() {
      _isControlsVisible = true;
    });
    _startControlsTimer();
  }

  void _togglePlayPause() {
    if (_controller == null) return;

    setState(() {
      if (_isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
      _isPlaying = !_isPlaying;
    });

    _showControls();
  }

  void _seekBackward() {
    if (_controller == null) return;

    final newPosition = _controller!.value.position - const Duration(seconds: 10);
    _controller!.seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
    _showControls();
  }

  void _seekForward() {
    if (_controller == null) return;

    final newPosition = _controller!.value.position + const Duration(seconds: 10);
    final duration = _controller!.value.duration;
    _controller!.seekTo(newPosition > duration ? duration : newPosition);
    _showControls();
  }

  void _toggleFavorite() {
    _showControls();
  }

  void _back() {
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: RawKeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKey: _handleKeyEvent,
        child: GestureDetector(
          onTap: _showControls,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video player
              Center(
                child:
                    _controller?.value.isInitialized ?? false
                        ? AspectRatio(aspectRatio: _controller!.value.aspectRatio, child: VideoPlayer(_controller!))
                        : const CircularProgressIndicator(),
              ),

              // Controls overlay
              if (_isControlsVisible)
                PlayerControls(
                  video: _video,
                  controller: _controller,
                  isPlaying: _isPlaying,
                  onPlayPause: _togglePlayPause,
                  onSeekBackward: _seekBackward,
                  onSeekForward: _seekForward,
                  onToggleFavorite: _toggleFavorite,
                  onBack: () => _back(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      _togglePlayPause();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _seekBackward();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _seekForward();
    } else if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.backspace ||
        event.logicalKey == LogicalKeyboardKey.goBack ||
        event.logicalKey == LogicalKeyboardKey.browserBack) {
      _back();
    } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
      _toggleFavorite();
    } else {
      _showControls();
    }
  }
}
