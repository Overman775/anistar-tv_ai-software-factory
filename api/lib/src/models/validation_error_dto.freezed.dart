// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'validation_error_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ValidationErrorDto {

 List<dynamic> get loc; String get msg; String get type; dynamic get input; dynamic get ctx;
/// Create a copy of ValidationErrorDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ValidationErrorDtoCopyWith<ValidationErrorDto> get copyWith => _$ValidationErrorDtoCopyWithImpl<ValidationErrorDto>(this as ValidationErrorDto, _$identity);

  /// Serializes this ValidationErrorDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ValidationErrorDto&&const DeepCollectionEquality().equals(other.loc, loc)&&(identical(other.msg, msg) || other.msg == msg)&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other.input, input)&&const DeepCollectionEquality().equals(other.ctx, ctx));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(loc),msg,type,const DeepCollectionEquality().hash(input),const DeepCollectionEquality().hash(ctx));

@override
String toString() {
  return 'ValidationErrorDto(loc: $loc, msg: $msg, type: $type, input: $input, ctx: $ctx)';
}


}

/// @nodoc
abstract mixin class $ValidationErrorDtoCopyWith<$Res>  {
  factory $ValidationErrorDtoCopyWith(ValidationErrorDto value, $Res Function(ValidationErrorDto) _then) = _$ValidationErrorDtoCopyWithImpl;
@useResult
$Res call({
 List<dynamic> loc, String msg, String type, dynamic input, dynamic ctx
});




}
/// @nodoc
class _$ValidationErrorDtoCopyWithImpl<$Res>
    implements $ValidationErrorDtoCopyWith<$Res> {
  _$ValidationErrorDtoCopyWithImpl(this._self, this._then);

  final ValidationErrorDto _self;
  final $Res Function(ValidationErrorDto) _then;

/// Create a copy of ValidationErrorDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? loc = null,Object? msg = null,Object? type = null,Object? input = freezed,Object? ctx = freezed,}) {
  return _then(_self.copyWith(
loc: null == loc ? _self.loc : loc // ignore: cast_nullable_to_non_nullable
as List<dynamic>,msg: null == msg ? _self.msg : msg // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,input: freezed == input ? _self.input : input // ignore: cast_nullable_to_non_nullable
as dynamic,ctx: freezed == ctx ? _self.ctx : ctx // ignore: cast_nullable_to_non_nullable
as dynamic,
  ));
}

}


/// Adds pattern-matching-related methods to [ValidationErrorDto].
extension ValidationErrorDtoPatterns on ValidationErrorDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ValidationErrorDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ValidationErrorDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ValidationErrorDto value)  $default,){
final _that = this;
switch (_that) {
case _ValidationErrorDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ValidationErrorDto value)?  $default,){
final _that = this;
switch (_that) {
case _ValidationErrorDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<dynamic> loc,  String msg,  String type,  dynamic input,  dynamic ctx)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ValidationErrorDto() when $default != null:
return $default(_that.loc,_that.msg,_that.type,_that.input,_that.ctx);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<dynamic> loc,  String msg,  String type,  dynamic input,  dynamic ctx)  $default,) {final _that = this;
switch (_that) {
case _ValidationErrorDto():
return $default(_that.loc,_that.msg,_that.type,_that.input,_that.ctx);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<dynamic> loc,  String msg,  String type,  dynamic input,  dynamic ctx)?  $default,) {final _that = this;
switch (_that) {
case _ValidationErrorDto() when $default != null:
return $default(_that.loc,_that.msg,_that.type,_that.input,_that.ctx);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ValidationErrorDto implements ValidationErrorDto {
  const _ValidationErrorDto({required final  List<dynamic> loc, required this.msg, required this.type, this.input, this.ctx}): _loc = loc;
  factory _ValidationErrorDto.fromJson(Map<String, dynamic> json) => _$ValidationErrorDtoFromJson(json);

 final  List<dynamic> _loc;
@override List<dynamic> get loc {
  if (_loc is EqualUnmodifiableListView) return _loc;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_loc);
}

@override final  String msg;
@override final  String type;
@override final  dynamic input;
@override final  dynamic ctx;

/// Create a copy of ValidationErrorDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ValidationErrorDtoCopyWith<_ValidationErrorDto> get copyWith => __$ValidationErrorDtoCopyWithImpl<_ValidationErrorDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ValidationErrorDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ValidationErrorDto&&const DeepCollectionEquality().equals(other._loc, _loc)&&(identical(other.msg, msg) || other.msg == msg)&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other.input, input)&&const DeepCollectionEquality().equals(other.ctx, ctx));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_loc),msg,type,const DeepCollectionEquality().hash(input),const DeepCollectionEquality().hash(ctx));

@override
String toString() {
  return 'ValidationErrorDto(loc: $loc, msg: $msg, type: $type, input: $input, ctx: $ctx)';
}


}

/// @nodoc
abstract mixin class _$ValidationErrorDtoCopyWith<$Res> implements $ValidationErrorDtoCopyWith<$Res> {
  factory _$ValidationErrorDtoCopyWith(_ValidationErrorDto value, $Res Function(_ValidationErrorDto) _then) = __$ValidationErrorDtoCopyWithImpl;
@override @useResult
$Res call({
 List<dynamic> loc, String msg, String type, dynamic input, dynamic ctx
});




}
/// @nodoc
class __$ValidationErrorDtoCopyWithImpl<$Res>
    implements _$ValidationErrorDtoCopyWith<$Res> {
  __$ValidationErrorDtoCopyWithImpl(this._self, this._then);

  final _ValidationErrorDto _self;
  final $Res Function(_ValidationErrorDto) _then;

/// Create a copy of ValidationErrorDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? loc = null,Object? msg = null,Object? type = null,Object? input = freezed,Object? ctx = freezed,}) {
  return _then(_ValidationErrorDto(
loc: null == loc ? _self._loc : loc // ignore: cast_nullable_to_non_nullable
as List<dynamic>,msg: null == msg ? _self.msg : msg // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,input: freezed == input ? _self.input : input // ignore: cast_nullable_to_non_nullable
as dynamic,ctx: freezed == ctx ? _self.ctx : ctx // ignore: cast_nullable_to_non_nullable
as dynamic,
  ));
}


}

// dart format on
