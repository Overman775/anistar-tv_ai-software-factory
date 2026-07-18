// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'episode_info_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EpisodeInfoDto {

/// Episode number
@JsonKey(name: 'episode_number') int get episodeNumber;/// Episode title
 String get title;/// API-relative JSON playback endpoint for this episode
@JsonKey(name: 'playback_path') String get playbackPath;/// Preview image URL
@JsonKey(name: 'preview_url') String? get previewUrl;
/// Create a copy of EpisodeInfoDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EpisodeInfoDtoCopyWith<EpisodeInfoDto> get copyWith => _$EpisodeInfoDtoCopyWithImpl<EpisodeInfoDto>(this as EpisodeInfoDto, _$identity);

  /// Serializes this EpisodeInfoDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EpisodeInfoDto&&(identical(other.episodeNumber, episodeNumber) || other.episodeNumber == episodeNumber)&&(identical(other.title, title) || other.title == title)&&(identical(other.playbackPath, playbackPath) || other.playbackPath == playbackPath)&&(identical(other.previewUrl, previewUrl) || other.previewUrl == previewUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,episodeNumber,title,playbackPath,previewUrl);

@override
String toString() {
  return 'EpisodeInfoDto(episodeNumber: $episodeNumber, title: $title, playbackPath: $playbackPath, previewUrl: $previewUrl)';
}


}

/// @nodoc
abstract mixin class $EpisodeInfoDtoCopyWith<$Res>  {
  factory $EpisodeInfoDtoCopyWith(EpisodeInfoDto value, $Res Function(EpisodeInfoDto) _then) = _$EpisodeInfoDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'episode_number') int episodeNumber, String title,@JsonKey(name: 'playback_path') String playbackPath,@JsonKey(name: 'preview_url') String? previewUrl
});




}
/// @nodoc
class _$EpisodeInfoDtoCopyWithImpl<$Res>
    implements $EpisodeInfoDtoCopyWith<$Res> {
  _$EpisodeInfoDtoCopyWithImpl(this._self, this._then);

  final EpisodeInfoDto _self;
  final $Res Function(EpisodeInfoDto) _then;

/// Create a copy of EpisodeInfoDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? episodeNumber = null,Object? title = null,Object? playbackPath = null,Object? previewUrl = freezed,}) {
  return _then(_self.copyWith(
episodeNumber: null == episodeNumber ? _self.episodeNumber : episodeNumber // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,playbackPath: null == playbackPath ? _self.playbackPath : playbackPath // ignore: cast_nullable_to_non_nullable
as String,previewUrl: freezed == previewUrl ? _self.previewUrl : previewUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [EpisodeInfoDto].
extension EpisodeInfoDtoPatterns on EpisodeInfoDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EpisodeInfoDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EpisodeInfoDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EpisodeInfoDto value)  $default,){
final _that = this;
switch (_that) {
case _EpisodeInfoDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EpisodeInfoDto value)?  $default,){
final _that = this;
switch (_that) {
case _EpisodeInfoDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'episode_number')  int episodeNumber,  String title, @JsonKey(name: 'playback_path')  String playbackPath, @JsonKey(name: 'preview_url')  String? previewUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EpisodeInfoDto() when $default != null:
return $default(_that.episodeNumber,_that.title,_that.playbackPath,_that.previewUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'episode_number')  int episodeNumber,  String title, @JsonKey(name: 'playback_path')  String playbackPath, @JsonKey(name: 'preview_url')  String? previewUrl)  $default,) {final _that = this;
switch (_that) {
case _EpisodeInfoDto():
return $default(_that.episodeNumber,_that.title,_that.playbackPath,_that.previewUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'episode_number')  int episodeNumber,  String title, @JsonKey(name: 'playback_path')  String playbackPath, @JsonKey(name: 'preview_url')  String? previewUrl)?  $default,) {final _that = this;
switch (_that) {
case _EpisodeInfoDto() when $default != null:
return $default(_that.episodeNumber,_that.title,_that.playbackPath,_that.previewUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EpisodeInfoDto implements EpisodeInfoDto {
  const _EpisodeInfoDto({@JsonKey(name: 'episode_number') required this.episodeNumber, required this.title, @JsonKey(name: 'playback_path') required this.playbackPath, @JsonKey(name: 'preview_url') this.previewUrl});
  factory _EpisodeInfoDto.fromJson(Map<String, dynamic> json) => _$EpisodeInfoDtoFromJson(json);

/// Episode number
@override@JsonKey(name: 'episode_number') final  int episodeNumber;
/// Episode title
@override final  String title;
/// API-relative JSON playback endpoint for this episode
@override@JsonKey(name: 'playback_path') final  String playbackPath;
/// Preview image URL
@override@JsonKey(name: 'preview_url') final  String? previewUrl;

/// Create a copy of EpisodeInfoDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EpisodeInfoDtoCopyWith<_EpisodeInfoDto> get copyWith => __$EpisodeInfoDtoCopyWithImpl<_EpisodeInfoDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EpisodeInfoDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EpisodeInfoDto&&(identical(other.episodeNumber, episodeNumber) || other.episodeNumber == episodeNumber)&&(identical(other.title, title) || other.title == title)&&(identical(other.playbackPath, playbackPath) || other.playbackPath == playbackPath)&&(identical(other.previewUrl, previewUrl) || other.previewUrl == previewUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,episodeNumber,title,playbackPath,previewUrl);

@override
String toString() {
  return 'EpisodeInfoDto(episodeNumber: $episodeNumber, title: $title, playbackPath: $playbackPath, previewUrl: $previewUrl)';
}


}

/// @nodoc
abstract mixin class _$EpisodeInfoDtoCopyWith<$Res> implements $EpisodeInfoDtoCopyWith<$Res> {
  factory _$EpisodeInfoDtoCopyWith(_EpisodeInfoDto value, $Res Function(_EpisodeInfoDto) _then) = __$EpisodeInfoDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'episode_number') int episodeNumber, String title,@JsonKey(name: 'playback_path') String playbackPath,@JsonKey(name: 'preview_url') String? previewUrl
});




}
/// @nodoc
class __$EpisodeInfoDtoCopyWithImpl<$Res>
    implements _$EpisodeInfoDtoCopyWith<$Res> {
  __$EpisodeInfoDtoCopyWithImpl(this._self, this._then);

  final _EpisodeInfoDto _self;
  final $Res Function(_EpisodeInfoDto) _then;

/// Create a copy of EpisodeInfoDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? episodeNumber = null,Object? title = null,Object? playbackPath = null,Object? previewUrl = freezed,}) {
  return _then(_EpisodeInfoDto(
episodeNumber: null == episodeNumber ? _self.episodeNumber : episodeNumber // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,playbackPath: null == playbackPath ? _self.playbackPath : playbackPath // ignore: cast_nullable_to_non_nullable
as String,previewUrl: freezed == previewUrl ? _self.previewUrl : previewUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
