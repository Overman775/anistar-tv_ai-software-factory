import 'dart:async';

import 'package:dio/dio.dart';
import 'package:storage/storage.dart';

import 'anistar_failure.dart';
import 'anistar_html_parser.dart';
import 'html_decoder.dart';

/// Only discovers the numbered astar.bz family. Probes never carry a session.
final class AnistarMirrorManager {
  static const storageKey = 'anistar.mirror.astar.bz.version';
  final SharedPreferencesStorage storage;
  final int maxNextVersions;
  static const _unavailable = AnistarFailure(
    message:
        'AniStar недоступен: текущее и следующие зеркала не отвечают. Проверьте интернет и повторите через минуту.',
  );
  final Dio _probe;
  final DateTime Function() _now;
  final StreamController<Uri> _changes = StreamController<Uri>.broadcast();
  final Uri _baseline;
  Uri _current;
  bool _checked = false;
  DateTime? _failedAt;
  Future<void>? _pending;

  Uri get current => _current;
  Stream<Uri> get changes => _changes.stream;
  bool get enabled => _version(_baseline) != null;

  AnistarMirrorManager({
    required Uri initial,
    required this.storage,
    required this._probe,
    this.maxNextVersions = 4,
    DateTime Function()? now,
  }) : _baseline = initial,
       _current = initial,
       _now = now ?? DateTime.now {
    if (maxNextVersions < 1 || maxNextVersions > 10) {
      throw ArgumentError.value(maxNextVersions, 'maxNextVersions');
    }
  }

  Future<void> initialize() async {
    final baseline = _version(_baseline);
    if (baseline == null) {
      return;
    }
    final cached = await storage.get<int>(storageKey, baseline);
    if (cached >= baseline && cached <= 9999) {
      _current = _at(cached);
    }
  }

  Future<void> ensureAvailable() => !enabled || _checked ? Future<void>.value() : _find();

  /// Validate the catalog before treating a single endpoint's failure as a block.
  Future<void> recover(Uri failedOrigin) {
    if (!enabled || failedOrigin.origin != current.origin) {
      return Future<void>.value();
    }

    return _find();
  }

  Future<void> close() async {
    _probe.close(force: true);
    await _changes.close();
  }

  Future<void> _find() {
    final pending = _pending;
    if (pending != null) {
      return pending;
    }
    final failedAt = _failedAt;
    if (failedAt != null && _now().difference(failedAt) < const Duration(minutes: 1)) {
      return Future<void>.error(_unavailable);
    }
    final result = _search();
    _pending = result;
    unawaited(result.then<void>((_) => _pending = null, onError: (Object _) => _pending = null));

    return result;
  }

  Future<void> _search() async {
    final starting = current;
    final version = _version(starting);
    if (version == null) {
      return;
    }
    for (var offset = 0; offset <= maxNextVersions && version + offset <= 9999; offset++) {
      final candidate = _at(version + offset);
      if (!await _available(candidate)) {
        continue;
      }
      await storage.set(storageKey, version + offset);
      _checked = true;
      _failedAt = null;
      _current = candidate;
      if (candidate.origin != starting.origin) {
        _changes.add(candidate);
      }

      return;
    }
    _checked = false;
    _failedAt = _now();
    throw _unavailable;
  }

  Future<bool> _available(Uri origin) async {
    try {
      final response = await _probe.get<List<int>>(
        origin.resolve('anime/').toString(),
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: false,
          validateStatus: (status) => status == 200,
          headers: const {'Accept': 'text/html', 'User-Agent': 'AniStarTV/1.0', 'Cache-Control': 'no-cache'},
        ),
      );
      if (response.headers.value('cf-mitigated') == 'challenge') {
        return false;
      }
      final html = HtmlDecoder.decode(response.data ?? const [], response.headers.value('content-type'));
      final catalog = AnistarHtmlParser(origin).catalog(html, 1);

      return catalog.items.isNotEmpty;
    } on DioException {
      return false;
    } on AnistarFailure {
      return false;
    } on FormatException {
      return false;
    }
  }

  static int? _version(Uri uri) {
    if (uri.scheme != 'https' || uri.hasPort || uri.userInfo.isNotEmpty) {
      return null;
    }
    final match = RegExp(r'^v([1-9]\d{0,3})\.astar\.bz$').firstMatch(uri.host);

    final digits = match?.group(1);

    return digits == null ? null : int.tryParse(digits);
  }

  static Uri _at(int version) => Uri.parse('https://v$version.astar.bz/');
}
