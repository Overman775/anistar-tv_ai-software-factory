// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'readiness_response_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReadinessResponseDto {

 StatusDto get status; String get service; AnistarDto get anistar; String get timestamp;
/// Create a copy of ReadinessResponseDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReadinessResponseDtoCopyWith<ReadinessResponseDto> get copyWith => _$ReadinessResponseDtoCopyWithImpl<ReadinessResponseDto>(this as ReadinessResponseDto, _$identity);

  /// Serializes this ReadinessResponseDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReadinessResponseDto&&(identical(other.status, status) || other.status == status)&&(identical(other.service, service) || other.service == service)&&(identical(other.anistar, anistar) || other.anistar == anistar)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,service,anistar,timestamp);

@override
String toString() {
  return 'ReadinessResponseDto(status: $status, service: $service, anistar: $anistar, timestamp: $timestamp)';
}


}

/// @nodoc
abstract mixin class $ReadinessResponseDtoCopyWith<$Res>  {
  factory $ReadinessResponseDtoCopyWith(ReadinessResponseDto value, $Res Function(ReadinessResponseDto) _then) = _$ReadinessResponseDtoCopyWithImpl;
@useResult
$Res call({
 StatusDto status, String service, AnistarDto anistar, String timestamp
});




}
/// @nodoc
class _$ReadinessResponseDtoCopyWithImpl<$Res>
    implements $ReadinessResponseDtoCopyWith<$Res> {
  _$ReadinessResponseDtoCopyWithImpl(this._self, this._then);

  final ReadinessResponseDto _self;
  final $Res Function(ReadinessResponseDto) _then;

/// Create a copy of ReadinessResponseDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? service = null,Object? anistar = null,Object? timestamp = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as StatusDto,service: null == service ? _self.service : service // ignore: cast_nullable_to_non_nullable
as String,anistar: null == anistar ? _self.anistar : anistar // ignore: cast_nullable_to_non_nullable
as AnistarDto,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ReadinessResponseDto].
extension ReadinessResponseDtoPatterns on ReadinessResponseDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReadinessResponseDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReadinessResponseDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReadinessResponseDto value)  $default,){
final _that = this;
switch (_that) {
case _ReadinessResponseDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReadinessResponseDto value)?  $default,){
final _that = this;
switch (_that) {
case _ReadinessResponseDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( StatusDto status,  String service,  AnistarDto anistar,  String timestamp)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReadinessResponseDto() when $default != null:
return $default(_that.status,_that.service,_that.anistar,_that.timestamp);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( StatusDto status,  String service,  AnistarDto anistar,  String timestamp)  $default,) {final _that = this;
switch (_that) {
case _ReadinessResponseDto():
return $default(_that.status,_that.service,_that.anistar,_that.timestamp);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( StatusDto status,  String service,  AnistarDto anistar,  String timestamp)?  $default,) {final _that = this;
switch (_that) {
case _ReadinessResponseDto() when $default != null:
return $default(_that.status,_that.service,_that.anistar,_that.timestamp);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReadinessResponseDto implements ReadinessResponseDto {
  const _ReadinessResponseDto({required this.status, required this.service, required this.anistar, required this.timestamp});
  factory _ReadinessResponseDto.fromJson(Map<String, dynamic> json) => _$ReadinessResponseDtoFromJson(json);

@override final  StatusDto status;
@override final  String service;
@override final  AnistarDto anistar;
@override final  String timestamp;

/// Create a copy of ReadinessResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReadinessResponseDtoCopyWith<_ReadinessResponseDto> get copyWith => __$ReadinessResponseDtoCopyWithImpl<_ReadinessResponseDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReadinessResponseDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReadinessResponseDto&&(identical(other.status, status) || other.status == status)&&(identical(other.service, service) || other.service == service)&&(identical(other.anistar, anistar) || other.anistar == anistar)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,service,anistar,timestamp);

@override
String toString() {
  return 'ReadinessResponseDto(status: $status, service: $service, anistar: $anistar, timestamp: $timestamp)';
}


}

/// @nodoc
abstract mixin class _$ReadinessResponseDtoCopyWith<$Res> implements $ReadinessResponseDtoCopyWith<$Res> {
  factory _$ReadinessResponseDtoCopyWith(_ReadinessResponseDto value, $Res Function(_ReadinessResponseDto) _then) = __$ReadinessResponseDtoCopyWithImpl;
@override @useResult
$Res call({
 StatusDto status, String service, AnistarDto anistar, String timestamp
});




}
/// @nodoc
class __$ReadinessResponseDtoCopyWithImpl<$Res>
    implements _$ReadinessResponseDtoCopyWith<$Res> {
  __$ReadinessResponseDtoCopyWithImpl(this._self, this._then);

  final _ReadinessResponseDto _self;
  final $Res Function(_ReadinessResponseDto) _then;

/// Create a copy of ReadinessResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? service = null,Object? anistar = null,Object? timestamp = null,}) {
  return _then(_ReadinessResponseDto(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as StatusDto,service: null == service ? _self.service : service // ignore: cast_nullable_to_non_nullable
as String,anistar: null == anistar ? _self.anistar : anistar // ignore: cast_nullable_to_non_nullable
as AnistarDto,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
