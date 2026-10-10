import 'package:app_logging/app_logging.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks/app_logging/capturing_log_output.dart';

void main() {
  test('adds the source type to a diagnostic message', () {
    final output = CapturingLogOutput();
    Logger.level = Level.all;
    addTearDown(() => Logger.level = Level.off);
    Logger(output: output).infoFor<TypedLoggerExtensionTest>('Session created');

    expect(output.messages, ['[TypedLoggerExtensionTest] Session created']);
  });
}

final class TypedLoggerExtensionTest {}
