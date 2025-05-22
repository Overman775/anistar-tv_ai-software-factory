import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

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
  @override
  void initState() {
    super.initState();

    // Configure system UI for fullscreen video
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [], // Hide all system overlays for fullscreen
    );
  }

  @override
  void dispose() {
    // Restore system UI when leaving the player
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri('https://v7.astar.bz/${widget.videoUrl}')),
        headlessWebView: HeadlessInAppWebView(
          findInteractionController: FindInteractionController(),
          initialSettings: InAppWebViewSettings(
            mediaPlaybackRequiresUserGesture: true,
            allowsInlineMediaPlayback: true,
          ),
        ),
      ),
    );
  }
}
