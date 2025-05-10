import 'dart:async';

import 'package:anistar_tv/packages/core/services/html_parser_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

    _initializePlayer();

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

  // Removed _loadVideo method as VideoModel is passed directly

  Future<HeadlessInAppWebView> _initializePlayer() async {
    final service = context.read<HtmlParserService>();
    await service.navigate('https://v7.astar.bz/${widget.videoUrl}');

    return service.getWebView();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<HeadlessInAppWebView>(
        future: _initializePlayer(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            return InAppWebView(headlessWebView: snapshot.data);
          }
        },
      ),
    );
  }
}
