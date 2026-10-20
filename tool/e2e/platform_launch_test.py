"""Flavor launch contracts exercised without Flutter, Xcode or devices."""
import base64
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]


def module(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'tool/environment' / f'{name}.py')
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


prepare = module('prepare')
ios_defines = module('ios_defines')


class PlatformLaunchTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        (self.root / 'env').mkdir()
        self.dev = self.root / 'env/dev.json'
        self.prod = self.root / 'env/prod.json'
        self.template = self.root / 'env/prod.example.json'
        self.dev.write_text('{"ANISTAR_MIRROR_URL":"https://dev.example/"}\n')
        self.template.write_text('{"ANISTAR_MIRROR_URL":"https://prod.example/"}\n')

    def test_prepare_copies_once_and_preserves_existing_bytes(self):
        prepare.prepare(self.root)
        self.assertEqual(self.prod.read_bytes(), self.template.read_bytes())
        local = b'{ "ANISTAR_MIRROR_URL": "https://local.example:8443/" }\n'
        self.prod.write_bytes(local)
        self.template.write_text('invalid replacement template')
        prepare.prepare(self.root)
        self.assertEqual(self.prod.read_bytes(), local)

    def test_missing_or_invalid_env_fails_without_copying_or_disclosing_values(self):
        for content in ('broken SECRET', '[]', '{}',
                        '{"ANISTAR_MIRROR_URL":"https://x/","PASSWORD":"SECRET"}',
                        *[json.dumps({'ANISTAR_MIRROR_URL': value}) for value in
                          ('http://x/', 'https://user:SECRET@x/', 'https://x/path',
                           'https://x/?SECRET', 'https://x/#SECRET', 'https://x:bad/',
                           'https://x:0/', 'https://x/ SECRET', 42)]):
            with self.subTest(content=content):
                self.dev.write_text(content)
                with self.assertRaises(ValueError) as error:
                    prepare.prepare(self.root)
                self.assertNotIn('SECRET', str(error.exception))
                self.assertFalse(self.prod.exists())
        self.dev.unlink()
        with self.assertRaises(ValueError):
            prepare.prepare(self.root)
        self.dev.write_text('{"ANISTAR_MIRROR_URL":"https://x/"}')
        self.template.unlink()
        with self.assertRaises(ValueError):
            prepare.prepare(self.root)

    def test_prepare_cli_diagnostics_do_not_echo_input(self):
        for error in (ValueError('dev.json: expected only ANISTAR_MIRROR_URL'), OSError('SECRET')):
            output = io.StringIO()
            with patch.object(prepare, 'prepare', side_effect=error), contextlib.redirect_stderr(output):
                self.assertEqual(prepare.main(), 1)
            self.assertNotIn('SECRET', output.getvalue())

    def test_stale_ios_test_and_flavor_defines_cannot_contaminate_normal_build(self):
        stale = ['ANISTAR_MIRROR_URL=https://localhost:1', 'FLUTTER_APP_FLAVOR=dev',
                 'ANISTAR_IOS_DIAGNOSTIC_PROFILE=tv', 'ANISTAR_LIVE_PASSWORD=SECRET',
                 'FLUTTER_BUILD_NAME=1.3.0', 'dart.vm.product=false']
        encoded = ','.join(base64.b64encode(value.encode()).decode() for value in stale)
        prepare.prepare(self.root)
        for flavor in ('dev', 'prod'):
            with self.subTest(flavor=flavor):
                result = [base64.b64decode(value).decode() for value in
                          ios_defines.compose(flavor, encoded, self.root).split(',')]
                self.assertCountEqual(result, [f'FLUTTER_APP_FLAVOR={flavor}',
                    f'ANISTAR_MIRROR_URL=https://{flavor}.example/',
                    'FLUTTER_BUILD_NAME=1.3.0', 'dart.vm.product=false'])
        with self.assertRaises(ValueError):
            ios_defines.compose('dev', 'not valid base64!', self.root)

    def test_ide_launch_uses_canonical_env_and_unsigned_debug(self):
        configurations = json.loads((ROOT / '.vscode/launch.json').read_text())['configurations']
        tasks = json.loads((ROOT / '.vscode/tasks.json').read_text())['tasks']
        task = next(item for item in tasks if item['label'] == 'env:prepare')
        self.assertEqual(task['command'], 'fvm')
        self.assertEqual(task['args'], ['dart', 'run', 'melos', 'run', 'env:prepare'])
        for flavor in ('dev', 'prod'):
            config = next(item for item in configurations
                          if item['program'] == f'lib/main_{flavor}.dart' and item['flutterMode'] == 'debug')
            self.assertEqual(config['preLaunchTask'], 'env:prepare')
            self.assertEqual(config['env']['ANISTAR_ANDROID_SIGNING_MODE'], 'unsigned')
            self.assertEqual(config['toolArgs'], ['--flavor', flavor,
                f'--dart-define-from-file=${{workspaceFolder}}/env/{flavor}.json'])
            self.assertNotIn('args', config)

    def test_cli_rejects_bad_env_before_launch_and_matches_ide_arguments(self):
        for directory in ('scripts', 'tool/environment', 'sdk/bin'):
            (self.root / directory).mkdir(parents=True)
        for source in ('scripts/flutter_app.sh', 'scripts/with_python.sh', 'tool/environment/prepare.py'):
            shutil.copy(ROOT / source, self.root / source)
        calls = self.root / 'calls.jsonl'
        flutter = self.root / 'sdk/bin/flutter'
        flutter.write_text('#!/usr/bin/env python3\nimport json,os,sys\n'
            'with open(os.environ["CALLS"],"a") as out: out.write(json.dumps('
            '{"args":sys.argv[1:],"signing":os.environ["ANISTAR_ANDROID_SIGNING_MODE"]})+"\\n")\n'
            'print("{}")\n')
        flutter.chmod(0o755)
        dart = self.root / 'sdk/bin/dart'
        dart.write_text('#!/bin/sh\ncat >/dev/null\n')
        dart.chmod(0o755)
        environment = {**os.environ, 'ANISTAR_FLUTTER_SDK': str(self.root / 'sdk'),
                       'ANISTAR_ANDROID_SIGNING_MODE': 'local', 'CALLS': str(calls)}
        for flavor in ('dev', 'prod'):
            process = subprocess.run(['bash', 'scripts/flutter_app.sh', 'run', flavor, 'debug', '-d', 'fixture'],
                cwd=self.root, env=environment, capture_output=True, text=True)
            self.assertEqual(process.returncode, 0, process.stderr)
            call = json.loads(calls.read_text().splitlines()[-1])
            self.assertEqual(call, {'args': ['--no-version-check', 'run', '--debug', '--flavor', flavor,
                '--target', f'lib/main_{flavor}.dart', f'--dart-define-from-file=env/{flavor}.json',
                '-d', 'fixture'], 'signing': 'unsigned'})
        calls.unlink()
        self.prod.write_text('SECRET malformed')
        process = subprocess.run(['bash', 'scripts/flutter_app.sh', 'run', 'prod', 'debug'],
            cwd=self.root, env=environment, capture_output=True, text=True)
        self.assertNotEqual(process.returncode, 0)
        self.assertNotIn('SECRET', process.stdout + process.stderr)
        self.assertTrue(all('--version' in json.loads(line)['args'] for line in calls.read_text().splitlines()))

    def test_optional_ios_prerequisites_fail_without_flutter_or_device_mutation(self):
        script = ROOT / 'scripts/e2e-ios.sh'
        for arguments in ([], ['bad', 'dev'], ['00000000-0000-0000-0000-000000000000', 'release']):
            result = subprocess.run(['bash', str(script), *arguments], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Usage:', result.stderr)
        pubspec = (ROOT / 'pubspec.yaml').read_text()
        for section in ('check:', 'test:e2e:'):
            match = re.search(r'^    ' + re.escape(section) + r'\n(.*?)(?=^    \S|\Z)',
                              pubspec, flags=re.MULTILINE | re.DOTALL)
            self.assertIsNotNone(match)
            body = match.group(1)
            self.assertTrue(body.strip())
            self.assertNotIn('e2e:ios', body)
            self.assertNotIn('e2e-ios.sh', body)
        self.assertTrue((ROOT / 'integration_test/ios_e2e_test.dart').is_file())

    def test_android_identity_labels_and_signing_pin_preserve_install_boundary(self):
        gradle = (ROOT / 'android/app/build.gradle.kts').read_text()
        self.assertRegex(gradle, r'namespace\s*=\s*"com\.anistar\.anistar_tv"')
        self.assertRegex(gradle, r'applicationId\s*=\s*"com\.anistar\.tv"')
        self.assertRegex(gradle, r'applicationIdSuffix\s*=\s*"\.dev"')
        for flavor, label in (('dev', 'AniStar TV Dev'), ('prod', 'AniStar TV')):
            self.assertRegex(gradle, re.escape(f'create("{flavor}")') +
                             r'[\s\S]*?resValue\("string", "app_name", "' + re.escape(label) + r'"\)')
        application = ET.parse(ROOT / 'android/app/src/main/AndroidManifest.xml').getroot().find('application')
        self.assertEqual(application.attrib['{http://schemas.android.com/apk/res/android}label'], '@string/app_name')
        current = json.loads((ROOT / 'android/signing-certificate.json').read_text())
        original = json.loads(subprocess.check_output(
            ['git', 'show', 'HEAD:android/signing-certificate.json'], cwd=ROOT, text=True))
        self.assertEqual(current['applicationId'], 'com.anistar.tv')
        self.assertEqual(current['certificateSha256'], original['certificateSha256'])

    def test_ios_scheme_modes_and_version_follow_flutter(self):
        for flavor in ('dev', 'prod'):
            scheme = ET.parse(ROOT / f'ios/Runner.xcodeproj/xcshareddata/xcschemes/{flavor}.xcscheme').getroot()
            for action, mode in (('TestAction', 'Debug'), ('LaunchAction', 'Debug'),
                                 ('AnalyzeAction', 'Debug'), ('ProfileAction', 'Profile'),
                                 ('ArchiveAction', 'Release')):
                self.assertEqual(scheme.find(action).attrib['buildConfiguration'], f'{mode}-{flavor}')
        with (ROOT / 'ios/Runner/Info.plist').open('rb') as source:
            info = plistlib.load(source)
        self.assertEqual(info['CFBundleIdentifier'], '$(PRODUCT_BUNDLE_IDENTIFIER)')
        self.assertEqual(info['CFBundleShortVersionString'], '$(FLUTTER_BUILD_NAME)')
        self.assertEqual(info['CFBundleVersion'], '$(FLUTTER_BUILD_NUMBER)')
        self.assertNotIn('NSAllowsArbitraryLoads', info.get('NSAppTransportSecurity', {}))

    def test_ios_missing_simulator_and_phone_tv_diagnostic_fail_before_flutter(self):
        binary = self.root / 'bin'
        binary.mkdir()
        device = '00000000-0000-0000-0000-000000000000'
        for name, body in {'uname': 'echo Darwin', 'xcrun':
            "echo '{\"devices\":{\"iOS\":[{\"udid\":\"" + device +
            "\",\"isAvailable\":true,\"deviceTypeIdentifier\":\"com.apple.iPhone\"}]}}'"}.items():
            path = binary / name
            path.write_text('#!/bin/sh\n' + body + '\n')
            path.chmod(0o755)
        environment = {**os.environ, 'PATH': str(binary) + os.pathsep + os.environ['PATH']}
        for selected, profile, expected in ((device.replace('000000000000', '111111111111'), 'mobile',
                                            'must already be booted'),
                                           (device, 'tv', 'requires an iPad')):
            result = subprocess.run(['bash', str(ROOT / 'scripts/e2e-ios.sh'), selected, 'dev', profile],
                                    env=environment, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(expected, result.stderr)

    def test_xcode_backend_replaces_stale_entry_and_only_allows_explicit_debug_fixture(self):
        for directory in ('scripts', 'tool/environment', 'ios', 'sdk/packages/flutter_tools/bin'):
            (self.root / directory).mkdir(parents=True)
        for source in ('scripts/with_python.sh', 'tool/environment/prepare.py',
                       'tool/environment/ios_defines.py'):
            shutil.copy(ROOT / source, self.root / source)
        backend = self.root / 'sdk/packages/flutter_tools/bin/xcode_backend.sh'
        backend.write_text('#!/bin/sh\nprintf "%s\\n%s\\n" "$FLUTTER_TARGET" "$DART_DEFINES"\n')
        base = {**os.environ, 'SRCROOT': str(self.root / 'ios'), 'FLUTTER_ROOT': str(self.root / 'sdk'),
                'FLUTTER_TARGET': 'integration_test/stale_live.dart', 'ANISTAR_FLAVOR': 'prod',
                'CONFIGURATION': 'Debug-prod', 'DART_DEFINES': ''}
        command = ['sh', str(ROOT / 'ios/Flutter/flutter_backend.sh'), 'build']
        result = subprocess.run(command, env=base, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('lib/main_prod.dart', result.stdout)
        self.assertNotIn('stale_live', result.stdout)
        for configuration, target, success in (
                ('Debug-prod', 'integration_test/ios_e2e_test.dart', True),
                ('Release-prod', 'integration_test/ios_e2e_test.dart', False),
                ('Debug-prod', 'integration_test/stale_live.dart', False)):
            result = subprocess.run(command, env={**base, 'CONFIGURATION': configuration,
                'ANISTAR_IOS_FIXTURE_TARGET': target}, capture_output=True, text=True)
            self.assertEqual(result.returncode == 0, success, result.stderr)
            if success:
                self.assertIn(target, result.stdout)


if __name__ == '__main__':
    unittest.main()
