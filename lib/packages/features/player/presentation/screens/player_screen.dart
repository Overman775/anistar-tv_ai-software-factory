import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

// Remove VideoModel import
// import '../../../video_list/domain/models/video_model.dart';
import '../widgets/player_controls.dart';

/// Screen for playing videos
class PlayerScreen extends StatefulWidget {
  // Remove video model field
  // final VideoModel video;
  // Add title and videoUrl fields
  final String title;
  final String videoUrl;

  /// Constructor
  const PlayerScreen({
    super.key,
    // Remove video parameter
    // required this.video,
    // Add title and videoUrl parameters
    required this.title,
    required this.videoUrl,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _controller;
  bool _isControlsVisible = true;
  bool _isPlaying = false;
  // VideoModel is now passed via widget.video
  // late VideoModel _video;
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();

    // Initialize video controller directly
    _initializePlayer();

    // Configure system UI for fullscreen video
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [], // Hide all system overlays for fullscreen
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controlsTimer?.cancel();

    // Restore system UI when leaving the player
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);

    super.dispose();
  }

  // Removed _loadVideo method as VideoModel is passed directly

  Future<void> _initializePlayer() async {
    // Initialize the video player using the passed videoUrl
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isPlaying = true; // Start playing automatically
          _controller!.play();
        });
        // Auto-hide controls after 5 seconds
        _startControlsTimer();
        // Listen to player state changes
        _controller!.addListener(_onVideoStateChanged);
      }
    } catch (e) {
      if (mounted) {
        // Show error and potentially navigate back or show retry option
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error initializing video: ${e.toString()}')));
        // Optionally navigate back if initialization fails critically
        // context.pop();
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
                  // Pass title instead of video object
                  title: widget.title,
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
