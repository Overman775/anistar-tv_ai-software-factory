import 'package:app_logging/providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dio_client.dart';
import 'network_config.dart';

final networkConfigProvider = Provider<NetworkConfig>(
  (ref) => throw StateError('NetworkConfig must be supplied by the application.'),
);

final dioProvider = Provider<Dio>((ref) {
  final dio = DioClient.create(config: ref.watch(networkConfigProvider), logger: ref.watch(loggerProvider));
  ref.onDispose(() => dio.close(force: true));

  return dio;
});
