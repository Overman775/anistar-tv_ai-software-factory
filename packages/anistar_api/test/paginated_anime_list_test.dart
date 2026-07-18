import 'package:test/test.dart';
import 'package:anistar_api/anistar_api.dart';

// tests for PaginatedAnimeList
void main() {
  final instance = PaginatedAnimeListBuilder();
  // TODO add properties to the builder and call build()

  group(PaginatedAnimeList, () {
    // BuiltList<AnimeListItem> items
    test('to test the property `items`', () async {
      // TODO
    });

    // Current page number
    // int currentPage
    test('to test the property `currentPage`', () async {
      // TODO
    });

    // Whether next page exists
    // bool hasNext
    test('to test the property `hasNext`', () async {
      // TODO
    });

    // Whether previous page exists
    // bool hasPrev
    test('to test the property `hasPrev`', () async {
      // TODO
    });
  });
}
