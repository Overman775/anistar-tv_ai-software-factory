import 'package:anistar/anistar.dart';
import 'package:anistar_tv/packages/features/search/data/anistar_search_repository.dart';
import 'package:core/data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:networking/networking.dart';

import '../../../../mocks/anistar/fake_anistar_client.dart';

void main() {
  test('forwards a search request and maps a matching response page', () async {
    final client = FakeAnistarClient()
      ..pageResult = AnistarCatalogPageDto(
        page: 3,
        hasNext: true,
        items: const [AnistarAnimeSummaryDto(id: 7, slug: 'seven', title: 'Seven')],
      );
    final cancellation = RequestCancellation();
    final result = await AnistarSearchRepository(client).search('seven', page: 3, cancellation: cancellation);
    final page = result.when(failure: (failure) => fail(failure.message), success: (value) => value);

    expect(client.calls, ['search']);
    expect((client.lastSearchQuery, client.lastSearchPage), ('seven', 3));
    expect(client.lastSearchCancellation, same(cancellation));
    expect((page.page, page.hasNext, page.items.single.id), (3, true, 7));
  });

  test('preserves an empty successful search response', () async {
    final client = FakeAnistarClient()..pageResult = AnistarCatalogPageDto(items: const [], page: 2, hasNext: false);
    final result = await AnistarSearchRepository(client).search('empty', page: 2);

    expect(result.when(failure: (failure) => fail(failure.message), success: (page) => page.items), isEmpty);
  });

  test('rejects a response page that does not match the requested page', () async {
    final client = FakeAnistarClient()..pageResult = AnistarCatalogPageDto(items: const [], page: 4, hasNext: false);
    final result = await AnistarSearchRepository(client).search('mismatch', page: 2);

    expect(result.failureOrNull, isA<RequestFailure>());
    expect(result.failureOrNull?.message, 'Номер страницы ответа не соответствует запросу.');
  });

  test('maps expected client errors and keeps unexpected errors unknown', () async {
    final timeoutClient = FakeAnistarClient()
      ..error = const AnistarClientException(AnistarClientErrorCategory.timeout, 'timeout');
    final unexpectedClient = FakeAnistarClient()..error = StateError('programming error');

    expect((await AnistarSearchRepository(timeoutClient).search('timeout')).failureOrNull, isA<TimeoutFailure>());
    expect((await AnistarSearchRepository(unexpectedClient).search('unexpected')).failureOrNull, isA<UnknownFailure>());
  });
}
