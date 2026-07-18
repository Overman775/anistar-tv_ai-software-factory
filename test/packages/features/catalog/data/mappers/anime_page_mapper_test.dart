import 'package:anistar_tv/packages/features/catalog/data/mappers/anime_page_mapper.dart';
import 'package:api/api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps pagination metadata and a catalog DTO into domain data', () {
    const dto = PaginatedAnimeListDto(
      currentPage: 3,
      hasNext: true,
      hasPrev: true,
      items: [
        AnimeListItemDto(
          id: 17,
          slug: '17-test-title',
          title: 'Тестовое аниме',
          posterUrl: ' https://images.test/poster.jpg ',
          year: '2026',
        ),
      ],
    );

    final page = dto.toDomain();
    final item = page.items.single;

    expect(page.page, 3);
    expect(page.hasNext, isTrue);
    expect(item.title, 'Тестовое аниме');
    expect(item.posterUri, Uri.parse('https://images.test/poster.jpg'));
  });
}
