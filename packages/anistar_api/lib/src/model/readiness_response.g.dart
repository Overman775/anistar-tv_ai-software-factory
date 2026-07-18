// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'readiness_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const ReadinessResponseStatusEnum _$readinessResponseStatusEnum_ok =
    const ReadinessResponseStatusEnum._('ok');
const ReadinessResponseStatusEnum _$readinessResponseStatusEnum_degraded =
    const ReadinessResponseStatusEnum._('degraded');

ReadinessResponseStatusEnum _$readinessResponseStatusEnumValueOf(String name) {
  switch (name) {
    case 'ok':
      return _$readinessResponseStatusEnum_ok;
    case 'degraded':
      return _$readinessResponseStatusEnum_degraded;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<ReadinessResponseStatusEnum>
    _$readinessResponseStatusEnumValues =
    BuiltSet<ReadinessResponseStatusEnum>(const <ReadinessResponseStatusEnum>[
  _$readinessResponseStatusEnum_ok,
  _$readinessResponseStatusEnum_degraded,
]);

const ReadinessResponseAnistarEnum _$readinessResponseAnistarEnum_ok =
    const ReadinessResponseAnistarEnum._('ok');
const ReadinessResponseAnistarEnum _$readinessResponseAnistarEnum_degraded =
    const ReadinessResponseAnistarEnum._('degraded');
const ReadinessResponseAnistarEnum _$readinessResponseAnistarEnum_unreachable =
    const ReadinessResponseAnistarEnum._('unreachable');

ReadinessResponseAnistarEnum _$readinessResponseAnistarEnumValueOf(
    String name) {
  switch (name) {
    case 'ok':
      return _$readinessResponseAnistarEnum_ok;
    case 'degraded':
      return _$readinessResponseAnistarEnum_degraded;
    case 'unreachable':
      return _$readinessResponseAnistarEnum_unreachable;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<ReadinessResponseAnistarEnum>
    _$readinessResponseAnistarEnumValues =
    BuiltSet<ReadinessResponseAnistarEnum>(const <ReadinessResponseAnistarEnum>[
  _$readinessResponseAnistarEnum_ok,
  _$readinessResponseAnistarEnum_degraded,
  _$readinessResponseAnistarEnum_unreachable,
]);

Serializer<ReadinessResponseStatusEnum>
    _$readinessResponseStatusEnumSerializer =
    _$ReadinessResponseStatusEnumSerializer();
Serializer<ReadinessResponseAnistarEnum>
    _$readinessResponseAnistarEnumSerializer =
    _$ReadinessResponseAnistarEnumSerializer();

class _$ReadinessResponseStatusEnumSerializer
    implements PrimitiveSerializer<ReadinessResponseStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'ok': 'ok',
    'degraded': 'degraded',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'ok': 'ok',
    'degraded': 'degraded',
  };

  @override
  final Iterable<Type> types = const <Type>[ReadinessResponseStatusEnum];
  @override
  final String wireName = 'ReadinessResponseStatusEnum';

  @override
  Object serialize(Serializers serializers, ReadinessResponseStatusEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  ReadinessResponseStatusEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      ReadinessResponseStatusEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$ReadinessResponseAnistarEnumSerializer
    implements PrimitiveSerializer<ReadinessResponseAnistarEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'ok': 'ok',
    'degraded': 'degraded',
    'unreachable': 'unreachable',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'ok': 'ok',
    'degraded': 'degraded',
    'unreachable': 'unreachable',
  };

  @override
  final Iterable<Type> types = const <Type>[ReadinessResponseAnistarEnum];
  @override
  final String wireName = 'ReadinessResponseAnistarEnum';

  @override
  Object serialize(Serializers serializers, ReadinessResponseAnistarEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  ReadinessResponseAnistarEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      ReadinessResponseAnistarEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$ReadinessResponse extends ReadinessResponse {
  @override
  final ReadinessResponseStatusEnum status;
  @override
  final String service;
  @override
  final ReadinessResponseAnistarEnum anistar;
  @override
  final String timestamp;

  factory _$ReadinessResponse(
          [void Function(ReadinessResponseBuilder)? updates]) =>
      (ReadinessResponseBuilder()..update(updates))._build();

  _$ReadinessResponse._(
      {required this.status,
      required this.service,
      required this.anistar,
      required this.timestamp})
      : super._();
  @override
  ReadinessResponse rebuild(void Function(ReadinessResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ReadinessResponseBuilder toBuilder() =>
      ReadinessResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ReadinessResponse &&
        status == other.status &&
        service == other.service &&
        anistar == other.anistar &&
        timestamp == other.timestamp;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, service.hashCode);
    _$hash = $jc(_$hash, anistar.hashCode);
    _$hash = $jc(_$hash, timestamp.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ReadinessResponse')
          ..add('status', status)
          ..add('service', service)
          ..add('anistar', anistar)
          ..add('timestamp', timestamp))
        .toString();
  }
}

class ReadinessResponseBuilder
    implements Builder<ReadinessResponse, ReadinessResponseBuilder> {
  _$ReadinessResponse? _$v;

  ReadinessResponseStatusEnum? _status;
  ReadinessResponseStatusEnum? get status => _$this._status;
  set status(ReadinessResponseStatusEnum? status) => _$this._status = status;

  String? _service;
  String? get service => _$this._service;
  set service(String? service) => _$this._service = service;

  ReadinessResponseAnistarEnum? _anistar;
  ReadinessResponseAnistarEnum? get anistar => _$this._anistar;
  set anistar(ReadinessResponseAnistarEnum? anistar) =>
      _$this._anistar = anistar;

  String? _timestamp;
  String? get timestamp => _$this._timestamp;
  set timestamp(String? timestamp) => _$this._timestamp = timestamp;

  ReadinessResponseBuilder() {
    ReadinessResponse._defaults(this);
  }

  ReadinessResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _status = $v.status;
      _service = $v.service;
      _anistar = $v.anistar;
      _timestamp = $v.timestamp;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ReadinessResponse other) {
    _$v = other as _$ReadinessResponse;
  }

  @override
  void update(void Function(ReadinessResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ReadinessResponse build() => _build();

  _$ReadinessResponse _build() {
    final _$result = _$v ??
        _$ReadinessResponse._(
          status: BuiltValueNullFieldError.checkNotNull(
              status, r'ReadinessResponse', 'status'),
          service: BuiltValueNullFieldError.checkNotNull(
              service, r'ReadinessResponse', 'service'),
          anistar: BuiltValueNullFieldError.checkNotNull(
              anistar, r'ReadinessResponse', 'anistar'),
          timestamp: BuiltValueNullFieldError.checkNotNull(
              timestamp, r'ReadinessResponse', 'timestamp'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
