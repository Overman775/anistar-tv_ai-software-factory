import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:networking/providers.dart';
import 'package:storage/providers.dart';

import 'anistar_active_mirror.dart';
import 'anistar_auth_service.dart';
import 'anistar_mirror_interceptor.dart';
import 'anistar_session.dart';
import 'anistar_session_interceptor.dart';
import 'anistar_source.dart';

export 'anistar_active_mirror.dart' show anistarActiveMirrorProvider, anistarMirrorManagerProvider;

final anistarSessionProvider = Provider<AnistarSession>((ref) {
  final session = AnistarSession(ref.watch(networkConfigProvider).baseUri, ref.watch(secureStorageProvider));
  ref.onDispose(() => unawaited(session.close()));

  return session;
});

final anistarDioProvider = Provider<Dio>((ref) {
  final dio = ref.watch(dioProvider);
  final interceptor = AnistarSessionInterceptor(ref.watch(anistarSessionProvider));
  final manager = ref.watch(anistarMirrorManagerProvider);
  final mirrorInterceptor = manager == null ? null : AnistarMirrorInterceptor(manager);
  if (mirrorInterceptor != null) {
    dio.interceptors.add(mirrorInterceptor);
  }
  dio.interceptors.add(interceptor);
  ref.onDispose(() {
    dio.interceptors.remove(interceptor);
    if (mirrorInterceptor != null) {
      dio.interceptors.remove(mirrorInterceptor);
    }
  });

  return dio;
});

final anistarAuthServiceProvider = Provider<AnistarAuthService>(
  (ref) => AnistarAuthService(
    ref.watch(anistarDioProvider),
    ref.watch(anistarSessionProvider),
    ensureMirror: ref.watch(anistarMirrorManagerProvider)?.ensureAvailable,
  ),
);

final anistarSourceProvider = Provider<AnistarSource>((ref) => AnistarSource(ref.watch(anistarDioProvider)));
