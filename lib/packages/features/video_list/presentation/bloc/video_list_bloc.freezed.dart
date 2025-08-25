// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'video_list_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$VideoListEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoListEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'VideoListEvent()';
}


}

/// @nodoc
class $VideoListEventCopyWith<$Res>  {
$VideoListEventCopyWith(VideoListEvent _, $Res Function(VideoListEvent) __);
}


/// Adds pattern-matching-related methods to [VideoListEvent].
extension VideoListEventPatterns on VideoListEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( VideoListLoadStarted value)?  loadStarted,TResult Function( VideoListLoadMoreRequested value)?  loadMoreRequested,required TResult orElse(),}){
final _that = this;
switch (_that) {
case VideoListLoadStarted() when loadStarted != null:
return loadStarted(_that);case VideoListLoadMoreRequested() when loadMoreRequested != null:
return loadMoreRequested(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( VideoListLoadStarted value)  loadStarted,required TResult Function( VideoListLoadMoreRequested value)  loadMoreRequested,}){
final _that = this;
switch (_that) {
case VideoListLoadStarted():
return loadStarted(_that);case VideoListLoadMoreRequested():
return loadMoreRequested(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( VideoListLoadStarted value)?  loadStarted,TResult? Function( VideoListLoadMoreRequested value)?  loadMoreRequested,}){
final _that = this;
switch (_that) {
case VideoListLoadStarted() when loadStarted != null:
return loadStarted(_that);case VideoListLoadMoreRequested() when loadMoreRequested != null:
return loadMoreRequested(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  loadStarted,TResult Function()?  loadMoreRequested,required TResult orElse(),}) {final _that = this;
switch (_that) {
case VideoListLoadStarted() when loadStarted != null:
return loadStarted();case VideoListLoadMoreRequested() when loadMoreRequested != null:
return loadMoreRequested();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  loadStarted,required TResult Function()  loadMoreRequested,}) {final _that = this;
switch (_that) {
case VideoListLoadStarted():
return loadStarted();case VideoListLoadMoreRequested():
return loadMoreRequested();case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  loadStarted,TResult? Function()?  loadMoreRequested,}) {final _that = this;
switch (_that) {
case VideoListLoadStarted() when loadStarted != null:
return loadStarted();case VideoListLoadMoreRequested() when loadMoreRequested != null:
return loadMoreRequested();case _:
  return null;

}
}

}

/// @nodoc


class VideoListLoadStarted implements VideoListEvent {
  const VideoListLoadStarted();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoListLoadStarted);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'VideoListEvent.loadStarted()';
}


}




/// @nodoc


class VideoListLoadMoreRequested implements VideoListEvent {
  const VideoListLoadMoreRequested();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoListLoadMoreRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'VideoListEvent.loadMoreRequested()';
}


}




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


/// Adds pattern-matching-related methods to [VideoListState].
extension VideoListStatePatterns on VideoListState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( VideoListInitial value)?  initial,TResult Function( VideoListLoading value)?  loading,TResult Function( VideoListLoadingMore value)?  loadingMore,TResult Function( VideoListLoaded value)?  loaded,TResult Function( VideoListError value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case VideoListInitial() when initial != null:
return initial(_that);case VideoListLoading() when loading != null:
return loading(_that);case VideoListLoadingMore() when loadingMore != null:
return loadingMore(_that);case VideoListLoaded() when loaded != null:
return loaded(_that);case VideoListError() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( VideoListInitial value)  initial,required TResult Function( VideoListLoading value)  loading,required TResult Function( VideoListLoadingMore value)  loadingMore,required TResult Function( VideoListLoaded value)  loaded,required TResult Function( VideoListError value)  error,}){
final _that = this;
switch (_that) {
case VideoListInitial():
return initial(_that);case VideoListLoading():
return loading(_that);case VideoListLoadingMore():
return loadingMore(_that);case VideoListLoaded():
return loaded(_that);case VideoListError():
return error(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( VideoListInitial value)?  initial,TResult? Function( VideoListLoading value)?  loading,TResult? Function( VideoListLoadingMore value)?  loadingMore,TResult? Function( VideoListLoaded value)?  loaded,TResult? Function( VideoListError value)?  error,}){
final _that = this;
switch (_that) {
case VideoListInitial() when initial != null:
return initial(_that);case VideoListLoading() when loading != null:
return loading(_that);case VideoListLoadingMore() when loadingMore != null:
return loadingMore(_that);case VideoListLoaded() when loaded != null:
return loaded(_that);case VideoListError() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  initial,TResult Function()?  loading,TResult Function( List<VideoModel> videos)?  loadingMore,TResult Function( List<VideoModel> videos,  bool hasMore)?  loaded,TResult Function( String message,  List<VideoModel>? videos,  bool? hasMore)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case VideoListInitial() when initial != null:
return initial();case VideoListLoading() when loading != null:
return loading();case VideoListLoadingMore() when loadingMore != null:
return loadingMore(_that.videos);case VideoListLoaded() when loaded != null:
return loaded(_that.videos,_that.hasMore);case VideoListError() when error != null:
return error(_that.message,_that.videos,_that.hasMore);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  initial,required TResult Function()  loading,required TResult Function( List<VideoModel> videos)  loadingMore,required TResult Function( List<VideoModel> videos,  bool hasMore)  loaded,required TResult Function( String message,  List<VideoModel>? videos,  bool? hasMore)  error,}) {final _that = this;
switch (_that) {
case VideoListInitial():
return initial();case VideoListLoading():
return loading();case VideoListLoadingMore():
return loadingMore(_that.videos);case VideoListLoaded():
return loaded(_that.videos,_that.hasMore);case VideoListError():
return error(_that.message,_that.videos,_that.hasMore);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  initial,TResult? Function()?  loading,TResult? Function( List<VideoModel> videos)?  loadingMore,TResult? Function( List<VideoModel> videos,  bool hasMore)?  loaded,TResult? Function( String message,  List<VideoModel>? videos,  bool? hasMore)?  error,}) {final _that = this;
switch (_that) {
case VideoListInitial() when initial != null:
return initial();case VideoListLoading() when loading != null:
return loading();case VideoListLoadingMore() when loadingMore != null:
return loadingMore(_that.videos);case VideoListLoaded() when loaded != null:
return loaded(_that.videos,_that.hasMore);case VideoListError() when error != null:
return error(_that.message,_that.videos,_that.hasMore);case _:
  return null;

}
}

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
