// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'video_list_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$VideoListState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoListState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'VideoListState()';
}


}

/// @nodoc
class $VideoListStateCopyWith<$Res>  {
$VideoListStateCopyWith(VideoListState _, $Res Function(VideoListState) __);
}


/// @nodoc


class VideoListInitial implements VideoListState {
  const VideoListInitial();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoListInitial);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'VideoListState.initial()';
}


}




/// @nodoc


class VideoListLoading implements VideoListState {
  const VideoListLoading();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoListLoading);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'VideoListState.loading()';
}


}




/// @nodoc


class VideoListLoadingMore implements VideoListState {
  const VideoListLoadingMore({required final  List<VideoModel> videos}): _videos = videos;
  

 final  List<VideoModel> _videos;
 List<VideoModel> get videos {
  if (_videos is EqualUnmodifiableListView) return _videos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_videos);
}


/// Create a copy of VideoListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VideoListLoadingMoreCopyWith<VideoListLoadingMore> get copyWith => _$VideoListLoadingMoreCopyWithImpl<VideoListLoadingMore>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoListLoadingMore&&const DeepCollectionEquality().equals(other._videos, _videos));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_videos));

@override
String toString() {
  return 'VideoListState.loadingMore(videos: $videos)';
}


}

/// @nodoc
abstract mixin class $VideoListLoadingMoreCopyWith<$Res> implements $VideoListStateCopyWith<$Res> {
  factory $VideoListLoadingMoreCopyWith(VideoListLoadingMore value, $Res Function(VideoListLoadingMore) _then) = _$VideoListLoadingMoreCopyWithImpl;
@useResult
$Res call({
 List<VideoModel> videos
});




}
/// @nodoc
class _$VideoListLoadingMoreCopyWithImpl<$Res>
    implements $VideoListLoadingMoreCopyWith<$Res> {
  _$VideoListLoadingMoreCopyWithImpl(this._self, this._then);

  final VideoListLoadingMore _self;
  final $Res Function(VideoListLoadingMore) _then;

/// Create a copy of VideoListState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? videos = null,}) {
  return _then(VideoListLoadingMore(
videos: null == videos ? _self._videos : videos // ignore: cast_nullable_to_non_nullable
as List<VideoModel>,
  ));
}


}

/// @nodoc


class VideoListLoaded implements VideoListState {
  const VideoListLoaded({required final  List<VideoModel> videos, required this.hasMore}): _videos = videos;
  

 final  List<VideoModel> _videos;
 List<VideoModel> get videos {
  if (_videos is EqualUnmodifiableListView) return _videos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_videos);
}

 final  bool hasMore;

/// Create a copy of VideoListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VideoListLoadedCopyWith<VideoListLoaded> get copyWith => _$VideoListLoadedCopyWithImpl<VideoListLoaded>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoListLoaded&&const DeepCollectionEquality().equals(other._videos, _videos)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_videos),hasMore);

@override
String toString() {
  return 'VideoListState.loaded(videos: $videos, hasMore: $hasMore)';
}


}

/// @nodoc
abstract mixin class $VideoListLoadedCopyWith<$Res> implements $VideoListStateCopyWith<$Res> {
  factory $VideoListLoadedCopyWith(VideoListLoaded value, $Res Function(VideoListLoaded) _then) = _$VideoListLoadedCopyWithImpl;
@useResult
$Res call({
 List<VideoModel> videos, bool hasMore
});




}
/// @nodoc
class _$VideoListLoadedCopyWithImpl<$Res>
    implements $VideoListLoadedCopyWith<$Res> {
  _$VideoListLoadedCopyWithImpl(this._self, this._then);

  final VideoListLoaded _self;
  final $Res Function(VideoListLoaded) _then;

/// Create a copy of VideoListState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? videos = null,Object? hasMore = null,}) {
  return _then(VideoListLoaded(
videos: null == videos ? _self._videos : videos // ignore: cast_nullable_to_non_nullable
as List<VideoModel>,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class VideoListError implements VideoListState {
  const VideoListError({required this.message, final  List<VideoModel>? videos, this.hasMore}): _videos = videos;
  

 final  String message;
 final  List<VideoModel>? _videos;
 List<VideoModel>? get videos {
  final value = _videos;
  if (value == null) return null;
  if (_videos is EqualUnmodifiableListView) return _videos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

// Videos loaded before the error
 final  bool? hasMore;

/// Create a copy of VideoListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VideoListErrorCopyWith<VideoListError> get copyWith => _$VideoListErrorCopyWithImpl<VideoListError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoListError&&(identical(other.message, message) || other.message == message)&&const DeepCollectionEquality().equals(other._videos, _videos)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore));
}


@override
int get hashCode => Object.hash(runtimeType,message,const DeepCollectionEquality().hash(_videos),hasMore);

@override
String toString() {
  return 'VideoListState.error(message: $message, videos: $videos, hasMore: $hasMore)';
}


}

/// @nodoc
abstract mixin class $VideoListErrorCopyWith<$Res> implements $VideoListStateCopyWith<$Res> {
  factory $VideoListErrorCopyWith(VideoListError value, $Res Function(VideoListError) _then) = _$VideoListErrorCopyWithImpl;
@useResult
$Res call({
 String message, List<VideoModel>? videos, bool? hasMore
});




}
/// @nodoc
class _$VideoListErrorCopyWithImpl<$Res>
    implements $VideoListErrorCopyWith<$Res> {
  _$VideoListErrorCopyWithImpl(this._self, this._then);

  final VideoListError _self;
  final $Res Function(VideoListError) _then;

/// Create a copy of VideoListState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,Object? videos = freezed,Object? hasMore = freezed,}) {
  return _then(VideoListError(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,videos: freezed == videos ? _self._videos : videos // ignore: cast_nullable_to_non_nullable
as List<VideoModel>?,hasMore: freezed == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}

// dart format on
