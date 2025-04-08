// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'video_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$VideoModel {

/// Unique identifier for the video
 String get id;/// Title of the video
 String get title;/// Description of the video
 String get description;/// URL to the video thumbnail image
 Uri get thumbnailUrl;/// URL to the video file
 String get videoUrl;/// Duration of the video
 Duration get duration;/// Category of the video
 String get category;/// Rating of the video (optional)
 double? get rating;
/// Create a copy of VideoModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VideoModelCopyWith<VideoModel> get copyWith => _$VideoModelCopyWithImpl<VideoModel>(this as VideoModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoModel&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl)&&(identical(other.videoUrl, videoUrl) || other.videoUrl == videoUrl)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.category, category) || other.category == category)&&(identical(other.rating, rating) || other.rating == rating));
}


@override
int get hashCode => Object.hash(runtimeType,id,title,description,thumbnailUrl,videoUrl,duration,category,rating);

@override
String toString() {
  return 'VideoModel(id: $id, title: $title, description: $description, thumbnailUrl: $thumbnailUrl, videoUrl: $videoUrl, duration: $duration, category: $category, rating: $rating)';
}


}

/// @nodoc
abstract mixin class $VideoModelCopyWith<$Res>  {
  factory $VideoModelCopyWith(VideoModel value, $Res Function(VideoModel) _then) = _$VideoModelCopyWithImpl;
@useResult
$Res call({
 String id, String title, String description, Uri thumbnailUrl, String videoUrl, Duration duration, String category, double? rating
});




}
/// @nodoc
class _$VideoModelCopyWithImpl<$Res>
    implements $VideoModelCopyWith<$Res> {
  _$VideoModelCopyWithImpl(this._self, this._then);

  final VideoModel _self;
  final $Res Function(VideoModel) _then;

/// Create a copy of VideoModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? description = null,Object? thumbnailUrl = null,Object? videoUrl = null,Object? duration = null,Object? category = null,Object? rating = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,thumbnailUrl: null == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as Uri,videoUrl: null == videoUrl ? _self.videoUrl : videoUrl // ignore: cast_nullable_to_non_nullable
as String,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// @nodoc


class _VideoModel implements VideoModel {
  const _VideoModel({required this.id, required this.title, required this.description, required this.thumbnailUrl, required this.videoUrl, required this.duration, required this.category, this.rating});
  

/// Unique identifier for the video
@override final  String id;
/// Title of the video
@override final  String title;
/// Description of the video
@override final  String description;
/// URL to the video thumbnail image
@override final  Uri thumbnailUrl;
/// URL to the video file
@override final  String videoUrl;
/// Duration of the video
@override final  Duration duration;
/// Category of the video
@override final  String category;
/// Rating of the video (optional)
@override final  double? rating;

/// Create a copy of VideoModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VideoModelCopyWith<_VideoModel> get copyWith => __$VideoModelCopyWithImpl<_VideoModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VideoModel&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl)&&(identical(other.videoUrl, videoUrl) || other.videoUrl == videoUrl)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.category, category) || other.category == category)&&(identical(other.rating, rating) || other.rating == rating));
}


@override
int get hashCode => Object.hash(runtimeType,id,title,description,thumbnailUrl,videoUrl,duration,category,rating);

@override
String toString() {
  return 'VideoModel(id: $id, title: $title, description: $description, thumbnailUrl: $thumbnailUrl, videoUrl: $videoUrl, duration: $duration, category: $category, rating: $rating)';
}


}

/// @nodoc
abstract mixin class _$VideoModelCopyWith<$Res> implements $VideoModelCopyWith<$Res> {
  factory _$VideoModelCopyWith(_VideoModel value, $Res Function(_VideoModel) _then) = __$VideoModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String description, Uri thumbnailUrl, String videoUrl, Duration duration, String category, double? rating
});




}
/// @nodoc
class __$VideoModelCopyWithImpl<$Res>
    implements _$VideoModelCopyWith<$Res> {
  __$VideoModelCopyWithImpl(this._self, this._then);

  final _VideoModel _self;
  final $Res Function(_VideoModel) _then;

/// Create a copy of VideoModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? description = null,Object? thumbnailUrl = null,Object? videoUrl = null,Object? duration = null,Object? category = null,Object? rating = freezed,}) {
  return _then(_VideoModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,thumbnailUrl: null == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as Uri,videoUrl: null == videoUrl ? _self.videoUrl : videoUrl // ignore: cast_nullable_to_non_nullable
as String,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

// dart format on
