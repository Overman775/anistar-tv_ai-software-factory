// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'series_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Series {

 String get seriesNumber;// Using String as it might contain non-numeric parts like "OVA" or "Special"
 String get title; String get dataUrl;
/// Create a copy of Series
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SeriesCopyWith<Series> get copyWith => _$SeriesCopyWithImpl<Series>(this as Series, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Series&&(identical(other.seriesNumber, seriesNumber) || other.seriesNumber == seriesNumber)&&(identical(other.title, title) || other.title == title)&&(identical(other.dataUrl, dataUrl) || other.dataUrl == dataUrl));
}


@override
int get hashCode => Object.hash(runtimeType,seriesNumber,title,dataUrl);

@override
String toString() {
  return 'Series(seriesNumber: $seriesNumber, title: $title, dataUrl: $dataUrl)';
}


}

/// @nodoc
abstract mixin class $SeriesCopyWith<$Res>  {
  factory $SeriesCopyWith(Series value, $Res Function(Series) _then) = _$SeriesCopyWithImpl;
@useResult
$Res call({
 String seriesNumber, String title, String dataUrl
});




}
/// @nodoc
class _$SeriesCopyWithImpl<$Res>
    implements $SeriesCopyWith<$Res> {
  _$SeriesCopyWithImpl(this._self, this._then);

  final Series _self;
  final $Res Function(Series) _then;

/// Create a copy of Series
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? seriesNumber = null,Object? title = null,Object? dataUrl = null,}) {
  return _then(_self.copyWith(
seriesNumber: null == seriesNumber ? _self.seriesNumber : seriesNumber // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,dataUrl: null == dataUrl ? _self.dataUrl : dataUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// @nodoc


class _Series implements Series {
  const _Series({required this.seriesNumber, required this.title, required this.dataUrl});
  

@override final  String seriesNumber;
// Using String as it might contain non-numeric parts like "OVA" or "Special"
@override final  String title;
@override final  String dataUrl;

/// Create a copy of Series
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SeriesCopyWith<_Series> get copyWith => __$SeriesCopyWithImpl<_Series>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Series&&(identical(other.seriesNumber, seriesNumber) || other.seriesNumber == seriesNumber)&&(identical(other.title, title) || other.title == title)&&(identical(other.dataUrl, dataUrl) || other.dataUrl == dataUrl));
}


@override
int get hashCode => Object.hash(runtimeType,seriesNumber,title,dataUrl);

@override
String toString() {
  return 'Series(seriesNumber: $seriesNumber, title: $title, dataUrl: $dataUrl)';
}


}

/// @nodoc
abstract mixin class _$SeriesCopyWith<$Res> implements $SeriesCopyWith<$Res> {
  factory _$SeriesCopyWith(_Series value, $Res Function(_Series) _then) = __$SeriesCopyWithImpl;
@override @useResult
$Res call({
 String seriesNumber, String title, String dataUrl
});




}
/// @nodoc
class __$SeriesCopyWithImpl<$Res>
    implements _$SeriesCopyWith<$Res> {
  __$SeriesCopyWithImpl(this._self, this._then);

  final _Series _self;
  final $Res Function(_Series) _then;

/// Create a copy of Series
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? seriesNumber = null,Object? title = null,Object? dataUrl = null,}) {
  return _then(_Series(
seriesNumber: null == seriesNumber ? _self.seriesNumber : seriesNumber // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,dataUrl: null == dataUrl ? _self.dataUrl : dataUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
