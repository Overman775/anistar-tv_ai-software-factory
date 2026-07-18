// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'liveness_response_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LivenessResponseDto {

 String get service; String get timestamp; String get status;
/// Create a copy of LivenessResponseDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LivenessResponseDtoCopyWith<LivenessResponseDto> get copyWith => _$LivenessResponseDtoCopyWithImpl<LivenessResponseDto>(this as LivenessResponseDto, _$identity);

  /// Serializes this LivenessResponseDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LivenessResponseDto&&(identical(other.service, service) || other.service == service)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,service,timestamp,status);

@override
String toString() {
  return 'LivenessResponseDto(service: $service, timestamp: $timestamp, status: $status)';
}


}

/// @nodoc
abstract mixin class $LivenessResponseDtoCopyWith<$Res>  {
  factory $LivenessResponseDtoCopyWith(LivenessResponseDto value, $Res Function(LivenessResponseDto) _then) = _$LivenessResponseDtoCopyWithImpl;
@useResult
$Res call({
 String service, String timestamp, String status
});




}
/// @nodoc
class _$LivenessResponseDtoCopyWithImpl<$Res>
    implements $LivenessResponseDtoCopyWith<$Res> {
  _$LivenessResponseDtoCopyWithImpl(this._self, this._then);

  final LivenessResponseDto _self;
  final $Res Function(LivenessResponseDto) _then;

/// Create a copy of LivenessResponseDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? service = null,Object? timestamp = null,Object? status = null,}) {
  return _then(_self.copyWith(
service: null == service ? _self.service : service // ignore: cast_nullable_to_non_nullable
as String,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [LivenessResponseDto].
extension LivenessResponseDtoPatterns on LivenessResponseDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LivenessResponseDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LivenessResponseDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LivenessResponseDto value)  $default,){
final _that = this;
switch (_that) {
case _LivenessResponseDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LivenessResponseDto value)?  $default,){
final _that = this;
switch (_that) {
case _LivenessResponseDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String service,  String timestamp,  String status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LivenessResponseDto() when $default != null:
return $default(_that.service,_that.timestamp,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String service,  String timestamp,  String status)  $default,) {final _that = this;
switch (_that) {
case _LivenessResponseDto():
return $default(_that.service,_that.timestamp,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String service,  String timestamp,  String status)?  $default,) {final _that = this;
switch (_that) {
case _LivenessResponseDto() when $default != null:
return $default(_that.service,_that.timestamp,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LivenessResponseDto implements LivenessResponseDto {
  const _LivenessResponseDto({required this.service, required this.timestamp, this.status = 'ok'});
  factory _LivenessResponseDto.fromJson(Map<String, dynamic> json) => _$LivenessResponseDtoFromJson(json);

@override final  String service;
@override final  String timestamp;
@override@JsonKey() final  String status;

/// Create a copy of LivenessResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LivenessResponseDtoCopyWith<_LivenessResponseDto> get copyWith => __$LivenessResponseDtoCopyWithImpl<_LivenessResponseDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LivenessResponseDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LivenessResponseDto&&(identical(other.service, service) || other.service == service)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,service,timestamp,status);

@override
String toString() {
  return 'LivenessResponseDto(service: $service, timestamp: $timestamp, status: $status)';
}


}

/// @nodoc
abstract mixin class _$LivenessResponseDtoCopyWith<$Res> implements $LivenessResponseDtoCopyWith<$Res> {
  factory _$LivenessResponseDtoCopyWith(_LivenessResponseDto value, $Res Function(_LivenessResponseDto) _then) = __$LivenessResponseDtoCopyWithImpl;
@override @useResult
$Res call({
 String service, String timestamp, String status
});




}
/// @nodoc
class __$LivenessResponseDtoCopyWithImpl<$Res>
    implements _$LivenessResponseDtoCopyWith<$Res> {
  __$LivenessResponseDtoCopyWithImpl(this._self, this._then);

  final _LivenessResponseDto _self;
  final $Res Function(_LivenessResponseDto) _then;

/// Create a copy of LivenessResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? service = null,Object? timestamp = null,Object? status = null,}) {
  return _then(_LivenessResponseDto(
service: null == service ? _self.service : service // ignore: cast_nullable_to_non_nullable
as String,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
