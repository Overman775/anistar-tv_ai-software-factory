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

 String get videoUrl; String get title; String? get posterUrl; bool get isViewed;
/// Create a copy of JwVideoInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JwVideoInfoCopyWith<JwVideoInfo> get copyWith => _$JwVideoInfoCopyWithImpl<JwVideoInfo>(this as JwVideoInfo, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JwVideoInfo&&(identical(other.videoUrl, videoUrl) || other.videoUrl == videoUrl)&&(identical(other.title, title) || other.title == title)&&(identical(other.posterUrl, posterUrl) || other.posterUrl == posterUrl)&&(identical(other.isViewed, isViewed) || other.isViewed == isViewed));
}


@override
int get hashCode => Object.hash(runtimeType,videoUrl,title,posterUrl,isViewed);

@override
String toString() {
  return 'JwVideoInfo(videoUrl: $videoUrl, title: $title, posterUrl: $posterUrl, isViewed: $isViewed)';
}


}

/// @nodoc
abstract mixin class $JwVideoInfoCopyWith<$Res>  {
  factory $JwVideoInfoCopyWith(JwVideoInfo value, $Res Function(JwVideoInfo) _then) = _$JwVideoInfoCopyWithImpl;
@useResult
$Res call({
 String videoUrl, String title, String? posterUrl, bool isViewed
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
@pragma('vm:prefer-inline') @override $Res call({Object? videoUrl = null,Object? title = null,Object? posterUrl = freezed,Object? isViewed = null,}) {
  return _then(_self.copyWith(
videoUrl: null == videoUrl ? _self.videoUrl : videoUrl // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,posterUrl: freezed == posterUrl ? _self.posterUrl : posterUrl // ignore: cast_nullable_to_non_nullable
as String?,isViewed: null == isViewed ? _self.isViewed : isViewed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// @nodoc


class _JwVideoInfo implements JwVideoInfo {
  const _JwVideoInfo({required this.videoUrl, required this.title, this.posterUrl, required this.isViewed});
  

@override final  String videoUrl;
@override final  String title;
@override final  String? posterUrl;
@override final  bool isViewed;

/// Create a copy of JwVideoInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$JwVideoInfoCopyWith<_JwVideoInfo> get copyWith => __$JwVideoInfoCopyWithImpl<_JwVideoInfo>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _JwVideoInfo&&(identical(other.videoUrl, videoUrl) || other.videoUrl == videoUrl)&&(identical(other.title, title) || other.title == title)&&(identical(other.posterUrl, posterUrl) || other.posterUrl == posterUrl)&&(identical(other.isViewed, isViewed) || other.isViewed == isViewed));
}


@override
int get hashCode => Object.hash(runtimeType,videoUrl,title,posterUrl,isViewed);

@override
String toString() {
  return 'JwVideoInfo(videoUrl: $videoUrl, title: $title, posterUrl: $posterUrl, isViewed: $isViewed)';
}


}

/// @nodoc
abstract mixin class _$JwVideoInfoCopyWith<$Res> implements $JwVideoInfoCopyWith<$Res> {
  factory _$JwVideoInfoCopyWith(_JwVideoInfo value, $Res Function(_JwVideoInfo) _then) = __$JwVideoInfoCopyWithImpl;
@override @useResult
$Res call({
 String videoUrl, String title, String? posterUrl, bool isViewed
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
@override @pragma('vm:prefer-inline') $Res call({Object? videoUrl = null,Object? title = null,Object? posterUrl = freezed,Object? isViewed = null,}) {
  return _then(_JwVideoInfo(
videoUrl: null == videoUrl ? _self.videoUrl : videoUrl // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,posterUrl: freezed == posterUrl ? _self.posterUrl : posterUrl // ignore: cast_nullable_to_non_nullable
as String?,isViewed: null == isViewed ? _self.isViewed : isViewed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
