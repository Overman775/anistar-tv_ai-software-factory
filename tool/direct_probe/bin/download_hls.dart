import 'dart:convert';
import 'dart:io';

import 'package:anistar_direct_probe/anistar_direct.dart';
import 'package:http/http.dart' as http;

/// Full 360p VOD download for the specific unencrypted MPEG-TS sample.
/// This is an experiment, not a general master-playlist/encryption downloader.
Future<void> main(List<String> args) async {
  final directory = Directory(
    args.isEmpty ? '/tmp/anistar-direct-probe/offline-hls' : args.first,
  );
  await directory.create(recursive: true);
  final client = http.Client();
  final api = DirectAnistar(client);
  try {
    final episodes = await api.episodes(10938);
    final uri = episodes.first.sources['files']!['360']!;
    final response = await api.get(uri, headers: api.videoHeaders(10938));
    requireSuccess(response);
    final text = utf8.decode(response.bodyBytes);
    if (!isHls(response) ||
        !text.contains('#EXT-X-ENDLIST') ||
        text.contains('#EXT-X-STREAM-INF') ||
        text.contains('#EXT-X-KEY') ||
        text.contains('#EXT-X-MAP') ||
        text.contains('#EXT-X-BYTERANGE')) {
      throw const FormatException(
        'Experiment only supports complete unencrypted TS media playlists',
      );
    }
    final lines = const LineSplitter().convert(text);
    final resources = <({Uri uri, String name})>[];
    final local = <String>[];
    for (final line in lines) {
      if (line.trim().isEmpty || line.startsWith('#')) {
        local.add(line);
      } else {
        final name = 'segment${resources.length}.ts';
        resources.add((uri: uri.resolve(line.trim()), name: name));
        local.add(name);
      }
    }
    var bytes = 0;
    for (var i = 0; i < resources.length; i += 4) {
      final batch = resources.skip(i).take(4);
      final sizes = await Future.wait(
        batch.map((resource) async {
          final segment = await api.get(
            resource.uri,
            headers: api.videoHeaders(10938),
          );
          requireSuccess(segment);
          if (segment.bodyBytes.isEmpty || segment.bodyBytes.first != 0x47)
            throw const FormatException('Non-TS segment');
          await File(
            '${directory.path}/${resource.name}',
          ).writeAsBytes(segment.bodyBytes);
          return segment.bodyBytes.length;
        }),
      );
      bytes += sizes.fold(0, (sum, size) => sum + size);
    }
    await File(
      '${directory.path}/offline.m3u8',
    ).writeAsString('${local.join('\n')}\n');
    stdout.writeln(
      jsonEncode({
        'segments': resources.length,
        'bytes': bytes,
        'localUrisOnly': true,
        'completeEpisode': true,
      }),
    );
  } finally {
    client.close();
  }
}
