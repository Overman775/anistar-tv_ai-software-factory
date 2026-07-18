// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'episode_info.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$EpisodeInfo extends EpisodeInfo {
  @override
  final int episodeNumber;
  @override
  final String title;
  @override
  final String? previewUrl;
  @override
  final String playbackPath;

  factory _$EpisodeInfo([void Function(EpisodeInfoBuilder)? updates]) =>
      (EpisodeInfoBuilder()..update(updates))._build();

  _$EpisodeInfo._(
      {required this.episodeNumber,
      required this.title,
      this.previewUrl,
      required this.playbackPath})
      : super._();
  @override
  EpisodeInfo rebuild(void Function(EpisodeInfoBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  EpisodeInfoBuilder toBuilder() => EpisodeInfoBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is EpisodeInfo &&
        episodeNumber == other.episodeNumber &&
        title == other.title &&
        previewUrl == other.previewUrl &&
        playbackPath == other.playbackPath;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, episodeNumber.hashCode);
    _$hash = $jc(_$hash, title.hashCode);
    _$hash = $jc(_$hash, previewUrl.hashCode);
    _$hash = $jc(_$hash, playbackPath.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'EpisodeInfo')
          ..add('episodeNumber', episodeNumber)
          ..add('title', title)
          ..add('previewUrl', previewUrl)
          ..add('playbackPath', playbackPath))
        .toString();
  }
}

class EpisodeInfoBuilder implements Builder<EpisodeInfo, EpisodeInfoBuilder> {
  _$EpisodeInfo? _$v;

  int? _episodeNumber;
  int? get episodeNumber => _$this._episodeNumber;
  set episodeNumber(int? episodeNumber) =>
      _$this._episodeNumber = episodeNumber;

  String? _title;
  String? get title => _$this._title;
  set title(String? title) => _$this._title = title;

  String? _previewUrl;
  String? get previewUrl => _$this._previewUrl;
  set previewUrl(String? previewUrl) => _$this._previewUrl = previewUrl;

  String? _playbackPath;
  String? get playbackPath => _$this._playbackPath;
  set playbackPath(String? playbackPath) => _$this._playbackPath = playbackPath;

  EpisodeInfoBuilder() {
    EpisodeInfo._defaults(this);
  }

  EpisodeInfoBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _episodeNumber = $v.episodeNumber;
      _title = $v.title;
      _previewUrl = $v.previewUrl;
      _playbackPath = $v.playbackPath;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(EpisodeInfo other) {
    _$v = other as _$EpisodeInfo;
  }

  @override
  void update(void Function(EpisodeInfoBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  EpisodeInfo build() => _build();

  _$EpisodeInfo _build() {
    final _$result = _$v ??
        _$EpisodeInfo._(
          episodeNumber: BuiltValueNullFieldError.checkNotNull(
              episodeNumber, r'EpisodeInfo', 'episodeNumber'),
          title: BuiltValueNullFieldError.checkNotNull(
              title, r'EpisodeInfo', 'title'),
          previewUrl: previewUrl,
          playbackPath: BuiltValueNullFieldError.checkNotNull(
              playbackPath, r'EpisodeInfo', 'playbackPath'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
