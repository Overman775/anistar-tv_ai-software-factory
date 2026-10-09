import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:anistar_direct_probe/anistar_direct.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

/// Copy to lib/main.dart of an isolated Flutter app; see the research report.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: ProbeScreen()));
}

class ProbeScreen extends StatefulWidget {
  const ProbeScreen({super.key});
  @override
  State<ProbeScreen> createState() => _ProbeScreenState();
}

class _ProbeScreenState extends State<ProbeScreen> {
  VideoPlayerController? controller;
  final results = <Map<String, Object?>>[];

  @override
  void initState() {
    super.initState();
    unawaited(run());
  }

  Future<void> run() async {
    final client = http.Client();
    final api = DirectAnistar(client);
    try {
      final pages = await api.catalog(1);
      final detail = await api.detail(
        pages.singleWhere((item) => item.id == 10938),
      );
      final episodes = await api.episodes(10938);
      record({
        'step': 'metadata',
        'cards': pages.length,
        'title': detail['title'],
        'episodes': episodes.length,
      });
      if (const bool.fromEnvironment('OFFLINE_ONLY')) {
        await offline(api, episodes);
        record({'step': 'done', 'platform': Platform.operatingSystem});
        return;
      }
      if (const bool.fromEnvironment('FORMAT_HINT_ONLY')) {
        await playback(
          '720_without_format_hint',
          episodes.first.sources['files']!['720']!,
          1,
          '720',
          headers: api.videoHeaders(10938),
        );
        record({'step': 'done', 'platform': Platform.operatingSystem});
        return;
      }
      for (final number in [1, 2]) {
        for (final quality in ['360', '720']) {
          final uri = episodes
              .singleWhere((item) => item.number == number)
              .sources['files']![quality]!;
          await playback(
            'hls',
            uri,
            number,
            quality,
            headers: api.videoHeaders(10938),
            format: VideoFormat.hls,
          );
        }
      }
      await playback(
        'withoutReferer',
        episodes.first.sources['files']!['360']!,
        1,
        '360',
        format: VideoFormat.hls,
      );
      for (final quality in ['360', '720']) {
        await playback(
          'mp4',
          episodes.first.sources['files_mp4']![quality]!,
          1,
          quality,
          headers: api.videoHeaders(10938),
        );
      }
      record({'step': 'done', 'platform': Platform.operatingSystem});
    } on Object catch (error) {
      record({'step': 'fatal', 'error': redact(error.toString())});
    } finally {
      client.close();
    }
  }

  Future<void> playback(
    String kind,
    Uri uri,
    int episode,
    String quality, {
    Map<String, String> headers = const {},
    VideoFormat? format,
    VideoPlayerController? sourceController,
    int seekAt = 120,
  }) async {
    final player =
        sourceController ??
        VideoPlayerController.networkUrl(
          uri,
          httpHeaders: headers,
          formatHint: format,
        );
    final result = <String, Object?>{
      'step': kind,
      'episode': episode,
      'quality': quality,
      'platform': Platform.operatingSystem,
    };
    try {
      await player.initialize().timeout(const Duration(seconds: 40));
      controller = player;
      if (mounted) setState(() {});
      result['durationMs'] = player.value.duration.inMilliseconds;
      result['width'] = player.value.size.width;
      result['height'] = player.value.size.height;
      await player.play();
      await Future<void>.delayed(const Duration(seconds: 4));
      result['startPositionMs'] = player.value.position.inMilliseconds;
      result['startOk'] =
          player.value.position > const Duration(seconds: 1) &&
          !player.value.hasError;
      await player.seekTo(Duration(seconds: seekAt));
      await Future<void>.delayed(const Duration(seconds: 5));
      result['seekPositionMs'] = player.value.position.inMilliseconds;
      result['seekOk'] =
          player.value.position >= Duration(seconds: seekAt + 1) &&
          !player.value.hasError;
      if (player.value.hasError)
        result['error'] = redact(player.value.errorDescription ?? 'unknown');
    } on Object catch (error) {
      result['error'] = redact(error.toString());
    } finally {
      controller = null;
      await player.dispose();
      record(result);
    }
  }

  Future<void> offline(DirectAnistar api, List<DirectEpisode> episodes) async {
    final directory = await Directory.systemTemp.createTemp('anistar-offline-');
    final mp4 = File('${directory.path}/episode.mp4');
    final request = http.Request(
      'GET',
      episodes.first.sources['files_mp4']!['360']!,
    )..headers.addAll(api.videoHeaders(10938));
    final download = await api.client
        .send(request)
        .timeout(const Duration(seconds: 25));
    if (download.statusCode != 200)
      throw StateError('Download HTTP ${download.statusCode}');
    final sink = mp4.openWrite();
    try {
      await sink.addStream(
        download.stream.timeout(const Duration(seconds: 25)),
      );
    } finally {
      await sink.close();
    }
    record({
      'step': 'download_mp4',
      'bytes': await mp4.length(),
      'expectedBytes': download.contentLength,
    });
    await playback(
      'offline_mp4',
      mp4.uri,
      1,
      '360',
      sourceController: VideoPlayerController.file(mp4),
    );

    final manifest = episodes.first.sources['files']!['360']!;
    final response = await api.get(manifest, headers: api.videoHeaders(10938));
    final lines = const LineSplitter().convert(utf8.decode(response.bodyBytes));
    final localLines = <String>[];
    var count = 0;
    var bytes = 0;
    for (final line in lines) {
      if (line.isEmpty || line.startsWith('#')) {
        localLines.add(line);
        continue;
      }
      final segment = await api.get(
        manifest.resolve(line),
        headers: api.videoHeaders(10938),
      );
      requireSuccess(segment);
      final filename = 'segment$count.ts';
      await File('${directory.path}/$filename').writeAsBytes(segment.bodyBytes);
      bytes += segment.bodyBytes.length;
      localLines.add(filename);
      if (++count == 3) break;
    }
    localLines.add('#EXT-X-ENDLIST');
    final localManifest = File('${directory.path}/offline.m3u8');
    await localManifest.writeAsString(localLines.join('\n'));
    record({
      'step': 'download_hls_excerpt',
      'segments': count,
      'bytes': bytes,
      'durationSeconds': 30,
    });
    await playback(
      'offline_hls_file',
      localManifest.uri,
      1,
      '360',
      sourceController: VideoPlayerController.file(localManifest),
      seekAt: 15,
    );

    // All media served here is on this device. No upstream network requests.
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var localRequests = 0;
    final subscription = server.listen((request) async {
      localRequests++;
      final name = request.uri.pathSegments.last;
      if (!RegExp(r'^(offline\.m3u8|segment[0-2]\.ts)$').hasMatch(name)) {
        request.response.statusCode = 404;
      } else {
        final file = File('${directory.path}/$name');
        request.response.headers.set(
          HttpHeaders.contentTypeHeader,
          name.endsWith('.m3u8')
              ? 'application/vnd.apple.mpegurl'
              : 'video/mp2t',
        );
        request.response.contentLength = await file.length();
        await request.response.addStream(file.openRead());
      }
      await request.response.close();
    });
    try {
      await playback(
        'offline_hls_device_server',
        Uri.parse('http://127.0.0.1:${server.port}/offline.m3u8'),
        1,
        '360',
        format: VideoFormat.hls,
        seekAt: 15,
      );
      record({
        'step': 'local_server',
        'requests': localRequests,
        'upstreamRequestsDuringPlayback': 0,
      });
    } finally {
      await server.close(force: true);
      await subscription.cancel();
      await directory.delete(recursive: true);
    }
  }

  String redact(String value) =>
      value.replaceAll(RegExp(r'https?://[^\s,)]+'), '<redacted-url>');

  void record(Map<String, Object?> result) {
    results.add(result);
    // Machine-readable research output in the Flutter runner log.
    debugPrint('ANISTAR_PROBE ${jsonEncode(result)}');
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    unawaited(controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        if (controller != null && controller!.value.isInitialized)
          SizedBox(height: 250, child: VideoPlayer(controller!)),
        Expanded(
          child: SingleChildScrollView(
            child: Text(const JsonEncoder.withIndent('  ').convert(results)),
          ),
        ),
      ],
    ),
  );
}
