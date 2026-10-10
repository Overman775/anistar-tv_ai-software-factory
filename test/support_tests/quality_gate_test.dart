import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory fixture;
  late File trace;
  late String expectedVersion;

  setUp(() async {
    final pin = (jsonDecode(File('.fvmrc').readAsStringSync()) as Map<String, Object?>)['flutter'];
    if (pin is! String) {
      throw const FormatException('Missing Flutter SDK pin');
    }
    expectedVersion = pin;
    fixture = Directory.systemTemp.createTempSync('anistar-quality-gate-');
    addTearDown(() => fixture.deleteSync(recursive: true));
    for (final path in ['scripts', 'tool/quality', 'lib', 'infrastructure', 'test', 'integration_test', 'sdk/bin']) {
      Directory('${fixture.path}/$path').createSync(recursive: true);
    }
    File('scripts/check.sh').copySync('${fixture.path}/scripts/check.sh');
    File('tool/quality/verify_sdk.dart').copySync('${fixture.path}/tool/quality/verify_sdk.dart');
    File('.fvmrc').copySync('${fixture.path}/.fvmrc');
    File('${fixture.path}/lib/example.dart').writeAsStringSync('void main() {}\n');
    trace = File('${fixture.path}/trace');
    final flutter = File('${fixture.path}/sdk/bin/flutter')..writeAsStringSync(_flutterStub.trimLeft());
    final sdk = Directory(Platform.environment['ANISTAR_FLUTTER_SDK'] ?? '.fvm/flutter_sdk').resolveSymbolicLinksSync();
    final dart = File('${fixture.path}/sdk/bin/dart')
      ..writeAsStringSync(_dartStub.trimLeft().replaceFirst('__DART__', "'$sdk/bin/dart'"));
    final chmod = await Process.run('chmod', ['+x', flutter.path, dart.path]);
    expect(chmod.exitCode, 0, reason: chmod.stderr.toString());
  });

  Future<ProcessResult> run(String mode, {Map<String, String> environment = const {}}) => Process.run(
    'bash',
    ['${fixture.path}/scripts/check.sh', mode],
    environment: {
      'ANISTAR_FLUTTER_SDK': '${fixture.path}/sdk',
      'ANISTAR_TEST_SEED': '20261010',
      'ANISTAR_GATE_TRACE': trace.path,
      'ANISTAR_GATE_VERSION': expectedVersion,
      ...environment,
    },
  );

  test('format failure stops before analyzer and preserves its exit code', () async {
    final result = await run('check', environment: {'ANISTAR_GATE_FORMAT_EXIT': '17'});
    expect(result.exitCode, 17, reason: result.stderr.toString());
    expect(trace.readAsLinesSync(), ['pub', 'format']);
  });

  test('analyzer failure stops before DCM and tests and preserves its exit code', () async {
    final result = await run('check', environment: {'ANISTAR_GATE_ANALYZE_EXIT': '23'});
    expect(result.exitCode, 23, reason: result.stderr.toString());
    expect(trace.readAsLinesSync(), ['pub', 'format', 'analyze']);
  });

  test('wrong SDK stops before dependency resolution', () async {
    final result = await run('ci', environment: {'ANISTAR_GATE_VERSION': '0.0.0'});
    expect(result.exitCode, 1);
    expect(result.stderr, contains('Flutter SDK mismatch'));
    expect(trace.existsSync(), isFalse);
  });

  test('Flutter-only profile runs format, analysis, unit coverage and golden comparison in order', () async {
    final result = await run('ci');
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(trace.readAsLinesSync(), ['pub', 'format', 'analyze', 'unit', 'golden']);
  });
}

const _flutterStub = r'''
#!/usr/bin/env bash
set -euo pipefail
[[ ${1:-} == --no-version-check ]] && shift
case "$1" in
  --version) printf '{"frameworkVersion":"%s"}\n' "${ANISTAR_GATE_VERSION:?Expected SDK version is required}" ;;
  pub) echo pub >> "$ANISTAR_GATE_TRACE" ;;
  analyze) echo analyze >> "$ANISTAR_GATE_TRACE"; exit "${ANISTAR_GATE_ANALYZE_EXIT:-0}" ;;
  test)
    case " $* " in
      *" --tags=golden "*) echo golden >> "$ANISTAR_GATE_TRACE" ;;
      *) echo unit >> "$ANISTAR_GATE_TRACE" ;;
    esac ;;
  *) exit 90 ;;
esac
''';

const _dartStub = r'''
#!/usr/bin/env bash
set -euo pipefail
if [[ $1 == format ]]; then
  echo format >> "$ANISTAR_GATE_TRACE"
  exit "${ANISTAR_GATE_FORMAT_EXIT:-0}"
fi
exec __DART__ "$@"
''';
