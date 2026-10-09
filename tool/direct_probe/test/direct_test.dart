import 'dart:convert';

import 'package:anistar_direct_probe/anistar_direct.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test(
    'JSON5 episode objects preserve quality and signed URLs regardless of order',
    () {
      const url =
          'https://sfv.an-media.org/key=a+b/c==,end=123/referer=/media=hls5/video/hash/720.mp4';
      final result = parseEpisodes('''var playlst = [
      { title: 'Серия 2', files: [{title:'720', file:'$url'}, {title:'360', file:'https://sf2.an-media.org/v/index.m3u8'}], files_as:[], files_mp4:[], },
      // nested brackets and a bracket inside a string
      { title: 'Серия 1', skip: [[1,2]], image: 'x]y', files: [], files_mp4: [], files_as: [] },
    ]; otherJavaScript();''');
      expect(result.map((episode) => episode.number), [2, 1]);
      expect(result.first.sources['files']!['720'].toString(), url);
      expect(result.first.sources['files']!['360']!.path, '/v/index.m3u8');
    },
  );

  test('catalog filters advertisement by ID, not position', () {
    final entries = parseCatalog('''
      <div class="news"><div class="title_left"><a href="/10938-real.html">Real</a></div></div>
      <div class="news"><div class="title_left"><a href="/9493-ad.html">Ad</a></div></div>
      <div class="news"><div class="title_left"><a href="/11048-next.html">Next</a></div></div>
    ''', Uri.parse('https://v30.astar.bz/'));
    expect(entries.map((entry) => entry.id), [10938, 11048]);
  });

  test('Windows-1251 and UTF-8 are decoded using Content-Type', () {
    expect(
      decodeHtml(
        http.Response.bytes(
          [0xcf, 0xf0, 0xe8, 0xe2, 0xe5, 0xf2],
          200,
          headers: {'content-type': 'text/html; charset=windows-1251'},
        ),
      ),
      'Привет',
    );
    expect(
      decodeHtml(
        http.Response.bytes(
          utf8.encode('Серия 1'),
          200,
          headers: {'content-type': 'text/html; charset=UTF-8'},
        ),
      ),
      'Серия 1',
    );
  });

  test('challenge is reported instead of an empty successful catalog', () {
    expect(
      () => parseCatalog(
        '<h1>Проверяем ваш браузер</h1>',
        Uri.parse('https://v30.astar.bz/'),
      ),
      throwsFormatException,
    );
    expect(
      () => parseEpisodes('<h1>Проверяем ваш браузер</h1>'),
      throwsFormatException,
    );
  });

  test(
    'relative and cross-domain HLS resources resolve against the manifest',
    () {
      final response = http.Response(
        '#EXTM3U\n#EXTINF:5,\nnext.ts\nhttps://cdn.example/last.ts\n',
        200,
      );
      expect(
        mediaLines(
          response,
          Uri.parse('https://sfv.an-media.org/key=x,video/v/720.mp4'),
        ).map((uri) => uri.toString()),
        [
          'https://sfv.an-media.org/key=x,video/v/next.ts',
          'https://cdn.example/last.ts',
        ],
      );
      expect(isHls(response), isTrue);
    },
  );

  test('persistent 403 makes exactly one refresh and no retry loop', () async {
    var pageRequests = 0;
    var mediaRequests = 0;
    final client = MockClient((request) async {
      if (request.url.host == 'v30.astar.bz') {
        pageRequests++;
        return http.Response(
          "var playlst=[{title:'Серия 1',files:[{title:'720',file:'https://sfv.an-media.org/fresh.mp4'}]}];",
          200,
          headers: {'content-type': 'text/html; charset=UTF-8'},
        );
      }
      mediaRequests++;
      expect(request.headers['Referer'], contains('id=10938'));
      return http.Response('Forbidden', 403);
    });
    addTearDown(client.close);
    final result = await DirectAnistar(client).manifestWithRefresh(
      10938,
      1,
      '720',
      initial: Uri.parse('https://sfv.an-media.org/expired.mp4'),
    );
    expect(result.response.statusCode, 403);
    expect(result.refreshes, 1);
    expect(pageRequests, 1);
    expect(mediaRequests, 2);
  });
}
