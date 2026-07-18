// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'error_response_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ErrorResponseDto {

/// Error type
 String get error;/// Error detail message
 String get detail;/// Request path
 String get path;
/// Create a copy of ErrorResponseDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ErrorResponseDtoCopyWith<ErrorResponseDto> get copyWith => _$ErrorResponseDtoCopyWithImpl<ErrorResponseDto>(this as ErrorResponseDto, _$identity);

  /// Serializes this ErrorResponseDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ErrorResponseDto&&(identical(other.error, error) || other.error == error)&&(identical(other.detail, detail) || other.detail == detail)&&(identical(other.path, path) || other.path == path));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,error,detail,path);

@override
String toString() {
  return 'ErrorResponseDto(error: $error, detail: $detail, path: $path)';
}


}

/// @nodoc
abstract mixin class $ErrorResponseDtoCopyWith<$Res>  {
  factory $ErrorResponseDtoCopyWith(ErrorResponseDto value, $Res Function(ErrorResponseDto) _then) = _$ErrorResponseDtoCopyWithImpl;
@useResult
$Res call({
 String error, String detail, String path
});




}
/// @nodoc
class _$ErrorResponseDtoCopyWithImpl<$Res>
    implements $ErrorResponseDtoCopyWith<$Res> {
  _$ErrorResponseDtoCopyWithImpl(this._self, this._then);

  final ErrorResponseDto _self;
  final $Res Function(ErrorResponseDto) _then;

/// Create a copy of ErrorResponseDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? error = null,Object? detail = null,Object? path = null,}) {
  return _then(_self.copyWith(
error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String,detail: null == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ErrorResponseDto].
extension ErrorResponseDtoPatterns on ErrorResponseDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ErrorResponseDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ErrorResponseDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ErrorResponseDto value)  $default,){
final _that = this;
switch (_that) {
case _ErrorResponseDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ErrorResponseDto value)?  $default,){
final _that = this;
switch (_that) {
case _ErrorResponseDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String error,  String detail,  String path)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ErrorResponseDto() when $default != null:
return $default(_that.error,_that.detail,_that.path);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String error,  String detail,  String path)  $default,) {final _that = this;
switch (_that) {
case _ErrorResponseDto():
return $default(_that.error,_that.detail,_that.path);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String error,  String detail,  String path)?  $default,) {final _that = this;
switch (_that) {
case _ErrorResponseDto() when $default != null:
return $default(_that.error,_that.detail,_that.path);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ErrorResponseDto implements ErrorResponseDto {
  const _ErrorResponseDto({required this.error, required this.detail, required this.path});
  factory _ErrorResponseDto.fromJson(Map<String, dynamic> json) => _$ErrorResponseDtoFromJson(json);

/// Error type
@override final  String error;
/// Error detail message
@override final  String detail;
/// Request path
@override final  String path;

/// Create a copy of ErrorResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ErrorResponseDtoCopyWith<_ErrorResponseDto> get copyWith => __$ErrorResponseDtoCopyWithImpl<_ErrorResponseDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ErrorResponseDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ErrorResponseDto&&(identical(other.error, error) || other.error == error)&&(identical(other.detail, detail) || other.detail == detail)&&(identical(other.path, path) || other.path == path));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,error,detail,path);

@override
String toString() {
  return 'ErrorResponseDto(error: $error, detail: $detail, path: $path)';
}


}

/// @nodoc
abstract mixin class _$ErrorResponseDtoCopyWith<$Res> implements $ErrorResponseDtoCopyWith<$Res> {
  factory _$ErrorResponseDtoCopyWith(_ErrorResponseDto value, $Res Function(_ErrorResponseDto) _then) = __$ErrorResponseDtoCopyWithImpl;
@override @useResult
$Res call({
 String error, String detail, String path
});




}
/// @nodoc
class __$ErrorResponseDtoCopyWithImpl<$Res>
    implements _$ErrorResponseDtoCopyWith<$Res> {
  __$ErrorResponseDtoCopyWithImpl(this._self, this._then);

  final _ErrorResponseDto _self;
  final $Res Function(_ErrorResponseDto) _then;

/// Create a copy of ErrorResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? error = null,Object? detail = null,Object? path = null,}) {
  return _then(_ErrorResponseDto(
error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String,detail: null == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
