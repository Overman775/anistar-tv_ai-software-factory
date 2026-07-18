# anistar_api.model.PlaybackInfo

## Load the model package
```dart
import 'package:anistar_api/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**animeId** | **int** |  | 
**episodeNumber** | **int** |  | 
**requestedQuality** | [**QualityType**](QualityType.md) |  | 
**selectedQuality** | [**QualityType**](QualityType.md) |  | 
**availableQualities** | [**BuiltList&lt;QualityType&gt;**](QualityType.md) |  | 
**manifestPath** | **String** | API-relative HLS manifest path; resolve it against the configured API base URL | 
**segmentTokenTtlSeconds** | **int** |  | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


