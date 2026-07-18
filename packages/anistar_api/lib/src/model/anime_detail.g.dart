// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'anime_detail.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AnimeDetail extends AnimeDetail {
  @override
  final int id;
  @override
  final String slug;
  @override
  final String title;
  @override
  final String? year;
  @override
  final BuiltList<String>? genres;
  @override
  final String? voiceover;
  @override
  final String? seriesInfo;
  @override
  final String? description;
  @override
  final bool? isOngoing;
  @override
  final String? posterUrl;

  factory _$AnimeDetail([void Function(AnimeDetailBuilder)? updates]) =>
      (AnimeDetailBuilder()..update(updates))._build();

  _$AnimeDetail._(
      {required this.id,
      required this.slug,
      required this.title,
      this.year,
      this.genres,
      this.voiceover,
      this.seriesInfo,
      this.description,
      this.isOngoing,
      this.posterUrl})
      : super._();
  @override
  AnimeDetail rebuild(void Function(AnimeDetailBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  AnimeDetailBuilder toBuilder() => AnimeDetailBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AnimeDetail &&
        id == other.id &&
        slug == other.slug &&
        title == other.title &&
        year == other.year &&
        genres == other.genres &&
        voiceover == other.voiceover &&
        seriesInfo == other.seriesInfo &&
        description == other.description &&
        isOngoing == other.isOngoing &&
        posterUrl == other.posterUrl;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, slug.hashCode);
    _$hash = $jc(_$hash, title.hashCode);
    _$hash = $jc(_$hash, year.hashCode);
    _$hash = $jc(_$hash, genres.hashCode);
    _$hash = $jc(_$hash, voiceover.hashCode);
    _$hash = $jc(_$hash, seriesInfo.hashCode);
    _$hash = $jc(_$hash, description.hashCode);
    _$hash = $jc(_$hash, isOngoing.hashCode);
    _$hash = $jc(_$hash, posterUrl.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AnimeDetail')
          ..add('id', id)
          ..add('slug', slug)
          ..add('title', title)
          ..add('year', year)
          ..add('genres', genres)
          ..add('voiceover', voiceover)
          ..add('seriesInfo', seriesInfo)
          ..add('description', description)
          ..add('isOngoing', isOngoing)
          ..add('posterUrl', posterUrl))
        .toString();
  }
}

class AnimeDetailBuilder implements Builder<AnimeDetail, AnimeDetailBuilder> {
  _$AnimeDetail? _$v;

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

  ListBuilder<String>? _genres;
  ListBuilder<String> get genres => _$this._genres ??= ListBuilder<String>();
  set genres(ListBuilder<String>? genres) => _$this._genres = genres;

  String? _voiceover;
  String? get voiceover => _$this._voiceover;
  set voiceover(String? voiceover) => _$this._voiceover = voiceover;

  String? _seriesInfo;
  String? get seriesInfo => _$this._seriesInfo;
  set seriesInfo(String? seriesInfo) => _$this._seriesInfo = seriesInfo;

  String? _description;
  String? get description => _$this._description;
  set description(String? description) => _$this._description = description;

  bool? _isOngoing;
  bool? get isOngoing => _$this._isOngoing;
  set isOngoing(bool? isOngoing) => _$this._isOngoing = isOngoing;

  String? _posterUrl;
  String? get posterUrl => _$this._posterUrl;
  set posterUrl(String? posterUrl) => _$this._posterUrl = posterUrl;

  AnimeDetailBuilder() {
    AnimeDetail._defaults(this);
  }

  AnimeDetailBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _slug = $v.slug;
      _title = $v.title;
      _year = $v.year;
      _genres = $v.genres?.toBuilder();
      _voiceover = $v.voiceover;
      _seriesInfo = $v.seriesInfo;
      _description = $v.description;
      _isOngoing = $v.isOngoing;
      _posterUrl = $v.posterUrl;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AnimeDetail other) {
    _$v = other as _$AnimeDetail;
  }

  @override
  void update(void Function(AnimeDetailBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AnimeDetail build() => _build();

  _$AnimeDetail _build() {
    _$AnimeDetail _$result;
    try {
      _$result = _$v ??
          _$AnimeDetail._(
            id: BuiltValueNullFieldError.checkNotNull(id, r'AnimeDetail', 'id'),
            slug: BuiltValueNullFieldError.checkNotNull(
                slug, r'AnimeDetail', 'slug'),
            title: BuiltValueNullFieldError.checkNotNull(
                title, r'AnimeDetail', 'title'),
            year: year,
            genres: _genres?.build(),
            voiceover: voiceover,
            seriesInfo: seriesInfo,
            description: description,
            isOngoing: isOngoing,
            posterUrl: posterUrl,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'genres';
        _genres?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'AnimeDetail', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
