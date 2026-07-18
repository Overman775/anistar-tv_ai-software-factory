// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_info.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PlaybackInfo extends PlaybackInfo {
  @override
  final int animeId;
  @override
  final int episodeNumber;
  @override
  final QualityType requestedQuality;
  @override
  final QualityType selectedQuality;
  @override
  final BuiltList<QualityType> availableQualities;
  @override
  final String manifestPath;
  @override
  final int segmentTokenTtlSeconds;

  factory _$PlaybackInfo([void Function(PlaybackInfoBuilder)? updates]) =>
      (PlaybackInfoBuilder()..update(updates))._build();

  _$PlaybackInfo._(
      {required this.animeId,
      required this.episodeNumber,
      required this.requestedQuality,
      required this.selectedQuality,
      required this.availableQualities,
      required this.manifestPath,
      required this.segmentTokenTtlSeconds})
      : super._();
  @override
  PlaybackInfo rebuild(void Function(PlaybackInfoBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PlaybackInfoBuilder toBuilder() => PlaybackInfoBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PlaybackInfo &&
        animeId == other.animeId &&
        episodeNumber == other.episodeNumber &&
        requestedQuality == other.requestedQuality &&
        selectedQuality == other.selectedQuality &&
        availableQualities == other.availableQualities &&
        manifestPath == other.manifestPath &&
        segmentTokenTtlSeconds == other.segmentTokenTtlSeconds;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, animeId.hashCode);
    _$hash = $jc(_$hash, episodeNumber.hashCode);
    _$hash = $jc(_$hash, requestedQuality.hashCode);
    _$hash = $jc(_$hash, selectedQuality.hashCode);
    _$hash = $jc(_$hash, availableQualities.hashCode);
    _$hash = $jc(_$hash, manifestPath.hashCode);
    _$hash = $jc(_$hash, segmentTokenTtlSeconds.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PlaybackInfo')
          ..add('animeId', animeId)
          ..add('episodeNumber', episodeNumber)
          ..add('requestedQuality', requestedQuality)
          ..add('selectedQuality', selectedQuality)
          ..add('availableQualities', availableQualities)
          ..add('manifestPath', manifestPath)
          ..add('segmentTokenTtlSeconds', segmentTokenTtlSeconds))
        .toString();
  }
}

class PlaybackInfoBuilder
    implements Builder<PlaybackInfo, PlaybackInfoBuilder> {
  _$PlaybackInfo? _$v;

  int? _animeId;
  int? get animeId => _$this._animeId;
  set animeId(int? animeId) => _$this._animeId = animeId;

  int? _episodeNumber;
  int? get episodeNumber => _$this._episodeNumber;
  set episodeNumber(int? episodeNumber) =>
      _$this._episodeNumber = episodeNumber;

  QualityType? _requestedQuality;
  QualityType? get requestedQuality => _$this._requestedQuality;
  set requestedQuality(QualityType? requestedQuality) =>
      _$this._requestedQuality = requestedQuality;

  QualityType? _selectedQuality;
  QualityType? get selectedQuality => _$this._selectedQuality;
  set selectedQuality(QualityType? selectedQuality) =>
      _$this._selectedQuality = selectedQuality;

  ListBuilder<QualityType>? _availableQualities;
  ListBuilder<QualityType> get availableQualities =>
      _$this._availableQualities ??= ListBuilder<QualityType>();
  set availableQualities(ListBuilder<QualityType>? availableQualities) =>
      _$this._availableQualities = availableQualities;

  String? _manifestPath;
  String? get manifestPath => _$this._manifestPath;
  set manifestPath(String? manifestPath) => _$this._manifestPath = manifestPath;

  int? _segmentTokenTtlSeconds;
  int? get segmentTokenTtlSeconds => _$this._segmentTokenTtlSeconds;
  set segmentTokenTtlSeconds(int? segmentTokenTtlSeconds) =>
      _$this._segmentTokenTtlSeconds = segmentTokenTtlSeconds;

  PlaybackInfoBuilder() {
    PlaybackInfo._defaults(this);
  }

  PlaybackInfoBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _animeId = $v.animeId;
      _episodeNumber = $v.episodeNumber;
      _requestedQuality = $v.requestedQuality;
      _selectedQuality = $v.selectedQuality;
      _availableQualities = $v.availableQualities.toBuilder();
      _manifestPath = $v.manifestPath;
      _segmentTokenTtlSeconds = $v.segmentTokenTtlSeconds;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PlaybackInfo other) {
    _$v = other as _$PlaybackInfo;
  }

  @override
  void update(void Function(PlaybackInfoBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PlaybackInfo build() => _build();

  _$PlaybackInfo _build() {
    _$PlaybackInfo _$result;
    try {
      _$result = _$v ??
          _$PlaybackInfo._(
            animeId: BuiltValueNullFieldError.checkNotNull(
                animeId, r'PlaybackInfo', 'animeId'),
            episodeNumber: BuiltValueNullFieldError.checkNotNull(
                episodeNumber, r'PlaybackInfo', 'episodeNumber'),
            requestedQuality: BuiltValueNullFieldError.checkNotNull(
                requestedQuality, r'PlaybackInfo', 'requestedQuality'),
            selectedQuality: BuiltValueNullFieldError.checkNotNull(
                selectedQuality, r'PlaybackInfo', 'selectedQuality'),
            availableQualities: availableQualities.build(),
            manifestPath: BuiltValueNullFieldError.checkNotNull(
                manifestPath, r'PlaybackInfo', 'manifestPath'),
            segmentTokenTtlSeconds: BuiltValueNullFieldError.checkNotNull(
                segmentTokenTtlSeconds,
                r'PlaybackInfo',
                'segmentTokenTtlSeconds'),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'availableQualities';
        availableQualities.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'PlaybackInfo', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
