import 'dart:async';

import 'package:anistar/anistar.dart';
import 'package:anistar/html.dart';
import 'package:app_logging/app_logging.dart';
import 'package:core/data.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:networking/networking.dart';

import '../../mocks/anistar/search_fixture_adapter.dart';
import '../../mocks/storage/memory_secure_storage.dart';

void main() {
  final clientError = throwsA(isA<AnistarClientException>());
  final origin = Uri.parse('https://search.test/');
  late MemorySecureStorage storage;
  late AnistarSession session;
  late SearchFixtureAdapter adapter;
  late Dio dio;
  late AnistarClient client;

  setUp(() {
    storage = MemorySecureStorage();
    session = AnistarSession(origin, storage);
    adapter = SearchFixtureAdapter();
    dio = DioClient.create(
      config: NetworkConfig(baseUri: origin),
      logger: Logger(level: Level.off),
    )..httpClientAdapter = adapter;
    DioClient.addInterceptors(dio, [AnistarSessionInterceptor(session)]);
    client = HtmlAnistarClient(dio, session);
  });
  tearDown(() async {
    dio.close(force: true);
    await session.close();
  });

  test('Cyrillic uses the form charset, shared card normalization and confirmed POST pagination', () async {
    final first = await client.search('Наруто');
    final second = await client.search('Наруто', page: 2);
    expect(first.items.map((item) => item.id), [1, 2]);
    expect(first.hasNext, isTrue);
    expect(second.items.map((item) => item.id), [2, 3]);
    expect(second.page, 2);
    expect(second.hasNext, isFalse);
    final requests = adapter.requests;
    expect(requests.map((request) => request.method), ['GET', 'POST', 'POST']);
    expect(requests[1].data.toString(), contains('story=%CD%E0%F0%F3%F2%EE'));
    expect(requests[1].headers['Content-Type'], contains('windows-1251'));
    final continuation = requests.last;
    final continuationUri = continuation.uri;
    final continuationBody = continuation.data.toString();
    expect(continuationUri.path, '/index.php');
    expect(continuationUri.query, 'do=search');
    expect(continuationBody, contains('search_start=2'));
    expect(continuationBody, contains('result_from=11'));
    expect(continuationBody, contains('full_search=0'));
    expect(requests.every((request) => !request.uri.path.endsWith('.html')), isTrue);
    expect(first.items.clear, throwsUnsupportedError);
  });

  test('blank search is local, short queries are rejected, and unrepresentable text never reaches POST', () async {
    expect((await client.search('   ')).items, isEmpty);
    await expectLater(client.search('abc'), clientError);
    expect(adapter.requests, isEmpty);
    await expectLater(client.search('🙂🙂🙂🙂'), clientError);
    expect(adapter.requests.map((request) => request.method), ['GET']);
  });

  for (final body in [
    '<div class="berrors">Введите не менее 4 символов</div>',
    '<div id="dle-content"></div>',
    '<html>Unknown protection response</html>',
  ]) {
    test('unconfirmed empty or invalid markup remains failure: ${body.length}', () async {
      adapter = SearchFixtureAdapter(
        respond: (request) async => SearchFixtureAdapter.response(request.method == 'GET' ? searchHomeForm : body),
      );
      dio.httpClientAdapter = adapter;
      await expectLater(client.search('Наруто'), clientError);
    });
  }

  test('only the explicit site no-results marker is a successful empty page', () async {
    adapter = SearchFixtureAdapter(
      respond: (request) async => SearchFixtureAdapter.response(
        request.method == 'GET'
            ? searchHomeForm
            : '<div class="berrors">К сожалению, поиск по сайту не дал никаких результатов.</div>',
      ),
    );
    dio.httpClientAdapter = adapter;
    final result = await client.search('Наруто');
    expect(result.items, isEmpty);
    expect(result.hasNext, isFalse);
  });

  for (final replacement in [
    'action="https://foreign.test/"',
    'action="http://search.test/"',
    'action="https://user@search.test/"',
    'action="javascript:alert(1)"',
  ]) {
    test('unsafe form action never receives the query: $replacement', () async {
      adapter.home = searchHomeForm.replaceFirst('action="/"', replacement);
      await expectLater(client.search('Наруто'), clientError);
      expect(adapter.requests.map((request) => request.method), ['GET']);
    });
  }

  test('unsupported form encoding and malformed pagination fail instead of guessing', () async {
    adapter.home = searchHomeForm.replaceFirst('windows-1251', 'shift-jis');
    await expectLater(client.search('Наруто'), clientError);
    adapter = SearchFixtureAdapter(
      respond: (request) async => SearchFixtureAdapter.response(
        request.method == 'GET'
            ? searchHomeForm
            : searchResultsHtml('Наруто').replaceFirst('list_submit(2); return false;', 'runUnknownCode(2)'),
      ),
    );
    dio.httpClientAdapter = adapter;
    // The second failure comes from malformed pagination rather than the earlier charset.
    await expectLater(client.search('Наруто'), clientError);
  });

  test('POST server failure has one attempt, and unconfirmed pages cannot be requested', () async {
    adapter.postStatus = 503;
    await expectLater(client.search('Наруто'), clientError);
    expect(adapter.requests.where((request) => request.method == 'POST'), hasLength(1));
    final count = adapter.requests.length;
    await expectLater(client.search('Наруто', page: 3), clientError);
    expect(adapter.requests, hasLength(count));
  });

  test(
    'a cancelled guest login preserves loaded search continuation while real account transitions invalidate it',
    () async {
      await client.search('Наруто');
      final oldAccess = session.accessGeneration;
      final httpGeneration = session.generation;
      await session.cancelAuthentication(httpGeneration);
      expect(session.accessGeneration, oldAccess);
      expect((await client.search('Наруто', page: 2)).items, isNotEmpty);
      await client.search('Наруто');
      await client.signIn('viewer', 'fixture-password');
      expect(session.accessGeneration, isNot(oldAccess));
      await expectLater(client.search('Наруто', page: 2), clientError);
      await client.search('Наруто');
      await client.signOut();
      // Logout must invalidate a freshly loaded continuation as account login did above.
      await expectLater(client.search('Наруто', page: 2), clientError);
      expect(storage.values, isEmpty);
    },
  );

  test('cancel stops an in-flight transport and late responses cannot restore its continuation', () async {
    final response = Completer<ResponseBody>();
    final arrived = Completer<void>();
    adapter = SearchFixtureAdapter(
      respond: (request) async {
        if (request.method == 'GET') {
          return SearchFixtureAdapter.response(searchHomeForm);
        }
        arrived.complete();

        return response.future;
      },
    );
    dio.httpClientAdapter = adapter;
    final cancellation = RequestCancellation();
    final pending = client.search('Наруто', cancellation: cancellation);
    final rejected = expectLater(pending, clientError);
    await arrived.future;
    cancellation.cancel();
    response.complete(SearchFixtureAdapter.response(searchResultsHtml('Наруто')));
    await rejected;
    await expectLater(client.search('Наруто', page: 2), clientError);
  });
}
