// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'liveness_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const LivenessResponseStatusEnum _$livenessResponseStatusEnum_ok =
    const LivenessResponseStatusEnum._('ok');

LivenessResponseStatusEnum _$livenessResponseStatusEnumValueOf(String name) {
  switch (name) {
    case 'ok':
      return _$livenessResponseStatusEnum_ok;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<LivenessResponseStatusEnum> _$livenessResponseStatusEnumValues =
    BuiltSet<LivenessResponseStatusEnum>(const <LivenessResponseStatusEnum>[
  _$livenessResponseStatusEnum_ok,
]);

Serializer<LivenessResponseStatusEnum> _$livenessResponseStatusEnumSerializer =
    _$LivenessResponseStatusEnumSerializer();

class _$LivenessResponseStatusEnumSerializer
    implements PrimitiveSerializer<LivenessResponseStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'ok': 'ok',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'ok': 'ok',
  };

  @override
  final Iterable<Type> types = const <Type>[LivenessResponseStatusEnum];
  @override
  final String wireName = 'LivenessResponseStatusEnum';

  @override
  Object serialize(Serializers serializers, LivenessResponseStatusEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  LivenessResponseStatusEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      LivenessResponseStatusEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$LivenessResponse extends LivenessResponse {
  @override
  final LivenessResponseStatusEnum? status;
  @override
  final String service;
  @override
  final String timestamp;

  factory _$LivenessResponse(
          [void Function(LivenessResponseBuilder)? updates]) =>
      (LivenessResponseBuilder()..update(updates))._build();

  _$LivenessResponse._(
      {this.status, required this.service, required this.timestamp})
      : super._();
  @override
  LivenessResponse rebuild(void Function(LivenessResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  LivenessResponseBuilder toBuilder() =>
      LivenessResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is LivenessResponse &&
        status == other.status &&
        service == other.service &&
        timestamp == other.timestamp;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, service.hashCode);
    _$hash = $jc(_$hash, timestamp.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'LivenessResponse')
          ..add('status', status)
          ..add('service', service)
          ..add('timestamp', timestamp))
        .toString();
  }
}

class LivenessResponseBuilder
    implements Builder<LivenessResponse, LivenessResponseBuilder> {
  _$LivenessResponse? _$v;

  LivenessResponseStatusEnum? _status;
  LivenessResponseStatusEnum? get status => _$this._status;
  set status(LivenessResponseStatusEnum? status) => _$this._status = status;

  String? _service;
  String? get service => _$this._service;
  set service(String? service) => _$this._service = service;

  String? _timestamp;
  String? get timestamp => _$this._timestamp;
  set timestamp(String? timestamp) => _$this._timestamp = timestamp;

  LivenessResponseBuilder() {
    LivenessResponse._defaults(this);
  }

  LivenessResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _status = $v.status;
      _service = $v.service;
      _timestamp = $v.timestamp;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(LivenessResponse other) {
    _$v = other as _$LivenessResponse;
  }

  @override
  void update(void Function(LivenessResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  LivenessResponse build() => _build();

  _$LivenessResponse _build() {
    final _$result = _$v ??
        _$LivenessResponse._(
          status: status,
          service: BuiltValueNullFieldError.checkNotNull(
              service, r'LivenessResponse', 'service'),
          timestamp: BuiltValueNullFieldError.checkNotNull(
              timestamp, r'LivenessResponse', 'timestamp'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
