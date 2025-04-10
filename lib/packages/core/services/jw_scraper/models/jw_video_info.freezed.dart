// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'jw_video_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$JwVideoInfo {

 String get videoUrl; String? get posterUrl;
/// Create a copy of JwVideoInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JwVideoInfoCopyWith<JwVideoInfo> get copyWith => _$JwVideoInfoCopyWithImpl<JwVideoInfo>(this as JwVideoInfo, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JwVideoInfo&&(identical(other.videoUrl, videoUrl) || other.videoUrl == videoUrl)&&(identical(other.posterUrl, posterUrl) || other.posterUrl == posterUrl));
}


@override
int get hashCode => Object.hash(runtimeType,videoUrl,posterUrl);

@override
String toString() {
  return 'JwVideoInfo(videoUrl: $videoUrl, posterUrl: $posterUrl)';
}


}

/// @nodoc
abstract mixin class $JwVideoInfoCopyWith<$Res>  {
  factory $JwVideoInfoCopyWith(JwVideoInfo value, $Res Function(JwVideoInfo) _then) = _$JwVideoInfoCopyWithImpl;
@useResult
$Res call({
 String videoUrl, String? posterUrl
});




}
/// @nodoc
class _$JwVideoInfoCopyWithImpl<$Res>
    implements $JwVideoInfoCopyWith<$Res> {
  _$JwVideoInfoCopyWithImpl(this._self, this._then);

  final JwVideoInfo _self;
  final $Res Function(JwVideoInfo) _then;

/// Create a copy of JwVideoInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? videoUrl = null,Object? posterUrl = freezed,}) {
  return _then(_self.copyWith(
videoUrl: null == videoUrl ? _self.videoUrl : videoUrl // ignore: cast_nullable_to_non_nullable
as String,posterUrl: freezed == posterUrl ? _self.posterUrl : posterUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// @nodoc


class _JwVideoInfo implements JwVideoInfo {
  const _JwVideoInfo({required this.videoUrl, this.posterUrl});
  

@override final  String videoUrl;
@override final  String? posterUrl;

/// Create a copy of JwVideoInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$JwVideoInfoCopyWith<_JwVideoInfo> get copyWith => __$JwVideoInfoCopyWithImpl<_JwVideoInfo>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _JwVideoInfo&&(identical(other.videoUrl, videoUrl) || other.videoUrl == videoUrl)&&(identical(other.posterUrl, posterUrl) || other.posterUrl == posterUrl));
}


@override
int get hashCode => Object.hash(runtimeType,videoUrl,posterUrl);

@override
String toString() {
  return 'JwVideoInfo(videoUrl: $videoUrl, posterUrl: $posterUrl)';
}


}

/// @nodoc
abstract mixin class _$JwVideoInfoCopyWith<$Res> implements $JwVideoInfoCopyWith<$Res> {
  factory _$JwVideoInfoCopyWith(_JwVideoInfo value, $Res Function(_JwVideoInfo) _then) = __$JwVideoInfoCopyWithImpl;
@override @useResult
$Res call({
 String videoUrl, String? posterUrl
});




}
/// @nodoc
class __$JwVideoInfoCopyWithImpl<$Res>
    implements _$JwVideoInfoCopyWith<$Res> {
  __$JwVideoInfoCopyWithImpl(this._self, this._then);

  final _JwVideoInfo _self;
  final $Res Function(_JwVideoInfo) _then;

/// Create a copy of JwVideoInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? videoUrl = null,Object? posterUrl = freezed,}) {
  return _then(_JwVideoInfo(
videoUrl: null == videoUrl ? _self.videoUrl : videoUrl // ignore: cast_nullable_to_non_nullable
as String,posterUrl: freezed == posterUrl ? _self.posterUrl : posterUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
