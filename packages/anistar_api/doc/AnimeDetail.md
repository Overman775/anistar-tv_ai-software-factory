# anistar_api.model.AnimeDetail

## Load the model package
```dart
import 'package:anistar_api/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**id** | **int** | Anime ID on website | 
**slug** | **String** | URL slug for detail page (e.g., '10247-title-here') | 
**title** | **String** | Full title | 
**year** | **String** | Release year | [optional] 
**genres** | **BuiltList&lt;String&gt;** | List of genres | [optional] 
**voiceover** | **String** | Voiceover type | [optional] 
**seriesInfo** | **String** | Series info as shown on site (e.g. '(52 эп.), 25 мин.') | [optional] 
**description** | **String** | Anime description | [optional] 
**isOngoing** | **bool** | Whether anime is currently airing (ongoing) | [optional] [default to false]
**posterUrl** | **String** | Poster image URL (None if not available) | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


