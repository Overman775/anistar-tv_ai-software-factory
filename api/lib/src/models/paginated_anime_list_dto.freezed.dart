// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'paginated_anime_list_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PaginatedAnimeListDto {

/// Current page number
@JsonKey(name: 'current_page') int get currentPage;/// Whether next page exists
@JsonKey(name: 'has_next') bool get hasNext;/// Whether previous page exists
@JsonKey(name: 'has_prev') bool get hasPrev; List<AnimeListItemDto>? get items;
/// Create a copy of PaginatedAnimeListDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaginatedAnimeListDtoCopyWith<PaginatedAnimeListDto> get copyWith => _$PaginatedAnimeListDtoCopyWithImpl<PaginatedAnimeListDto>(this as PaginatedAnimeListDto, _$identity);

  /// Serializes this PaginatedAnimeListDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaginatedAnimeListDto&&(identical(other.currentPage, currentPage) || other.currentPage == currentPage)&&(identical(other.hasNext, hasNext) || other.hasNext == hasNext)&&(identical(other.hasPrev, hasPrev) || other.hasPrev == hasPrev)&&const DeepCollectionEquality().equals(other.items, items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,currentPage,hasNext,hasPrev,const DeepCollectionEquality().hash(items));

@override
String toString() {
  return 'PaginatedAnimeListDto(currentPage: $currentPage, hasNext: $hasNext, hasPrev: $hasPrev, items: $items)';
}


}

/// @nodoc
abstract mixin class $PaginatedAnimeListDtoCopyWith<$Res>  {
  factory $PaginatedAnimeListDtoCopyWith(PaginatedAnimeListDto value, $Res Function(PaginatedAnimeListDto) _then) = _$PaginatedAnimeListDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'current_page') int currentPage,@JsonKey(name: 'has_next') bool hasNext,@JsonKey(name: 'has_prev') bool hasPrev, List<AnimeListItemDto>? items
});




}
/// @nodoc
class _$PaginatedAnimeListDtoCopyWithImpl<$Res>
    implements $PaginatedAnimeListDtoCopyWith<$Res> {
  _$PaginatedAnimeListDtoCopyWithImpl(this._self, this._then);

  final PaginatedAnimeListDto _self;
  final $Res Function(PaginatedAnimeListDto) _then;

/// Create a copy of PaginatedAnimeListDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? currentPage = null,Object? hasNext = null,Object? hasPrev = null,Object? items = freezed,}) {
  return _then(_self.copyWith(
currentPage: null == currentPage ? _self.currentPage : currentPage // ignore: cast_nullable_to_non_nullable
as int,hasNext: null == hasNext ? _self.hasNext : hasNext // ignore: cast_nullable_to_non_nullable
as bool,hasPrev: null == hasPrev ? _self.hasPrev : hasPrev // ignore: cast_nullable_to_non_nullable
as bool,items: freezed == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<AnimeListItemDto>?,
  ));
}

}


/// Adds pattern-matching-related methods to [PaginatedAnimeListDto].
extension PaginatedAnimeListDtoPatterns on PaginatedAnimeListDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaginatedAnimeListDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaginatedAnimeListDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaginatedAnimeListDto value)  $default,){
final _that = this;
switch (_that) {
case _PaginatedAnimeListDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaginatedAnimeListDto value)?  $default,){
final _that = this;
switch (_that) {
case _PaginatedAnimeListDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'current_page')  int currentPage, @JsonKey(name: 'has_next')  bool hasNext, @JsonKey(name: 'has_prev')  bool hasPrev,  List<AnimeListItemDto>? items)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaginatedAnimeListDto() when $default != null:
return $default(_that.currentPage,_that.hasNext,_that.hasPrev,_that.items);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'current_page')  int currentPage, @JsonKey(name: 'has_next')  bool hasNext, @JsonKey(name: 'has_prev')  bool hasPrev,  List<AnimeListItemDto>? items)  $default,) {final _that = this;
switch (_that) {
case _PaginatedAnimeListDto():
return $default(_that.currentPage,_that.hasNext,_that.hasPrev,_that.items);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'current_page')  int currentPage, @JsonKey(name: 'has_next')  bool hasNext, @JsonKey(name: 'has_prev')  bool hasPrev,  List<AnimeListItemDto>? items)?  $default,) {final _that = this;
switch (_that) {
case _PaginatedAnimeListDto() when $default != null:
return $default(_that.currentPage,_that.hasNext,_that.hasPrev,_that.items);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PaginatedAnimeListDto implements PaginatedAnimeListDto {
  const _PaginatedAnimeListDto({@JsonKey(name: 'current_page') required this.currentPage, @JsonKey(name: 'has_next') required this.hasNext, @JsonKey(name: 'has_prev') required this.hasPrev, final  List<AnimeListItemDto>? items}): _items = items;
  factory _PaginatedAnimeListDto.fromJson(Map<String, dynamic> json) => _$PaginatedAnimeListDtoFromJson(json);

/// Current page number
@override@JsonKey(name: 'current_page') final  int currentPage;
/// Whether next page exists
@override@JsonKey(name: 'has_next') final  bool hasNext;
/// Whether previous page exists
@override@JsonKey(name: 'has_prev') final  bool hasPrev;
 final  List<AnimeListItemDto>? _items;
@override List<AnimeListItemDto>? get items {
  final value = _items;
  if (value == null) return null;
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of PaginatedAnimeListDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaginatedAnimeListDtoCopyWith<_PaginatedAnimeListDto> get copyWith => __$PaginatedAnimeListDtoCopyWithImpl<_PaginatedAnimeListDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PaginatedAnimeListDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaginatedAnimeListDto&&(identical(other.currentPage, currentPage) || other.currentPage == currentPage)&&(identical(other.hasNext, hasNext) || other.hasNext == hasNext)&&(identical(other.hasPrev, hasPrev) || other.hasPrev == hasPrev)&&const DeepCollectionEquality().equals(other._items, _items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,currentPage,hasNext,hasPrev,const DeepCollectionEquality().hash(_items));

@override
String toString() {
  return 'PaginatedAnimeListDto(currentPage: $currentPage, hasNext: $hasNext, hasPrev: $hasPrev, items: $items)';
}


}

/// @nodoc
abstract mixin class _$PaginatedAnimeListDtoCopyWith<$Res> implements $PaginatedAnimeListDtoCopyWith<$Res> {
  factory _$PaginatedAnimeListDtoCopyWith(_PaginatedAnimeListDto value, $Res Function(_PaginatedAnimeListDto) _then) = __$PaginatedAnimeListDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'current_page') int currentPage,@JsonKey(name: 'has_next') bool hasNext,@JsonKey(name: 'has_prev') bool hasPrev, List<AnimeListItemDto>? items
});




}
/// @nodoc
class __$PaginatedAnimeListDtoCopyWithImpl<$Res>
    implements _$PaginatedAnimeListDtoCopyWith<$Res> {
  __$PaginatedAnimeListDtoCopyWithImpl(this._self, this._then);

  final _PaginatedAnimeListDto _self;
  final $Res Function(_PaginatedAnimeListDto) _then;

/// Create a copy of PaginatedAnimeListDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? currentPage = null,Object? hasNext = null,Object? hasPrev = null,Object? items = freezed,}) {
  return _then(_PaginatedAnimeListDto(
currentPage: null == currentPage ? _self.currentPage : currentPage // ignore: cast_nullable_to_non_nullable
as int,hasNext: null == hasNext ? _self.hasNext : hasNext // ignore: cast_nullable_to_non_nullable
as bool,hasPrev: null == hasPrev ? _self.hasPrev : hasPrev // ignore: cast_nullable_to_non_nullable
as bool,items: freezed == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<AnimeListItemDto>?,
  ));
}


}

// dart format on
