import 'package:anistar_tv/packages/core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Right exposes a successful value and runs the right branch', () {
    const result = Either<String, int>.right(42);

    expect(result.rightOrNull, 42);
    expect(result.fold(onLeft: (value) => 'failure: $value', onRight: (value) => 'value: $value'), 'value: 42');
  });

  test('Left hides the successful value and runs the left branch', () {
    const result = Either<String, int>.left('offline');

    expect(result.rightOrNull, isNull);
    expect(result.fold(onLeft: (value) => 'failure: $value', onRight: (value) => 'value: $value'), 'failure: offline');
  });

  test('Failure renders its user-facing message', () {
    const failure = ConnectionFailure();

    expect(failure.toString(), 'Не удалось подключиться к серверу.');
  });
}
