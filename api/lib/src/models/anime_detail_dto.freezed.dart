// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'anime_detail_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AnimeDetailDto {

/// Anime ID on website
 int get id;/// URL slug for detail page (e.g., '10247-title-here')
 String get slug;/// Full title
 String get title;/// Whether anime is currently airing (ongoing)
@JsonKey(name: 'is_ongoing') bool get isOngoing;/// Release year
 String? get year;/// List of genres
 List<String>? get genres;/// Voiceover type
 String? get voiceover;/// Series info as shown on site (e.g. '(52 эп.), 25 мин.')
@JsonKey(name: 'series_info') String? get seriesInfo;/// Anime description
 String? get description;/// Poster image URL (None if not available)
@JsonKey(name: 'poster_url') String? get posterUrl;
/// Create a copy of AnimeDetailDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AnimeDetailDtoCopyWith<AnimeDetailDto> get copyWith => _$AnimeDetailDtoCopyWithImpl<AnimeDetailDto>(this as AnimeDetailDto, _$identity);

  /// Serializes this AnimeDetailDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AnimeDetailDto&&(identical(other.id, id) || other.id == id)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.title, title) || other.title == title)&&(identical(other.isOngoing, isOngoing) || other.isOngoing == isOngoing)&&(identical(other.year, year) || other.year == year)&&const DeepCollectionEquality().equals(other.genres, genres)&&(identical(other.voiceover, voiceover) || other.voiceover == voiceover)&&(identical(other.seriesInfo, seriesInfo) || other.seriesInfo == seriesInfo)&&(identical(other.description, description) || other.description == description)&&(identical(other.posterUrl, posterUrl) || other.posterUrl == posterUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,slug,title,isOngoing,year,const DeepCollectionEquality().hash(genres),voiceover,seriesInfo,description,posterUrl);

@override
String toString() {
  return 'AnimeDetailDto(id: $id, slug: $slug, title: $title, isOngoing: $isOngoing, year: $year, genres: $genres, voiceover: $voiceover, seriesInfo: $seriesInfo, description: $description, posterUrl: $posterUrl)';
}


}

/// @nodoc
abstract mixin class $AnimeDetailDtoCopyWith<$Res>  {
  factory $AnimeDetailDtoCopyWith(AnimeDetailDto value, $Res Function(AnimeDetailDto) _then) = _$AnimeDetailDtoCopyWithImpl;
@useResult
$Res call({
 int id, String slug, String title,@JsonKey(name: 'is_ongoing') bool isOngoing, String? year, List<String>? genres, String? voiceover,@JsonKey(name: 'series_info') String? seriesInfo, String? description,@JsonKey(name: 'poster_url') String? posterUrl
});




}
/// @nodoc
class _$AnimeDetailDtoCopyWithImpl<$Res>
    implements $AnimeDetailDtoCopyWith<$Res> {
  _$AnimeDetailDtoCopyWithImpl(this._self, this._then);

  final AnimeDetailDto _self;
  final $Res Function(AnimeDetailDto) _then;

/// Create a copy of AnimeDetailDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? slug = null,Object? title = null,Object? isOngoing = null,Object? year = freezed,Object? genres = freezed,Object? voiceover = freezed,Object? seriesInfo = freezed,Object? description = freezed,Object? posterUrl = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,isOngoing: null == isOngoing ? _self.isOngoing : isOngoing // ignore: cast_nullable_to_non_nullable
as bool,year: freezed == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as String?,genres: freezed == genres ? _self.genres : genres // ignore: cast_nullable_to_non_nullable
as List<String>?,voiceover: freezed == voiceover ? _self.voiceover : voiceover // ignore: cast_nullable_to_non_nullable
as String?,seriesInfo: freezed == seriesInfo ? _self.seriesInfo : seriesInfo // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,posterUrl: freezed == posterUrl ? _self.posterUrl : posterUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AnimeDetailDto].
extension AnimeDetailDtoPatterns on AnimeDetailDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AnimeDetailDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AnimeDetailDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AnimeDetailDto value)  $default,){
final _that = this;
switch (_that) {
case _AnimeDetailDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AnimeDetailDto value)?  $default,){
final _that = this;
switch (_that) {
case _AnimeDetailDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String slug,  String title, @JsonKey(name: 'is_ongoing')  bool isOngoing,  String? year,  List<String>? genres,  String? voiceover, @JsonKey(name: 'series_info')  String? seriesInfo,  String? description, @JsonKey(name: 'poster_url')  String? posterUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AnimeDetailDto() when $default != null:
return $default(_that.id,_that.slug,_that.title,_that.isOngoing,_that.year,_that.genres,_that.voiceover,_that.seriesInfo,_that.description,_that.posterUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String slug,  String title, @JsonKey(name: 'is_ongoing')  bool isOngoing,  String? year,  List<String>? genres,  String? voiceover, @JsonKey(name: 'series_info')  String? seriesInfo,  String? description, @JsonKey(name: 'poster_url')  String? posterUrl)  $default,) {final _that = this;
switch (_that) {
case _AnimeDetailDto():
return $default(_that.id,_that.slug,_that.title,_that.isOngoing,_that.year,_that.genres,_that.voiceover,_that.seriesInfo,_that.description,_that.posterUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String slug,  String title, @JsonKey(name: 'is_ongoing')  bool isOngoing,  String? year,  List<String>? genres,  String? voiceover, @JsonKey(name: 'series_info')  String? seriesInfo,  String? description, @JsonKey(name: 'poster_url')  String? posterUrl)?  $default,) {final _that = this;
switch (_that) {
case _AnimeDetailDto() when $default != null:
return $default(_that.id,_that.slug,_that.title,_that.isOngoing,_that.year,_that.genres,_that.voiceover,_that.seriesInfo,_that.description,_that.posterUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AnimeDetailDto implements AnimeDetailDto {
  const _AnimeDetailDto({required this.id, required this.slug, required this.title, @JsonKey(name: 'is_ongoing') this.isOngoing = false, this.year, final  List<String>? genres, this.voiceover, @JsonKey(name: 'series_info') this.seriesInfo, this.description, @JsonKey(name: 'poster_url') this.posterUrl}): _genres = genres;
  factory _AnimeDetailDto.fromJson(Map<String, dynamic> json) => _$AnimeDetailDtoFromJson(json);

/// Anime ID on website
@override final  int id;
/// URL slug for detail page (e.g., '10247-title-here')
@override final  String slug;
/// Full title
@override final  String title;
/// Whether anime is currently airing (ongoing)
@override@JsonKey(name: 'is_ongoing') final  bool isOngoing;
/// Release year
@override final  String? year;
/// List of genres
 final  List<String>? _genres;
/// List of genres
@override List<String>? get genres {
  final value = _genres;
  if (value == null) return null;
  if (_genres is EqualUnmodifiableListView) return _genres;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

/// Voiceover type
@override final  String? voiceover;
/// Series info as shown on site (e.g. '(52 эп.), 25 мин.')
@override@JsonKey(name: 'series_info') final  String? seriesInfo;
/// Anime description
@override final  String? description;
/// Poster image URL (None if not available)
@override@JsonKey(name: 'poster_url') final  String? posterUrl;

/// Create a copy of AnimeDetailDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AnimeDetailDtoCopyWith<_AnimeDetailDto> get copyWith => __$AnimeDetailDtoCopyWithImpl<_AnimeDetailDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AnimeDetailDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AnimeDetailDto&&(identical(other.id, id) || other.id == id)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.title, title) || other.title == title)&&(identical(other.isOngoing, isOngoing) || other.isOngoing == isOngoing)&&(identical(other.year, year) || other.year == year)&&const DeepCollectionEquality().equals(other._genres, _genres)&&(identical(other.voiceover, voiceover) || other.voiceover == voiceover)&&(identical(other.seriesInfo, seriesInfo) || other.seriesInfo == seriesInfo)&&(identical(other.description, description) || other.description == description)&&(identical(other.posterUrl, posterUrl) || other.posterUrl == posterUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,slug,title,isOngoing,year,const DeepCollectionEquality().hash(_genres),voiceover,seriesInfo,description,posterUrl);

@override
String toString() {
  return 'AnimeDetailDto(id: $id, slug: $slug, title: $title, isOngoing: $isOngoing, year: $year, genres: $genres, voiceover: $voiceover, seriesInfo: $seriesInfo, description: $description, posterUrl: $posterUrl)';
}


}

/// @nodoc
abstract mixin class _$AnimeDetailDtoCopyWith<$Res> implements $AnimeDetailDtoCopyWith<$Res> {
  factory _$AnimeDetailDtoCopyWith(_AnimeDetailDto value, $Res Function(_AnimeDetailDto) _then) = __$AnimeDetailDtoCopyWithImpl;
@override @useResult
$Res call({
 int id, String slug, String title,@JsonKey(name: 'is_ongoing') bool isOngoing, String? year, List<String>? genres, String? voiceover,@JsonKey(name: 'series_info') String? seriesInfo, String? description,@JsonKey(name: 'poster_url') String? posterUrl
});




}
/// @nodoc
class __$AnimeDetailDtoCopyWithImpl<$Res>
    implements _$AnimeDetailDtoCopyWith<$Res> {
  __$AnimeDetailDtoCopyWithImpl(this._self, this._then);

  final _AnimeDetailDto _self;
  final $Res Function(_AnimeDetailDto) _then;

/// Create a copy of AnimeDetailDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? slug = null,Object? title = null,Object? isOngoing = null,Object? year = freezed,Object? genres = freezed,Object? voiceover = freezed,Object? seriesInfo = freezed,Object? description = freezed,Object? posterUrl = freezed,}) {
  return _then(_AnimeDetailDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,isOngoing: null == isOngoing ? _self.isOngoing : isOngoing // ignore: cast_nullable_to_non_nullable
as bool,year: freezed == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as String?,genres: freezed == genres ? _self._genres : genres // ignore: cast_nullable_to_non_nullable
as List<String>?,voiceover: freezed == voiceover ? _self.voiceover : voiceover // ignore: cast_nullable_to_non_nullable
as String?,seriesInfo: freezed == seriesInfo ? _self.seriesInfo : seriesInfo // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,posterUrl: freezed == posterUrl ? _self.posterUrl : posterUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
