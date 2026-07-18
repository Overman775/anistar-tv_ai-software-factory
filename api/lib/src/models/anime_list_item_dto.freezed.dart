// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'anime_list_item_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AnimeListItemDto {

/// Anime ID on website
 int get id;/// URL slug for detail page (e.g., '10247-title-here')
 String get slug;/// Full title
 String get title;/// Poster image URL
@JsonKey(name: 'poster_url') String get posterUrl;/// Release date
 String? get year;
/// Create a copy of AnimeListItemDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AnimeListItemDtoCopyWith<AnimeListItemDto> get copyWith => _$AnimeListItemDtoCopyWithImpl<AnimeListItemDto>(this as AnimeListItemDto, _$identity);

  /// Serializes this AnimeListItemDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AnimeListItemDto&&(identical(other.id, id) || other.id == id)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.title, title) || other.title == title)&&(identical(other.posterUrl, posterUrl) || other.posterUrl == posterUrl)&&(identical(other.year, year) || other.year == year));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,slug,title,posterUrl,year);

@override
String toString() {
  return 'AnimeListItemDto(id: $id, slug: $slug, title: $title, posterUrl: $posterUrl, year: $year)';
}


}

/// @nodoc
abstract mixin class $AnimeListItemDtoCopyWith<$Res>  {
  factory $AnimeListItemDtoCopyWith(AnimeListItemDto value, $Res Function(AnimeListItemDto) _then) = _$AnimeListItemDtoCopyWithImpl;
@useResult
$Res call({
 int id, String slug, String title,@JsonKey(name: 'poster_url') String posterUrl, String? year
});




}
/// @nodoc
class _$AnimeListItemDtoCopyWithImpl<$Res>
    implements $AnimeListItemDtoCopyWith<$Res> {
  _$AnimeListItemDtoCopyWithImpl(this._self, this._then);

  final AnimeListItemDto _self;
  final $Res Function(AnimeListItemDto) _then;

/// Create a copy of AnimeListItemDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? slug = null,Object? title = null,Object? posterUrl = null,Object? year = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,posterUrl: null == posterUrl ? _self.posterUrl : posterUrl // ignore: cast_nullable_to_non_nullable
as String,year: freezed == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AnimeListItemDto].
extension AnimeListItemDtoPatterns on AnimeListItemDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AnimeListItemDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AnimeListItemDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AnimeListItemDto value)  $default,){
final _that = this;
switch (_that) {
case _AnimeListItemDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AnimeListItemDto value)?  $default,){
final _that = this;
switch (_that) {
case _AnimeListItemDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String slug,  String title, @JsonKey(name: 'poster_url')  String posterUrl,  String? year)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AnimeListItemDto() when $default != null:
return $default(_that.id,_that.slug,_that.title,_that.posterUrl,_that.year);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String slug,  String title, @JsonKey(name: 'poster_url')  String posterUrl,  String? year)  $default,) {final _that = this;
switch (_that) {
case _AnimeListItemDto():
return $default(_that.id,_that.slug,_that.title,_that.posterUrl,_that.year);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String slug,  String title, @JsonKey(name: 'poster_url')  String posterUrl,  String? year)?  $default,) {final _that = this;
switch (_that) {
case _AnimeListItemDto() when $default != null:
return $default(_that.id,_that.slug,_that.title,_that.posterUrl,_that.year);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AnimeListItemDto implements AnimeListItemDto {
  const _AnimeListItemDto({required this.id, required this.slug, required this.title, @JsonKey(name: 'poster_url') required this.posterUrl, this.year});
  factory _AnimeListItemDto.fromJson(Map<String, dynamic> json) => _$AnimeListItemDtoFromJson(json);

/// Anime ID on website
@override final  int id;
/// URL slug for detail page (e.g., '10247-title-here')
@override final  String slug;
/// Full title
@override final  String title;
/// Poster image URL
@override@JsonKey(name: 'poster_url') final  String posterUrl;
/// Release date
@override final  String? year;

/// Create a copy of AnimeListItemDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AnimeListItemDtoCopyWith<_AnimeListItemDto> get copyWith => __$AnimeListItemDtoCopyWithImpl<_AnimeListItemDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AnimeListItemDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AnimeListItemDto&&(identical(other.id, id) || other.id == id)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.title, title) || other.title == title)&&(identical(other.posterUrl, posterUrl) || other.posterUrl == posterUrl)&&(identical(other.year, year) || other.year == year));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,slug,title,posterUrl,year);

@override
String toString() {
  return 'AnimeListItemDto(id: $id, slug: $slug, title: $title, posterUrl: $posterUrl, year: $year)';
}


}

/// @nodoc
abstract mixin class _$AnimeListItemDtoCopyWith<$Res> implements $AnimeListItemDtoCopyWith<$Res> {
  factory _$AnimeListItemDtoCopyWith(_AnimeListItemDto value, $Res Function(_AnimeListItemDto) _then) = __$AnimeListItemDtoCopyWithImpl;
@override @useResult
$Res call({
 int id, String slug, String title,@JsonKey(name: 'poster_url') String posterUrl, String? year
});




}
/// @nodoc
class __$AnimeListItemDtoCopyWithImpl<$Res>
    implements _$AnimeListItemDtoCopyWith<$Res> {
  __$AnimeListItemDtoCopyWithImpl(this._self, this._then);

  final _AnimeListItemDto _self;
  final $Res Function(_AnimeListItemDto) _then;

/// Create a copy of AnimeListItemDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? slug = null,Object? title = null,Object? posterUrl = null,Object? year = freezed,}) {
  return _then(_AnimeListItemDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,posterUrl: null == posterUrl ? _self.posterUrl : posterUrl // ignore: cast_nullable_to_non_nullable
as String,year: freezed == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
