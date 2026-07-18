// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'error_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ErrorResponse extends ErrorResponse {
  @override
  final String error;
  @override
  final String detail;
  @override
  final String path;

  factory _$ErrorResponse([void Function(ErrorResponseBuilder)? updates]) =>
      (ErrorResponseBuilder()..update(updates))._build();

  _$ErrorResponse._(
      {required this.error, required this.detail, required this.path})
      : super._();
  @override
  ErrorResponse rebuild(void Function(ErrorResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ErrorResponseBuilder toBuilder() => ErrorResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ErrorResponse &&
        error == other.error &&
        detail == other.detail &&
        path == other.path;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, error.hashCode);
    _$hash = $jc(_$hash, detail.hashCode);
    _$hash = $jc(_$hash, path.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ErrorResponse')
          ..add('error', error)
          ..add('detail', detail)
          ..add('path', path))
        .toString();
  }
}

class ErrorResponseBuilder
    implements Builder<ErrorResponse, ErrorResponseBuilder> {
  _$ErrorResponse? _$v;

  String? _error;
  String? get error => _$this._error;
  set error(String? error) => _$this._error = error;

  String? _detail;
  String? get detail => _$this._detail;
  set detail(String? detail) => _$this._detail = detail;

  String? _path;
  String? get path => _$this._path;
  set path(String? path) => _$this._path = path;

  ErrorResponseBuilder() {
    ErrorResponse._defaults(this);
  }

  ErrorResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _error = $v.error;
      _detail = $v.detail;
      _path = $v.path;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ErrorResponse other) {
    _$v = other as _$ErrorResponse;
  }

  @override
  void update(void Function(ErrorResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ErrorResponse build() => _build();

  _$ErrorResponse _build() {
    final _$result = _$v ??
        _$ErrorResponse._(
          error: BuiltValueNullFieldError.checkNotNull(
              error, r'ErrorResponse', 'error'),
          detail: BuiltValueNullFieldError.checkNotNull(
              detail, r'ErrorResponse', 'detail'),
          path: BuiltValueNullFieldError.checkNotNull(
              path, r'ErrorResponse', 'path'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
