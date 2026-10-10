import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'anistar_mirror_config.dart';
import 'anistar_mirror_manager.dart';

final anistarMirrorManagerProvider = Provider<AnistarMirrorManager?>((ref) => null);

final anistarActiveMirrorProvider = NotifierProvider<AnistarActiveMirror, Uri>(AnistarActiveMirror.new);

final class AnistarActiveMirror extends Notifier<Uri> {
  @override
  Uri build() {
    final manager = ref.watch(anistarMirrorManagerProvider);
    if (manager == null) {
      return AnistarMirrorConfig.baseUri;
    }
    final subscription = manager.changes.listen((origin) => state = origin);
    ref.onDispose(() => unawaited(subscription.cancel()));

    return manager.current;
  }
}
