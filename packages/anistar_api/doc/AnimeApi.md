# anistar_api.api.AnimeApi

## Load the API package
```dart
import 'package:anistar_api/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getAnimeDetail**](AnimeApi.md#getanimedetail) | **GET** /api/anime/{slug} | Get anime details by slug
[**listAnime**](AnimeApi.md#listanime) | **GET** /api/anime | Get anime list
[**listAnimeEpisodes**](AnimeApi.md#listanimeepisodes) | **GET** /api/anime/{anime_id}/episodes | Get anime episodes


# **getAnimeDetail**
> AnimeDetail getAnimeDetail(slug)

Get anime details by slug

Retrieve anime information by slug from list endpoint.

### Example
```dart
import 'package:anistar_api/api.dart';

final api = AnistarApi().getAnimeApi();
final String slug = slug_example; // String | 

try {
    final response = api.getAnimeDetail(slug);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AnimeApi->getAnimeDetail: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **slug** | **String**|  | 

### Return type

[**AnimeDetail**](AnimeDetail.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listAnime**
> PaginatedAnimeList listAnime(page)

Get anime list

Retrieve a paginated list of anime from AniStar website.

### Example
```dart
import 'package:anistar_api/api.dart';

final api = AnistarApi().getAnimeApi();
final int page = 56; // int | Page number (/page/{n})

try {
    final response = api.listAnime(page);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AnimeApi->listAnime: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **page** | **int**| Page number (/page/{n}) | [optional] [default to 1]

### Return type

[**PaginatedAnimeList**](PaginatedAnimeList.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listAnimeEpisodes**
> BuiltList<EpisodeInfo> listAnimeEpisodes(animeId)

Get anime episodes

Retrieve episode metadata and playback paths from the player page.

### Example
```dart
import 'package:anistar_api/api.dart';

final api = AnistarApi().getAnimeApi();
final int animeId = 56; // int | 

try {
    final response = api.listAnimeEpisodes(animeId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AnimeApi->listAnimeEpisodes: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **animeId** | **int**|  | 

### Return type

[**BuiltList&lt;EpisodeInfo&gt;**](EpisodeInfo.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

