// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'anime_list_item.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AnimeListItem extends AnimeListItem {
  @override
  final int id;
  @override
  final String slug;
  @override
  final String title;
  @override
  final String? year;
  @override
  final String posterUrl;

  factory _$AnimeListItem([void Function(AnimeListItemBuilder)? updates]) =>
      (AnimeListItemBuilder()..update(updates))._build();

  _$AnimeListItem._(
      {required this.id,
      required this.slug,
      required this.title,
      this.year,
      required this.posterUrl})
      : super._();
  @override
  AnimeListItem rebuild(void Function(AnimeListItemBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  AnimeListItemBuilder toBuilder() => AnimeListItemBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AnimeListItem &&
        id == other.id &&
        slug == other.slug &&
        title == other.title &&
        year == other.year &&
        posterUrl == other.posterUrl;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, slug.hashCode);
    _$hash = $jc(_$hash, title.hashCode);
    _$hash = $jc(_$hash, year.hashCode);
    _$hash = $jc(_$hash, posterUrl.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AnimeListItem')
          ..add('id', id)
          ..add('slug', slug)
          ..add('title', title)
          ..add('year', year)
          ..add('posterUrl', posterUrl))
        .toString();
  }
}

class AnimeListItemBuilder
    implements Builder<AnimeListItem, AnimeListItemBuilder> {
  _$AnimeListItem? _$v;

  int? _id;
  int? get id => _$this._id;
  set id(int? id) => _$this._id = id;

  String? _slug;
  String? get slug => _$this._slug;
  set slug(String? slug) => _$this._slug = slug;

  String? _title;
  String? get title => _$this._title;
  set title(String? title) => _$this._title = title;

  String? _year;
  String? get year => _$this._year;
  set year(String? year) => _$this._year = year;

  String? _posterUrl;
  String? get posterUrl => _$this._posterUrl;
  set posterUrl(String? posterUrl) => _$this._posterUrl = posterUrl;

  AnimeListItemBuilder() {
    AnimeListItem._defaults(this);
  }

  AnimeListItemBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _slug = $v.slug;
      _title = $v.title;
      _year = $v.year;
      _posterUrl = $v.posterUrl;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AnimeListItem other) {
    _$v = other as _$AnimeListItem;
  }

  @override
  void update(void Function(AnimeListItemBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AnimeListItem build() => _build();

  _$AnimeListItem _build() {
    final _$result = _$v ??
        _$AnimeListItem._(
          id: BuiltValueNullFieldError.checkNotNull(id, r'AnimeListItem', 'id'),
          slug: BuiltValueNullFieldError.checkNotNull(
              slug, r'AnimeListItem', 'slug'),
          title: BuiltValueNullFieldError.checkNotNull(
              title, r'AnimeListItem', 'title'),
          year: year,
          posterUrl: BuiltValueNullFieldError.checkNotNull(
              posterUrl, r'AnimeListItem', 'posterUrl'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
