# anistar_api.api.HealthApi

## Load the API package
```dart
import 'package:anistar_api/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getLiveness**](HealthApi.md#getliveness) | **GET** /live | Check process liveness
[**getReadiness**](HealthApi.md#getreadiness) | **GET** /ready | Check AniStar readiness


# **getLiveness**
> LivenessResponse getLiveness()

Check process liveness

Does not contact AniStar. Use this endpoint for container health checks.

### Example
```dart
import 'package:anistar_api/api.dart';

final api = AnistarApi().getHealthApi();

try {
    final response = api.getLiveness();
    print(response);
} on DioException catch (e) {
    print('Exception when calling HealthApi->getLiveness: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**LivenessResponse**](LivenessResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getReadiness**
> ReadinessResponse getReadiness()

Check AniStar readiness

Returns HTTP 503 when the upstream dependency is unavailable.

### Example
```dart
import 'package:anistar_api/api.dart';

final api = AnistarApi().getHealthApi();

try {
    final response = api.getReadiness();
    print(response);
} on DioException catch (e) {
    print('Exception when calling HealthApi->getReadiness: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**ReadinessResponse**](ReadinessResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

