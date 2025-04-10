// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'series_list_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SeriesListEvent {

 String get url;
/// Create a copy of SeriesListEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SeriesListEventCopyWith<SeriesListEvent> get copyWith => _$SeriesListEventCopyWithImpl<SeriesListEvent>(this as SeriesListEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SeriesListEvent&&(identical(other.url, url) || other.url == url));
}


@override
int get hashCode => Object.hash(runtimeType,url);

@override
String toString() {
  return 'SeriesListEvent(url: $url)';
}


}

/// @nodoc
abstract mixin class $SeriesListEventCopyWith<$Res>  {
  factory $SeriesListEventCopyWith(SeriesListEvent value, $Res Function(SeriesListEvent) _then) = _$SeriesListEventCopyWithImpl;
@useResult
$Res call({
 String url
});




}
/// @nodoc
class _$SeriesListEventCopyWithImpl<$Res>
    implements $SeriesListEventCopyWith<$Res> {
  _$SeriesListEventCopyWithImpl(this._self, this._then);

  final SeriesListEvent _self;
  final $Res Function(SeriesListEvent) _then;

/// Create a copy of SeriesListEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? url = null,}) {
  return _then(_self.copyWith(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// @nodoc


class LoadSeriesList implements SeriesListEvent {
  const LoadSeriesList({required this.url});
  

@override final  String url;

/// Create a copy of SeriesListEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LoadSeriesListCopyWith<LoadSeriesList> get copyWith => _$LoadSeriesListCopyWithImpl<LoadSeriesList>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoadSeriesList&&(identical(other.url, url) || other.url == url));
}


@override
int get hashCode => Object.hash(runtimeType,url);

@override
String toString() {
  return 'SeriesListEvent.load(url: $url)';
}


}

/// @nodoc
abstract mixin class $LoadSeriesListCopyWith<$Res> implements $SeriesListEventCopyWith<$Res> {
  factory $LoadSeriesListCopyWith(LoadSeriesList value, $Res Function(LoadSeriesList) _then) = _$LoadSeriesListCopyWithImpl;
@override @useResult
$Res call({
 String url
});




}
/// @nodoc
class _$LoadSeriesListCopyWithImpl<$Res>
    implements $LoadSeriesListCopyWith<$Res> {
  _$LoadSeriesListCopyWithImpl(this._self, this._then);

  final LoadSeriesList _self;
  final $Res Function(LoadSeriesList) _then;

/// Create a copy of SeriesListEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? url = null,}) {
  return _then(LoadSeriesList(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$SeriesListState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SeriesListState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SeriesListState()';
}


}

/// @nodoc
class $SeriesListStateCopyWith<$Res>  {
$SeriesListStateCopyWith(SeriesListState _, $Res Function(SeriesListState) __);
}


/// @nodoc


class SeriesListInitial implements SeriesListState {
  const SeriesListInitial();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SeriesListInitial);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SeriesListState.initial()';
}


}




/// @nodoc


class SeriesListLoading implements SeriesListState {
  const SeriesListLoading();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SeriesListLoading);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SeriesListState.loading()';
}


}




/// @nodoc


class SeriesListLoaded implements SeriesListState {
  const SeriesListLoaded({required final  List<Series> series}): _series = series;
  

 final  List<Series> _series;
 List<Series> get series {
  if (_series is EqualUnmodifiableListView) return _series;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_series);
}


/// Create a copy of SeriesListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SeriesListLoadedCopyWith<SeriesListLoaded> get copyWith => _$SeriesListLoadedCopyWithImpl<SeriesListLoaded>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SeriesListLoaded&&const DeepCollectionEquality().equals(other._series, _series));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_series));

@override
String toString() {
  return 'SeriesListState.loaded(series: $series)';
}


}

/// @nodoc
abstract mixin class $SeriesListLoadedCopyWith<$Res> implements $SeriesListStateCopyWith<$Res> {
  factory $SeriesListLoadedCopyWith(SeriesListLoaded value, $Res Function(SeriesListLoaded) _then) = _$SeriesListLoadedCopyWithImpl;
@useResult
$Res call({
 List<Series> series
});




}
/// @nodoc
class _$SeriesListLoadedCopyWithImpl<$Res>
    implements $SeriesListLoadedCopyWith<$Res> {
  _$SeriesListLoadedCopyWithImpl(this._self, this._then);

  final SeriesListLoaded _self;
  final $Res Function(SeriesListLoaded) _then;

/// Create a copy of SeriesListState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? series = null,}) {
  return _then(SeriesListLoaded(
series: null == series ? _self._series : series // ignore: cast_nullable_to_non_nullable
as List<Series>,
  ));
}


}

/// @nodoc


class SeriesListError implements SeriesListState {
  const SeriesListError({required this.message});
  

 final  String message;

/// Create a copy of SeriesListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SeriesListErrorCopyWith<SeriesListError> get copyWith => _$SeriesListErrorCopyWithImpl<SeriesListError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SeriesListError&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'SeriesListState.error(message: $message)';
}


}

/// @nodoc
abstract mixin class $SeriesListErrorCopyWith<$Res> implements $SeriesListStateCopyWith<$Res> {
  factory $SeriesListErrorCopyWith(SeriesListError value, $Res Function(SeriesListError) _then) = _$SeriesListErrorCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$SeriesListErrorCopyWithImpl<$Res>
    implements $SeriesListErrorCopyWith<$Res> {
  _$SeriesListErrorCopyWithImpl(this._self, this._then);

  final SeriesListError _self;
  final $Res Function(SeriesListError) _then;

/// Create a copy of SeriesListState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(SeriesListError(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
