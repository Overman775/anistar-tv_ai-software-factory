import 'dart:convert';
import 'dart:io';

import 'package:anistar_direct_probe/anistar_direct.dart';
import 'package:http/http.dart' as http;

Future<void> main(List<String> args) async {
  final directory = Directory(
    args.isEmpty ? '/tmp/anistar-direct-probe' : args.first,
  )..createSync(recursive: true);
  final client = http.Client();
  final api = DirectAnistar(client);
  final report = <String, Object?>{
    'checkedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'animeId': 10938,
  };
  final privateUrls = <String, String>{};
  try {
    final pages = await Future.wait([api.catalog(1), api.catalog(2)]);
    report['catalog'] = pages
        .map(
          (page) => {
            'count': page.length,
            'firstId': page.first.id,
            'adExcluded': page.every((item) => item.id != 9493),
          },
        )
        .toList();
    final entry = pages.first.singleWhere((item) => item.id == 10938);
    report['detail'] = await api.detail(entry);
    final episodes = await api.episodes(10938);
    report['episodes'] = {
      'count': episodes.length,
      'numbers': episodes.map((item) => item.number).toList(),
      'qualities': episodes.first.sources.map(
        (name, values) => MapEntry(name, values.keys.toList()),
      ),
    };
    final probes = <Map<String, Object?>>[];
    for (final number in [1, 2]) {
      final episode = episodes.singleWhere((item) => item.number == number);
      for (final quality in ['360', '720']) {
        final uri = episode.sources['files']![quality]!;
        privateUrls['episode${number}_$quality'] = uri.toString();
        final response = await api.get(uri, headers: api.videoHeaders(10938));
        final result = <String, Object?>{
          'episode': number,
          'quality': quality,
          ...describe(response),
          'hls': isHls(response),
          'urlEndsInMp4': uri.path.endsWith('.mp4'),
        };
        if (isHls(response)) {
          await File(
            '${directory.path}/episode${number}_$quality.m3u8',
          ).writeAsBytes(response.bodyBytes);
          var lines = mediaLines(response, uri);
          // Follow a child playlist if the root is a master playlist.
          if (utf8.decode(response.bodyBytes).contains('#EXT-X-STREAM-INF')) {
            final child = lines.first;
            final nested = await api.get(
              child,
              headers: api.videoHeaders(10938),
            );
            result['child'] = describe(nested);
            lines = mediaLines(nested, child);
          }
          result['resourceCount'] = lines.length;
          result['hosts'] = lines.map((item) => item.host).toSet().toList();
          final selected = <Uri>{
            lines.first,
            lines[lines.length ~/ 2],
            lines.last,
          };
          for (final host in lines.map((item) => item.host).toSet()) {
            selected.add(lines.firstWhere((item) => item.host == host));
          }
          final segments = <Map<String, Object?>>[];
          for (final segment in selected) {
            final ranged = await api.get(
              segment,
              headers: {...api.videoHeaders(10938), 'Range': 'bytes=0-4095'},
            );
            segments.add({
              'host': segment.host,
              ...describe(ranged),
              'mpegTsSync':
                  ranged.bodyBytes.isNotEmpty && ranged.bodyBytes.first == 0x47,
            });
          }
          result['segments'] = segments;
          if (number == 1) {
            privateUrls['segment_$quality'] = lines.first.toString();
            result['withoutReferer'] = describe(
              await api.get(lines.first, headers: {'Range': 'bytes=0-4095'}),
            );
            result['webReferer'] = describe(
              await api.get(
                lines.first,
                headers: {
                  'Range': 'bytes=0-4095',
                  'Referer': 'http://127.0.0.1:8765/',
                  'Origin': 'http://127.0.0.1:8765',
                },
              ),
            );
            result['corsManifest'] = describe(
              await api.get(
                uri,
                headers: {
                  ...api.videoHeaders(10938),
                  'Origin': 'http://127.0.0.1:8765',
                },
              ),
            );
            final corsResources = <Map<String, Object?>>[];
            for (final host in lines.map((item) => item.host).toSet()) {
              final segment = lines.firstWhere((item) => item.host == host);
              privateUrls['segment_$host'] = segment.toString();
              corsResources.add({
                'host': host,
                ...describe(
                  await api.get(
                    segment,
                    headers: {
                      ...api.videoHeaders(10938),
                      'Range': 'bytes=0-4095',
                      'Origin': 'http://127.0.0.1:8765',
                    },
                  ),
                ),
              });
            }
            result['corsResources'] = corsResources;
          }
        }
        probes.add(result);
        stdout.writeln(jsonEncode({'hlsProbe': result}));
      }
    }
    report['hls'] = probes;
    final mp4 = <Map<String, Object?>>[];
    for (final quality in ['360', '720']) {
      final uri = episodes.first.sources['files_mp4']![quality]!;
      privateUrls['mp4_$quality'] = uri.toString();
      final response = await api.get(
        uri,
        headers: {...api.videoHeaders(10938), 'Range': 'bytes=0-4095'},
      );
      final isMp4 =
          response.bodyBytes.length >= 8 &&
          ascii.decode(response.bodyBytes.sublist(4, 8), allowInvalid: true) ==
              'ftyp';
      if (isMp4)
        await File(
          '${directory.path}/mp4_$quality.prefix',
        ).writeAsBytes(response.bodyBytes);
      mp4.add({
        'quality': quality,
        'host': uri.host,
        ...describe(response),
        'ftyp': isMp4,
      });
    }
    report['mp4'] = mp4;
    final good720 = episodes.first.sources['files']!['720']!;
    final invalid = Uri.parse(
      good720.toString().replaceFirst(RegExp(r'key=[^,]+'), 'key=invalid'),
    );
    final refreshed = await api.manifestWithRefresh(
      10938,
      1,
      '720',
      initial: invalid,
    );
    report['invalidKeyRefresh'] = {
      'refreshes': refreshed.refreshes,
      ...describe(refreshed.response),
      'hls': isHls(refreshed.response),
    };
    final signedEnd = RegExp(r'end=(\d+)').firstMatch(good720.toString());
    if (signedEnd != null)
      report['observedExpiryUtc'] = DateTime.fromMillisecondsSinceEpoch(
        int.parse(signedEnd[1]!) * 1000,
        isUtc: true,
      ).toIso8601String();
    final expired = Uri.parse(
      good720.toString().replaceFirst(RegExp(r'end=\d+'), 'end=1'),
    );
    final expiredResult = await api.manifestWithRefresh(
      10938,
      1,
      '720',
      initial: expired,
    );
    report['modifiedExpiryRefresh'] = {
      'refreshes': expiredResult.refreshes,
      ...describe(expiredResult.response),
      'hls': isHls(expiredResult.response),
      'note': 'Modified signed URL; not a naturally expired token',
    };
    final siteCors = await api.get(
      api.base.resolve('anime/'),
      headers: {'Origin': 'http://127.0.0.1:8765'},
    );
    report['siteCors'] = describe(siteCors);
    privateUrls['catalog'] = api.base.resolve('anime/').toString();
    privateUrls['player'] = api.playerUri(10938).toString();
    await File(
      '${directory.path}/private_urls.json',
    ).writeAsString(jsonEncode(privateUrls));
    await File(
      '${directory.path}/results.json',
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
  } finally {
    client.close();
  }
}

Map<String, Object?> describe(http.Response response) => {
  'status': response.statusCode,
  'type': response.headers['content-type'],
  'bytes': response.bodyBytes.length,
  'contentRange': response.headers['content-range'],
  'allowOrigin': response.headers['access-control-allow-origin'],
  'allowHeaders': response.headers['access-control-allow-headers'],
  'exposeHeaders': response.headers['access-control-expose-headers'],
};
