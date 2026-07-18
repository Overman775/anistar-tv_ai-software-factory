import 'package:test/test.dart';
import 'package:anistar_api/anistar_api.dart';

/// tests for HealthApi
void main() {
  final instance = AnistarApi().getHealthApi();

  group(HealthApi, () {
    // Check process liveness
    //
    // Does not contact AniStar. Use this endpoint for container health checks.
    //
    //Future<LivenessResponse> getLiveness() async
    test('test getLiveness', () async {
      // TODO
    });

    // Check AniStar readiness
    //
    // Returns HTTP 503 when the upstream dependency is unavailable.
    //
    //Future<ReadinessResponse> getReadiness() async
    test('test getReadiness', () async {
      // TODO
    });
  });
}
