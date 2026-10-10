import 'dart:async';

import 'support/test_bootstrap.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) => runTestSuite(testMain);
