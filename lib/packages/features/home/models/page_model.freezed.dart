// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'page_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PageModel {

 List<VideoModel> get videos; String get title; bool get hasMorePages;
/// Create a copy of PageModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PageModelCopyWith<PageModel> get copyWith => _$PageModelCopyWithImpl<PageModel>(this as PageModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PageModel&&const DeepCollectionEquality().equals(other.videos, videos)&&(identical(other.title, title) || other.title == title)&&(identical(other.hasMorePages, hasMorePages) || other.hasMorePages == hasMorePages));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(videos),title,hasMorePages);

@override
String toString() {
  return 'PageModel(videos: $videos, title: $title, hasMorePages: $hasMorePages)';
}


}

/// @nodoc
abstract mixin class $PageModelCopyWith<$Res>  {
  factory $PageModelCopyWith(PageModel value, $Res Function(PageModel) _then) = _$PageModelCopyWithImpl;
@useResult
$Res call({
 List<VideoModel> videos, String title, bool hasMorePages
});




}
/// @nodoc
class _$PageModelCopyWithImpl<$Res>
    implements $PageModelCopyWith<$Res> {
  _$PageModelCopyWithImpl(this._self, this._then);

  final PageModel _self;
  final $Res Function(PageModel) _then;

/// Create a copy of PageModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? videos = null,Object? title = null,Object? hasMorePages = null,}) {
  return _then(_self.copyWith(
videos: null == videos ? _self.videos : videos // ignore: cast_nullable_to_non_nullable
as List<VideoModel>,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,hasMorePages: null == hasMorePages ? _self.hasMorePages : hasMorePages // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// @nodoc


class _PageModel implements PageModel {
  const _PageModel({required final  List<VideoModel> videos, required this.title, required this.hasMorePages}): _videos = videos;
  

 final  List<VideoModel> _videos;
@override List<VideoModel> get videos {
  if (_videos is EqualUnmodifiableListView) return _videos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_videos);
}

@override final  String title;
@override final  bool hasMorePages;

/// Create a copy of PageModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PageModelCopyWith<_PageModel> get copyWith => __$PageModelCopyWithImpl<_PageModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PageModel&&const DeepCollectionEquality().equals(other._videos, _videos)&&(identical(other.title, title) || other.title == title)&&(identical(other.hasMorePages, hasMorePages) || other.hasMorePages == hasMorePages));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_videos),title,hasMorePages);

@override
String toString() {
  return 'PageModel(videos: $videos, title: $title, hasMorePages: $hasMorePages)';
}


}

/// @nodoc
abstract mixin class _$PageModelCopyWith<$Res> implements $PageModelCopyWith<$Res> {
  factory _$PageModelCopyWith(_PageModel value, $Res Function(_PageModel) _then) = __$PageModelCopyWithImpl;
@override @useResult
$Res call({
 List<VideoModel> videos, String title, bool hasMorePages
});




}
/// @nodoc
class __$PageModelCopyWithImpl<$Res>
    implements _$PageModelCopyWith<$Res> {
  __$PageModelCopyWithImpl(this._self, this._then);

  final _PageModel _self;
  final $Res Function(_PageModel) _then;

/// Create a copy of PageModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? videos = null,Object? title = null,Object? hasMorePages = null,}) {
  return _then(_PageModel(
videos: null == videos ? _self._videos : videos // ignore: cast_nullable_to_non_nullable
as List<VideoModel>,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,hasMorePages: null == hasMorePages ? _self.hasMorePages : hasMorePages // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
