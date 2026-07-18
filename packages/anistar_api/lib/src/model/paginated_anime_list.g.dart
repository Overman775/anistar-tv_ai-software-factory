// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paginated_anime_list.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PaginatedAnimeList extends PaginatedAnimeList {
  @override
  final BuiltList<AnimeListItem>? items;
  @override
  final int currentPage;
  @override
  final bool hasNext;
  @override
  final bool hasPrev;

  factory _$PaginatedAnimeList(
          [void Function(PaginatedAnimeListBuilder)? updates]) =>
      (PaginatedAnimeListBuilder()..update(updates))._build();

  _$PaginatedAnimeList._(
      {this.items,
      required this.currentPage,
      required this.hasNext,
      required this.hasPrev})
      : super._();
  @override
  PaginatedAnimeList rebuild(
          void Function(PaginatedAnimeListBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PaginatedAnimeListBuilder toBuilder() =>
      PaginatedAnimeListBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PaginatedAnimeList &&
        items == other.items &&
        currentPage == other.currentPage &&
        hasNext == other.hasNext &&
        hasPrev == other.hasPrev;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, items.hashCode);
    _$hash = $jc(_$hash, currentPage.hashCode);
    _$hash = $jc(_$hash, hasNext.hashCode);
    _$hash = $jc(_$hash, hasPrev.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PaginatedAnimeList')
          ..add('items', items)
          ..add('currentPage', currentPage)
          ..add('hasNext', hasNext)
          ..add('hasPrev', hasPrev))
        .toString();
  }
}

class PaginatedAnimeListBuilder
    implements Builder<PaginatedAnimeList, PaginatedAnimeListBuilder> {
  _$PaginatedAnimeList? _$v;

  ListBuilder<AnimeListItem>? _items;
  ListBuilder<AnimeListItem> get items =>
      _$this._items ??= ListBuilder<AnimeListItem>();
  set items(ListBuilder<AnimeListItem>? items) => _$this._items = items;

  int? _currentPage;
  int? get currentPage => _$this._currentPage;
  set currentPage(int? currentPage) => _$this._currentPage = currentPage;

  bool? _hasNext;
  bool? get hasNext => _$this._hasNext;
  set hasNext(bool? hasNext) => _$this._hasNext = hasNext;

  bool? _hasPrev;
  bool? get hasPrev => _$this._hasPrev;
  set hasPrev(bool? hasPrev) => _$this._hasPrev = hasPrev;

  PaginatedAnimeListBuilder() {
    PaginatedAnimeList._defaults(this);
  }

  PaginatedAnimeListBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _items = $v.items?.toBuilder();
      _currentPage = $v.currentPage;
      _hasNext = $v.hasNext;
      _hasPrev = $v.hasPrev;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PaginatedAnimeList other) {
    _$v = other as _$PaginatedAnimeList;
  }

  @override
  void update(void Function(PaginatedAnimeListBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PaginatedAnimeList build() => _build();

  _$PaginatedAnimeList _build() {
    _$PaginatedAnimeList _$result;
    try {
      _$result = _$v ??
          _$PaginatedAnimeList._(
            items: _items?.build(),
            currentPage: BuiltValueNullFieldError.checkNotNull(
                currentPage, r'PaginatedAnimeList', 'currentPage'),
            hasNext: BuiltValueNullFieldError.checkNotNull(
                hasNext, r'PaginatedAnimeList', 'hasNext'),
            hasPrev: BuiltValueNullFieldError.checkNotNull(
                hasPrev, r'PaginatedAnimeList', 'hasPrev'),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'items';
        _items?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'PaginatedAnimeList', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
