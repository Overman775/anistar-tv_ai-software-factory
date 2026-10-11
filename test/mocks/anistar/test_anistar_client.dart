import 'package:anistar/anistar.dart';
import 'package:anistar/html.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/memory_secure_storage.dart';

/// Fixture transport with an isolated session; tests may supply their own.
AnistarClient createTestAnistarClient(Dio dio, {AnistarSession? session}) {
  final clientSession = session ?? AnistarSession(Uri.parse(dio.options.baseUrl), MemorySecureStorage());
  if (session == null) {
    addTearDown(clientSession.close);
  }

  return HtmlAnistarClient(dio, clientSession);
}
