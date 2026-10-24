import 'package:anistar_tv/packages/features/common/presentation/rating_presentation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats valid rating once for visual and semantic consumers', () {
    final rating = RatingPresentation.from(8.25);

    expect(rating?.label, '8,3');
    expect(rating?.semanticLabel, 'Рейтинг 8,3 из 10');
  });

  test('rejects absent, non-finite and out-of-range server ratings', () {
    for (final value in [null, double.nan, double.infinity, -0.1, 10.1]) {
      expect(RatingPresentation.from(value), isNull, reason: '$value');
    }
    expect(RatingPresentation.from(0)?.label, '0,0');
    expect(RatingPresentation.from(10)?.label, '10,0');
  });
}
