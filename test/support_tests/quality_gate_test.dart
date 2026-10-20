import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  late Directory fixture;
  late File trace;
  late String expectedVersion;
  late String realDart;

  setUp(() async {
    final pin = (jsonDecode(File('.fvmrc').readAsStringSync()) as Map<String, Object?>)['flutter'];
    if (pin is! String) {
      throw const FormatException('Missing Flutter SDK pin');
    }
    expectedVersion = pin;
    fixture = Directory.systemTemp.createTempSync('anistar-quality-gate-');
    addTearDown(() => fixture.deleteSync(recursive: true));
    for (final path in [
      'scripts',
      'tool/quality',
      'lib',
      'infrastructure',
      'test',
      'integration_test',
      'sdk/bin',
      'bin',
    ]) {
      Directory('${fixture.path}/$path').createSync(recursive: true);
    }
    final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
    File('${fixture.path}/pubspec.yaml').writeAsStringSync(
      jsonEncode({
        'name': 'quality_fixture',
        'environment': {'sdk': '^3.13.0'},
        'dev_dependencies': {'melos': '7.8.0'},
        'melos': pubspec['melos'],
      }),
    );
    Directory('${fixture.path}/.dart_tool').createSync();
    File('.dart_tool/package_config.json').copySync('${fixture.path}/.dart_tool/package_config.json');
    File('scripts/with_python.sh').copySync('${fixture.path}/scripts/with_python.sh');
    for (final scanner in ['gitleaks', 'osv', 'semgrep']) {
      File('${fixture.path}/scripts/security_$scanner.sh').writeAsStringSync(
        'echo $scanner >> "\$ANISTAR_GATE_TRACE"\nexit "\${ANISTAR_SECURITY_${scanner.toUpperCase()}_EXIT:-0}"\n',
      );
    }
    File('${fixture.path}/scripts/test_tooling.sh').writeAsStringSync('echo tooling >> "\$ANISTAR_GATE_TRACE"\n');
    Directory('${fixture.path}/tool/version').createSync(recursive: true);
    File('${fixture.path}/tool/version/app_version.py').writeAsStringSync(_versionStub);
    File('tool/quality/verify_sdk.dart').copySync('${fixture.path}/tool/quality/verify_sdk.dart');
    File('.fvmrc').copySync('${fixture.path}/.fvmrc');
    File('${fixture.path}/lib/example.dart').writeAsStringSync('void main() {}\n');
    trace = File('${fixture.path}/trace');
    final flutter = File('${fixture.path}/sdk/bin/flutter')..writeAsStringSync(_flutterStub.trimLeft());
    final sdk = Directory(Platform.environment['ANISTAR_FLUTTER_SDK'] ?? '.fvm/flutter_sdk').resolveSymbolicLinksSync();
    realDart = '$sdk/bin/dart';
    Directory('${fixture.path}/.fvm').createSync();
    Link('${fixture.path}/.fvm/flutter_sdk').createSync(sdk);
    final dart = File('${fixture.path}/sdk/bin/dart')
      ..writeAsStringSync(_dartStub.trimLeft().replaceFirst('__DART__', "'$sdk/bin/dart'"));
    final dcm = File('${fixture.path}/bin/dcm')..writeAsStringSync(_dcmStub.trimLeft());
    final forbiddenHook = File('${fixture.path}/bin/lefthook')..writeAsStringSync('#!/bin/sh\nexit 99\n');
    final git = await Process.run('git', ['init', '-q'], workingDirectory: fixture.path);
    expect(git.exitCode, 0, reason: git.stderr.toString());
    final chmod = await Process.run('chmod', ['+x', flutter.path, dart.path, dcm.path, forbiddenHook.path]);
    expect(chmod.exitCode, 0, reason: chmod.stderr.toString());
  });

  Future<ProcessResult> run(
    String mode, {
    Map<String, String> environment = const {},
    List<String> arguments = const [],
  }) => Process.run(
    realDart,
    ['run', 'melos', 'run', mode, ...arguments],
    workingDirectory: fixture.path,
    environment: {
      'PATH': '${fixture.path}/bin:${Platform.environment['PATH']}',
      'ANISTAR_FLUTTER_SDK': '${fixture.path}/sdk',
      'ANISTAR_TEST_SEED': '20261010',
      'ANISTAR_GATE_TRACE': trace.path,
      'ANISTAR_GATE_VERSION': expectedVersion,
      ...environment,
    },
  );

  test('format failure stops before analyzer and reports its failing stage', () async {
    final result = await run('check', environment: {'ANISTAR_GATE_FORMAT_EXIT': '17'});
    expect(result.exitCode, isNot(0), reason: result.stderr.toString());
    expect('${result.stdout}${result.stderr}', contains('quality:format-check'));
    expect(trace.readAsLinesSync(), ['pub', 'format']);
  });

  test('analyzer failure stops before DCM and tests and reports its failing stage', () async {
    final result = await run('check', environment: {'ANISTAR_GATE_ANALYZE_EXIT': '23'});
    expect(result.exitCode, isNot(0), reason: result.stderr.toString());
    expect('${result.stdout}${result.stderr}', contains('analyze'));
    expect(trace.readAsLinesSync(), ['pub', 'format', 'analyze']);
  });

  test('wrong SDK stops before dependency resolution', () async {
    final result = await run('check:flutter', environment: {'ANISTAR_GATE_VERSION': '0.0.0'});
    expect(result.exitCode, isNot(0));
    expect('${result.stdout}${result.stderr}', contains('Flutter SDK mismatch'));
    expect(trace.existsSync(), isFalse);
  });

  test('invalid seed stops before SDK or dependency commands', () async {
    final result = await run('check', environment: {'ANISTAR_TEST_SEED': '-1'});
    expect(result.exitCode, isNot(0));
    expect('${result.stdout}${result.stderr}', contains('ANISTAR_TEST_SEED'));
    expect(trace.existsSync(), isFalse);
  });

  test('native DCM failure prevents unit, golden, tooling and version checks', () async {
    final result = await run('check', environment: {'ANISTAR_GATE_DCM_EXIT': '29'});
    expect(result.exitCode, isNot(0));
    expect('${result.stdout}${result.stderr}', contains('dcm'));
    expect(trace.readAsLinesSync(), ['pub', 'format', 'analyze', 'dcm']);
  });

  test('lockfile failure prevents every quality stage', () async {
    final result = await run('check', environment: {'ANISTAR_GATE_PUB_EXIT': '31'});
    expect(result.exitCode, isNot(0));
    expect(trace.readAsLinesSync(), ['pub']);
  });

  test('unit and golden failures stop subsequent stages', () async {
    for (final stage in ['unit', 'golden']) {
      trace.writeAsStringSync('');
      final result = await run('check', environment: {'ANISTAR_GATE_TEST_FAILURE': stage});
      expect(result.exitCode, isNot(0), reason: '${result.stdout}${result.stderr}');
      expect(trace.readAsLinesSync(), ['pub', 'format', 'analyze', 'dcm', 'unit', if (stage == 'golden') 'golden']);
    }
  });

  test('Melos owns full stage order independently of Lefthook and prepares once', () async {
    final result = await run('check');
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(trace.readAsLinesSync(), ['pub', 'format', 'analyze', 'dcm', 'unit', 'golden', 'tooling', 'version']);
  });

  test('individual profiles prepare once and run only their selected stage', () async {
    const stages = {
      'format:check': 'format',
      'format': 'format',
      'analyze': 'analyze',
      'dcm': 'dcm',
      'test:unit': 'unit',
      'test:coverage': 'unit',
      'test:goldens': 'golden',
    };
    for (final profile in stages.entries) {
      trace.writeAsStringSync('');
      final result = await run(
        profile.key,
        environment: {
          'ANISTAR_TEST_SEED': '1337',
          'ANISTAR_GATE_FORMAT_MODE': profile.key == 'format' ? 'write' : 'check',
        },
      );
      expect(result.exitCode, 0, reason: '${profile.key}: ${result.stdout}${result.stderr}');
      expect(trace.readAsLinesSync(), ['pub', profile.value]);
    }
  });

  test('Flutter-only profile runs format, analysis, unit coverage and golden comparison in order', () async {
    final result = await run('check:flutter');
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(trace.readAsLinesSync(), ['pub', 'format', 'analyze', 'unit', 'golden']);
  });

  test('all preserved aliases and exactly the requested private scripts remain discoverable', () async {
    final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
    final melos = pubspec['melos'] as YamlMap;
    final scripts = melos['scripts'] as YamlMap;
    const preserved =
        '''analyze clean clean:all format format:check fix fix:check dcm dcm:fix fix:all check check:flutter get upgrade upgrade:major outdated deps workspace doctor devices emulators generate build_runner generate:assets watch generate:clean build_runner:clean generate:branding generate:icon generate:splash generate:e2e-media check:apk graph:update graph:check vcs:check version:show version:check version:plan version:set test:unit test:goldens test:goldens:update test:coverage test:tooling test:e2e test:e2e:tv test:e2e:mobile test:e2e:live test:network:live run:dev build:android:dev:apk build:android:dev:bundle build:android:dev:apk:debug run:prod build:android:prod:apk build:android:prod:bundle build:android:prod:apk:debug''';
    const private =
        '''test:e2e:tv test:e2e:mobile test:e2e:live test:network:live generate:e2e-media check:apk graph:update graph:check version:check quality:prepare quality:format quality:format-check quality:analyze quality:dcm quality:unit quality:goldens quality:goldens:update''';
    const securityNames = ['security:secrets', 'security:deps', 'security:code', 'security'];
    final privateNames = private.split(' ');
    expect(scripts.keys.toSet(), {
      ...preserved.split(' '),
      ...privateNames,
      ...securityNames,
      'build:android:prod:apk:unsigned',
      'env:prepare',
      'test:e2e:ios',
      'build:ios:dev:simulator',
      'build:ios:prod:simulator',
    });
    expect(
      scripts.entries.where((entry) => (entry.value as YamlMap)['private'] == true).map((entry) => entry.key).toSet(),
      privateNames.toSet(),
    );
    for (final entry in {
      'build_runner': 'generate',
      'generate:assets': 'generate',
      'build_runner:clean': 'generate:clean',
      'generate:icon': 'generate:branding',
      'generate:splash': 'generate:branding',
    }.entries) {
      expect((scripts[entry.key] as YamlMap)['run'], 'dart run melos run ${entry.value}');
    }
    final publicList = await run('--list');
    final completeList = await run('--list', arguments: ['--include-private']);
    expect(publicList.exitCode, 0, reason: '${publicList.stdout}${publicList.stderr}');
    expect(completeList.exitCode, 0, reason: '${completeList.stdout}${completeList.stderr}');
    for (final name in scripts.keys.cast<String>()) {
      final listedName = RegExp('^${RegExp.escape(name)}\\s', multiLine: true);
      expect(listedName.hasMatch(completeList.stdout.toString()), isTrue, reason: name);
      expect(listedName.hasMatch(publicList.stdout.toString()), !privateNames.contains(name), reason: name);
    }
    final denied = await run('version:check');
    expect(denied.exitCode, isNot(0));
    expect(trace.existsSync(), isFalse);
    final allowed = await run('version:check', arguments: ['--include-private']);
    expect(allowed.exitCode, 0, reason: '${allowed.stdout}${allowed.stderr}');
    expect(trace.readAsLinesSync(), ['version']);
  });

  test('security commands run separately and aggregate stops at the first failure', () async {
    const profiles = {'security:secrets': 'gitleaks', 'security:deps': 'osv', 'security:code': 'semgrep'};
    for (final profile in profiles.entries) {
      trace.writeAsStringSync('');
      final result = await run(profile.key);
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(trace.readAsLinesSync(), [profile.value]);
    }
    trace.writeAsStringSync('');
    final success = await run('security');
    expect(success.exitCode, 0, reason: '${success.stdout}${success.stderr}');
    expect(trace.readAsLinesSync(), ['gitleaks', 'osv', 'semgrep']);
    for (final scanner in ['gitleaks', 'osv', 'semgrep']) {
      trace.writeAsStringSync('');
      final failure = await run('security', environment: {'ANISTAR_SECURITY_${scanner.toUpperCase()}_EXIT': '37'});
      expect(failure.exitCode, isNot(0));
      expect(trace.readAsLinesSync(), [
        'gitleaks',
        if (scanner != 'gitleaks') 'osv',
        if (scanner == 'semgrep') 'semgrep',
      ]);
    }
  });

  test('VS Code shell and process callers opt into private Melos scripts', () {
    final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
    final scripts = (pubspec['melos'] as YamlMap)['scripts'] as YamlMap;
    final configuration = jsonDecode(File('.vscode/tasks.json').readAsStringSync()) as Map<String, Object?>;
    final checkedScripts = <String>{};
    final tasks = configuration['tasks'];
    if (tasks is! List<Object?>) {
      fail('VS Code tasks must be a list');
    }
    for (final task in tasks) {
      if (task is! Map<String, Object?>) {
        fail('VS Code task must be an object');
      }
      final command = task['command'];
      if (command is! String) {
        fail('VS Code task command must be a string');
      }
      final arguments = (task['args'] as List<Object?>?)?.cast<String>() ?? const <String>[];
      final tokens = [if (task['type'] == 'shell') ...command.split(RegExp(r'\s+')) else command, ...arguments];
      final melosIndex = tokens.indexOf('melos');
      if (melosIndex < 0 || tokens[melosIndex + 1] != 'run') {
        continue;
      }
      final name = tokens[melosIndex + 2];
      final script = scripts[name] as YamlMap;
      if (script['private'] != true) {
        continue;
      }
      final options = tokens.skip(melosIndex + 3).takeWhile((token) => token != '--');
      expect(options, contains('--include-private'), reason: '${task['label']}: $name');
      checkedScripts.add(name);
    }
    expect(checkedScripts, {'test:e2e:tv', 'test:e2e:mobile', 'test:e2e:live'});
  });
}

const _flutterStub = r'''
#!/usr/bin/env bash
set -euo pipefail
[[ ${1:-} == --no-version-check ]] && shift
case "$1" in
  --version) printf '{"frameworkVersion":"%s"}\n' "${ANISTAR_GATE_VERSION:?Expected SDK version is required}" ;;
  pub) [[ " $* " == *" --enforce-lockfile "* ]] || exit 91; echo pub >> "$ANISTAR_GATE_TRACE"; exit "${ANISTAR_GATE_PUB_EXIT:-0}" ;;
  analyze) [[ " $* " == *" --no-pub --fatal-infos "* ]] || exit 92; echo analyze >> "$ANISTAR_GATE_TRACE"; exit "${ANISTAR_GATE_ANALYZE_EXIT:-0}" ;;
  test)
    [[ " $* " == *" --no-pub "* ]] || exit 93
    [[ " $* " == *" --test-randomize-ordering-seed=$ANISTAR_TEST_SEED "* ]] || exit 94
    case " $* " in
      *" --tags=golden "*) [[ " $* " == *" --concurrency=1 "* && " $* " != *" --update-goldens "* ]] || exit 95; stage=golden ;;
      *) [[ " $* " == *" --coverage "* && " $* " == *" --concurrency=4 "* && " $* " == *" --exclude-tags=golden "* ]] || exit 96; stage=unit ;;
    esac
    echo "$stage" >> "$ANISTAR_GATE_TRACE"
    if [[ ${ANISTAR_GATE_TEST_FAILURE:-} == "$stage" ]]; then exit 32; fi ;;
  *) exit 90 ;;
esac
''';

const _dartStub = r'''
#!/usr/bin/env bash
set -euo pipefail
if [[ $1 == format ]]; then
  if [[ ${ANISTAR_GATE_FORMAT_MODE:-check} == check ]]; then
    [[ " $* " == *" --output=none --set-exit-if-changed "* ]] || exit 98
  else
    [[ " $* " != *" --output=none "* ]] || exit 98
  fi
  echo format >> "$ANISTAR_GATE_TRACE"
  exit "${ANISTAR_GATE_FORMAT_EXIT:-0}"
fi
exec __DART__ "$@"
''';

const _dcmStub = r'''
#!/usr/bin/env bash
set -euo pipefail
[[ " $* " == *" --fatal-style --fatal-warnings --no-analytics "* ]] || exit 97
echo dcm >> "$ANISTAR_GATE_TRACE"
exit "${ANISTAR_GATE_DCM_EXIT:-0}"
''';

const _versionStub = r'''
import os
with open(os.environ['ANISTAR_GATE_TRACE'], 'a') as trace:
    trace.write('version\n')
''';
