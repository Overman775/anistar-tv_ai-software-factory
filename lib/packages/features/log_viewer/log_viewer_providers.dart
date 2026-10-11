import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/repositories/log_repository.dart';

final logRepositoryProvider = Provider<LogRepository>(
  (ref) => throw StateError('LogRepository must be supplied by the application.'),
);
