import 'package:core/data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('success exposes the value and executes only the success branch', () {
    const result = Result<int, Failure>.success(42);

    expect(result.successOrNull, 42);
    expect(result.isSuccess, isTrue);
    expect(result.isFailure, isFalse);
    expect(result.failureOrNull, isNull);
    expect(result.when(failure: (value) => 'failure: $value', success: (value) => 'value: $value'), 'value: 42');
  });

  test('failure preserves the typed error and executes only the failure branch', () {
    const failure = UnknownFailure();
    const result = Result<int, Failure>.failure(failure);

    expect(result.successOrNull, isNull);
    expect(result.isFailure, isTrue);
    final originalFailure = same(failure);
    expect(result.failureOrNull, originalFailure);
    expect(result.when(failure: (value) => value, success: (_) => fail('Unexpected success')), originalFailure);
  });

  test('Failure renders its user-facing message', () {
    const failure = UnknownFailure();

    expect(failure.toString(), 'Не удалось выполнить запрос.');
  });

  test('a nullable successful value is distinct from a failure', () {
    const result = Result<String?, Failure>.success(null);
    expect(result.successOrNull, isNull);
    expect(result.isSuccess, isTrue);
    expect(result.when(success: (_) => 'success', failure: (_) => 'failure'), 'success');
  });
}
