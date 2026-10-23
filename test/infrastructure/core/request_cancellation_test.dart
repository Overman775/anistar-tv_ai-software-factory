import 'package:core/data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cancel is synchronous and idempotent and removed observers are not called', () {
    final signal = RequestCancellation();
    final calls = <String>[];
    signal.onCancel(() => calls.add('active'));
    final remove = signal.onCancel(() => calls.add('removed'));
    remove();
    expect(signal.isCancelled, isFalse);
    signal
      ..cancel()
      ..cancel();
    expect(signal.isCancelled, isTrue);
    expect(calls, ['active']);
    signal.onCancel(() => calls.add('late'));
    expect(calls.last, 'late');
  });
}
