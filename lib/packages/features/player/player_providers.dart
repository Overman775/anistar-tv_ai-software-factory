import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/repositories/playback_repository.dart';

final playbackRepositoryProvider = Provider<PlaybackRepository>(
  (ref) => throw StateError('PlaybackRepository must be supplied by the application.'),
);
