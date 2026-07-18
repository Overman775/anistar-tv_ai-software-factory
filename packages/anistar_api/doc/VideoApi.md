# anistar_api.api.VideoApi

## Load the API package
```dart
import 'package:anistar_api/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getHlsManifest**](VideoApi.md#gethlsmanifest) | **GET** /api/video/{anime_id}/episodes/{episode_number}/manifest.m3u8 | Get a rewritten HLS manifest
[**getHlsResource**](VideoApi.md#gethlsresource) | **GET** /api/video/{anime_id}/episodes/{episode_number}/resources/{token} | Stream a signed HLS resource
[**getPlaybackInfo**](VideoApi.md#getplaybackinfo) | **GET** /api/video/{anime_id}/episodes/{episode_number}/playback | Get HLS playback information


# **getHlsManifest**
> String getHlsManifest(animeId, episodeNumber, quality)

Get a rewritten HLS manifest

Returns an HLS manifest whose resources use short-lived signed API paths.

### Example
```dart
import 'package:anistar_api/api.dart';

final api = AnistarApi().getVideoApi();
final int animeId = 56; // int | 
final int episodeNumber = 56; // int | 
final QualityType quality = ; // QualityType | Preferred quality

try {
    final response = api.getHlsManifest(animeId, episodeNumber, quality);
    print(response);
} on DioException catch (e) {
    print('Exception when calling VideoApi->getHlsManifest: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **animeId** | **int**|  | 
 **episodeNumber** | **int**|  | 
 **quality** | [**QualityType**](.md)| Preferred quality | [optional] [default to 720]

### Return type

**String**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/vnd.apple.mpegurl, application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getHlsResource**
> Uint8List getHlsResource(animeId, episodeNumber, token, range)

Stream a signed HLS resource

Used by URLs embedded in the rewritten manifest. Flutter applications normally do not call this operation directly.

### Example
```dart
import 'package:anistar_api/api.dart';

final api = AnistarApi().getVideoApi();
final int animeId = 56; // int | 
final int episodeNumber = 56; // int | 
final String token = token_example; // String | 
final String range = range_example; // String | Single HTTP byte range

try {
    final response = api.getHlsResource(animeId, episodeNumber, token, range);
    print(response);
} on DioException catch (e) {
    print('Exception when calling VideoApi->getHlsResource: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **animeId** | **int**|  | 
 **episodeNumber** | **int**|  | 
 **token** | **String**|  | 
 **range** | **String**| Single HTTP byte range | [optional] 

### Return type

[**Uint8List**](Uint8List.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/octet-stream, application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getPlaybackInfo**
> PlaybackInfo getPlaybackInfo(animeId, episodeNumber, quality)

Get HLS playback information

Returns a JSON contract for Flutter. Resolve `manifest_path` against the API base URL and pass the resulting URL to an HLS-capable player.

### Example
```dart
import 'package:anistar_api/api.dart';

final api = AnistarApi().getVideoApi();
final int animeId = 56; // int | 
final int episodeNumber = 56; // int | 
final QualityType quality = ; // QualityType | Preferred quality

try {
    final response = api.getPlaybackInfo(animeId, episodeNumber, quality);
    print(response);
} on DioException catch (e) {
    print('Exception when calling VideoApi->getPlaybackInfo: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **animeId** | **int**|  | 
 **episodeNumber** | **int**|  | 
 **quality** | [**QualityType**](.md)| Preferred quality | [optional] [default to 720]

### Return type

[**PlaybackInfo**](PlaybackInfo.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

