// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'playback_info_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PlaybackInfoDto {

@JsonKey(name: 'anime_id') int get animeId;@JsonKey(name: 'episode_number') int get episodeNumber;@JsonKey(name: 'requested_quality') QualityTypeDto get requestedQuality;@JsonKey(name: 'selected_quality') QualityTypeDto get selectedQuality;@JsonKey(name: 'available_qualities') List<QualityTypeDto> get availableQualities;/// API-relative HLS manifest path; resolve it against the configured API base URL
@JsonKey(name: 'manifest_path') String get manifestPath;@JsonKey(name: 'segment_token_ttl_seconds') int get segmentTokenTtlSeconds;
/// Create a copy of PlaybackInfoDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlaybackInfoDtoCopyWith<PlaybackInfoDto> get copyWith => _$PlaybackInfoDtoCopyWithImpl<PlaybackInfoDto>(this as PlaybackInfoDto, _$identity);

  /// Serializes this PlaybackInfoDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlaybackInfoDto&&(identical(other.animeId, animeId) || other.animeId == animeId)&&(identical(other.episodeNumber, episodeNumber) || other.episodeNumber == episodeNumber)&&(identical(other.requestedQuality, requestedQuality) || other.requestedQuality == requestedQuality)&&(identical(other.selectedQuality, selectedQuality) || other.selectedQuality == selectedQuality)&&const DeepCollectionEquality().equals(other.availableQualities, availableQualities)&&(identical(other.manifestPath, manifestPath) || other.manifestPath == manifestPath)&&(identical(other.segmentTokenTtlSeconds, segmentTokenTtlSeconds) || other.segmentTokenTtlSeconds == segmentTokenTtlSeconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,animeId,episodeNumber,requestedQuality,selectedQuality,const DeepCollectionEquality().hash(availableQualities),manifestPath,segmentTokenTtlSeconds);

@override
String toString() {
  return 'PlaybackInfoDto(animeId: $animeId, episodeNumber: $episodeNumber, requestedQuality: $requestedQuality, selectedQuality: $selectedQuality, availableQualities: $availableQualities, manifestPath: $manifestPath, segmentTokenTtlSeconds: $segmentTokenTtlSeconds)';
}


}

/// @nodoc
abstract mixin class $PlaybackInfoDtoCopyWith<$Res>  {
  factory $PlaybackInfoDtoCopyWith(PlaybackInfoDto value, $Res Function(PlaybackInfoDto) _then) = _$PlaybackInfoDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'anime_id') int animeId,@JsonKey(name: 'episode_number') int episodeNumber,@JsonKey(name: 'requested_quality') QualityTypeDto requestedQuality,@JsonKey(name: 'selected_quality') QualityTypeDto selectedQuality,@JsonKey(name: 'available_qualities') List<QualityTypeDto> availableQualities,@JsonKey(name: 'manifest_path') String manifestPath,@JsonKey(name: 'segment_token_ttl_seconds') int segmentTokenTtlSeconds
});




}
/// @nodoc
class _$PlaybackInfoDtoCopyWithImpl<$Res>
    implements $PlaybackInfoDtoCopyWith<$Res> {
  _$PlaybackInfoDtoCopyWithImpl(this._self, this._then);

  final PlaybackInfoDto _self;
  final $Res Function(PlaybackInfoDto) _then;

/// Create a copy of PlaybackInfoDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? animeId = null,Object? episodeNumber = null,Object? requestedQuality = null,Object? selectedQuality = null,Object? availableQualities = null,Object? manifestPath = null,Object? segmentTokenTtlSeconds = null,}) {
  return _then(_self.copyWith(
animeId: null == animeId ? _self.animeId : animeId // ignore: cast_nullable_to_non_nullable
as int,episodeNumber: null == episodeNumber ? _self.episodeNumber : episodeNumber // ignore: cast_nullable_to_non_nullable
as int,requestedQuality: null == requestedQuality ? _self.requestedQuality : requestedQuality // ignore: cast_nullable_to_non_nullable
as QualityTypeDto,selectedQuality: null == selectedQuality ? _self.selectedQuality : selectedQuality // ignore: cast_nullable_to_non_nullable
as QualityTypeDto,availableQualities: null == availableQualities ? _self.availableQualities : availableQualities // ignore: cast_nullable_to_non_nullable
as List<QualityTypeDto>,manifestPath: null == manifestPath ? _self.manifestPath : manifestPath // ignore: cast_nullable_to_non_nullable
as String,segmentTokenTtlSeconds: null == segmentTokenTtlSeconds ? _self.segmentTokenTtlSeconds : segmentTokenTtlSeconds // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [PlaybackInfoDto].
extension PlaybackInfoDtoPatterns on PlaybackInfoDto {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlaybackInfoDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlaybackInfoDto() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlaybackInfoDto value)  $default,){
final _that = this;
switch (_that) {
case _PlaybackInfoDto():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlaybackInfoDto value)?  $default,){
final _that = this;
switch (_that) {
case _PlaybackInfoDto() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'anime_id')  int animeId, @JsonKey(name: 'episode_number')  int episodeNumber, @JsonKey(name: 'requested_quality')  QualityTypeDto requestedQuality, @JsonKey(name: 'selected_quality')  QualityTypeDto selectedQuality, @JsonKey(name: 'available_qualities')  List<QualityTypeDto> availableQualities, @JsonKey(name: 'manifest_path')  String manifestPath, @JsonKey(name: 'segment_token_ttl_seconds')  int segmentTokenTtlSeconds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlaybackInfoDto() when $default != null:
return $default(_that.animeId,_that.episodeNumber,_that.requestedQuality,_that.selectedQuality,_that.availableQualities,_that.manifestPath,_that.segmentTokenTtlSeconds);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'anime_id')  int animeId, @JsonKey(name: 'episode_number')  int episodeNumber, @JsonKey(name: 'requested_quality')  QualityTypeDto requestedQuality, @JsonKey(name: 'selected_quality')  QualityTypeDto selectedQuality, @JsonKey(name: 'available_qualities')  List<QualityTypeDto> availableQualities, @JsonKey(name: 'manifest_path')  String manifestPath, @JsonKey(name: 'segment_token_ttl_seconds')  int segmentTokenTtlSeconds)  $default,) {final _that = this;
switch (_that) {
case _PlaybackInfoDto():
return $default(_that.animeId,_that.episodeNumber,_that.requestedQuality,_that.selectedQuality,_that.availableQualities,_that.manifestPath,_that.segmentTokenTtlSeconds);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'anime_id')  int animeId, @JsonKey(name: 'episode_number')  int episodeNumber, @JsonKey(name: 'requested_quality')  QualityTypeDto requestedQuality, @JsonKey(name: 'selected_quality')  QualityTypeDto selectedQuality, @JsonKey(name: 'available_qualities')  List<QualityTypeDto> availableQualities, @JsonKey(name: 'manifest_path')  String manifestPath, @JsonKey(name: 'segment_token_ttl_seconds')  int segmentTokenTtlSeconds)?  $default,) {final _that = this;
switch (_that) {
case _PlaybackInfoDto() when $default != null:
return $default(_that.animeId,_that.episodeNumber,_that.requestedQuality,_that.selectedQuality,_that.availableQualities,_that.manifestPath,_that.segmentTokenTtlSeconds);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlaybackInfoDto implements PlaybackInfoDto {
  const _PlaybackInfoDto({@JsonKey(name: 'anime_id') required this.animeId, @JsonKey(name: 'episode_number') required this.episodeNumber, @JsonKey(name: 'requested_quality') required this.requestedQuality, @JsonKey(name: 'selected_quality') required this.selectedQuality, @JsonKey(name: 'available_qualities') required final  List<QualityTypeDto> availableQualities, @JsonKey(name: 'manifest_path') required this.manifestPath, @JsonKey(name: 'segment_token_ttl_seconds') required this.segmentTokenTtlSeconds}): _availableQualities = availableQualities;
  factory _PlaybackInfoDto.fromJson(Map<String, dynamic> json) => _$PlaybackInfoDtoFromJson(json);

@override@JsonKey(name: 'anime_id') final  int animeId;
@override@JsonKey(name: 'episode_number') final  int episodeNumber;
@override@JsonKey(name: 'requested_quality') final  QualityTypeDto requestedQuality;
@override@JsonKey(name: 'selected_quality') final  QualityTypeDto selectedQuality;
 final  List<QualityTypeDto> _availableQualities;
@override@JsonKey(name: 'available_qualities') List<QualityTypeDto> get availableQualities {
  if (_availableQualities is EqualUnmodifiableListView) return _availableQualities;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_availableQualities);
}

/// API-relative HLS manifest path; resolve it against the configured API base URL
@override@JsonKey(name: 'manifest_path') final  String manifestPath;
@override@JsonKey(name: 'segment_token_ttl_seconds') final  int segmentTokenTtlSeconds;

/// Create a copy of PlaybackInfoDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlaybackInfoDtoCopyWith<_PlaybackInfoDto> get copyWith => __$PlaybackInfoDtoCopyWithImpl<_PlaybackInfoDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlaybackInfoDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlaybackInfoDto&&(identical(other.animeId, animeId) || other.animeId == animeId)&&(identical(other.episodeNumber, episodeNumber) || other.episodeNumber == episodeNumber)&&(identical(other.requestedQuality, requestedQuality) || other.requestedQuality == requestedQuality)&&(identical(other.selectedQuality, selectedQuality) || other.selectedQuality == selectedQuality)&&const DeepCollectionEquality().equals(other._availableQualities, _availableQualities)&&(identical(other.manifestPath, manifestPath) || other.manifestPath == manifestPath)&&(identical(other.segmentTokenTtlSeconds, segmentTokenTtlSeconds) || other.segmentTokenTtlSeconds == segmentTokenTtlSeconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,animeId,episodeNumber,requestedQuality,selectedQuality,const DeepCollectionEquality().hash(_availableQualities),manifestPath,segmentTokenTtlSeconds);

@override
String toString() {
  return 'PlaybackInfoDto(animeId: $animeId, episodeNumber: $episodeNumber, requestedQuality: $requestedQuality, selectedQuality: $selectedQuality, availableQualities: $availableQualities, manifestPath: $manifestPath, segmentTokenTtlSeconds: $segmentTokenTtlSeconds)';
}


}

/// @nodoc
abstract mixin class _$PlaybackInfoDtoCopyWith<$Res> implements $PlaybackInfoDtoCopyWith<$Res> {
  factory _$PlaybackInfoDtoCopyWith(_PlaybackInfoDto value, $Res Function(_PlaybackInfoDto) _then) = __$PlaybackInfoDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'anime_id') int animeId,@JsonKey(name: 'episode_number') int episodeNumber,@JsonKey(name: 'requested_quality') QualityTypeDto requestedQuality,@JsonKey(name: 'selected_quality') QualityTypeDto selectedQuality,@JsonKey(name: 'available_qualities') List<QualityTypeDto> availableQualities,@JsonKey(name: 'manifest_path') String manifestPath,@JsonKey(name: 'segment_token_ttl_seconds') int segmentTokenTtlSeconds
});




}
/// @nodoc
class __$PlaybackInfoDtoCopyWithImpl<$Res>
    implements _$PlaybackInfoDtoCopyWith<$Res> {
  __$PlaybackInfoDtoCopyWithImpl(this._self, this._then);

  final _PlaybackInfoDto _self;
  final $Res Function(_PlaybackInfoDto) _then;

/// Create a copy of PlaybackInfoDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? animeId = null,Object? episodeNumber = null,Object? requestedQuality = null,Object? selectedQuality = null,Object? availableQualities = null,Object? manifestPath = null,Object? segmentTokenTtlSeconds = null,}) {
  return _then(_PlaybackInfoDto(
animeId: null == animeId ? _self.animeId : animeId // ignore: cast_nullable_to_non_nullable
as int,episodeNumber: null == episodeNumber ? _self.episodeNumber : episodeNumber // ignore: cast_nullable_to_non_nullable
as int,requestedQuality: null == requestedQuality ? _self.requestedQuality : requestedQuality // ignore: cast_nullable_to_non_nullable
as QualityTypeDto,selectedQuality: null == selectedQuality ? _self.selectedQuality : selectedQuality // ignore: cast_nullable_to_non_nullable
as QualityTypeDto,availableQualities: null == availableQualities ? _self._availableQualities : availableQualities // ignore: cast_nullable_to_non_nullable
as List<QualityTypeDto>,manifestPath: null == manifestPath ? _self.manifestPath : manifestPath // ignore: cast_nullable_to_non_nullable
as String,segmentTokenTtlSeconds: null == segmentTokenTtlSeconds ? _self.segmentTokenTtlSeconds : segmentTokenTtlSeconds // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
