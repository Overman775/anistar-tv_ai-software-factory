/// Shared application primitives that are independent from a feature UI.
///
/// Features may depend on this public surface, but must not depend on another
/// feature's data or presentation layer.
library;

export 'api/anistar_api_config.dart';
export 'data/base_repository.dart';
export 'domain/either.dart';
export 'domain/failure.dart';
export 'network/dio_client.dart';
export 'network/http_client.dart';
export 'network/network_config.dart';
export 'services/secure_storage.dart';
export 'services/shared_preferences_storage.dart';
